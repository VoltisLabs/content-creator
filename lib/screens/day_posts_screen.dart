import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/content_entry.dart';
import '../services/plan_service.dart';
import '../services/storage_service.dart';
import '../utils/app_haptics.dart';
import '../utils/relative_time.dart';
import '../widgets/post_image.dart';
import '../widgets/haptic_buttons.dart';
import '../widgets/paywall_sheet.dart';
import '../widgets/post_fullscreen_viewer.dart';
import '../widgets/share_sheet.dart';
import 'content_detail_screen.dart';

enum _DayPostsViewMode { list, grid }

class DayPostsScreen extends StatefulWidget {
  const DayPostsScreen({
    super.key,
    required this.date,
    required this.onChanged,
    this.postsOverride,
    this.readOnly = false,
  });

  final DateTime date;
  final VoidCallback onChanged;
  final List<ContentEntry>? postsOverride;
  final bool readOnly;

  @override
  State<DayPostsScreen> createState() => _DayPostsScreenState();
}

class _DayPostsScreenState extends State<DayPostsScreen> {
  final _storage = StorageService.instance;
  late String _dateKey;
  List<ContentEntry> _posts = [];
  _DayPostsViewMode _viewMode = _DayPostsViewMode.list;

  @override
  void initState() {
    super.initState();
    _dateKey = DateFormat('yyyy-MM-dd').format(widget.date);
    _loadPosts();
  }

  void _loadPosts() {
    if (widget.postsOverride != null) {
      setState(() => _posts = List<ContentEntry>.from(widget.postsOverride!));
      return;
    }
    setState(() => _posts = _storage.getEntriesForDate(_dateKey));
  }

  void _openPostViewer(int index) {
    if (_posts.isEmpty || index < 0 || index >= _posts.length) return;
    AppHaptics.tap();
    final capturedIndex = index;
    showPostFullscreenViewer(
      context,
      posts: List<ContentEntry>.from(_posts),
      initialPostIndex: capturedIndex,
      date: widget.date,
      onEditPost: () => _openPostEditor(entry: _posts[capturedIndex]),
    );
  }

  Future<void> _openPostEditor({ContentEntry? entry}) async {
    if (widget.readOnly && entry != null) {
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => ContentDetailScreen(
            date: widget.date,
            initialEntry: entry,
            readOnly: true,
          ),
        ),
      );
      return;
    }
    if (entry == null) {
      final limit = await PlanService.instance.limitMessageForNewPost(
        dateKey: _dateKey,
      );
      if (limit != null) {
        if (!mounted) return;
        await showPaywallSheet(
          context,
          feature: limit,
        );
        return;
      }
    }

    if (!mounted) return;
    final result = await Navigator.push<ContentEntry?>(
      context,
      MaterialPageRoute(
        builder: (_) => ContentDetailScreen(
          date: widget.date,
          initialEntry: entry,
          onEntryChanged: (_) => widget.onChanged(),
        ),
      ),
    );
    if (!mounted) return;
    _loadPosts();
    widget.onChanged();
    if (result != null && result.hasContent) {
      _loadPosts();
    }
  }

  Future<void> _deletePost(ContentEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete post?'),
        content: const Text('This removes the post and its images from this day.'),
        actions: [
          HapticTextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          HapticFilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _storage.deleteEntry(_dateKey, entry.id);
    _loadPosts();
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final formattedDate = DateFormat('EEEE, MMMM d, yyyy').format(widget.date);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(formattedDate, overflow: TextOverflow.ellipsis),
        actions: [
          RoundOutlinedIconButton(
            tooltip: 'List view',
            icon: Icons.view_agenda_outlined,
            selected: _viewMode == _DayPostsViewMode.list,
            onPressed: () => setState(() => _viewMode = _DayPostsViewMode.list),
          ),
          const SizedBox(width: 4),
          RoundOutlinedIconButton(
            tooltip: 'Grid view',
            icon: Icons.grid_view_rounded,
            selected: _viewMode == _DayPostsViewMode.grid,
            onPressed: () => setState(() => _viewMode = _DayPostsViewMode.grid),
          ),
          const SizedBox(width: 4),
          HapticIconButton(
            tooltip: 'Share day',
            onPressed: () => showShareSheet(context, date: widget.date),
            icon: Icons.share_outlined,
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: widget.readOnly
          ? null
          : FloatingActionButton(
              onPressed: AppHaptics.wrap(() => _openPostEditor()),
              tooltip: 'Add post',
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              shape: const CircleBorder(),
              elevation: 3,
              highlightElevation: 5,
              child: const Icon(Icons.add),
            ),
      body: _posts.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.event_note_outlined,
                      size: 48,
                      color: theme.colorScheme.primary.withValues(alpha: 0.7),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No posts yet for this day',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Add one or more posts to plan your content.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : _viewMode == _DayPostsViewMode.grid
              ? GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.72,
                  ),
                  itemCount: _posts.length,
                  itemBuilder: (context, index) {
                    final post = _posts[index];
                    return _PostGridCard(
                      post: post,
                      index: index + 1,
                      readOnly: widget.readOnly,
                      onView: () => _openPostViewer(index),
                      onEdit: () => _openPostEditor(entry: post),
                      onDelete: () => _deletePost(post),
                      onShare: () => showShareSheet(
                        context,
                        date: widget.date,
                        postCaption: post.caption,
                      ),
                    );
                  },
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                  itemCount: _posts.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final post = _posts[index];
                    return _PostCard(
                      post: post,
                      index: index + 1,
                      onView: () => _openPostViewer(index),
                      onEdit: () => _openPostEditor(entry: post),
                      onDelete: () => _deletePost(post),
                      onShare: () => showShareSheet(
                        context,
                        date: widget.date,
                        postCaption: post.caption,
                      ),
                    );
                  },
                ),
    );
  }
}

