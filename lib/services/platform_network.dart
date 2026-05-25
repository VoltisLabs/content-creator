import 'dart:io';

import 'local_address.dart';
import 'local_share_host.dart';

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

/// Best hostname/IP for LAN share links on this device.
Future<String?> resolveShareHost() async {
  final ip = await primaryLanIPv4();

  if (prefersIpShareHost) return ip;

  final friendly = sanitizeLocalShareHost();
  if (friendly != null && !isLoopbackShareHost(friendly)) {
    return friendly;
  }

  return ip;
}

/// Optional secondary link (e.g. IP fallback when a friendly hostname is shown).
Future<String?> resolveShareHostFallback(String primaryHost) async {
  if (isLoopbackShareHost(primaryHost)) return null;
  final ip = await primaryLanIPv4();
  if (ip == null || ip == primaryHost) return null;
  return ip;
}

/// URIs to try when importing, in order (original first, then fallbacks).
Future<List<Uri>> importUriCandidates(Uri uri) async {
  final seen = <String>{};
  final candidates = <Uri>[];

  void add(Uri candidate) {
    final key = candidate.toString();
    if (seen.add(key)) candidates.add(candidate);
  }

  add(uri);

  final host = uri.host.toLowerCase();

  if (isLoopbackShareHost(host)) {
    if (Platform.isMacOS) {
      add(uri.replace(host: '127.0.0.1'));
      final ip = await primaryLanIPv4();
      if (ip != null) {
        add(uri.replace(host: ip));
      }
    }
    return candidates;
  }

  return candidates;
}

String importConnectionHint(Uri uri) {
  if (isLoopbackShareHost(uri.host)) {
    return 'This link uses localhost and only works on the sender\'s device. '
        'Copy a fresh link from the sender — it should start with http://192.168…';
  }
  if (Platform.isIOS || Platform.isAndroid) {
    return 'Could not connect. Make sure both devices are on the same Wi‑Fi '
        'and the sender copied a new link (with an IP address like 192.168…).';
  }
  return 'Could not connect. Make sure you are on the same Wi‑Fi as the sender.';
}
