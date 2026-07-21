import 'package:flutter/foundation.dart';

/// The kind of asset a [LibraryFile] points to — drives icon/color choice
/// in list tiles without re-deriving it from the file extension everywhere.
enum LibraryFileType { pdf, image }

LibraryFileType libraryFileTypeFromExtension(String path) {
  final lower = path.toLowerCase();
  if (lower.endsWith('.pdf')) return LibraryFileType.pdf;
  return LibraryFileType.image;
}

/// A file the app knows about: something the user created, imported, or
/// scanned. Backs both the "Recent" and "Favorite" lists across PDF Tools,
/// Image Tools, and the File Manager — those are just different bucketed
/// views over the same shape.
@immutable
class LibraryFile {
  final String id;
  final String path;
  final String name;
  final int sizeBytes;
  final DateTime modifiedAt;
  final LibraryFileType type;

  const LibraryFile({
    required this.id,
    required this.path,
    required this.name,
    required this.sizeBytes,
    required this.modifiedAt,
    required this.type,
  });

  factory LibraryFile.fromPath(String path, {DateTime? modifiedAt, int? sizeBytes}) {
    final name = path.split(Platform.pathSeparatorRegex).last;
    return LibraryFile(
      id: path,
      path: path,
      name: name,
      sizeBytes: sizeBytes ?? 0,
      modifiedAt: modifiedAt ?? DateTime.now(),
      type: libraryFileTypeFromExtension(path),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'path': path,
        'name': name,
        'sizeBytes': sizeBytes,
        'modifiedAt': modifiedAt.toIso8601String(),
        'type': type.name,
      };

  factory LibraryFile.fromJson(Map<String, dynamic> json) => LibraryFile(
        id: json['id'] as String,
        path: json['path'] as String,
        name: json['name'] as String,
        sizeBytes: json['sizeBytes'] as int? ?? 0,
        modifiedAt: DateTime.tryParse(json['modifiedAt'] as String? ?? '') ?? DateTime.now(),
        type: LibraryFileType.values.firstWhere(
          (t) => t.name == json['type'],
          orElse: () => LibraryFileType.pdf,
        ),
      );

  LibraryFile copyWith({String? name, int? sizeBytes, DateTime? modifiedAt}) => LibraryFile(
        id: id,
        path: path,
        name: name ?? this.name,
        sizeBytes: sizeBytes ?? this.sizeBytes,
        modifiedAt: modifiedAt ?? this.modifiedAt,
        type: type,
      );

  String get readableSize {
    if (sizeBytes <= 0) return '0 KB';
    const units = ['B', 'KB', 'MB', 'GB'];
    var size = sizeBytes.toDouble();
    var unitIndex = 0;
    while (size >= 1024 && unitIndex < units.length - 1) {
      size /= 1024;
      unitIndex++;
    }
    return '${size.toStringAsFixed(size >= 10 || unitIndex == 0 ? 0 : 1)} ${units[unitIndex]}';
  }
}

/// Minimal stand-in so this model file has no direct `dart:io` dependency
/// beyond a path separator split — keeps it usable from pure-Dart tests.
class Platform {
  static final pathSeparatorRegex = RegExp(r'[\\/]');
}
