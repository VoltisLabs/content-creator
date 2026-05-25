import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../models/content_entry.dart';
import '../models/content_image.dart';
import '../models/transfer_progress.dart';
import 'platform_network.dart';
import 'storage_service.dart';

class CalendarImportResult {
  const CalendarImportResult({
    required this.dateKey,
    required this.importedCount,
    this.importedDays = 1,
  });

  final String dateKey;
  final int importedCount;
  final int importedDays;
}

class CalendarImportException implements Exception {
  CalendarImportException(this.message);

  final String message;

  @override
  String toString() => message;
}

class CalendarImportService {
  CalendarImportService._();

  static final CalendarImportService instance = CalendarImportService._();

  static final _dateKeyPattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');
  static final _monthKeyPattern = RegExp(r'^\d{4}-\d{2}$');

  bool isShareUrl(String? text) => parseShareUri(text) != null;

  Uri? parseShareUri(String? text) {
    if (text == null) return null;
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;

    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return null;

    final segments = uri.pathSegments.where((segment) => segment.isNotEmpty).toList();
    if (segments.length < 2) return null;

    final kind = segments[segments.length - 2];
    final key = segments.last;
    if (kind == 'day' && _dateKeyPattern.hasMatch(key)) return uri;
    if (kind == 'month' && _monthKeyPattern.hasMatch(key)) return uri;
    return null;
  }

  String _originFor(Uri uri) {
    final defaultPort = uri.scheme == 'https' ? 443 : 80;
    if (uri.hasPort && uri.port != defaultPort) {
      return '${uri.scheme}://${uri.host}:${uri.port}';
    }
    return '${uri.scheme}://${uri.host}';
  }

  Future<CalendarImportResult> importFromUrl(
    String urlText, {
    TransferProgressCallback? onProgress,
  }) async {
    await StorageService.instance.init();

    final uri = parseShareUri(urlText);
    if (uri == null) {
      throw CalendarImportException('Paste a valid shared link.');
    }

    Object? lastError;
    for (final candidate in await importUriCandidates(uri)) {
      try {
        return await _importFromUri(candidate, onProgress: onProgress);
      } on CalendarImportException catch (error) {
        lastError = error;
      } on SocketException catch (error) {
        lastError = error;
      }
    }

    if (lastError is CalendarImportException) {
      throw lastError;
    }
    throw CalendarImportException(importConnectionHint(uri));
  }

