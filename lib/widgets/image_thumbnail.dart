import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../utils/app_haptics.dart';
import 'post_image.dart';

/// Small image tile with remove control: always visible on mobile, hover-only on desktop.
class ImageThumbnail extends StatefulWidget {
  const ImageThumbnail({
    super.key,
    required this.path,
    this.onRemove,
    this.size = 72,
    this.selected = false,
    this.onTap,
    this.onLongPress,
  });

  final String path;
  final VoidCallback? onRemove;
  final double size;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

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
    final accent = theme.colorScheme.primary;
    final borderColor = widget.selected
        ? accent
        : accent.withValues(alpha: 0.28);
    final borderWidth = widget.selected ? 2.0 : 1.0;
    final imageSize = widget.size - (borderWidth * 2);
    final fill = accent.withValues(alpha: 0.06);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: () {
          AppHaptics.tap();
          widget.onTap?.call();
        },
        onLongPress: widget.onLongPress == null
            ? null
            : () {
                AppHaptics.tap();
                widget.onLongPress!();
              },
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: borderColor, width: borderWidth),
              color: fill,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: Stack(
                fit: StackFit.expand,
                clipBehavior: Clip.hardEdge,
                children: [
                  PostImage(
                    path: widget.path,
                    width: imageSize,
                    height: imageSize,
                    fit: BoxFit.cover,
                    cacheWidth: (widget.size * 2).toInt(),
                    color: accent.withValues(alpha: 0.08),
                    colorBlendMode: BlendMode.softLight,
                  ),
                  if (widget.onRemove != null)
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
                            onTap: () {
                              AppHaptics.tap();
                              widget.onRemove?.call();
                            },
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
