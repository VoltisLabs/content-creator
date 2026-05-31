/// Content Calendar subscription tiers via Voltis Core billing.
enum VoltisPlanTier {
  free,
  quarterly,
  sixMonths,
  lifetime,
}

extension VoltisPlanTierX on VoltisPlanTier {
  String get label => switch (this) {
        VoltisPlanTier.free => 'Free',
        VoltisPlanTier.quarterly => '3 months',
        VoltisPlanTier.sixMonths => 'Yearly',
        VoltisPlanTier.lifetime => 'Lifetime',
      };

  /// Query param for Voltiscore checkout (`?plan=…`).
  String get checkoutId => switch (this) {
        VoltisPlanTier.free => 'free',
        VoltisPlanTier.quarterly => 'quarterly',
        VoltisPlanTier.sixMonths => 'yearly',
        VoltisPlanTier.lifetime => 'lifetime',
      };

  bool get isPaid => this != VoltisPlanTier.free;

  /// Prefer [catalog] plan names (Voltiscore) so the header matches plan cards.
  static String displayLabel({
    required bool contentCalendarPro,
    required VoltisPlanTier planTier,
    VoltisPlansCatalog? catalog,
  }) {
    if (catalog != null) {
      for (final plan in catalog.plans) {
        final isCurrent = !contentCalendarPro
            ? plan.tier == VoltisPlanTier.free
            : planTier.isPaid && planTier == plan.tier;
        if (isCurrent) return plan.name;
      }
    }
    if (contentCalendarPro && !planTier.isPaid) return 'Pro';
    return planTier.label;
  }

  static VoltisPlanTier fromApiValue(String? raw) {
    switch (raw?.trim().toLowerCase()) {
      case 'quarterly':
      case '3_months':
      case '3months':
      case 'content_calendar_3_months':
        return VoltisPlanTier.quarterly;
      case 'sixmonths':
      case 'six_months':
      case '6_months':
      case '6months':
      case 'semiannual':
      case 'biannual':
      case 'content_calendar_yearly':
        return VoltisPlanTier.sixMonths;
      case 'annual':
      case 'yearly':
      case 'year':
        return VoltisPlanTier.sixMonths;
      case 'lifetime':
      case 'forever':
      case 'own':
      case 'content_calendar_lifetime':
        return VoltisPlanTier.lifetime;
      case 'free':
      case null:
      case '':
        return VoltisPlanTier.free;
      default:
        return VoltisPlanTier.free;
    }
  }
}

/// Public plan row from Voltis Core `GET /api/apps/plans`.
class VoltisPlanOffer {
  const VoltisPlanOffer({
    required this.id,
    required this.tier,
    required this.name,
    required this.priceDisplay,
    required this.priceAmount,
    required this.currency,
    required this.billingLabel,
    required this.description,
    required this.features,
    this.badge,
    this.recommended = false,
    this.sortOrder = 0,
  });

  final String id;
  final VoltisPlanTier tier;
  final String name;
  final String priceDisplay;
  final int priceAmount;
  final String currency;
  final String billingLabel;
  final String description;
  final List<String> features;
  final String? badge;
  final bool recommended;
  final int sortOrder;

  bool get isFree => tier == VoltisPlanTier.free;

  factory VoltisPlanOffer.fromJson(Map<String, dynamic> json) {
    final tierRaw = json['tier'] as String? ?? json['id'] as String? ?? 'free';
    return VoltisPlanOffer(
      id: json['id'] as String? ?? tierRaw,
      tier: VoltisPlanTierX.fromApiValue(tierRaw),
      name: json['name'] as String? ?? 'Plan',
      priceDisplay: json['price_display'] as String? ?? '',
      priceAmount: (json['price_amount'] as num?)?.toInt() ?? 0,
      currency: json['currency'] as String? ?? 'GBP',
      billingLabel: json['billing_label'] as String? ?? '',
      description: json['description'] as String? ?? '',
      features: (json['features'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .where((item) => item.isNotEmpty)
          .toList(),
      badge: json['badge'] as String?,
      recommended: json['recommended'] == true,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    );
  }
}

class VoltisPlansCatalog {
  const VoltisPlansCatalog({
    required this.appId,
    required this.appName,
    required this.currency,
    required this.checkoutUrl,
    required this.plans,
  });

  final String appId;
  final String appName;
  final String currency;
  final String checkoutUrl;
  final List<VoltisPlanOffer> plans;

  factory VoltisPlansCatalog.fromJson(Map<String, dynamic> json) {
    final rawPlans = json['plans'] as List<dynamic>? ?? const [];
    final plans = rawPlans
        .whereType<Map<String, dynamic>>()
        .map(VoltisPlanOffer.fromJson)
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    return VoltisPlansCatalog(
      appId: json['app_id'] as String? ?? 'content-calendar',
      appName: json['app_name'] as String? ?? 'Content Calendar',
      currency: json['currency'] as String? ?? 'GBP',
      checkoutUrl: json['checkout_url'] as String? ?? '',
      plans: plans,
    );
  }
}
