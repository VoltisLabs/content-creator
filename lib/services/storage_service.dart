import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../models/content_entry.dart';
import '../models/content_image.dart';

enum PurgeScope { day, month, year, all }

class StorageService {
  StorageService._();
  static final StorageService instance = StorageService._();

  static const _entriesFileName = 'entries.json';
  static const _imagesDirName = 'images';

  Directory? _appDir;
  Directory? _imagesDir;
  final Map<String, List<ContentEntry>> _entriesByDate = {};

  Map<String, List<ContentEntry>> get entriesByDate =>
      Map.unmodifiable(_entriesByDate);

  List<ContentEntry> get allEntries =>
      _entriesByDate.values.expand((posts) => posts).toList();

  Future<void> init() async {
    if (_appDir != null) return;
    final docs = await getApplicationDocumentsDirectory();
    _appDir = Directory(p.join(docs.path, 'content_calendar'));
    _imagesDir = Directory(p.join(_appDir!.path, _imagesDirName));
    if (!_appDir!.existsSync()) {
      await _appDir!.create(recursive: true);
    }
    if (!_imagesDir!.existsSync()) {
      await _imagesDir!.create(recursive: true);
    }
    await _loadEntries();
  }

  Future<void> _ensureReady() async {
    if (_appDir == null) {
      await init();
    }
  }

  Future<void> reloadFromDisk() async {
    await _ensureReady();
    await _loadEntries();
  }

  String? resolveImagePath(String? stored) {
    if (stored == null || stored.isEmpty || _imagesDir == null) return null;
    if (stored.startsWith('http://') || stored.startsWith('https://')) {
      return null;
    }

    final direct = File(stored);
    if (p.isAbsolute(stored) && direct.existsSync()) {
      return direct.path;
    }

    final name = p.basename(stored.replaceFirst(RegExp(r'^/images/'), ''));
    final resolved = File(p.join(_imagesDir!.path, name));
    if (resolved.existsSync()) {
      return resolved.path;
    }

    return null;
  }

