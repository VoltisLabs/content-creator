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
  static const _imageConcurrency = 4;

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

  String? dateKeyFromUri(Uri uri) {
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.length < 2 || segments[segments.length - 2] != 'day') {
      return null;
    }
    final key = segments.last;
    return _dateKeyPattern.hasMatch(key) ? key : null;
  }

  String? monthKeyFromUri(Uri uri) {
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.length < 2 || segments[segments.length - 2] != 'month') {
      return null;
    }
    final key = segments.last;
    return _monthKeyPattern.hasMatch(key) ? key : null;
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
    client.connectionTimeout = const Duration(seconds: 12);

    final importTempDir = Directory.systemTemp.createTempSync('content_calendar_import');

    try {
      onProgress?.call(
        const TransferProgress(fraction: 0.04, label: 'Downloading calendar…'),
      );

      final request = await client.getUrl(uri);
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        throw CalendarImportException(
          'Could not reach that calendar (HTTP ${response.statusCode}).',
        );
      }

      final body = await response.transform(utf8.decoder).join();
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic> || decoded['ok'] != true) {
        throw CalendarImportException('That link did not return shared content.');
      }

      onProgress?.call(
        const TransferProgress(fraction: 0.1, label: 'Downloading calendar…'),
      );

      final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
      final isMonth = segments[segments.length - 2] == 'month';

      if (isMonth) {
        return _importMonthPayload(
          client,
          uri,
          decoded,
          importTempDir,
          onProgress: onProgress,
        );
      }

      return _importDayPayload(
        client,
        uri,
        decoded,
        importTempDir,
        onProgress: onProgress,
      );
    } on CalendarImportException {
      rethrow;
    } on SocketException {
      rethrow;
    } catch (error) {
      throw CalendarImportException('Could not import from that link.');
    } finally {
      client.close(force: true);
      if (importTempDir.existsSync()) {
        await importTempDir.delete(recursive: true);
      }
    }
  }

  Future<CalendarImportResult> _importDayPayload(
    HttpClient client,
    Uri uri,
    Map<String, dynamic> decoded,
    Directory importTempDir, {
    TransferProgressCallback? onProgress,
  }) async {
    final dateKey = decoded['dateKey'] as String? ?? dateKeyFromUri(uri);
    if (dateKey == null || !_dateKeyPattern.hasMatch(dateKey)) {
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
      importTempDir,
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
    Map<String, dynamic> decoded,
    Directory importTempDir, {
    TransferProgressCallback? onProgress,
  }) async {
    final monthKey = decoded['monthKey'] as String? ?? monthKeyFromUri(uri);
    if (monthKey == null || !_monthKeyPattern.hasMatch(monthKey)) {
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
        importTempDir,
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
    List<dynamic> rawPosts,
    Directory importTempDir, {
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

    final uniqueImages = imageJobs.toSet().toList();
    final imageCache = await _downloadImagesParallel(
      client,
      origin,
      uniqueImages,
      importTempDir,
      onProgress: (done, total) {
        if (total == 0) return;
        final span = progressEnd - progressStart;
        final fraction = progressStart + span * (done / total);
        onProgress?.call(
          TransferProgress(
            fraction: fraction,
            label: 'Downloading images ($done/$total)',
          ),
        );
      },
      progressStart: progressStart,
      progressEnd: progressEnd,
    );

    Future<String?> lookup(String? relativePath) async {
      if (relativePath == null || relativePath.isEmpty) return null;
      return imageCache[relativePath];
    }

    final imported = <ContentEntry>[];
    for (final item in rawPosts) {
      if (item is! Map<String, dynamic>) continue;
      imported.add(await _entryFromExport(lookup, dateKey, item));
    }

    return imported.where((entry) => entry.hasContent).toList();
  }

  Future<Map<String, String?>> _downloadImagesParallel(
    HttpClient client,
    String origin,
    List<String> relativePaths,
    Directory importTempDir, {
    required void Function(int done, int total) onProgress,
    required double progressStart,
    required double progressEnd,
  }) async {
    final cache = <String, String?>{};
    if (relativePaths.isEmpty) {
      onProgress(0, 0);
      return cache;
    }

    var nextIndex = 0;
    var completed = 0;
    final total = relativePaths.length;

    Future<void> worker() async {
      while (true) {
        final index = nextIndex++;
        if (index >= total) return;
        final path = relativePaths[index];
        cache[path] = await _downloadImage(
          client,
          origin,
          path,
          importTempDir,
        );
        completed++;
        onProgress(completed, total);
      }
    }

    final workers = _imageConcurrency.clamp(1, total);
    await Future.wait(List.generate(workers, (_) => worker()));
    return cache;
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
    String relativePath,
    Directory importTempDir,
  ) async {
    final normalized = relativePath.startsWith('/')
        ? relativePath
        : '/${relativePath.trim()}';
    final uri = Uri.parse('$origin$normalized');

    try {
      final request = await client.getUrl(uri);
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) return null;

      final ext = p.extension(normalized);
      final tempFile = File(
        p.join(
          importTempDir.path,
          '${const Uuid().v4()}${ext.isEmpty ? '.jpg' : ext}',
        ),
      );
      final sink = tempFile.openWrite();
      try {
        await response.pipe(sink);
      } finally {
        await sink.close();
      }

      if (!tempFile.existsSync() || tempFile.lengthSync() == 0) {
        return null;
      }

      return StorageService.instance.importImage(tempFile);
    } catch (_) {
      return null;
    }
  }
}
