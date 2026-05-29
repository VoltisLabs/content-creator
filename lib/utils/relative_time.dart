/// Human-readable relative timestamps (e.g. "just now", "2 mins ago").
String formatRelativeTime(DateTime dateTime, {DateTime? now}) {
  final reference = now ?? DateTime.now();
  final diff = reference.difference(dateTime);

  if (diff.isNegative || diff.inSeconds < 45) {
    return 'just now';
  }
  if (diff.inMinutes < 60) {
    final m = diff.inMinutes;
    return m == 1 ? '1 min ago' : '$m mins ago';
  }
  if (diff.inHours < 24) {
    final h = diff.inHours;
    return h == 1 ? '1 hour ago' : '$h hours ago';
  }
  if (diff.inDays < 7) {
    final d = diff.inDays;
    return d == 1 ? '1 day ago' : '$d days ago';
  }
  if (diff.inDays < 30) {
    final w = diff.inDays ~/ 7;
    return w == 1 ? '1 week ago' : '$w weeks ago';
  }
  if (diff.inDays < 365) {
    final mo = diff.inDays ~/ 30;
    return mo <= 1 ? '1 month ago' : '$mo months ago';
  }
  final y = diff.inDays ~/ 365;
  return y == 1 ? '1 year ago' : '$y years ago';
}

String formatPostCreatedLabel(int? createdAtMillis) {
  if (createdAtMillis == null) return '';
  return formatRelativeTime(
    DateTime.fromMillisecondsSinceEpoch(createdAtMillis),
  );
}
