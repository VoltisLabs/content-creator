import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/content_entry.dart';
import 'post_image.dart';
import '../utils/app_haptics.dart';

/// Full-screen horizontal pager across [posts] for a day; each post can swipe images.
Future<void> showPostFullscreenViewer(
  BuildContext context, {
  required List<ContentEntry> posts,
  required int initialPostIndex,
  required DateTime date,
  required VoidCallback onEditPost,
}) {
  if (posts.isEmpty) return Future.value();
  final index = initialPostIndex.clamp(0, posts.length - 1);

  return Navigator.of(context, rootNavigator: true).push<void>(
    PageRouteBuilder<void>(
      opaque: true,
      pageBuilder: (context, animation, secondaryAnimation) {
        return _PostFullscreenViewer(
          posts: posts,
          initialPostIndex: index,
          date: date,
          onEditPost: onEditPost,
        );
      },
      transitionsBuilder: (context, animation, secondaryAnimation, child) =>
          child,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
    ),
  );
}

class _PostFullscreenViewer extends StatefulWidget {
  const _PostFullscreenViewer({
    required this.posts,
    required this.initialPostIndex,
    required this.date,
    required this.onEditPost,
  });

  final List<ContentEntry> posts;
  final int initialPostIndex;
  final DateTime date;
  final VoidCallback onEditPost;

  @override
  State<_PostFullscreenViewer> createState() => _PostFullscreenViewerState();
}

class _PostFullscreenViewerState extends State<_PostFullscreenViewer> {
  late final PageController _postController;
  late int _postIndex;
  final Map<int, PageController> _imageControllers = {};

  @override
  void initState() {
    super.initState();
    _postIndex = widget.initialPostIndex;
    _postController = PageController(initialPage: _postIndex);
  }

  @override
  void dispose() {
    _postController.dispose();
    for (final c in _imageControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  PageController _imageControllerFor(int postIndex, int imageCount) {
    return _imageControllers.putIfAbsent(
      postIndex,
      () => PageController(),
    );
  }

  int _imageIndexFor(int postIndex) {
    final controller = _imageControllers[postIndex];
    if (controller == null || !controller.hasClients) return 0;
    return controller.page?.round() ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final post = widget.posts[_postIndex];
    final images = post.images;
    final imageCount = images.length;

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.45),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          DateFormat('MMM d').format(widget.date),
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          if (widget.posts.length > 1)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  '${_postIndex + 1} / ${widget.posts.length}',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: Colors.white70,
                  ),
                ),
              ),
            ),
          IconButton(
            tooltip: 'Edit post',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () {
              AppHaptics.tap();
              Navigator.of(context).pop();
              WidgetsBinding.instance.addPostFrameCallback((_) {
                widget.onEditPost();
              });
            },
          ),
        ],
      ),
      body: PageView.builder(
        controller: _postController,
        itemCount: widget.posts.length,
        onPageChanged: (index) {
          AppHaptics.tap();
          setState(() => _postIndex = index);
        },
        itemBuilder: (context, postIndex) {
          final entry = widget.posts[postIndex];
          final paths = [
            for (final image in entry.images)
              if (PostImage.resolveDisplayPath(image.path) case final p?) p,
          ];

          if (paths.isEmpty) {
            return _EmptyPostPane(
              caption: entry.caption,
              postNumber: postIndex + 1,
            );
          }

          final imgController = _imageControllerFor(postIndex, paths.length);

          return Stack(
            fit: StackFit.expand,
            children: [
              PageView.builder(
                controller: imgController,
                itemCount: paths.length,
                onPageChanged: (_) => setState(() {}),
                itemBuilder: (context, imgIdx) {
                  return InteractiveViewer(
                    minScale: 0.85,
                    maxScale: 3,
                    child: Center(
                      child: PostImage(
                        path: paths[imgIdx],
                        fit: BoxFit.contain,
                      ),
                    ),
                  );
                },
              ),
              if (paths.length > 1)
                Positioned(
                  top: MediaQuery.paddingOf(context).top + 56,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_imageIndexFor(postIndex) + 1} / ${paths.length}',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              _PostCaptionOverlay(
                postNumber: postIndex + 1,
                caption: entry.caption,
                tags: entry.tags,
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: widget.posts.length > 1
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(widget.posts.length, (i) {
                    final active = i == _postIndex;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: active ? 18 : 7,
                      height: 7,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: active
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.35),
                      ),
                    );
                  }),
                ),
              ),
            )
          : imageCount > 1
              ? SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: Text(
                      'Swipe for more images',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white54,
                      ),
                    ),
                  ),
                )
              : null,
    );
  }
}

class _EmptyPostPane extends StatelessWidget {
  const _EmptyPostPane({
    required this.caption,
    required this.postNumber,
  });

  final String caption;
  final int postNumber;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.article_outlined,
                size: 56,
                color: Colors.white.withValues(alpha: 0.35),
              ),
              const SizedBox(height: 12),
              Text(
                'No images in this post',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white70,
                    ),
              ),
            ],
          ),
        ),
        _PostCaptionOverlay(
          postNumber: postNumber,
          caption: caption,
          tags: const [],
        ),
      ],
    );
  }
}

class _PostCaptionOverlay extends StatelessWidget {
  const _PostCaptionOverlay({
    required this.postNumber,
    required this.caption,
    required this.tags,
  });

  final int postNumber;
  final String caption;
  final List<String> tags;

  @override
  Widget build(BuildContext context) {
    final trimmed = caption.trim();
    final hasCaption = trimmed.isNotEmpty;
    final hasTags = tags.isNotEmpty;
    if (!hasCaption && !hasTags) {
      return Positioned(
        left: 16,
        right: 16,
        bottom: 24,
        child: Text(
          'Post $postNumber',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Colors.white54,
              ),
        ),
      );
    }

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.black.withValues(alpha: 0.85),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 32, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Post $postNumber',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Colors.white60,
                    ),
              ),
              if (hasCaption) ...[
                const SizedBox(height: 6),
                Text(
                  trimmed,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        height: 1.35,
                      ),
                ),
              ],
              if (hasTags) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: tags
                      .map(
                        (t) => Chip(
                          label: Text(t),
                          visualDensity: VisualDensity.compact,
                          backgroundColor: Colors.white.withValues(alpha: 0.12),
                          labelStyle: const TextStyle(color: Colors.white),
                          side: BorderSide.none,
                        ),
                      )
                      .toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
