import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../models/content_entry.dart';
import '../models/content_image.dart';
import '../services/image_pick_service.dart';
import '../services/plan_service.dart';
import '../services/storage_service.dart';
import '../utils/app_haptics.dart';
import '../widgets/haptic_buttons.dart';
import '../widgets/image_thumbnail.dart';
import '../widgets/post_image.dart';
import '../widgets/paywall_sheet.dart';
import '../widgets/image_gallery_viewer.dart';
import '../widgets/post_fullscreen_viewer.dart';
import '../widgets/resizable_text_field.dart';
import '../widgets/share_sheet.dart';

class ContentDetailScreen extends StatefulWidget {
  const ContentDetailScreen({
    super.key,
    required this.date,
    this.initialEntry,
    this.onEntryChanged,
    this.readOnly = false,
  });

  final DateTime date;
  final ContentEntry? initialEntry;
  final ValueChanged<ContentEntry?>? onEntryChanged;
  final bool readOnly;

  @override
  State<ContentDetailScreen> createState() => _ContentDetailScreenState();
}

class _ContentDetailScreenState extends State<ContentDetailScreen> {
  final _captionController = TextEditingController();
  final _altController = TextEditingController();
  final _tagController = TextEditingController();
  final _storage = StorageService.instance;

  late String _dateKey;
  late String _entryId;
  String? _coverPath;
  List<ContentImage> _images = [];
  List<String> _tags = [];
  int? _selectedImageIndex;
  bool _saving = false;

  static const _thumbSize = 72.0;

  @override
  void initState() {
    super.initState();
    _dateKey = DateFormat('yyyy-MM-dd').format(widget.date);
    final entry = widget.initialEntry ?? ContentEntry.create(dateKey: _dateKey);
    _entryId = entry.id;
    _captionController.text = entry.caption;
    _altController.text = entry.altDescription;
    _coverPath = PostImage.isAssetPath(entry.coverImagePath)
        ? entry.coverImagePath
        : _storage.resolveImagePath(entry.coverImagePath);
    _images = [
      for (final image in entry.images)
        if (PostImage.isAssetPath(image.path))
          image
        else if (_storage.resolveImagePath(image.path) case final resolved?)
          image.copyWith(path: resolved),
    ];
    _tags = List.from(entry.tags);
    if (_images.isNotEmpty) {
      _selectedImageIndex = 0;
    }
    if (!widget.readOnly) {
      _captionController.addListener(_schedulePersist);
      _altController.addListener(_schedulePersist);
    }
  }

  void _schedulePersist() {
    _persistDebounce?.cancel();
    _persistDebounce = Timer(const Duration(milliseconds: 400), () {
      _persistAndNotify();
    });
  }

  Timer? _persistDebounce;

