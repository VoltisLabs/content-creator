import '../services/plan_service.dart';

/// Shared plan marketing copy — must match [PlanLimits] and Pro gates in the app.
abstract final class PlanCatalogCopy {
  static const proFeatureBullets = [
    'Unlimited posts every day and every month',
    'Plan content in any future month on the calendar',
    'Share a whole month with another device on your Wi-Fi',
    'All colour, gradient, and live home themes',
  ];

  static List<String> get freeFeatureBullets => [
        '${PlanLimits.maxPostsPerDayFree} posts per day',
        '${PlanLimits.maxPostsPerMonthFree} posts per month',
        'This month and the next month on your calendar',
        'Share individual days and posts with another device on your LAN, Organisation or School',
        'Posts and images stored only on this device',
      ];
}
