import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Owns the on-disk folder layout used by the whole app:
///
///   <app documents>/pdfmaster/library/     -> files currently in the Library
///   <app documents>/pdfmaster/trash/       -> files moved to Recently Deleted
///   <app documents>/pdfmaster/thumbnails/  -> cached page-1 thumbnails
///   <app documents>/pdfmaster/tmp/         -> scratch space for tool output
///
/// Files are always MOVED (never duplicated) between library/ and trash/,
/// so there is exactly one on-disk copy per document at all times. That is
/// what keeps delete/restore atomic and prevents a file "reappearing" or
/// needing to be deleted twice.
class FileStorageService {
  static const _uuid = Uuid();

  Directory? _root;

  Future<Directory> get root async {
    if (_root != null) return _root!;
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'pdfmaster'));
    if (!await dir.exists()) await dir.create(recursive: true);
    _root = dir;
    return dir;
  }

  Future<Directory> _sub(String name) async {
    final r = await root;
    final dir = Directory(p.join(r.path, name));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<Directory> get libraryDir => _sub('library');
  Future<Directory> get trashDir => _sub('trash');
  Future<Directory> get thumbnailsDir => _sub('thumbnails');
  Future<Directory> get tmpDir => _sub('tmp');

  String newId() => _uuid.v4();

  /// Copies an external/source file into the Library folder with a
  /// collision-safe unique filename, returning the new absolute path.
  Future<String> importIntoLibrary(File source, {String? preferredName}) async {
    final dir = await libraryDir;
    final ext = p.extension(source.path).isNotEmpty
        ? p.extension(source.path)
        : '.pdf';
    final base = preferredName != null
        ? p.basenameWithoutExtension(preferredName)
        : p.basenameWithoutExtension(source.path);
    final safeBase = base.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final fileName = '${safeBase}_${_uuid.v4().substring(0, 8)}$ext';
    final dest = File(p.join(dir.path, fileName));
    await source.copy(dest.path);
    return dest.path;
  }

  /// Moves a freshly-produced tool output (already in tmp/) into the
  /// Library folder.
  Future<String> commitToolOutput(File tmpFile, {required String fileName}) async {
    final dir = await libraryDir;
    final safe = fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final unique = '${p.basenameWithoutExtension(safe)}_${_uuid.v4().substring(0, 8)}${p.extension(safe)}';
    final dest = File(p.join(dir.path, unique));
    if (await tmpFile.exists()) {
      await tmpFile.copy(dest.path);
      try {
        await tmpFile.delete();
      } catch (_) {}
    }
    return dest.path;
  }

  Future<File> newTmpFile(String fileName) async {
    final dir = await tmpDir;
    return File(p.join(dir.path, '${_uuid.v4().substring(0, 8)}_$fileName'));
  }

  /// Moves a file from library/ to trash/. Returns the new path.
  Future<String> moveToTrash(String libraryPath) async {
    final trash = await trashDir;
    final src = File(libraryPath);
    final dest = File(p.join(trash.path, p.basename(libraryPath)));
    if (await src.exists()) {
      await src.rename(dest.path);
    }
    return dest.path;
  }

  /// Moves a file from trash/ back to library/. Returns the new path.
  Future<String> restoreFromTrash(String trashPath) async {
    final lib = await libraryDir;
    final src = File(trashPath);
    final dest = File(p.join(lib.path, p.basename(trashPath)));
    if (await src.exists()) {
      await src.rename(dest.path);
    }
    return dest.path;
  }

  Future<void> deletePermanently(String path) async {
    final f = File(path);
    if (await f.exists()) {
      try {
        await f.delete();
      } catch (_) {}
    }
  }

  Future<int> fileSize(String path) async {
    final f = File(path);
    if (await f.exists()) return f.length();
    return 0;
  }
}
