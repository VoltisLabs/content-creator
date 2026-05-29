import 'dart:convert';

import 'package:http/http.dart' as http;

import '../constants/plan_catalog_copy.dart';
import '../constants/voltis_core_config.dart';
import '../models/voltis_plan.dart';

/// Fetches the public plan catalog from Voltis Core.
abstract final class VoltisPlansService {
  static Future<VoltisPlansCatalog> fetchCatalog({
    String appId = VoltisCoreConfig.appId,
  }) async {
    final uri = Uri.parse('${VoltisCoreConfig.voltisCoreUrl}/apps/plans')
        .replace(queryParameters: {'app_id': appId});

    final response = await http.get(
      uri,
      headers: const {'Accept': 'application/json'},
    );

    if (response.statusCode == 404) {
      return _fallbackCatalog(appId);
    }

    if (response.statusCode != 200) {
      throw VoltisPlansException(
        _messageForStatus(response.statusCode, response.body),
      );
    }

    final body = jsonDecode(response.body);
    if (body is! Map<String, dynamic>) {
      throw VoltisPlansException('Invalid plans response from Voltis Core.');
    }

    final catalog = VoltisPlansCatalog.fromJson(body);
    if (catalog.plans.isEmpty) {
      return _fallbackCatalog(appId);
    }
    return catalog;
  }

  static VoltisPlansCatalog _fallbackCatalog(String appId) {
    if (appId != 'content-calendar') {
      throw VoltisPlansException('No plans published for $appId.');
    }

    final pro = PlanCatalogCopy.proFeatureBullets;

    return VoltisPlansCatalog.fromJson({
      'app_id': 'content-calendar',
      'app_name': 'Content Calendar',
      'currency': 'GBP',
      'checkout_url': 'https://voltislabs.uk/voltiscore/content-calendar/',
      'plans': [
        {
          'id': 'free',
          'tier': 'free',
          'name': 'Free',
          'price_display': '£0',
          'price_amount': 0,
          'currency': 'GBP',
          'billing_label': 'Included with Voltis Core',
          'description':
              'Plan social content on your device with sensible limits.',
          'features': PlanCatalogCopy.freeFeatureBullets,
          'sort_order': 0,
        },
        {
          'id': 'quarterly',
          'tier': 'quarterly',
          'name': '3 months',
          'price_display': '£11.99',
          'price_amount': 1199,
          'currency': 'GBP',
          'billing_label': 'every 3 months',
          'description': 'Pro access for a quarter of planning and posting.',
          'features': pro,
          'sort_order': 1,
        },
        {
          'id': 'yearly',
          'tier': 'yearly',
          'name': 'Yearly',
          'price_display': '£29.99',
          'price_amount': 2999,
          'currency': 'GBP',
          'billing_label': 'per year',
          'description': 'A full year of Pro - best if you post every week.',
          'features': pro,
          'badge': 'Best value',
          'recommended': true,
          'sort_order': 2,
        },
        {
          'id': 'lifetime',
          'tier': 'lifetime',
          'name': 'Forever',
          'price_display': '£79.99',
          'price_amount': 7999,
          'currency': 'GBP',
          'billing_label': 'one-time',
          'description': 'Pay once and keep every Pro feature for good.',
          'features': [
            ...pro,
            'No renewals - yours for as long as you use Content Calendar',
          ],
          'badge': 'Own it forever',
          'sort_order': 3,
        },
      ],
    });
  }

  static String _messageForStatus(int status, String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['error'] is String) {
        return decoded['error'] as String;
      }
    } on Object {
      // Ignore parse errors.
    }
    return 'Could not load plans from Voltis Core ($status).';
  }
}

class VoltisPlansException implements Exception {
  VoltisPlansException(this.message);
  final String message;

  @override
  String toString() => message;
}
