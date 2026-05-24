import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../models/content_entry.dart';
import '../models/content_image.dart';
import '../services/storage_service.dart';
import '../widgets/image_thumbnail.dart';

class ContentDetailScreen extends StatefulWidget {
  const ContentDetailScreen({
    super.key,
    required this.date,
    required this.initialEntry,
    this.onEntryChanged,
  });

  final DateTime date;
  final ContentEntry? initialEntry;
  final ValueChanged<ContentEntry?>? onEntryChanged;

  @override
  State<ContentDetailScreen> createState() => _ContentDetailScreenState();
}

class _ContentDetailScreenState extends State<ContentDetailScreen> {
  final _captionController = TextEditingController();
  final _altController = TextEditingController();
  final _tagController = TextEditingController();
  final _imageAltController = TextEditingController();
  final _picker = ImagePicker();
  final _storage = StorageService.instance;

  late String _dateKey;
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
    final entry = widget.initialEntry;
    if (entry != null) {
      _captionController.text = entry.caption;
      _altController.text = entry.altDescription;
      _coverPath = entry.coverImagePath;
      _images = List.from(entry.images);
      _tags = List.from(entry.tags);
      if (_images.isNotEmpty) {
        _selectedImageIndex = 0;
        _imageAltController.text = _images.first.altDescription;
      }
    }
  }

  @override
  void dispose() {
    _captionController.dispose();
    _altController.dispose();
    _tagController.dispose();
    _imageAltController.dispose();
    super.dispose();
  }

  ContentEntry _buildEntry() {
    return ContentEntry(
      dateKey: _dateKey,
      caption: _captionController.text.trim(),
      tags: _tags,
      altDescription: _altController.text.trim(),
      coverImagePath: _coverPath,
      images: _images,
    );
  }

  Future<void> _persistAndNotify() async {
    final entry = _buildEntry();
    await _storage.saveEntry(entry);
    widget.onEntryChanged?.call(entry.hasContent ? entry : null);
  }

  Future<void> _pickCover() async {
    final file = await _pickSingleImageFile();
    if (file == null || !mounted) return;
    final path = await _storage.importImage(file);
    setState(() => _coverPath = path);
    await _persistAndNotify();
  }

  Future<void> _addImages() async {
    final files = await _pickMultipleImageFiles();
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
      if (_selectedImageIndex != null) {
        _imageAltController.text = _images[_selectedImageIndex!].altDescription;
      }
    });
    await _persistAndNotify();
  }

  Future<File?> _pickSingleImageFile() async {
    final result = await _picker.pickImage(source: ImageSource.gallery);
    if (result == null) return null;
    return File(result.path);
  }

  Future<List<File>> _pickMultipleImageFiles() async {
    final results = await _picker.pickMultiImage();
    return results.map((r) => File(r.path)).toList();
  }

  void _addTag() {
    final tag = _tagController.text.trim();
    if (tag.isEmpty || _tags.contains(tag)) return;
    setState(() {
      _tags = [..._tags, tag];
      _tagController.clear();
    });
  }

  void _removeTag(String tag) {
    setState(() => _tags = _tags.where((t) => t != tag).toList());
  }

  void _selectImage(int index) {
    setState(() {
      _selectedImageIndex = index;
      _imageAltController.text = _images[index].altDescription;
    });
  }

  void _updateSelectedImageAlt(String alt) {
    final index = _selectedImageIndex;
    if (index == null) return;
    setState(() {
      _images[index] = _images[index].copyWith(altDescription: alt);
    });
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
        _imageAltController.clear();
      } else if (_selectedImageIndex == index) {
        _selectedImageIndex = 0;
        _imageAltController.text = _images.first.altDescription;
      } else if (_selectedImageIndex != null && _selectedImageIndex! > index) {
        _selectedImageIndex = _selectedImageIndex! - 1;
      }
    });
    await _persistAndNotify();
  }

  Future<void> _removeCover() async {
    await _storage.deleteImageFile(_coverPath);
    setState(() => _coverPath = null);
    await _persistAndNotify();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final entry = _buildEntry();
    await _storage.saveEntry(entry);
    if (mounted) {
      setState(() => _saving = false);
      Navigator.pop(context, entry.hasContent ? entry : null);
    }
  }

  Future<void> _useImageAsCover(int index) async {
    setState(() => _coverPath = _images[index].path);
    await _persistAndNotify();
  }

  @override
  Widget build(BuildContext context) {
    final formattedDate = DateFormat('EEEE, MMMM d, yyyy').format(widget.date);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(formattedDate, overflow: TextOverflow.ellipsis),
        actions: [
          TextButton.icon(
            onPressed: _saving ? null : _save,
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
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle(context, 'Grid cover', Icons.image_outlined),
            const SizedBox(height: 8),
            _CoverRow(
              coverPath: _coverPath,
              onPick: _pickCover,
              onRemove: _coverPath != null ? _removeCover : null,
            ),
            const SizedBox(height: 14),
            _sectionTitle(context, 'Caption', Icons.notes),
            const SizedBox(height: 8),
            TextField(
              controller: _captionController,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: 'Write your post caption...',
                isDense: true,
              ),
            ),
            const SizedBox(height: 14),
            _sectionTitle(context, 'Tags', Icons.local_offer_outlined),
            const SizedBox(height: 8),
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
                FilledButton(onPressed: _addTag, child: const Text('Add')),
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
                          onDeleted: () => _removeTag(tag),
                          visualDensity: VisualDensity.compact,
                        );
                      },
                    ),
            ),
            const SizedBox(height: 14),
            _sectionTitle(context, 'Alt description', Icons.accessibility_new),
            const SizedBox(height: 8),
            TextField(
              controller: _altController,
              maxLines: 1,
              decoration: const InputDecoration(
                hintText: 'Describe this content for accessibility...',
                isDense: true,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _sectionTitle(
                    context,
                    'Images',
                    Icons.photo_library_outlined,
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: _addImages,
                  icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
                  label: const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: _thumbSize,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                primary: false,
                shrinkWrap: true,
                itemCount: _images.isEmpty ? 1 : _images.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  if (_images.isEmpty) {
                    return Container(
                      width: _thumbSize,
                      height: _thumbSize,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: theme.colorScheme.outline.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Icon(
                        Icons.photo_outlined,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
                      ),
                    );
                  }

                  final image = _images[index];
                  return ImageThumbnail(
                    path: image.path,
                    size: _thumbSize,
                    selected: _selectedImageIndex == index,
                    onTap: () => _selectImage(index),
                    onRemove: () => _removeImage(index),
                  );
                },
              ),
            ),
            if (_selectedImageIndex != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _imageAltController,
                      maxLines: 1,
                      decoration: const InputDecoration(
                        labelText: 'Alt for selected image',
                        isDense: true,
                      ),
                      onChanged: _updateSelectedImageAlt,
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => _useImageAsCover(_selectedImageIndex!),
                    child: const Text('Set as cover'),
                  ),
                ],
              ),
            ],
          ],
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
        if (coverPath != null)
          ImageThumbnail(
            path: coverPath!,
            size: 72,
            onRemove: onRemove ?? () {},
          )
        else
          Container(
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
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'Shown on the calendar grid',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ),
        FilledButton.tonal(
          onPressed: onPick,
          child: Text(coverPath == null ? 'Choose' : 'Change'),
        ),
      ],
    );
  }
}
