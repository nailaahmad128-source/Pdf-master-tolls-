import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/storage/local_store.dart';
import '../models/history_entry.dart';
import '../providers/library_provider.dart';
import '../services/file_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'dialogs_and_sheets.dart';

/// Runs the app-wide "create a file" workflow used by every tool that
/// produces an output file (Merge, Split, Compress, PDF ⇄ Image, QR
/// export, Scanner, OCR export, ...):
///
///  1. The caller has already disabled/loading-locked its action button
///     before calling this (each screen's own `_creating`/`_busy` flag).
///  2. A premium, non-dismissible loading overlay is shown immediately.
///  3. [task] runs the actual file generation/registration/history-save
///     work. It must not touch [BuildContext] after awaiting internally
///     unless it re-checks `mounted` itself -- this function only
///     guarantees the *overlay's* context stays valid.
///  4. On success, the loading overlay is swapped for a premium success
///     overlay ("✅ File Created Successfully") that auto-dismisses, or
///     can be dismissed early with a tap.
///  5. On failure, the overlay is closed and the exception is rethrown
///     so the caller's existing try/catch/SnackBar handling keeps
///     working unchanged.
///
/// This never opens the native share sheet -- sharing only ever happens
/// when the user explicitly taps a Share action elsewhere (history card,
/// success/confirmation dialog button, etc).
Future<T> runCreationFlow<T>({
  required BuildContext context,
  required Future<T> Function() task,
  String loadingTitle = 'Creating file…',
  String loadingSubtitle = 'Please wait, this will only take a moment.',
  String successTitle = 'File Created Successfully',
  String? successSubtitle,
  Duration successAutoDismiss = const Duration(milliseconds: 1300),
}) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  var loadingOpen = true;

  void closeLoading() {
    if (loadingOpen) {
      loadingOpen = false;
      navigator.pop();
    }
  }

  unawaited(
    navigator.push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.black.withOpacity(0.45),
        transitionDuration: const Duration(milliseconds: 220),
        reverseTransitionDuration: const Duration(milliseconds: 160),
        pageBuilder: (_, __, ___) => PopScope(
          canPop: false,
          child: _CreationFlowCard(
            state: _CreationFlowState.loading,
            title: loadingTitle,
            subtitle: loadingSubtitle,
          ),
        ),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.94, end: 1.0)
                .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
            child: child,
          ),
        ),
      ),
    ),
  );

  try {
    final result = await task();
    closeLoading();

    final overlayContext = navigator.overlay?.context;
    if (overlayContext != null && overlayContext.mounted) {
      await showGeneralDialog<void>(
        context: overlayContext,
        barrierDismissible: true,
        barrierLabel: 'Success',
        barrierColor: Colors.black.withOpacity(0.45),
        transitionDuration: const Duration(milliseconds: 260),
        pageBuilder: (dialogContext, __, ___) {
          Timer(successAutoDismiss, () {
            if (Navigator.of(dialogContext).canPop()) {
              Navigator.of(dialogContext).maybePop();
            }
          });
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(dialogContext).maybePop(),
            child: _CreationFlowCard(
              state: _CreationFlowState.success,
              title: successTitle,
              subtitle: successSubtitle,
            ),
          );
        },
        transitionBuilder: (_, animation, __, child) => FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.9, end: 1.0)
                .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutBack)),
            child: child,
          ),
        ),
      );
    }
    return result;
  } catch (_) {
    closeLoading();
    rethrow;
  }
}

enum _CreationFlowState { loading, success }

/// Shared chrome (rounded card, title, subtitle) for both the loading
/// and success moments of [runCreationFlow], so the two states feel like
/// one continuous piece of motion instead of two unrelated dialogs.
class _CreationFlowCard extends StatelessWidget {
  final _CreationFlowState state;
  final String title;
  final String? subtitle;

