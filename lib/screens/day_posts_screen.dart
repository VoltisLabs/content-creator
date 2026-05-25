import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/content_entry.dart';
import '../services/plan_service.dart';
import '../services/storage_service.dart';
import '../utils/app_haptics.dart';
import '../widgets/haptic_buttons.dart';
import '../widgets/paywall_sheet.dart';
import '../widgets/share_sheet.dart';
import 'content_detail_screen.dart';

class DayPostsScreen extends StatefulWidget {
  const DayPostsScreen({
    super.key,
    required this.date,
    required this.onChanged,
  });

  final DateTime date;
  final VoidCallback onChanged;

  @override
  State<DayPostsScreen> createState() => _DayPostsScreenState();
}

class _DayPostsScreenState extends State<DayPostsScreen> {
  final _storage = StorageService.instance;
  late String _dateKey;
  List<ContentEntry> _posts = [];

  @override
  void initState() {
    super.initState();
    _dateKey = DateFormat('yyyy-MM-dd').format(widget.date);
    _loadPosts();
  }

  void _loadPosts() {
    setState(() => _posts = _storage.getEntriesForDate(_dateKey));
  }

  Future<void> _openPost({ContentEntry? entry}) async {
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
          HapticIconButton(
            tooltip: 'Share day',
            onPressed: () => showShareSheet(context, date: widget.date),
            icon: Icons.share_outlined,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: AppHaptics.wrap(() => _openPost()),
        icon: const Icon(Icons.add),
        label: const Text('Add post'),
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
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              itemCount: _posts.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final post = _posts[index];
                return _PostCard(
                  post: post,
                  index: index + 1,
                  onTap: () => _openPost(entry: post),
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
    required this.onTap,
    required this.onDelete,
    required this.onShare,
  });

  final ContentEntry post;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final caption = post.caption.trim();
    final preview = caption.isEmpty ? 'Untitled post' : caption;

    return Material(
      color: theme.cardTheme.color ?? theme.colorScheme.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.outline.withValues(alpha: 0.25),
        ),
      ),
      child: HapticInkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _CoverThumb(
                path: post.coverImagePath ?? post.images.firstOrNull?.path,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Post $index',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      preview,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge,
                    ),
                    if (post.tags.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        '${post.tags.length} tag${post.tags.length == 1 ? '' : 's'} · ${post.images.length} image${post.images.length == 1 ? '' : 's'}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              HapticIconButton(
                tooltip: 'Share post',
                onPressed: onShare,
                icon: Icons.share_outlined,
              ),
              HapticIconButton(
                tooltip: 'Delete post',
                onPressed: onDelete,
                icon: Icons.delete_outline,
                style: IconButton.styleFrom(
                  foregroundColor: theme.colorScheme.error.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CoverThumb extends StatelessWidget {
  const _CoverThumb({this.path});

  final String? path;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final resolved = StorageService.instance.resolveImagePath(path);

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 56,
        height: 56,
        color: theme.colorScheme.surfaceContainerHighest,
        child: resolved == null
            ? Icon(
                Icons.broken_image_outlined,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
              )
            : Image.file(
                File(resolved),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Icon(
                  Icons.broken_image_outlined,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
                ),
              ),
      ),
    );
  }
}

extension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
