import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

const String _webClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
const String _iosClientId = String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');

bool contentCalendarGoogleSignInConfigured() {
  if (kIsWeb) return false;
  if (Platform.isIOS) {
    return _webClientId.isNotEmpty && _iosClientId.isNotEmpty;
  }
  return _webClientId.isNotEmpty;
}
