import 'dart:io';

import 'local_address.dart';

/// True when running inside the iOS Simulator (not a physical device).
bool get isIOSSimulator {
  if (!Platform.isIOS) return false;
  return Platform.environment.containsKey('SIMULATOR_DEVICE_NAME') ||
      Platform.environment.containsKey('SIMULATOR_UDID') ||
      Platform.environment.containsKey('SIMULATOR_MODEL_IDENTIFIER');
}

/// True when running inside an Android emulator.
bool get isAndroidEmulator {
  if (!Platform.isAndroid) return false;
  return Platform.environment.containsKey('ANDROID_EMULATOR') ||
      Platform.environment['EMU'] == '1';
}

/// Mobile devices should always share via LAN IP — their hostname is usually `localhost`.
bool get prefersIpShareHost =>
    Platform.isIOS || Platform.isAndroid || isAndroidEmulator;

bool isLoopbackShareHost(String host) {
  final h = host.toLowerCase();
  return h == 'localhost' ||
      h == 'localhost.local' ||
      h.startsWith('127.') ||
      h.endsWith('.localhost');
}

bool _isLocalHostname(String host) {
  final h = host.toLowerCase();
  return h.endsWith('.local') || h.contains('.local.');
}

/// LAN IP for share links — reliable across iPhone, Mac, and desktop.
Future<String?> resolveShareHost() async => primaryLanIPv4();

/// Optional secondary link when a friendly hostname was shown elsewhere.
Future<String?> resolveShareHostFallback(String primaryHost) async {
  if (isLoopbackShareHost(primaryHost)) return null;
  final ip = await primaryLanIPv4();
  if (ip == null || ip == primaryHost) return null;
  return ip;
}

/// URIs to try when importing (original link, then IP / loopback fallbacks).
Future<List<Uri>> importUriCandidates(Uri uri) async {
  final seen = <String>{};
  final candidates = <Uri>[];

  void add(Uri candidate) {
    final key = candidate.toString();
    if (seen.add(key)) candidates.add(candidate);
  }

  add(uri);

  final host = uri.host.toLowerCase();
  final ip = await primaryLanIPv4();

  if (isLoopbackShareHost(host)) {
    add(uri.replace(host: '127.0.0.1'));
    if (ip != null) add(uri.replace(host: ip));
    return candidates;
  }

  if (ip != null && host != ip) {
    add(uri.replace(host: ip));
  }

  if (_isLocalHostname(host) && ip != null) {
    add(uri.replace(host: ip));
  }

  if (Platform.isMacOS && ip != null && !isLoopbackShareHost(host) && host != ip) {
    add(uri.replace(host: '127.0.0.1'));
  }

  return candidates;
}

String importConnectionHint(Uri uri) {
  if (isLoopbackShareHost(uri.host)) {
    return 'This link uses localhost and only works on the sender\'s device. '
        'Copy a fresh link from the sender - it should start with http://192.168…';
  }
  if (_isLocalHostname(uri.host)) {
    return 'This link uses a computer name (.local) which often fails on phones. '
        'Ask the sender to copy a new link - it should show an IP like http://192.168…';
  }
  if (Platform.isIOS || Platform.isAndroid) {
    return 'Could not connect. Make sure both devices are on the same Wi‑Fi '
        'and the sender copied a new link (with an IP address like 192.168…).';
  }
  return 'Could not connect. Make sure you are on the same Wi‑Fi as the sender.';
}
