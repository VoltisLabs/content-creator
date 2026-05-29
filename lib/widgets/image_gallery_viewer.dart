import 'package:flutter/material.dart';

import '../utils/app_haptics.dart';
import 'post_image.dart';

/// Full-screen swipeable gallery for a list of on-disk image paths.
Future<void> showImageGalleryViewer(
  BuildContext context, {
  required List<String> imagePaths,
  int initialIndex = 0,
}) {
  if (imagePaths.isEmpty) return Future.value();
  final index = initialIndex.clamp(0, imagePaths.length - 1);

  return Navigator.of(context, rootNavigator: true).push<void>(
    PageRouteBuilder<void>(
      opaque: true,
      pageBuilder: (context, animation, secondaryAnimation) {
        return _ImageGalleryViewer(
          imagePaths: imagePaths,
          initialIndex: index,
        );
      },
      transitionsBuilder: (context, animation, secondaryAnimation, child) =>
          child,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
    ),
  );
}

class _ImageGalleryViewer extends StatefulWidget {
  const _ImageGalleryViewer({
    required this.imagePaths,
    required this.initialIndex,
  });

  final List<String> imagePaths;
  final int initialIndex;

  @override
  State<_ImageGalleryViewer> createState() => _ImageGalleryViewerState();
}

class _ImageGalleryViewerState extends State<_ImageGalleryViewer> {
  late final PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _controller = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.imagePaths.length;

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.45),
        foregroundColor: Colors.white,
        elevation: 0,
        title: count > 1 ? Text('${_index + 1} / $count') : null,
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: count,
        onPageChanged: (i) {
          AppHaptics.tap();
          setState(() => _index = i);
        },
        itemBuilder: (context, i) {
          return InteractiveViewer(
            minScale: 0.85,
            maxScale: 3,
            child: Center(
              child: PostImage(
                path: widget.imagePaths[i],
                fit: BoxFit.contain,
              ),
            ),
          );
        },
      ),
    );
  }
}
