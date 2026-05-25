import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'appearance_preferences.dart';

class CustomBackgroundService {
  CustomBackgroundService._();

  static final CustomBackgroundService instance = CustomBackgroundService._();
  final _picker = ImagePicker();

  Future<String?> pickAndSaveBackground() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
    );
    if (file == null) return null;

    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'backgrounds'));
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }

    final ext = p.extension(file.path).isEmpty ? '.jpg' : p.extension(file.path);
    final dest = p.join(dir.path, 'custom_bg$ext');
    await File(file.path).copy(dest);
    await AppearancePreferences.saveCustomBackgroundPath(dest);
    return dest;
  }

  Future<void> clearBackground() async {
    final existing = await AppearancePreferences.loadCustomBackgroundPath();
    if (existing != null) {
      final file = File(existing);
      if (file.existsSync()) {
        try {
          await file.delete();
        } catch (_) {}
      }
    }
    await AppearancePreferences.saveCustomBackgroundPath(null);
  }

  Future<File?> loadBackgroundFile() async {
    final path = await AppearancePreferences.loadCustomBackgroundPath();
    if (path == null || path.isEmpty) return null;
    final file = File(path);
    if (!file.existsSync()) return null;
    return file;
  }
}
