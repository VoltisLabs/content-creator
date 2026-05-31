import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../constants/app_version.dart';
import '../constants/voltis_core_config.dart';

class BugReportAttachment {
  const BugReportAttachment({
    required this.name,
    required this.mime,
    required this.bytes,
  });

  final String name;
  final String mime;
  final Uint8List bytes;

  Map<String, String> toJson() => {
        'name': name,
        'mime': mime,
        'data': base64Encode(bytes),
      };
}

class BugReportService {
  BugReportService._();

  static const maxAttachments = 5;
  static const maxBytesPerImage = 4 * 1024 * 1024;

  static Future<String> submit({
    required String email,
    required String summary,
    required String description,
    String? reporterName,
    List<BugReportAttachment> attachments = const [],
  }) async {
    final trimmedSummary = summary.trim();
    final trimmedDescription = description.trim();
    if (trimmedSummary.isEmpty || trimmedDescription.isEmpty) {
      throw BugReportException('Add a short summary and describe what happened.');
    }
    if (email.trim().isEmpty || !email.contains('@')) {
      throw BugReportException('Sign in or enter a valid email.');
    }

    final uri = Uri.parse('${VoltisCoreConfig.voltisCoreUrl}/support/reports');
    final payload = <String, dynamic>{
      'product_slug': 'content-calendar',
      'product_label': 'Content Calendar',
      'issue_type': 'Bug',
      'summary': trimmedSummary,
      'description': trimmedDescription,
      'email': email.trim(),
      if (reporterName != null && reporterName.trim().isNotEmpty)
        'name': reporterName.trim(),
      'platform': _platformLabel(),
      'app_version': AppVersion.label,
      'device': _deviceLabel(),
      'source': 'app',
      'screenshot_count': attachments.length,
      if (attachments.isNotEmpty)
        'screenshots': attachments.map((a) => a.toJson()).toList(),
    };

    final response = await http.post(
      uri,
      headers: const {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(payload),
    );

    if (response.statusCode == 201) {
      return 'Report sent. We will review it in Voltiscore ADL.';
    }

    String message = 'Could not send report (${response.statusCode}).';
    try {
      final body = jsonDecode(response.body);
      if (body is Map && body['error'] is String) {
        message = body['error'] as String;
      }
    } on Object {
      // Ignore parse errors.
    }
    throw BugReportException(message);
  }

  static String _platformLabel() {
    if (kIsWeb) return 'Web';
    if (Platform.isIOS) return 'iOS ${Platform.operatingSystemVersion}';
    if (Platform.isAndroid) return 'Android ${Platform.operatingSystemVersion}';
    if (Platform.isMacOS) return 'macOS ${Platform.operatingSystemVersion}';
    if (Platform.isWindows) return 'Windows';
    return Platform.operatingSystem;
  }

  static String _deviceLabel() {
    if (kIsWeb) return 'Browser';
    return Platform.localHostname;
  }
}

class BugReportException implements Exception {
  BugReportException(this.message);
  final String message;

  @override
  String toString() => message;
}
