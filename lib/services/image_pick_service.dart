import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import 'desktop_window.dart';

/// Desktop uses the native file dialog (Finder on macOS). Mobile uses the gallery.
class ImagePickService {
  ImagePickService._();

  static final _picker = ImagePicker();

  static bool get _useFilePicker {
    if (kIsWeb) return false;
    return isDesktop;
  }

  static Future<File?> pickSingleImage() async {
    if (_useFilePicker) {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: false,
        dialogTitle: 'Choose an image',
      );
      if (result == null || result.files.isEmpty) return null;
      final path = result.files.single.path;
      if (path == null || path.isEmpty) return null;
      return File(path);
    }

    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return null;
    return File(picked.path);
  }

  static Future<List<File>> pickMultipleImages() async {
    if (_useFilePicker) {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
        withData: false,
        dialogTitle: 'Choose images',
      );
      if (result == null) return [];
      return result.files
          .where((file) => file.path != null && file.path!.isNotEmpty)
          .map((file) => File(file.path!))
          .toList();
    }

    final picked = await _picker.pickMultiImage();
    return picked.map((file) => File(file.path)).toList();
  }
}