  const _CreationFlowCard({required this.state, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 260,
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(28),
            boxShadow: AppColors.cardShadow(theme.brightness, tint: AppColors.brandIndigo),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (state == _CreationFlowState.loading) const _LoadingPulse() else const _SuccessCheck(),
              const SizedBox(height: 20),
              Text(title, style: AppTextStyles.title(theme.colorScheme.onSurface), textAlign: TextAlign.center),
              if (subtitle != null && subtitle!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  subtitle!,
                  style: AppTextStyles.bodySmall(theme.colorScheme.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Rotating ring with a gently pulsing document glyph at its center --
/// the "premium loading" motion used while a file is being generated.
class _LoadingPulse extends StatefulWidget {
  const _LoadingPulse();

  @override
  State<_LoadingPulse> createState() => _LoadingPulseState();
}

class _LoadingPulseState extends State<_LoadingPulse> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      height: 72,
      child: Stack(
        alignment: Alignment.center,
        children: [
          RotationTransition(
            turns: _controller,
            child: const SizedBox(
              width: 72,
              height: 72,
              child: CircularProgressIndicator(
                strokeWidth: 3.4,
                valueColor: AlwaysStoppedAnimation(AppColors.brandIndigo),
                backgroundColor: AppColors.brandIndigoSoft,
              ),
            ),
          ),
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final scale = 0.92 + (0.08 * (0.5 + 0.5 * math.sin(_controller.value * 2 * math.pi)));
              return Transform.scale(scale: scale, child: child);
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(color: AppColors.brandIndigoSoft, shape: BoxShape.circle),
              child: const Icon(Icons.insert_drive_file_rounded, color: AppColors.brandIndigo, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bouncy checkmark used the instant a file finishes creating.
class _SuccessCheck extends StatefulWidget {
  const _SuccessCheck();

  @override
  State<_SuccessCheck> createState() => _SuccessCheckState();
}

class _SuccessCheckState extends State<_SuccessCheck> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 560))..forward();
  late final Animation<double> _scale = CurvedAnimation(parent: _controller, curve: Curves.elasticOut);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: AppColors.success,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: AppColors.success.withOpacity(0.35), blurRadius: 20, spreadRadius: -2),
          ],
        ),
        child: const Icon(Icons.check_rounded, color: Colors.white, size: 40),
      ),
    );
  }
}

/// A ready-made "Conversion History" row for files produced by a tool:
/// icon, name, subtitle/date, plus 👁 Open / 📤 Share / ⋮ More actions.
/// Rename/Delete/File info/Copy path are all handled here and, on
/// success, both update the underlying file (via [LibraryProvider], so
/// My Work / Recent Files stay in sync) *and* this entry's own
/// per-tool history bucket -- callers just drop this widget in and pass
/// [onChanged] to refresh their local `_history` list afterward.
///
/// Supports multi-file entries (e.g. Split PDF, PDF to Image) whose
/// payload joins every output path with [HistoryEntry.pathDelimiter];
/// Open acts on the first file, Share sends all of them, and Rename is
/// only offered for single-file entries.
class FileHistoryCard extends StatelessWidget {
  final HistoryEntry entry;
  final IconData icon;
  final Color color;
  final String historyBucketKey;
  final VoidCallback? onChanged;

  const FileHistoryCard({
    super.key,
    required this.entry,
    required this.icon,
    required this.color,
    required this.historyBucketKey,
    this.onChanged,
  });

  List<String> get _paths =>
      entry.payload.split(HistoryEntry.pathDelimiter).map((p) => p.trim()).where((p) => p.isNotEmpty).toList();

  Future<void> _open(BuildContext context) async {
    final paths = _paths;
    if (paths.isEmpty) return;
    try {
      await FileService.openFile(paths.first);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not open this file: $e')));
      }
    }
  }

  
  Future<void> _saveToFiles(BuildContext context) async {
    final paths=_paths.where((e)=>File(e).existsSync()).toList();
    if(paths.isEmpty) return;

    final base=Directory("/storage/emulated/0/PDF Master Tools/Saved Files");
    if(!await base.exists()){
      await base.create(recursive:true);
    }

    final src=File(paths.first);
    final dst=File("${base.path}/${src.uri.pathSegments.last}");

    
try {
  await src.copy(dst.path);
} catch (e) {
  await dst.writeAsBytes(await src.readAsBytes(), flush: true);
}


if (context.mounted) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        '✅ File saved successfully\n📂 PDF Master Tools/Saved Files',
      ),
      duration: Duration(seconds: 3),
    ),
  );
}


    if(context.mounted){
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("✅ Successfully saved to files"),
        ),
      );
    }
  }

