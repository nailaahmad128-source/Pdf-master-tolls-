import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/library_file.dart';

enum FileSortOrder { nameAsc, nameDesc, dateNewest, dateOldest, sizeLargest, sizeSmallest }

enum FileTypeFilter { all, pdf, image }

/// File Manager backend: lists everything the app has created/imported
/// under its working directory, plus search/sort/filter over that list,
/// storage usage totals, and the rename/delete/share actions shared by
/// the File Manager, PDF Tools, and Image Tools screens.
class FileService {
  FileService._();

  static Future<Directory> workingDirectory() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'PDFMasterTools'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static Future<List<LibraryFile>> listAll() async {
    final dir = await workingDirectory();
    final entities = await dir.list(recursive: false).toList();
    final files = <LibraryFile>[];
    for (final entity in entities) {
      if (entity is! File) continue;
      final stat = await entity.stat();
      files.add(LibraryFile(
        id: entity.path,
        path: entity.path,
        name: p.basename(entity.path),
        sizeBytes: stat.size,
        modifiedAt: stat.modified,
        type: libraryFileTypeFromExtension(entity.path),
      ));
    }
    return files;
  }

  static List<LibraryFile> applyFilterAndSearch(
    List<LibraryFile> files, {
    required FileTypeFilter filter,
    String query = '',
  }) {
    var result = files;
    if (filter == FileTypeFilter.pdf) {
      result = result.where((f) => f.type == LibraryFileType.pdf).toList();
    } else if (filter == FileTypeFilter.image) {
      result = result.where((f) => f.type == LibraryFileType.image).toList();
    }
    if (query.trim().isNotEmpty) {
      final lower = query.trim().toLowerCase();
      result = result.where((f) => f.name.toLowerCase().contains(lower)).toList();
    }
    return result;
  }

  static List<LibraryFile> applySort(List<LibraryFile> files, FileSortOrder order) {
    final sorted = List<LibraryFile>.from(files);
    switch (order) {
      case FileSortOrder.nameAsc:
        sorted.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
      case FileSortOrder.nameDesc:
        sorted.sort((a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()));
        break;
      case FileSortOrder.dateNewest:
        sorted.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
        break;
      case FileSortOrder.dateOldest:
        sorted.sort((a, b) => a.modifiedAt.compareTo(b.modifiedAt));
        break;
      case FileSortOrder.sizeLargest:
        sorted.sort((a, b) => b.sizeBytes.compareTo(a.sizeBytes));
        break;
      case FileSortOrder.sizeSmallest:
        sorted.sort((a, b) => a.sizeBytes.compareTo(b.sizeBytes));
        break;
    }
    return sorted;
  }

  /// Total bytes used by app-managed files, plus a device-free-space
  /// estimate where the platform makes that available.
  static Future<({int usedBytes, int fileCount})> storageSummary() async {
    final files = await listAll();
    final used = files.fold<int>(0, (sum, f) => sum + f.sizeBytes);
    return (usedBytes: used, fileCount: files.length);
  }

  static Future<void> shareFile(String path, {String? text}) async {
    await Share.shareXFiles([XFile(path)], text: text);
  }

  static Future<void> shareText(String text, {String? subject}) async {
    await Share.share(text, subject: subject);
  }

  static Future<String> rename(String oldPath, String newBaseName) async {
    final file = File(oldPath);
    if (!await file.exists()) {
      throw StateError('File no longer exists.');
    }
    final dir = p.dirname(oldPath);
    final ext = p.extension(oldPath);
    final sanitized = newBaseName.trim();
    if (sanitized.isEmpty) {
      throw StateError('Enter a valid file name.');
    }
    final newPath = p.join(dir, '$sanitized$ext');
    if (await File(newPath).exists()) {
      throw StateError('A file named "$sanitized$ext" already exists.');
    }
    final renamed = await file.rename(newPath);
    return renamed.path;
  }

  static Future<void> delete(String path) async {
    final file = File(path);
    if (await file.exists()) await file.delete();
  }

  static String readableSize(int bytes) {
    if (bytes <= 0) return '0 KB';
    const units = ['B', 'KB', 'MB', 'GB'];
    var size = bytes.toDouble();
    var unitIndex = 0;
    while (size >= 1024 && unitIndex < units.length - 1) {
      size /= 1024;
      unitIndex++;
    }
    return '${size.toStringAsFixed(size >= 10 || unitIndex == 0 ? 0 : 1)} ${units[unitIndex]}';
  }
}
