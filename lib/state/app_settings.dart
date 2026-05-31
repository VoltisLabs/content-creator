import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/voltis_plan.dart';
import '../services/subscription_service.dart';

/// Persisted account + Voltis Core entitlement state for UI.
class AppSettings extends ChangeNotifier {
  AppSettings._(this._prefs);

  static const _kAccountEmail = 'content_calendar.accountEmail';
  static const _kContentCalendarPro = 'content_calendar.contentCalendarPro';
  static const _kPlanTier = 'content_calendar.planTier';

  final SharedPreferences _prefs;

  static Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return AppSettings._(prefs);
  }

  String? get accountEmail {
    final v = _prefs.getString(_kAccountEmail);
    return v == null || v.isEmpty ? null : v;
  }

  bool get isSignedIn => accountEmail != null;

  bool get contentCalendarPro => _prefs.getBool(_kContentCalendarPro) ?? false;

  VoltisPlanTier get planTier =>
      VoltisPlanTierX.fromApiValue(_prefs.getString(_kPlanTier));

  /// Label for UI — Pro from Voltiscore even when plan id is not set yet.
  String get planLabel => VoltisPlanTierX.displayLabel(
        contentCalendarPro: contentCalendarPro,
        planTier: planTier,
      );

  Future<void> setContentCalendarPro(bool value) async {
    await _prefs.setBool(_kContentCalendarPro, value);
    notifyListeners();
  }

  Future<void> setPlanTier(VoltisPlanTier tier) async {
    if (tier == VoltisPlanTier.free) {
      await _prefs.remove(_kPlanTier);
    } else {
      await _prefs.setString(_kPlanTier, tier.name);
    }
    notifyListeners();
  }

  Future<void> setAccountEmail(String? email) async {
    if (email == null || email.isEmpty) {
      await _prefs.remove(_kAccountEmail);
    } else {
      await _prefs.setString(_kAccountEmail, email);
    }
    notifyListeners();
  }

  Future<void> syncFromVoltis({
    required bool contentCalendarPro,
    required VoltisPlanTier planTier,
  }) async {
    await setContentCalendarPro(contentCalendarPro);
    await setPlanTier(planTier);
    await SubscriptionService.instance
        .setCoreProEntitlement(contentCalendarPro);
  }
}

class AppSettingsScope extends InheritedNotifier<AppSettings> {
  const AppSettingsScope({
    super.key,
    required AppSettings settings,
    required super.child,
  }) : super(notifier: settings);

  static AppSettings of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<AppSettingsScope>();
    assert(scope != null, 'No AppSettingsScope found in widget tree');
    return scope!.notifier!;
  }

  static AppSettings read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<AppSettingsScope>();
    assert(scope != null, 'No AppSettingsScope found in widget tree');
    return scope!.notifier!;
  }
}
