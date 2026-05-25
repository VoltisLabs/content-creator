import 'package:uuid/uuid.dart';

import 'content_image.dart';

class ContentEntry {
  const ContentEntry({
    required this.id,
    required this.dateKey,
    this.caption = '',
    this.tags = const [],
    this.altDescription = '',
    this.coverImagePath,
    this.images = const [],
  });

  /// Stable id for multi-post days.
  final String id;

  /// yyyy-MM-dd
  final String dateKey;
  final String caption;
  final List<String> tags;
  final String altDescription;
  final String? coverImagePath;
  final List<ContentImage> images;

  bool get hasContent =>
      caption.isNotEmpty ||
      tags.isNotEmpty ||
      altDescription.isNotEmpty ||
      coverImagePath != null ||
      images.isNotEmpty;

  ContentEntry copyWith({
    String? id,
    String? dateKey,
    String? caption,
    List<String>? tags,
    String? altDescription,
    String? coverImagePath,
    bool clearCover = false,
    List<ContentImage>? images,
  }) {
    return ContentEntry(
      id: id ?? this.id,
      dateKey: dateKey ?? this.dateKey,
      caption: caption ?? this.caption,
      tags: tags ?? this.tags,
      altDescription: altDescription ?? this.altDescription,
      coverImagePath: clearCover ? null : (coverImagePath ?? this.coverImagePath),
      images: images ?? this.images,
    );
  }

  factory ContentEntry.create({required String dateKey}) {
    return ContentEntry(
      id: const Uuid().v4(),
      dateKey: dateKey,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'dateKey': dateKey,
        'caption': caption,
        'tags': tags,
        'altDescription': altDescription,
        'coverImagePath': coverImagePath,
        'images': images.map((i) => i.toJson()).toList(),
      };

  factory ContentEntry.fromJson(Map<String, dynamic> json) {
    return ContentEntry(
      id: json['id'] as String? ?? const Uuid().v4(),
      dateKey: json['dateKey'] as String,
      caption: json['caption'] as String? ?? '',
      tags: (json['tags'] as List<dynamic>? ?? []).cast<String>(),
      altDescription: json['altDescription'] as String? ?? '',
      coverImagePath: json['coverImagePath'] as String?,
      images: (json['images'] as List<dynamic>? ?? [])
          .map((e) => ContentImage.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
