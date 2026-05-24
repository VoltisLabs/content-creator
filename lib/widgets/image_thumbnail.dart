import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Small image tile with remove control: always visible on mobile, hover-only on desktop.
class ImageThumbnail extends StatefulWidget {
  const ImageThumbnail({
    super.key,
    required this.path,
    required this.onRemove,
    this.size = 72,
    this.selected = false,
    this.onTap,
  });

  final String path;
  final VoidCallback onRemove;
  final double size;
  final bool selected;
  final VoidCallback? onTap;

  @override
  State<ImageThumbnail> createState() => _ImageThumbnailState();
}

class _ImageThumbnailState extends State<ImageThumbnail> {
  bool _hovering = false;

  bool get _isMobile {
    if (kIsWeb) return false;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        return true;
      default:
        return false;
    }
  }

  bool get _showRemove => _isMobile || _hovering;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor = widget.selected
        ? theme.colorScheme.primary
        : theme.colorScheme.outline.withValues(alpha: 0.35);
    final borderWidth = widget.selected ? 2.0 : 1.0;
    final imageSize = widget.size - (borderWidth * 2);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: borderColor, width: borderWidth),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: Stack(
                fit: StackFit.expand,
                clipBehavior: Clip.hardEdge,
                children: [
                  Image.file(
                    File(widget.path),
                    width: imageSize,
                    height: imageSize,
                    fit: BoxFit.cover,
                    cacheWidth: (widget.size * 2).toInt(),
                  ),
                  Positioned(
                    top: 2,
                    right: 2,
                    child: AnimatedOpacity(
                      opacity: _showRemove ? 1 : 0,
                      duration: const Duration(milliseconds: 120),
                      child: IgnorePointer(
                        ignoring: !_showRemove,
                        child: Material(
                          color: Colors.black.withValues(alpha: 0.72),
                          shape: const CircleBorder(),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: widget.onRemove,
                            child: const SizedBox(
                              width: 20,
                              height: 20,
                              child: Icon(Icons.close, size: 13, color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
