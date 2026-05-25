import 'subscription_service.dart';
import 'storage_service.dart';

enum SubscriptionPlan { free, pro }

class PlanLimits {
  PlanLimits._();

  static const maxPostsPerDayFree = 2;
  static const maxPostsPerMonthFree = 10;

  /// Free users may plan content in the current month and the next month only.
  static bool isMonthAllowedForFree(DateTime month) {
    final now = DateTime.now();
    final current = DateTime(now.year, now.month);
    final next = DateTime(now.year, now.month + 1);
    final target = DateTime(month.year, month.month);
    return _sameMonth(target, current) || _sameMonth(target, next);
  }

  static bool _sameMonth(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month;

  static String get freeMonthWindowMessage =>
      'Free plan lets you add posts in this month and next month only. '
      'Upgrade to Pro to plan further ahead.';
}

class PlanService {
  PlanService._();

  static final PlanService instance = PlanService._();

  Future<SubscriptionPlan> currentPlan() async {
    return (await isPro) ? SubscriptionPlan.pro : SubscriptionPlan.free;
  }

  Future<bool> get isPro async => SubscriptionService.instance.isPro;

  int postsOnDate(String dateKey) {
    return StorageService.instance.getEntriesForDate(dateKey).length;
  }

  int postsInMonth(int year, int month) {
    var count = 0;
    for (final entry in StorageService.instance.entriesByDate.entries) {
      final parts = entry.key.split('-');
      if (parts.length != 3) continue;
      if (int.parse(parts[0]) == year && int.parse(parts[1]) == month) {
        count += entry.value.length;
      }
    }
    return count;
  }

  Future<String?> limitMessageForNewPost({
    required String dateKey,
    String? existingEntryId,
  }) async {
    if (await isPro) return null;

    final parts = dateKey.split('-');
    if (parts.length != 3) return null;
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);

    if (!PlanLimits.isMonthAllowedForFree(DateTime(year, month))) {
      return PlanLimits.freeMonthWindowMessage;
    }

    final onDay = postsOnDate(dateKey);
    final isNew = existingEntryId == null ||
        StorageService.instance.getEntry(dateKey, existingEntryId) == null;

    if (isNew && onDay >= PlanLimits.maxPostsPerDayFree) {
      return 'Free plan allows ${PlanLimits.maxPostsPerDayFree} posts per day. '
          'Upgrade to Pro for unlimited posts.';
    }

    if (isNew && postsInMonth(year, month) >= PlanLimits.maxPostsPerMonthFree) {
      return 'Free plan allows ${PlanLimits.maxPostsPerMonthFree} posts per month. '
          'Upgrade to Pro for unlimited posts.';
    }

    return null;
  }
}
