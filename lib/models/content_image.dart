class ContentImage {
  const ContentImage({
    required this.id,
    required this.path,
    this.altDescription = '',
  });

  final String id;
  final String path;
  final String altDescription;

  ContentImage copyWith({
    String? id,
    String? path,
    String? altDescription,
  }) {
    return ContentImage(
      id: id ?? this.id,
      path: path ?? this.path,
      altDescription: altDescription ?? this.altDescription,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'path': path,
        'altDescription': altDescription,
      };

  factory ContentImage.fromJson(Map<String, dynamic> json) {
    return ContentImage(
      id: json['id'] as String,
      path: json['path'] as String,
      altDescription: json['altDescription'] as String? ?? '',
    );
  }
}
