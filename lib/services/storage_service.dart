import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../models/content_entry.dart';

class StorageService {
  StorageService._();
  static final StorageService instance = StorageService._();

  static const _entriesFileName = 'entries.json';
  static const _imagesDirName = 'images';

  Directory? _appDir;
  Directory? _imagesDir;
  Map<String, ContentEntry> _entries = {};

  Map<String, ContentEntry> get entries => Map.unmodifiable(_entries);

  Future<void> init() async {
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

  Future<void> _loadEntries() async {
    final file = File(p.join(_appDir!.path, _entriesFileName));
    if (!file.existsSync()) {
      _entries = {};
      return;
    }
    final raw = await file.readAsString();
    if (raw.isEmpty) {
      _entries = {};
      return;
    }
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    _entries = decoded.map(
      (key, value) => MapEntry(
        key,
        ContentEntry.fromJson(value as Map<String, dynamic>),
      ),
    );
  }

  Future<void> _saveEntries() async {
    final file = File(p.join(_appDir!.path, _entriesFileName));
    final encoded = jsonEncode(
      _entries.map((key, value) => MapEntry(key, value.toJson())),
    );
    await file.writeAsString(encoded);
  }

  ContentEntry? getEntry(String dateKey) => _entries[dateKey];

  Future<ContentEntry> saveEntry(ContentEntry entry) async {
    if (entry.hasContent) {
      _entries[entry.dateKey] = entry;
    } else {
      _entries.remove(entry.dateKey);
    }
    await _saveEntries();
    return entry;
  }

  Future<String> importImage(File source) async {
    final ext = p.extension(source.path);
    final fileName = '${const Uuid().v4()}$ext';
    final dest = File(p.join(_imagesDir!.path, fileName));
    await source.copy(dest.path);
    return dest.path;
  }

  Future<void> deleteImageFile(String? path) async {
    if (path == null) return;
    final file = File(path);
    if (file.existsSync()) {
      await file.delete();
    }
  }
}