  @override
  void dispose() {
    _persistDebounce?.cancel();
    _captionController.removeListener(_schedulePersist);
    _altController.removeListener(_schedulePersist);
    _captionController.dispose();
    _altController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  ContentEntry _buildEntry() {
    return ContentEntry(
      id: _entryId,
      dateKey: _dateKey,
      caption: _captionController.text.trim(),
      tags: _tags,
      altDescription: _altController.text.trim(),
      coverImagePath: _coverPath,
      images: _images,
    );
  }

  Future<bool> _withinPlanLimits() async {
    final entry = _buildEntry();
    if (!entry.hasContent) return true;
    final message = await PlanService.instance.limitMessageForNewPost(
      dateKey: _dateKey,
      existingEntryId: widget.initialEntry?.id ?? _entryId,
    );
    if (message == null) return true;
    if (!mounted) return false;
    await showPaywallSheet(context, feature: message);
    return false;
  }

  Future<void> _persistAndNotify() async {
    if (!await _withinPlanLimits()) return;
    final entry = _buildEntry();
    await _storage.saveEntry(entry);
    widget.onEntryChanged?.call(entry.hasContent ? entry : null);
  }

  Future<void> _pickCover() async {
    final file = await ImagePickService.pickSingleImage();
    if (file == null || !mounted) return;
    final path = await _storage.importImage(file);
    setState(() => _coverPath = path);
    await _persistAndNotify();
  }

  Future<void> _addImages() async {
    final files = await ImagePickService.pickMultipleImages();
    if (files.isEmpty || !mounted) return;

    final imported = <ContentImage>[];
    for (final file in files) {
      final path = await _storage.importImage(file);
      imported.add(ContentImage(id: const Uuid().v4(), path: path));
    }

    setState(() {
      _images = [..._images, ...imported];
      if (_coverPath == null && _images.isNotEmpty) {
        _coverPath = _images.first.path;
      }
      _selectedImageIndex ??= 0;
    });
    await _persistAndNotify();
  }

  void _addTag() {
    final tag = _tagController.text.trim();
    if (tag.isEmpty || _tags.contains(tag)) return;
    setState(() {
      _tags = [..._tags, tag];
      _tagController.clear();
    });
    _persistAndNotify();
  }

  void _removeTag(String tag) {
    setState(() => _tags = _tags.where((t) => t != tag).toList());
    _persistAndNotify();
  }

  void _selectImage(int index) {
    setState(() => _selectedImageIndex = index);
  }

  Future<void> _showImageAltSheet(int index) async {
    _selectImage(index);
    final controller = TextEditingController(
      text: _images[index].altDescription,
    );
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            16 + MediaQuery.viewInsetsOf(sheetContext).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Alt text for image ${index + 1}',
                style: Theme.of(sheetContext).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 3,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Describe this image for accessibility…',
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () {
                  AppHaptics.tap();
                  _updateImageAlt(index, controller.text.trim());
                  Navigator.pop(sheetContext);
                },
                child: const Text('Save'),
              ),
            ],
          ),
        );
      },
    );
    controller.dispose();
    await _persistAndNotify();
  }

  void _updateImageAlt(int index, String alt) {
    setState(() {
      _images[index] = _images[index].copyWith(altDescription: alt);
    });
  }

  void _openImagesFullscreen(int initialIndex) {
    if (_images.isEmpty) return;
    AppHaptics.tap();
    final paths = [
      for (final image in _images)
        if (PostImage.resolveDisplayPath(image.path) case final path?) path,
    ];
    if (paths.isEmpty) return;
    final safeIndex = initialIndex.clamp(0, paths.length - 1);
    setState(() => _selectedImageIndex = safeIndex);
    showImageGalleryViewer(
      context,
      imagePaths: paths,
      initialIndex: safeIndex,
    );
  }

  String _tagsForClipboard() {
    return _tags
        .map((tag) {
          final trimmed = tag.trim();
          if (trimmed.isEmpty) return '';
          return trimmed.startsWith('#') ? trimmed : '#$trimmed';
        })
        .where((tag) => tag.isNotEmpty)
        .join(' ');
  }

  Future<void> _copyAllTags() async {
    if (_tags.isEmpty) return;
    AppHaptics.tap();
    await Clipboard.setData(ClipboardData(text: _tagsForClipboard()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _tags.length == 1
              ? 'Copied 1 tag'
              : 'Copied ${_tags.length} tags',
        ),
      ),
    );
  }

  Future<void> _removeImage(int index) async {
    final image = _images[index];
    await _storage.deleteImageFile(image.path);

    setState(() {
      _images = [..._images]..removeAt(index);
      if (_coverPath == image.path) {
        _coverPath = _images.isNotEmpty ? _images.first.path : null;
      }
      if (_images.isEmpty) {
        _selectedImageIndex = null;
      } else if (_selectedImageIndex == index) {
        _selectedImageIndex = 0;
      } else if (_selectedImageIndex != null && _selectedImageIndex! > index) {
        _selectedImageIndex = _selectedImageIndex! - 1;
      }
    });
    await _persistAndNotify();
  }

  Future<void> _removeCover() async {
    if (_coverPath == null) return;
    await _storage.deleteImageFile(_coverPath);
    setState(() => _coverPath = null);
    await _persistAndNotify();
  }

  Future<void> _save() async {
    if (!await _withinPlanLimits()) return;
    setState(() => _saving = true);
    final entry = _buildEntry();
    await _storage.saveEntry(entry);
    if (mounted) {
      setState(() => _saving = false);
      Navigator.pop(context, entry.hasContent ? entry : null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final formattedDate = DateFormat('EEEE, MMMM d, yyyy').format(widget.date);
    final theme = Theme.of(context);
    final readOnly = widget.readOnly;

    return PopScope(
      canPop: readOnly,
      onPopInvokedWithResult: (didPop, _) {
        if (readOnly || didPop) return;
        _persistDebounce?.cancel();
        _persistAndNotify().then((_) {
          if (!context.mounted) return;
          final entry = _buildEntry();
          Navigator.of(context).pop(entry.hasContent ? entry : null);
        });
      },
      child: Scaffold(
      appBar: AppBar(
        title: Text(formattedDate, overflow: TextOverflow.ellipsis),
        actions: [
          if (!readOnly) ...[
            HapticIconButton(
              tooltip: 'Share',
              onPressed: () => showShareSheet(
                context,
                date: widget.date,
                postCaption: _captionController.text.trim(),
              ),
              icon: Icons.share_outlined,
            ),
            TextButton.icon(
              onPressed: AppHaptics.wrap(_saving ? null : _save),
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: const Text('Save'),
            ),
          ],
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle(context, 'Grid cover', Icons.image_outlined),
            const SizedBox(height: 8),
            if (readOnly && _coverPath != null)
              GestureDetector(
                onTap: _images.isNotEmpty
                    ? () => _openImagesFullscreen(0)
                    : null,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: PostImage(path: _coverPath!, width: 72, height: 72),
                ),
              )
            else if (!readOnly)
              _CoverRow(
                coverPath: _coverPath,
                onPick: _pickCover,
                onRemove: _coverPath != null ? _removeCover : null,
              ),
            const SizedBox(height: 14),
            _sectionTitle(context, 'Caption', Icons.notes),
            const SizedBox(height: 8),
            readOnly
                ? SelectableText(
                    _captionController.text.isEmpty
                        ? '-'
                        : _captionController.text,
                    style: theme.textTheme.bodyLarge,
                  )
                : ResizableTextField(
                    controller: _captionController,
                    hintText: 'Write your post caption...',
                    minLines: 2,
                    maxLines: 14,
                  ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _sectionTitle(context, 'Tags', Icons.local_offer_outlined),
                ),
                if (readOnly && _tags.isNotEmpty)
                  HapticTextButton(
                    onPressed: _copyAllTags,
                    child: const Text('Copy all'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (!readOnly)
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _tagController,
                      decoration: const InputDecoration(
                        hintText: 'Add a tag',
                        isDense: true,
                      ),
                      onSubmitted: (_) => _addTag(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  HapticFilledButton(
                    onPressed: _addTag,
                    child: const Text('Add'),
                  ),
                  if (_tags.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    HapticTextButton(
                      onPressed: _copyAllTags,
                      child: const Text('Copy all'),
                    ),
                  ],
                ],
              ),
            const SizedBox(height: 8),
            SizedBox(
              height: 36,
              child: _tags.isEmpty
                  ? Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'No tags yet',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    )
                  : ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _tags.length,
                      separatorBuilder: (context, index) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final tag = _tags[index];
                        return InputChip(
                          label: Text(tag),
                          onDeleted: readOnly
                              ? null
                              : () {
                                  AppHaptics.tap();
                                  _removeTag(tag);
                                },
                          visualDensity: VisualDensity.compact,
                        );
                      },
                    ),
            ),
            const SizedBox(height: 14),
            _sectionTitle(context, 'Alt description', Icons.accessibility_new),
            const SizedBox(height: 8),
            readOnly
                ? SelectableText(
                    _altController.text.isEmpty
                        ? '-'
                        : _altController.text,
                    style: theme.textTheme.bodyMedium,
                  )
                : ResizableTextField(
                    controller: _altController,
                    hintText: 'Describe this content for accessibility...',
                    minLines: 1,
                    maxLines: 10,
                  ),
            const SizedBox(height: 14),
            _sectionTitle(context, 'Images', Icons.photo_library_outlined),
            const SizedBox(height: 8),
            SizedBox(
              height: _thumbSize,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                primary: false,
                shrinkWrap: true,
                itemCount: readOnly
                    ? _images.length
                    : (_images.isEmpty ? 1 : _images.length + 1),
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  if (!readOnly && _images.isEmpty) {
                    return _AddImageTile(
                      size: _thumbSize,
                      onTap: _addImages,
                    );
                  }

                  if (!readOnly && index == _images.length) {
                    return _AddImageTile(
                      size: _thumbSize,
                      onTap: _addImages,
                    );
                  }

                  final image = _images[index];
                  return ImageThumbnail(
                    path: image.path,
                    size: _thumbSize,
                    selected: _selectedImageIndex == index,
                    onTap: () => _openImagesFullscreen(index),
                    onLongPress: readOnly
                        ? (image.altDescription?.isNotEmpty == true
                            ? () => _showImageAltSheet(index)
                            : null)
                        : () => _showImageAltSheet(index),
                    onRemove: readOnly ? null : () => _removeImage(index),
                  );
                },
              ),
            ),
            if (_images.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Tap an image for full screen. Long-press for alt text.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}

class _CoverRow extends StatelessWidget {
  const _CoverRow({
    required this.coverPath,
    required this.onPick,
    this.onRemove,
  });

  final String? coverPath;
  final VoidCallback onPick;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        GestureDetector(
          onTap: () {
            AppHaptics.tap();
            onPick();
          },
          child: coverPath != null
              ? ImageThumbnail(
                  path: coverPath!,
                  size: 72,
                  onTap: onPick,
                  onRemove: onRemove,
                )
              : Container(
                  width: 72,
                  height: 72,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: theme.colorScheme.surfaceContainerHighest,
                    border: Border.all(
                      color: theme.colorScheme.outline.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Icon(
                    Icons.image_outlined,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ),
        ),
        const SizedBox(width: 12),
        FilledButton.tonal(
          onPressed: AppHaptics.wrap(onPick),
          child: Text(coverPath == null ? 'Choose' : 'Change'),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'Shown on the calendar grid',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ),
      ],
    );
  }
}

class _AddImageTile extends StatelessWidget {
  const _AddImageTile({
    required this.size,
    required this.onTap,
  });

  final double size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: theme.colorScheme.outline.withValues(alpha: 0.35),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: HapticInkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(
            Icons.add_photo_alternate_outlined,
            color: theme.colorScheme.primary,
          ),
        ),
      ),
    );
  }
}
