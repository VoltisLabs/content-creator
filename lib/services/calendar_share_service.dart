import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/content_entry.dart';
import '../models/transfer_progress.dart';
import 'local_share_host.dart';
import 'platform_network.dart';
import 'storage_service.dart';

/// Lightweight LAN HTTP server so peers on the same network can view shared days.
class CalendarShareService {
  CalendarShareService._();

  static final CalendarShareService instance = CalendarShareService._();

  HttpServer? _server;
  int _port = 0;
  TransferProgress? outboundProgress;

  int get port => _port;
  bool get isRunning => _server != null;

  Future<void> start() async {
    if (_server != null) return;
    _server = await HttpServer.bind(InternetAddress.anyIPv4, 0);
    _port = _server!.port;
    _server!.listen(_handleRequest);
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    _port = 0;
  }

  Future<String?> shareUrlForDay(String dateKey) async {
    await start();
    if (_port == 0) return null;

    final host = await resolveShareHost();
    if (host == null) return null;
    return shareUrlForHost(host, _port, dateKey);
  }

  Future<String?> shareUrlForMonth(String monthKey) async {
    await start();
    if (_port == 0) return null;

    final host = await resolveShareHost();
    if (host == null) return null;
    return shareMonthUrlForHost(host, _port, monthKey);
  }

  Future<int> estimateDayTransferBytes(String dateKey) async {
    return _estimateBytes(StorageService.instance.getEntriesForDate(dateKey));
  }

  Future<int> estimateMonthTransferBytes(int year, int month) async {
    var total = 0;
    for (final entry in StorageService.instance.entriesByDate.entries) {
      final parts = entry.key.split('-');
      if (parts.length != 3) continue;
      if (int.parse(parts[0]) == year && int.parse(parts[1]) == month) {
        total += await _estimateBytes(entry.value);
      }
    }
    return total;
  }

  Future<int> _estimateBytes(List<ContentEntry> posts) async {
    var total = 0;
    for (final post in posts) {
      total += 2048;
      for (final path in [
        post.coverImagePath,
        ...post.images.map((image) => image.path),
      ]) {
        if (path == null) continue;
        final resolved = StorageService.instance.resolveImagePath(path);
        if (resolved == null) continue;
        final file = File(resolved);
        if (file.existsSync()) {
          total += await file.length();
        }
      }
    }
    return total;
  }

  Future<void> prepareShare({
    required TransferProgressCallback onProgress,
    required Future<int> Function() estimateBytes,
    required String label,
  }) async {
    onProgress(TransferProgress(fraction: 0.05, label: label));
    final bytes = await estimateBytes();
    onProgress(TransferProgress(fraction: 0.45, label: 'Preparing $label'));
    await Future<void>.delayed(const Duration(milliseconds: 120));
    onProgress(
      TransferProgress(
        fraction: 0.85,
        label: bytes > 0 ? 'Ready (${_formatBytes(bytes)})' : 'Ready',
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 80));
    onProgress(const TransferProgress(fraction: 1, label: 'Link ready'));
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _handleRequest(HttpRequest request) async {
    try {
      final segments = request.uri.pathSegments.where((s) => s.isNotEmpty).toList();
      if (request.method == 'GET' && segments.isEmpty) {
        return _json(request, {
          'ok': true,
          'app': 'Content Calendar',
          'apiVersion': 2,
        });
      }

      if (request.method == 'GET' && segments.length == 2 && segments.first == 'day') {
        final dateKey = segments[1];
        final posts = StorageService.instance.getEntriesForDate(dateKey);
        return _json(request, _exportDay(dateKey, posts));
      }

      if (request.method == 'GET' && segments.length == 2 && segments.first == 'month') {
        final monthKey = segments[1];
        return _json(request, _exportMonth(monthKey));
      }

      if (request.method == 'GET' &&
          segments.length == 2 &&
          segments.first == 'images') {
        final fileName = p.basename(segments[1]);
        final file = StorageService.instance.imageFileByName(fileName);
        if (file == null || !file.existsSync()) {
          request.response.statusCode = HttpStatus.notFound;
          await request.response.close();
          return;
        }
        request.response.headers.contentType = _contentTypeFor(fileName);
        final total = await file.length();
        request.response.contentLength = total;
        var sent = 0;
        outboundProgress = const TransferProgress(fraction: 0, label: 'Sending');
        await for (final chunk in file.openRead()) {
          sent += chunk.length;
          outboundProgress = TransferProgress(
            fraction: total == 0 ? 1 : sent / total,
            label: 'Sending',
          );
          request.response.add(chunk);
        }
        outboundProgress = const TransferProgress(fraction: 1, label: 'Sent');
        await request.response.close();
        return;
      }

      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
    } catch (_) {
      request.response.statusCode = HttpStatus.internalServerError;
      await request.response.close();
    }
  }

  Map<String, dynamic> _exportDay(String dateKey, List<ContentEntry> posts) {
    return {
      'ok': true,
      'dateKey': dateKey,
      'posts': posts.map(_exportPost).toList(),
    };
  }

  Map<String, dynamic> _exportMonth(String monthKey) {
    final parts = monthKey.split('-');
    if (parts.length != 2) {
      return {'ok': false, 'error': 'Invalid month'};
    }
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);

    final days = <Map<String, dynamic>>[];
    for (final entry in StorageService.instance.entriesByDate.entries) {
      final keyParts = entry.key.split('-');
      if (keyParts.length != 3) continue;
      if (int.parse(keyParts[0]) == year && int.parse(keyParts[1]) == month) {
        if (entry.value.isNotEmpty) {
          days.add(_exportDay(entry.key, entry.value));
        }
      }
    }

    return {
      'ok': true,
      'monthKey': monthKey,
      'days': days,
    };
  }

  Map<String, dynamic> _exportPost(ContentEntry entry) {
    return {
      'id': entry.id,
      'caption': entry.caption,
      'tags': entry.tags,
      'altDescription': entry.altDescription,
      'coverImage': _imageUrl(entry.coverImagePath),
      'images': entry.images
          .map(
            (image) => {
              'id': image.id,
              'path': _imageUrl(image.path),
              'altDescription': image.altDescription,
            },
          )
          .toList(),
    };
  }

  String? _imageUrl(String? localPath) {
    if (localPath == null) return null;
    final name = p.basename(localPath);
    return '/images/$name';
  }

  ContentType _contentTypeFor(String fileName) {
    final ext = p.extension(fileName).toLowerCase();
    return switch (ext) {
      '.png' => ContentType('image', 'png'),
      '.webp' => ContentType('image', 'webp'),
      '.gif' => ContentType('image', 'gif'),
      _ => ContentType('image', 'jpeg'),
    };
  }

  Future<void> _json(HttpRequest request, Map<String, dynamic> body) async {
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode(body));
    await request.response.close();
  }
}