Future<void> _share(BuildContext context) async {
    final paths = _paths.where((p) => File(p).existsSync()).toList();
    if (paths.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This file is no longer available.')),
        );
      }
      return;
    }
    if (paths.length == 1) {
      await FileService.shareFile(paths.first);
    } else {
      await FileService.shareFiles(paths);
    }
  }

  Future<void> _updateBucketEntry(HistoryEntry updated) async {
    final items = LocalStore.instance.readBucket(historyBucketKey);
    for (final item in items) {
      if (item['id'] == entry.id) {
        item['title'] = updated.title;
        item['payload'] = updated.payload;
      }
    }
    await LocalStore.instance.writeBucket(historyBucketKey, items);
  }

  Future<void> _removeBucketEntry() async {
    await LocalStore.instance.removeFromBucket(historyBucketKey, entry.id);
  }

  Future<void> _showRenameDialog(BuildContext context, String path, LibraryProvider library) async {
    final currentName = path.split(RegExp(r'[\\/]+')).last;
    final controller = TextEditingController(
      text: currentName.contains('.') ? currentName.substring(0, currentName.lastIndexOf('.')) : currentName,
    );
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename file'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final name = controller.text.trim();
              if (name.isEmpty) return;
              try {
                final newPath = await library.renameFile(path, name);
                await _updateBucketEntry(
                  HistoryEntry(
                    id: entry.id,
                    title: newPath.split(RegExp(r'[\\/]+')).last,
                    subtitle: entry.subtitle,
                    payload: newPath,
                    createdAt: entry.createdAt,
                  ),
                );
                onChanged?.call();
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, List<String> paths, LibraryProvider library) {
    AppDialog.show(
      context,
      AppDialog(
        icon: Icons.delete_outline_rounded,
        iconColor: AppColors.error,
        title: paths.length > 1 ? 'Delete ${paths.length} files?' : 'Delete "${entry.title}"?',
        message: 'These files will be moved to Recently Deleted in My Work.',
        confirmLabel: 'Delete',
        destructive: true,
        onConfirm: () async {
          for (final path in paths) {
            await library.deleteFile(path);
          }
          await _removeBucketEntry();
          onChanged?.call();
        },
      ),
    );
  }

  Future<void> _showInfo(BuildContext context, List<String> paths) async {
    final rows = <Widget>[];
    for (final path in paths) {
      final file = File(path);
      final exists = await file.exists();
      final size = exists ? await file.length() : 0;
      rows.add(_InfoRow(name: path.split(RegExp(r'[\\/]+')).last, size: FileService.readableSize(size), path: path));
    }
    if (!context.mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('File information'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: rows),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
      ),
    );
  }

  void _showMore(BuildContext context) {
    final paths = _paths;
    final library = context.read<LibraryProvider>();
    AppBottomSheet.show(
      context,
      title: entry.title,
      children: [
        SheetAction(
          icon: Icons.drive_file_rename_outline_rounded,
          label: 'Rename',
          onTap: () {
            Navigator.pop(context);
            if (paths.length == 1) {
              _showRenameDialog(context, paths.first, library);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Renaming is only available for single-file items.')),
              );
            }
          },
        ),
        SheetAction(
          icon: Icons.info_outline_rounded,
          label: 'File information',
          onTap: () {
            Navigator.pop(context);
            _showInfo(context, paths);
          },
        ),
        if (paths.length == 1)
          SheetAction(
            icon: Icons.copy_rounded,
            label: 'Copy path',
            onTap: () async {
              Navigator.pop(context);
              await Clipboard.setData(ClipboardData(text: paths.first));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Path copied.')));
              }
            },
          ),
        SheetAction(
          icon: Icons.delete_outline_rounded,
          label: 'Delete',
          color: AppColors.error,
          onTap: () {
            Navigator.pop(context);
            _confirmDelete(context, paths, library);
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                    child: Icon(icon, color: color, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(

                    child: Column(
                      children: [
                        Text(
                          entry.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodyLarge(theme.colorScheme.onSurface),
                        ),
                        if (entry.subtitle.isNotEmpty)
                          Text(entry.subtitle, style: AppTextStyles.caption(theme.colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(_relativeDate(entry.createdAt), style: AppTextStyles.caption(theme.colorScheme.onSurfaceVariant)),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(

                    child: TextButton.icon(
                      onPressed: () => _open(context),
                      icon: const Icon(Icons.visibility_outlined, size: 20),
                      label: const FittedBox(child: Text('Open', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                    ),
                  ),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () => _share(context),
                      icon: const Icon(Icons.ios_share_rounded, size: 20),
                      label: const FittedBox(child: Text('Share', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                    ),
                  ),
                  IconButton(
                    tooltip: 'More',
                    icon: const Icon(Icons.more_vert_rounded),
                    onPressed: () => _showMore(context),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _relativeDate(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

class _InfoRow extends StatelessWidget {
  final String name;
  final String size;
  final String path;
  const _InfoRow({required this.name, required this.size, required this.path});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: AppTextStyles.bodyMedium(theme.colorScheme.onSurface)),
          const SizedBox(height: 2),
          Text(size, style: AppTextStyles.caption(theme.colorScheme.onSurfaceVariant)),
          Text(path, style: AppTextStyles.caption(theme.colorScheme.onSurfaceVariant)),
          const Divider(height: 16),
        ],
      ),
    );
  }
}