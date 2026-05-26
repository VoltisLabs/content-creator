import 'dart:io';

import 'package:network_info_plus/network_info_plus.dart';

/// Best-effort Wi‑Fi IPv4 for LAN share links (Pinnacle-style discovery).
Future<String?> localWifiIPv4() async {
  final info = NetworkInfo();
  try {
    final ip = await info.getWifiIP();
    if (ip == null || ip.isEmpty || ip == '0.0.0.0') return null;
    return ip;
  } catch (_) {
    return null;
  }
}

/// Non-loopback IPv4 for LAN URLs — Wi‑Fi first, then interface scan.
Future<String?> primaryLanIPv4() async {
  final wifi = await localWifiIPv4();
  if (wifi != null) return wifi;

  try {
    final interfaces = await NetworkInterface.list(
      includeLoopback: false,
      includeLinkLocal: true,
    );
    String? fallback;
    for (final iface in interfaces) {
      if (iface.name == 'lo0') continue;
      for (final addr in iface.addresses) {
        if (addr.type != InternetAddressType.IPv4 || addr.isLoopback) {
          continue;
        }
        final ip = addr.address;
        if (ip.startsWith('169.254.')) {
          fallback ??= ip;
          continue;
        }
        if (iface.name == 'en0' || iface.name.startsWith('en')) {
          return ip;
        }
        fallback ??= ip;
      }
    }
    return fallback;
  } catch (_) {
    return null;
  }
}
