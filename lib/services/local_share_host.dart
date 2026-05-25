import 'dart:io';

/// Human-friendly LAN hostname for share links (e.g. `macbook-pro.local`).
String? sanitizeLocalShareHost() {
  try {
    var name = Platform.localHostname;
    if (name.endsWith('.local')) {
      name = name.substring(0, name.length - 6);
    }
    name = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9-]+'), '-');
    name = name.replaceAll(RegExp(r'-{2,}'), '-');
    name = name.replaceAll(RegExp(r'^-|-$'), '');
    if (name.isEmpty || name == 'localhost') return null;
    return '$name.local';
  } catch (_) {
    return null;
  }
}

String shareUrlForHost(String host, int port, String dateKey) {
  return 'http://$host:$port/day/$dateKey';
}

String shareMonthUrlForHost(String host, int port, String monthKey) {
  return 'http://$host:$port/month/$monthKey';
}