  Future<CalendarImportResult> _importFromUri(
    Uri uri, {
    TransferProgressCallback? onProgress,
  }) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 30);

    try {
      onProgress?.call(const TransferProgress(fraction: 0.02, label: 'Connecting'));

      final request = await client.getUrl(uri);
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        throw CalendarImportException(
          'Could not reach that calendar (HTTP ${response.statusCode}).',
        );
      }

      onProgress?.call(const TransferProgress(fraction: 0.08, label: 'Downloading'));

      final body = await response.transform(utf8.decoder).join();
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic> || decoded['ok'] != true) {
        throw CalendarImportException('That link did not return shared content.');
      }

      final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
      final isMonth = segments[segments.length - 2] == 'month';

      if (isMonth) {
        return _importMonthPayload(
          client,
          uri,
          decoded,
          onProgress: onProgress,
        );
      }

      return _importDayPayload(
        client,
        uri,
        decoded,
        onProgress: onProgress,
      );
    } on CalendarImportException {
      rethrow;
    } on SocketException {
      rethrow;
    } catch (_) {
      throw CalendarImportException('Could not import from that link.');
    } finally {
      client.close(force: true);
    }
  }

  Future<CalendarImportResult> _importDayPayload(
    HttpClient client,
    Uri uri,
    Map<String, dynamic> decoded, {
    TransferProgressCallback? onProgress,
  }) async {
    final dateKey = decoded['dateKey'] as String? ?? uri.pathSegments.last;
    if (!_dateKeyPattern.hasMatch(dateKey)) {
      throw CalendarImportException('The shared link is missing a valid date.');
    }

    final rawPosts = decoded['posts'];
    if (rawPosts is! List<dynamic> || rawPosts.isEmpty) {
      throw CalendarImportException('That day has no posts to import.');
    }

    final origin = _originFor(uri);
    final imported = await _importPosts(
      client,
      origin,
      dateKey,
      rawPosts,
      onProgress: onProgress,
      progressStart: 0.12,
      progressEnd: 0.98,
    );

    if (imported.isEmpty) {
      throw CalendarImportException('That day has no posts to import.');
    }

    for (final entry in imported) {
      await StorageService.instance.saveEntry(entry);
    }

    onProgress?.call(const TransferProgress(fraction: 1, label: 'Complete'));

    return CalendarImportResult(
      dateKey: dateKey,
      importedCount: imported.length,
    );
  }

  Future<CalendarImportResult> _importMonthPayload(
    HttpClient client,
    Uri uri,
    Map<String, dynamic> decoded, {
    TransferProgressCallback? onProgress,
  }) async {
    final monthKey = decoded['monthKey'] as String? ?? uri.pathSegments.last;
    if (!_monthKeyPattern.hasMatch(monthKey)) {
      throw CalendarImportException('The shared link is missing a valid month.');
    }

    final days = decoded['days'];
    if (days is! List<dynamic> || days.isEmpty) {
      throw CalendarImportException('That month has no posts to import.');
    }

    final origin = _originFor(uri);
    var totalPosts = 0;
  var importedDays = 0;
    String? firstDateKey;

    for (var i = 0; i < days.length; i++) {
      final day = days[i];
      if (day is! Map<String, dynamic>) continue;
      final dateKey = day['dateKey'] as String? ?? '';
      if (!_dateKeyPattern.hasMatch(dateKey)) continue;

      final rawPosts = day['posts'];
      if (rawPosts is! List<dynamic> || rawPosts.isEmpty) continue;

      final dayStart = 0.12 + (0.86 * (i / days.length));
      final dayEnd = 0.12 + (0.86 * ((i + 1) / days.length));

      final imported = await _importPosts(
        client,
        origin,
        dateKey,
        rawPosts,
        onProgress: onProgress,
        progressStart: dayStart,
        progressEnd: dayEnd,
      );

      for (final entry in imported) {
        await StorageService.instance.saveEntry(entry);
      }

      if (imported.isNotEmpty) {
        totalPosts += imported.length;
        importedDays++;
        firstDateKey ??= dateKey;
      }
    }

    if (totalPosts == 0) {
      throw CalendarImportException('That month has no posts to import.');
    }

    onProgress?.call(const TransferProgress(fraction: 1, label: 'Complete'));

    return CalendarImportResult(
      dateKey: firstDateKey ?? '$monthKey-01',
      importedCount: totalPosts,
      importedDays: importedDays,
    );
  }

  Future<List<ContentEntry>> _importPosts(
    HttpClient client,
    String origin,
    String dateKey,
    List<dynamic> rawPosts, {
    TransferProgressCallback? onProgress,
    required double progressStart,
    required double progressEnd,
  }) async {
    final imageJobs = <String>[];
    for (final item in rawPosts) {
      if (item is! Map<String, dynamic>) continue;
      final cover = item['coverImage'] as String?;
      if (cover != null && cover.isNotEmpty) imageJobs.add(cover);
      final rawImages = item['images'];
      if (rawImages is List<dynamic>) {
        for (final img in rawImages) {
          if (img is Map<String, dynamic>) {
            final path = img['path'] as String?;
            if (path != null && path.isNotEmpty) imageJobs.add(path);
          }
        }
      }
    }

    final totalImages = imageJobs.isEmpty ? 1 : imageJobs.length;
    var downloadedImages = 0;
    final imageCache = <String, String>{};

    Future<String?> cachedDownload(String? relativePath) async {
      if (relativePath == null || relativePath.isEmpty) return null;
      if (imageCache.containsKey(relativePath)) {
        return imageCache[relativePath];
      }
      final local = await _downloadImage(client, origin, relativePath);
      downloadedImages++;
      final span = progressEnd - progressStart;
      final fraction = progressStart +
          span * (downloadedImages / totalImages).clamp(0, 1);
      onProgress?.call(
        TransferProgress(
          fraction: fraction,
          label: 'Transferring files',
        ),
      );
      if (local != null) {
        imageCache[relativePath] = local;
      }
      return local;
    }

    final imported = <ContentEntry>[];
    for (final item in rawPosts) {
      if (item is! Map<String, dynamic>) continue;
      imported.add(
        await _entryFromExport(
          cachedDownload,
          dateKey,
          item,
        ),
      );
    }

    return imported.where((entry) => entry.hasContent).toList();
  }

  Future<ContentEntry> _entryFromExport(
    Future<String?> Function(String?) download,
    String dateKey,
    Map<String, dynamic> json,
  ) async {
    final coverPath = await download(json['coverImage'] as String?);

    final images = <ContentImage>[];
    final rawImages = json['images'];
    if (rawImages is List<dynamic>) {
      for (final item in rawImages) {
        if (item is! Map<String, dynamic>) continue;
        final localPath = await download(item['path'] as String?);
        if (localPath == null) continue;
        images.add(
          ContentImage(
            id: const Uuid().v4(),
            path: localPath,
            altDescription: item['altDescription'] as String? ?? '',
          ),
        );
      }
    }

    return ContentEntry(
      id: const Uuid().v4(),
      dateKey: dateKey,
      caption: json['caption'] as String? ?? '',
      tags: (json['tags'] as List<dynamic>? ?? []).cast<String>(),
      altDescription: json['altDescription'] as String? ?? '',
      coverImagePath: coverPath,
      images: images,
    );
  }

  Future<String?> _downloadImage(
    HttpClient client,
    String origin,
    String? relativePath,
  ) async {
    if (relativePath == null || relativePath.isEmpty) return null;

    final normalized = relativePath.startsWith('/')
        ? relativePath
        : '/${relativePath.trim()}';
    final uri = Uri.parse('$origin$normalized');

    final request = await client.getUrl(uri);
    final response = await request.close();
    if (response.statusCode != HttpStatus.ok) return null;

    final bytes = await response.fold<List<int>>(
      <int>[],
      (previous, element) => previous..addAll(element),
    );
    if (bytes.isEmpty) return null;

    final ext = p.extension(normalized);
    final tempDir = Directory.systemTemp.createTempSync('content_calendar_import');
    final tempFile = File(
      p.join(
        tempDir.path,
        '${const Uuid().v4()}${ext.isEmpty ? '.jpg' : ext}',
      ),
    );
    await tempFile.writeAsBytes(bytes, flush: true);

    try {
      return await StorageService.instance.importImage(tempFile);
    } finally {
      if (tempFile.existsSync()) {
        await tempFile.delete();
      }
      if (tempDir.existsSync()) {
        await tempDir.delete();
      }
    }
  }
}