  String? _basenameForDisk(String? path) {
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return null;
    }
    return p.basename(path.replaceFirst(RegExp(r'^/images/'), ''));
  }

  ContentEntry _normalizeEntry(ContentEntry entry) {
    final images = <ContentImage>[];
    for (final image in entry.images) {
      final resolved = resolveImagePath(image.path);
      if (resolved != null) {
        images.add(image.copyWith(path: resolved));
      }
    }

    var cover = resolveImagePath(entry.coverImagePath);
    cover ??= images.isNotEmpty ? images.first.path : null;

    var createdAtMillis = entry.createdAtMillis;
    if (createdAtMillis == null) {
      final parts = entry.dateKey.split('-');
      if (parts.length == 3) {
        createdAtMillis = DateTime(
          int.parse(parts[0]),
          int.parse(parts[1]),
          int.parse(parts[2]),
        ).millisecondsSinceEpoch;
      }
    }

    return entry.copyWith(
      createdAtMillis: createdAtMillis,
      coverImagePath: cover,
      clearCover: cover == null,
      images: images,
    );
  }

  ContentEntry _entryForDisk(ContentEntry entry) {
    return entry.copyWith(
      coverImagePath: _basenameForDisk(entry.coverImagePath),
      images: entry.images
          .map(
            (image) => image.copyWith(path: _basenameForDisk(image.path) ?? image.path),
          )
          .toList(),
    );
  }

  Future<void> _loadEntries() async {
    final file = File(p.join(_appDir!.path, _entriesFileName));
    if (!file.existsSync()) return;

    final raw = await file.readAsString();
    if (raw.isEmpty) return;

    final decoded = jsonDecode(raw);
    _entriesByDate.clear();

    if (decoded is Map<String, dynamic>) {
      for (final entry in decoded.entries) {
        final dateKey = entry.key;
        final value = entry.value;
        if (value is List<dynamic>) {
          final posts = value
              .map((item) => _normalizeEntry(
                    ContentEntry.fromJson(item as Map<String, dynamic>),
                  ))
              .where((post) => post.hasContent)
              .toList();
          if (posts.isNotEmpty) {
            _entriesByDate[dateKey] = posts;
          }
        } else if (value is Map<String, dynamic>) {
          final post = _normalizeEntry(ContentEntry.fromJson(value));
          if (post.hasContent) {
            _entriesByDate[dateKey] = [post];
          }
        }
      }
    }
  }

  Future<void> _saveEntries() async {
    if (_appDir == null) return;
    final file = File(p.join(_appDir!.path, _entriesFileName));
    final temp = File('${file.path}.tmp');
    final encoded = jsonEncode(
      _entriesByDate.map(
        (key, value) => MapEntry(
          key,
          value.map((post) => _entryForDisk(post).toJson()).toList(),
        ),
      ),
    );
    await temp.writeAsString(encoded, flush: true);
    if (file.existsSync()) {
      await file.delete();
    }
    await temp.rename(file.path);
  }

  List<ContentEntry> getEntriesForDate(String dateKey) {
    return List.unmodifiable(_entriesByDate[dateKey] ?? const []);
  }

  ContentEntry? getEntry(String dateKey, String entryId) {
    return _entriesByDate[dateKey]
        ?.cast<ContentEntry?>()
        .firstWhere((post) => post?.id == entryId, orElse: () => null);
  }

  Future<ContentEntry> saveEntry(ContentEntry entry) async {
    await _ensureReady();
    final normalized = _normalizeEntry(
      entry.createdAtMillis == null
          ? entry.copyWith(createdAtMillis: DateTime.now().millisecondsSinceEpoch)
          : entry,
    );
    final posts = List<ContentEntry>.from(_entriesByDate[normalized.dateKey] ?? []);
    final index = posts.indexWhere((post) => post.id == normalized.id);
    if (normalized.hasContent) {
      if (index >= 0) {
        posts[index] = normalized;
      } else {
        posts.add(normalized);
      }
      posts.sort((a, b) {
        final aTime = a.createdAtMillis ?? 0;
        final bTime = b.createdAtMillis ?? 0;
        if (aTime != bTime) return bTime.compareTo(aTime);
        return a.caption.compareTo(b.caption);
      });
      _entriesByDate[normalized.dateKey] = posts;
    } else if (index >= 0) {
      posts.removeAt(index);
      if (posts.isEmpty) {
        _entriesByDate.remove(normalized.dateKey);
      } else {
        _entriesByDate[normalized.dateKey] = posts;
      }
    }
    await _saveEntries();
    return normalized;
  }

  static String dateKeyFor(DateTime date) {
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '${date.year}-$m-$d';
  }

  bool _dateKeyMatchesPurge(String dateKey, PurgeScope scope, DateTime? target) {
    final parts = dateKey.split('-');
    if (parts.length != 3) return false;
    switch (scope) {
      case PurgeScope.all:
        return true;
      case PurgeScope.day:
        if (target == null) return false;
        return dateKey == dateKeyFor(target);
      case PurgeScope.month:
        if (target == null) return false;
        final month = target.month.toString().padLeft(2, '0');
        return parts[0] == '${target.year}' && parts[1] == month;
      case PurgeScope.year:
        if (target == null) return false;
        return parts[0] == '${target.year}';
    }
  }

  int countPostsForPurge({required PurgeScope scope, DateTime? target}) {
    var count = 0;
    for (final entry in _entriesByDate.entries) {
      if (_dateKeyMatchesPurge(entry.key, scope, target)) {
        count += entry.value.length;
      }
    }
    return count;
  }

  Future<int> purgeContent({required PurgeScope scope, DateTime? target}) async {
    await _ensureReady();
    var deletedPosts = 0;
    final keys = _entriesByDate.keys.toList();

    for (final dateKey in keys) {
      if (!_dateKeyMatchesPurge(dateKey, scope, target)) continue;
      final posts = List<ContentEntry>.from(_entriesByDate[dateKey] ?? []);
      for (final post in posts) {
        for (final image in post.images) {
          await deleteImageFile(image.path);
        }
        await deleteImageFile(post.coverImagePath);
        deletedPosts++;
      }
      _entriesByDate.remove(dateKey);
    }

    await _saveEntries();
    return deletedPosts;
  }

  Future<void> deleteEntry(String dateKey, String entryId) async {
    await _ensureReady();
    final posts = List<ContentEntry>.from(_entriesByDate[dateKey] ?? []);
    final index = posts.indexWhere((post) => post.id == entryId);
    if (index < 0) return;

    final removed = posts.removeAt(index);
    for (final image in removed.images) {
      await deleteImageFile(image.path);
    }
    await deleteImageFile(removed.coverImagePath);

    if (posts.isEmpty) {
      _entriesByDate.remove(dateKey);
    } else {
      _entriesByDate[dateKey] = posts;
    }
    await _saveEntries();
  }

  Future<String> importImage(File source) async {
    await _ensureReady();
    final ext = p.extension(source.path);
    final fileName = '${const Uuid().v4()}$ext';
    final dest = File(p.join(_imagesDir!.path, fileName));
    await source.copy(dest.path);
    return dest.path;
  }

  File? imageFileByName(String fileName) {
    if (_imagesDir == null) return null;
    final file = File(p.join(_imagesDir!.path, p.basename(fileName)));
    if (!file.existsSync()) return null;
    return file;
  }

  Future<void> deleteImageFile(String? path) async {
    if (path == null) return;
    final resolved = resolveImagePath(path) ?? path;
    final file = File(resolved);
    if (file.existsSync()) {
      await file.delete();
    }
  }
}