class _PostCard extends StatelessWidget {
  const _PostCard({
    required this.post,
    required this.index,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
    required this.onShare,
  });

  final ContentEntry post;
  final int index;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final Future<void> Function() onDelete;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final caption = post.caption.trim();
    final preview = caption.isEmpty ? 'Untitled post' : caption;
    final relative = formatPostCreatedLabel(post.createdAtMillis);
    final metaStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
    );
    final metaText =
        '${post.tags.length} tag${post.tags.length == 1 ? '' : 's'} · '
        '${post.images.length} image${post.images.length == 1 ? '' : 's'}';

    return Dismissible(
      key: ValueKey(post.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        await onDelete();
        return false;
      },
      background: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Icon(
              Icons.delete_outline,
              color: theme.colorScheme.onErrorContainer,
            ),
          ),
        ),
      ),
      child: Material(
        color: theme.cardTheme.color ?? theme.colorScheme.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.25),
          ),
        ),
        child: InkWell(
          onTap: onEdit,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CoverThumb(
                  path: post.coverImagePath ?? post.images.firstOrNull?.path,
                  size: 56,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Post $index',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (relative.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                relative,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: metaStyle,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        preview,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              metaText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: metaStyle,
                            ),
                          ),
                          HapticIconButton(
                            tooltip: 'View full screen',
                            onPressed: onView,
                            icon: Icons.visibility_outlined,
                          ),
                          HapticIconButton(
                            tooltip: 'Share post',
                            onPressed: onShare,
                            icon: Icons.share_outlined,
                          ),
                          HapticIconButton(
                            tooltip: 'Delete post',
                            onPressed: () => onDelete(),
                            icon: Icons.delete_outline,
                            style: IconButton.styleFrom(
                              foregroundColor: theme.colorScheme.error.withValues(alpha: 0.85),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PostGridCard extends StatelessWidget {
  const _PostGridCard({
    required this.post,
    required this.index,
    required this.readOnly,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
    required this.onShare,
  });

  final ContentEntry post;
  final int index;
  final bool readOnly;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final Future<void> Function() onDelete;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final caption = post.caption.trim();
    final preview = caption.isEmpty ? 'Untitled post' : caption;
    final relative = formatPostCreatedLabel(post.createdAtMillis);
    final path = post.coverImagePath ?? post.images.firstOrNull?.path;

    return Material(
      color: theme.cardTheme.color ?? theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.outline.withValues(alpha: 0.25),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onEdit,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: path == null
                  ? ColoredBox(
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: Icon(
                        Icons.article_outlined,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
                      ),
                    )
                  : _CoverThumb(path: path, size: double.infinity, expand: true),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Post $index',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (relative.isNotEmpty)
                    Text(
                      relative,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    preview,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      HapticIconButton(
                        tooltip: 'View',
                        onPressed: onView,
                        icon: Icons.visibility_outlined,
                      ),
                      HapticIconButton(
                        tooltip: 'Share post',
                        onPressed: onShare,
                        icon: Icons.share_outlined,
                      ),
                      if (!readOnly)
                        HapticIconButton(
                          tooltip: 'Delete',
                          onPressed: () => onDelete(),
                          icon: Icons.delete_outline,
                          style: IconButton.styleFrom(
                            foregroundColor:
                                theme.colorScheme.error.withValues(alpha: 0.85),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CoverThumb extends StatelessWidget {
  const _CoverThumb({
    this.path,
    required this.size,
    this.expand = false,
  });

  final String? path;
  final double size;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final resolved = PostImage.isAssetPath(path)
        ? path
        : StorageService.instance.resolveImagePath(path);

    final image = resolved == null
        ? Icon(
            Icons.broken_image_outlined,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
          )
        : PostImage(
            path: resolved,
            fit: BoxFit.cover,
            width: expand ? double.infinity : size,
            height: expand ? double.infinity : size,
          );

    if (expand) {
      return ColoredBox(
        color: theme.colorScheme.surfaceContainerHighest,
        child: image,
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: size,
        height: size,
        color: theme.colorScheme.surfaceContainerHighest,
        child: image,
      ),
    );
  }
}

extension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
