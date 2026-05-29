import 'dart:io';

import 'package:flutter/material.dart';

import '../services/storage_service.dart';

/// Renders a post image from disk or from bundled demo assets (`assets/...`).
class PostImage extends StatelessWidget {
  const PostImage({
    super.key,
    required this.path,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.cacheWidth,
    this.color,
    this.colorBlendMode,
  });

  final String path;
  final BoxFit fit;
  final double? width;
  final double? height;
  final int? cacheWidth;
  final Color? color;
  final BlendMode? colorBlendMode;

  static bool isAssetPath(String? path) =>
      path != null && path.startsWith('assets/');

  static String? resolveDisplayPath(String? path) {
    if (path == null || path.isEmpty) return null;
    if (isAssetPath(path)) return path;
    return StorageService.instance.resolveImagePath(path);
  }

  @override
  Widget build(BuildContext context) {
    final error = Icon(
      Icons.broken_image_outlined,
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.35),
    );

    if (isAssetPath(path)) {
      return Image.asset(
        path,
        width: width,
        height: height,
        fit: fit,
        cacheWidth: cacheWidth,
        color: color,
        colorBlendMode: colorBlendMode,
        errorBuilder: (context, _, __) => error,
      );
    }

    return Image.file(
      File(path),
      width: width,
      height: height,
      fit: fit,
      cacheWidth: cacheWidth,
      color: color,
      colorBlendMode: colorBlendMode,
      errorBuilder: (context, _, __) => error,
    );
  }
}
