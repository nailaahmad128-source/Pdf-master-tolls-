import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_filex/open_filex.dart';

import '../core/storage/local_store.dart';
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


  static Future<Directory> trashDirectory() async {
    final dir = Directory(
      p.join((await workingDirectory()).path, '.trash'),
    );
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<List<LibraryFile>> listAll() async {
    final dir = await workingDirectory();
    final trash = await trashDirectory();
    final entities = await dir.list(recursive: true).toList();
    final files = <LibraryFile>[];
    for (final entity in entities) {
      if (entity is! File) continue;
      // The trash lives inside the working directory (see
      // trashDirectory()), so a recursive scan of the working directory
      // also walks it. Without this check, a deleted file kept showing
      // up in "All Files" *and* "Recently Deleted" at once.
      if (p.isWithin(trash.path, entity.path)) continue;
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

  /// Copies a set of externally-picked files (from the system file
  /// picker) into the app's working directory so they show up in the
  /// Library. Used only for files the user explicitly selected via
  /// "Add Files" -- this never scans the device on its own. Name
  /// collisions with an existing library file get a numeric suffix
  /// rather than overwriting anything.
  static Future<int> importFiles(List<String> sourcePaths) async {
    final dir = await workingDirectory();
    var imported = 0;
    for (final sourcePath in sourcePaths) {
      final source = File(sourcePath);
      if (!await source.exists()) continue;

      final ext = p.extension(sourcePath);
      final base = p.basenameWithoutExtension(sourcePath);
      var candidate = p.join(dir.path, p.basename(sourcePath));
      var attempt = 2;
      while (await File(candidate).exists()) {
        candidate = p.join(dir.path, '$base ($attempt)$ext');
        attempt++;
      }

      await source.copy(candidate);
      imported++;
    }
    return imported;
  }

  static Future<void> shareFile(String path, {String? text}) async {
    await Share.shareXFiles([XFile(path)], text: text);
  }

  /// Shares several files at once via the native share sheet (e.g. every
  /// page produced by Split PDF or PDF to Image in one go). Only ever
  /// called after the user explicitly taps a Share action -- never
  /// automatically.
  static Future<void> shareFiles(List<String> paths, {String? text}) async {
    if (paths.isEmpty) return;
    await Share.shareXFiles(paths.map((p) => XFile(p)).toList(), text: text);
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


  /// Duplicates a file within the app's working directory, appending
  /// " (copy)" (and a numeric suffix if that name is already taken).
  static Future<String> copyFile(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      throw StateError('File no longer exists.');
    }
    final dir = p.dirname(path);
    final ext = p.extension(path);
    final base = p.basenameWithoutExtension(path);
    var candidate = p.join(dir, '$base (copy)$ext');
    var attempt = 2;
    while (await File(candidate).exists()) {
      candidate = p.join(dir, '$base (copy $attempt)$ext');
      attempt++;
    }
    final copied = await file.copy(candidate);
    return copied.path;
  }

  /// Moves a file to a different folder on the device (chosen by the
  /// user), leaving nothing behind in the app's working directory.
  static Future<String> moveFile(String path, String destinationDir) async {
    final file = File(path);
    if (!await file.exists()) {
      throw StateError('File no longer exists.');
    }
    final target = p.join(destinationDir, p.basename(path));
    if (await File(target).exists()) {
      throw StateError('A file named "${p.basename(path)}" already exists there.');
    }
    final moved = await file.rename(target);
    return moved.path;
  }

  static Future<void> moveToTrash(String path) async {
    final file = File(path);
    if (!await file.exists()) return;

    final trash = await trashDirectory();
    final ext = p.extension(path);
    final base = p.basenameWithoutExtension(path);
    // Two different files can share a base name (e.g. a file is deleted,
    // then a new file created with the same name is deleted later). Without
    // this uniqueness check, the second rename would silently overwrite the
    // first file already sitting in trash.
    var target = p.join(trash.path, p.basename(path));
    var attempt = 2;
    while (await File(target).exists()) {
      target = p.join(trash.path, '$base ($attempt)$ext');
      attempt++;
    }

    await file.rename(target);

    await LocalStore.instance.pushToBucket(
      StoreKeys.trashFiles,
      {
        'id': target,
        'path': target,
        'originalPath': path,
        'deletedAt': DateTime.now().toIso8601String(),
      },
    );
  }


  static Future<List<LibraryFile>> listTrashFiles() async {
    final trash = await trashDirectory();
    final entities = await trash.list().toList();

    final files = <LibraryFile>[];

    for (final entity in entities) {
      if (entity is! File) continue;

      final stat = await entity.stat();

      final meta = LocalStore.instance
          .readBucket(StoreKeys.trashFiles)
          .cast<Map<String, dynamic>>()
          .where((e) => e['path'] == entity.path)
          .cast<Map<String, dynamic>>()
          .toList();

      files.add(
        LibraryFile(
          id: entity.path,
          path: entity.path,
          name: p.basename(entity.path),
          sizeBytes: stat.size,
          modifiedAt: stat.modified,
          type: libraryFileTypeFromExtension(entity.path),
          originalPath: meta.isEmpty ? null : meta.first['originalPath'] as String?,
        ),
      );
    }

    return files;
  }


  static Future<void> restoreFromTrash(
    String trashPath,
    String originalPath,
  ) async {
    final file = File(trashPath);
    if (!await file.exists()) return;

    // If something new already occupies the original path, restore
    // alongside it instead of silently overwriting that other file.
    var restorePath = originalPath;
    if (await File(restorePath).exists()) {
      final dir = p.dirname(originalPath);
      final ext = p.extension(originalPath);
      final base = p.basenameWithoutExtension(originalPath);
      var attempt = 2;
      do {
        restorePath = p.join(dir, '$base (restored $attempt)$ext');
        attempt++;
      } while (await File(restorePath).exists());
    }

    final target = File(restorePath);
    if (!await target.parent.exists()) {
      await target.parent.create(recursive: true);
    }

    await file.rename(restorePath);

    await LocalStore.instance.removeFromBucket(
      StoreKeys.trashFiles,
      trashPath,
    );
  }


  /// Permanently removes every app-managed file, including anything
  /// currently sitting in trash, and clears all related bucket metadata.
  /// Used by Settings > Clear cache, which promises an unrecoverable
  /// wipe -- unlike [delete], this does not go through trash.
  static Future<void> wipeAll() async {
    final dir = await workingDirectory();
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
    await dir.create(recursive: true);
    await LocalStore.instance.clearBucket(StoreKeys.trashFiles);
  }

  static Future<void> deleteForever(String trashPath) async {
    final file = File(trashPath);

    if (await file.exists()) {
      await file.delete();
    }

    await LocalStore.instance.removeFromBucket(
      StoreKeys.trashFiles,
      trashPath,
    );
  }

  static Future<void> openFile(String path) async {
    final result = await OpenFilex.open(path);
    if (result.type != ResultType.done) {
      throw StateError(result.message);
    }
  }

  static Future<void> delete(String path) async {
    await moveToTrash(path);
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
