import 'dart:convert';

import 'package:http/http.dart' as http;

import '../constants/voltis_core_config.dart';

class VoltisGraphqlException implements Exception {
  VoltisGraphqlException(this.message);
  final String message;
  @override
  String toString() => message;
}

class VoltisCoreGraphql {
  VoltisCoreGraphql._();

  static final VoltisCoreGraphql instance = VoltisCoreGraphql._();

  Uri get _endpoint => Uri.parse(VoltisCoreConfig.graphqlUrl);

  Future<Map<String, dynamic>> query(
    String document, {
    Map<String, dynamic>? variables,
    String? accessToken,
  }) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (accessToken != null && accessToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $accessToken';
    }

    final response = await http.post(
      _endpoint,
      headers: headers,
      body: jsonEncode({
        'query': document,
        if (variables != null) 'variables': variables,
      }),
    );

    final body = jsonDecode(response.body);
    if (body is! Map<String, dynamic>) {
      throw VoltisGraphqlException('Invalid GraphQL response');
    }

    if (response.statusCode >= 400) {
      final err = body['error'];
      throw VoltisGraphqlException(
        err is String ? err : 'Request failed (${response.statusCode})',
      );
    }

    final errors = body['errors'];
    if (errors is List && errors.isNotEmpty) {
      final messages = errors
          .map((e) => e is Map ? e['message']?.toString() : e.toString())
          .whereType<String>()
          .join(' · ');
      throw VoltisGraphqlException(
        messages.isEmpty ? 'GraphQL error' : messages,
      );
    }

    final data = body['data'];
    if (data is! Map<String, dynamic>) {
      throw VoltisGraphqlException('Missing GraphQL data');
    }
    return data;
  }
}
