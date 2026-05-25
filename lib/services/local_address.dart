import 'dart:io';

/// Best-effort LAN IPv4 for sharing URLs (Wi‑Fi / Ethernet).
Future<String?> primaryLanIPv4() async {
  try {
    final interfaces = await NetworkInterface.list(
      includeLoopback: false,
      includeLinkLocal: true,
    );
    String? fallback;
    for (final iface in interfaces) {
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
