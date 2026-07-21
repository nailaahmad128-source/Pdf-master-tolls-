import 'dart:io';

import 'package:flutter/material.dart';

import '../core/storage/local_store.dart';
import '../models/library_file.dart';
import '../services/file_service.dart';

/// Tracks "Recent Files" / "Recent PDFs" and "Favorite" files across the
/// whole app. A single provider backs every screen's recent/favorite
/// list so an action taken in one place (e.g. favoriting from the File
/// Manager) is reflected everywhere else immediately.
class LibraryProvider extends ChangeNotifier {
  LibraryProvider() {
    _load();
  }

  List<LibraryFile> _recents = [];
  List<LibraryFile> _favorites = [];

  List<LibraryFile> get recents => List.unmodifiable(_recents);
  List<LibraryFile> get favorites => List.unmodifiable(_favorites);

  List<LibraryFile> recentsByType(LibraryFileType type) =>
      _recents.where((f) => f.type == type).toList();

  bool isFavorite(String path) => _favorites.any((f) => f.path == path);

  void _load() {
    _recents = LocalStore.instance
        .readBucket(StoreKeys.recentFiles)
        .map(LibraryFile.fromJson)
        .toList();
    _favorites = LocalStore.instance
        .readBucket(StoreKeys.favoriteFiles)
        .map(LibraryFile.fromJson)
        .toList();
  }

  /// Registers a newly created/imported file as the most recent item.
  /// Call this after every successful tool operation (merge, split,
  /// compress, scan save, image-to-pdf, etc.) so "Recent" stays accurate.
  Future<LibraryFile> registerFile(String path) async {
    final file = File(path);
    final stat = await file.exists() ? await file.stat() : null;
    final entry = LibraryFile(
      id: path,
      path: path,
      name: path.split(RegExp(r'[\\/]+')).last,
      sizeBytes: stat?.size ?? 0,
      modifiedAt: stat?.modified ?? DateTime.now(),
      type: libraryFileTypeFromExtension(path),
    );
    final updated = await LocalStore.instance.pushToBucket(
      StoreKeys.recentFiles,
      entry.toJson(),
      maxItems: 60,
    );
    _recents = updated.map(LibraryFile.fromJson).toList();
    notifyListeners();
    return entry;
  }

  Future<void> toggleFavorite(LibraryFile file) async {
    if (isFavorite(file.path)) {
      final updated = await LocalStore.instance.removeFromBucket(StoreKeys.favoriteFiles, file.path);
      _favorites = updated.map(LibraryFile.fromJson).toList();
    } else {
      final updated = await LocalStore.instance.pushToBucket(
        StoreKeys.favoriteFiles,
        file.toJson(),
        maxItems: 200,
      );
      _favorites = updated.map(LibraryFile.fromJson).toList();
    }
    notifyListeners();
  }

  Future<void> removeRecent(String path) async {
    final updated = await LocalStore.instance.removeFromBucket(StoreKeys.recentFiles, path);
    _recents = updated.map(LibraryFile.fromJson).toList();
    notifyListeners();
  }

  /// Renames a file on disk and updates any recent/favorite entries that
  /// point at its old path so lists don't go stale or dangle.
  Future<String> renameFile(String oldPath, String newBaseName) async {
    final newPath = await FileService.rename(oldPath, newBaseName);

    await _replacePath(StoreKeys.recentFiles, oldPath, newPath);
    await _replacePath(StoreKeys.favoriteFiles, oldPath, newPath);
    _load();
    notifyListeners();
    return newPath;
  }

  Future<void> _replacePath(String bucketKey, String oldPath, String newPath) async {
    final items = LocalStore.instance.readBucket(bucketKey);
    var changed = false;
    for (final item in items) {
      if (item['id'] == oldPath) {
        item['id'] = newPath;
        item['path'] = newPath;
        item['name'] = newPath.split(RegExp(r'[\\/]+')).last;
        changed = true;
      }
    }
    if (changed) await LocalStore.instance.writeBucket(bucketKey, items);
  }

  Future<void> deleteFile(String path) async {
    final file = File(path);
    if (await file.exists()) await file.delete();
    await LocalStore.instance.removeFromBucket(StoreKeys.recentFiles, path);
    await LocalStore.instance.removeFromBucket(StoreKeys.favoriteFiles, path);
    _load();
    notifyListeners();
  }

  /// Clears every Recent/Favorite entry without touching any file on
  /// disk. Call this after a bulk file-system wipe (e.g. Settings ->
  /// Clear cache) so lists don't keep showing entries that now point at
  /// deleted files.
  Future<void> clearAll() async {
    await LocalStore.instance.clearBucket(StoreKeys.recentFiles);
    await LocalStore.instance.clearBucket(StoreKeys.favoriteFiles);
    _load();
    notifyListeners();
  }
}
