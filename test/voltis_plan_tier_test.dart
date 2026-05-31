import 'package:content_calendar/models/voltis_plan.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VoltisPlanTierX.fromApiValue', () {
    test('reads checkout ids from Voltiscore', () {
      expect(
        VoltisPlanTierX.fromApiValue('six_months'),
        VoltisPlanTier.sixMonths,
      );
      expect(
        VoltisPlanTierX.fromApiValue('content_calendar_yearly'),
        VoltisPlanTier.sixMonths,
      );
      expect(
        VoltisPlanTierX.fromApiValue('content_calendar_lifetime'),
        VoltisPlanTier.lifetime,
      );
      expect(
        VoltisPlanTierX.fromApiValue('content_calendar_3_months'),
        VoltisPlanTier.quarterly,
      );
    });

    test('reads enum names persisted locally', () {
      expect(
        VoltisPlanTierX.fromApiValue('sixMonths'),
        VoltisPlanTier.sixMonths,
      );
      expect(
        VoltisPlanTierX.fromApiValue('quarterly'),
        VoltisPlanTier.quarterly,
      );
      expect(
        VoltisPlanTierX.fromApiValue('lifetime'),
        VoltisPlanTier.lifetime,
      );
    });

    test('yearly catalog tier maps to six months enum', () {
      expect(
        VoltisPlanTierX.fromApiValue('yearly'),
        VoltisPlanTier.sixMonths,
      );
      expect(
        VoltisPlanTierX.fromApiValue('six_months'),
        VoltisPlanTier.sixMonths,
      );
    });
  });

  group('VoltisPlanTierX.displayLabel', () {
    test('uses catalog plan name for current tier', () {
      const catalog = VoltisPlansCatalog(
        appId: 'content-calendar',
        appName: 'Content Calendar',
        currency: 'GBP',
        checkoutUrl: 'https://voltislabs.uk/voltiscore/content-calendar/',
        plans: [
          VoltisPlanOffer(
            id: 'yearly',
            tier: VoltisPlanTier.sixMonths,
            name: 'Yearly',
            priceDisplay: '£29.99',
            priceAmount: 2999,
            currency: 'GBP',
            billingLabel: 'per year',
            description: '',
            features: const [],
          ),
        ],
      );
      expect(
        VoltisPlanTierX.displayLabel(
          contentCalendarPro: true,
          planTier: VoltisPlanTier.sixMonths,
          catalog: catalog,
        ),
        'Yearly',
      );
    });
  });

  group('VoltisPlanTierX.checkoutId', () {
    test('round-trips through fromApiValue', () {
      for (final tier in VoltisPlanTier.values) {
        if (tier == VoltisPlanTier.free) continue;
        expect(
          VoltisPlanTierX.fromApiValue(tier.checkoutId),
          tier,
        );
      }
    });
  });
}
