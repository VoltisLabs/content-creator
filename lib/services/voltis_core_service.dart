import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/voltis_core_config.dart';
import '../models/voltis_plan.dart';
import 'content_calendar_google_auth.dart';
import 'voltis_core_graphql.dart';

/// Voltis Core identity + entitlements for Content Calendar (GraphQL + JWT).
class VoltisCoreService {
  VoltisCoreService._();

  static final VoltisCoreService instance = VoltisCoreService._();

  static const _kAccess = 'vl_access_token';
  static const _kRefresh = 'vl_refresh_token';
  static const _kEmail = 'vl_account_email';

  final _gql = VoltisCoreGraphql.instance;

  bool _initialized = false;
  bool contentCalendarPro = false;
  VoltisPlanTier planTier = VoltisPlanTier.free;
  String? _accessToken;
  String? _refreshToken;
  String? _email;

  bool get isConfigured => VoltisCoreConfig.isConfigured;

  bool get isSignedIn =>
      _accessToken != null && _accessToken!.isNotEmpty;

  String? get email => _email;

  String? get accessToken => _accessToken;

  Future<void> initialize() async {
    if (!isConfigured || _initialized) return;
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString(_kAccess);
    _refreshToken = prefs.getString(_kRefresh);
    _email = prefs.getString(_kEmail);
    _initialized = true;
  }

  Future<void> _persistSession({
    required String accessToken,
    required String refreshToken,
    required String email,
  }) async {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    _email = email;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kAccess, accessToken);
    await prefs.setString(_kRefresh, refreshToken);
    await prefs.setString(_kEmail, email);
  }

  Future<void> syncFromSession() async {
    if (!isSignedIn) {
      contentCalendarPro = false;
      return;
    }
    await refreshEntitlements();
  }

  Future<String?> signInWithPassword({
    required String email,
    required String password,
  }) async {
    _requireReady();
    try {
      final data = await _gql.query(
        r'''
        mutation Login($email: String!, $password: String!) {
          login(email: $email, password: $password) {
            accessToken
            refreshToken
            user { email }
          }
        }
        ''',
        variables: {'email': email.trim(), 'password': password},
      );
      final login = data['login'] as Map<String, dynamic>?;
      if (login == null) return 'Sign-in failed.';
      await _persistSession(
        accessToken: login['accessToken'] as String,
        refreshToken: login['refreshToken'] as String,
        email: (login['user'] as Map)['email'] as String? ?? email.trim(),
      );
      await refreshEntitlements();
      return null;
    } on VoltisGraphqlException catch (e) {
      return e.message;
    } catch (e) {
      return _friendlyNetworkError(e);
    }
  }

  Future<String?> signUpWithPassword({
    required String email,
    required String password,
  }) async {
    _requireReady();
    try {
      await _gql.query(
        r'''
        mutation Register($email: String!, $password: String!) {
          register(email: $email, password: $password) {
            success
            needsVerification
            message
          }
        }
        ''',
        variables: {'email': email.trim(), 'password': password},
      );
      return 'Check your email for a 6-digit verification code, then sign in.';
    } on VoltisGraphqlException catch (e) {
      return e.message;
    } catch (e) {
      return _friendlyNetworkError(e);
    }
  }

  Future<String?> signInWithGoogle() async {
    if (!contentCalendarGoogleSignInConfigured()) {
      return 'Google sign-in is not configured on this build.';
    }
    _requireReady();
    try {
      await GoogleSignIn.instance.initialize(
        clientId: !kIsWeb && Platform.isIOS ? _iosClientId : null,
        serverClientId: _webClientId,
      );
      if (!GoogleSignIn.instance.supportsAuthenticate()) {
        return 'Google sign-in is not supported on this device.';
      }
      final account = await GoogleSignIn.instance.authenticate(
        scopeHint: const ['email', 'profile', 'openid'],
      );
      final idToken = account.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        return 'Google did not return an ID token.';
      }
      final data = await _gql.query(
        r'''
        mutation Google($idToken: String!) {
          signInWithGoogle(idToken: $idToken) {
            accessToken
            refreshToken
            user { email }
          }
        }
        ''',
        variables: {'idToken': idToken},
      );
      final payload = data['signInWithGoogle'] as Map<String, dynamic>?;
      if (payload == null) return 'Google sign-in failed.';
      await _persistSession(
        accessToken: payload['accessToken'] as String,
        refreshToken: payload['refreshToken'] as String,
        email: (payload['user'] as Map)['email'] as String? ?? '',
      );
      await refreshEntitlements();
      return null;
    } on VoltisGraphqlException catch (e) {
      return e.message;
    } on Object {
      return 'Google sign-in was cancelled or failed.';
    }
  }

  Future<void> signOut() async {
    contentCalendarPro = false;
    planTier = VoltisPlanTier.free;
    _accessToken = null;
    _refreshToken = null;
    _email = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kAccess);
    await prefs.remove(_kRefresh);
    await prefs.remove(_kEmail);
    if (contentCalendarGoogleSignInConfigured()) {
      try {
        await GoogleSignIn.instance.signOut();
      } on Object {
        // Ignore
      }
    }
  }

  Future<bool> refreshEntitlements() async {
    contentCalendarPro = false;
    planTier = VoltisPlanTier.free;
    final token = accessToken;
    if (token == null || token.isEmpty) return false;

    final uri = Uri.parse(
      '${VoltisCoreConfig.voltisCoreUrl}/entitlements',
    ).replace(queryParameters: {'app_id': VoltisCoreConfig.appId});

    try {
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      if (response.statusCode == 401 && _refreshToken != null) {
        final renewed = await _tryRefreshSession();
        if (renewed) return refreshEntitlements();
      }
      if (response.statusCode != 200) return false;
      final body = jsonDecode(response.body);
      if (body is Map<String, dynamic>) {
        contentCalendarPro = body['content_calendar_pro'] == true;
        planTier = VoltisPlanTierX.fromApiValue(
          body['content_calendar_plan'] as String? ??
              body['plan'] as String? ??
              (contentCalendarPro ? 'six_months' : 'free'),
        );
        if (!contentCalendarPro && planTier.isPaid) {
          contentCalendarPro = true;
        }
        return contentCalendarPro;
      }
    } on Object {
      return false;
    }
    return false;
  }

  Future<bool> _tryRefreshSession() async {
    final refresh = _refreshToken;
    if (refresh == null || refresh.isEmpty) return false;
    try {
      final data = await _gql.query(
        r'''
        mutation Refresh($refreshToken: String!) {
          refreshToken(refreshToken: $refreshToken) {
            accessToken
            refreshToken
            user { email }
          }
        }
        ''',
        variables: {'refreshToken': refresh},
      );
      final payload = data['refreshToken'] as Map<String, dynamic>?;
      if (payload == null) return false;
      await _persistSession(
        accessToken: payload['accessToken'] as String,
        refreshToken: payload['refreshToken'] as String,
        email: (payload['user'] as Map)['email'] as String? ?? _email ?? '',
      );
      return true;
    } on Object {
      await signOut();
      return false;
    }
  }

  void _requireReady() {
    if (!_initialized) {
      throw StateError('Voltis Core is not initialized.');
    }
  }

  String _friendlyNetworkError(Object error) {
    final msg = error.toString();
    if (msg.contains('CERTIFICATE_VERIFY_FAILED') ||
        msg.contains('HandshakeException')) {
      return 'Could not reach Voltis Core securely. Check your connection and try again.';
    }
    return msg;
  }
}

const String _webClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
const String _iosClientId = String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');
