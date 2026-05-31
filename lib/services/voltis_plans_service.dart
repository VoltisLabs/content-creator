import 'dart:convert';

import 'package:http/http.dart' as http;

import '../constants/voltis_core_config.dart';
import '../models/voltis_plan.dart';

/// Fetches the public plan catalog from Voltis Core (`GET /apps/plans`).
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
      throw VoltisPlansException('No plans published for $appId.');
    }
    return catalog;
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
