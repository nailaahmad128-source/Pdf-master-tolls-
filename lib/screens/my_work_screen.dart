import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/library_file.dart';
import '../providers/library_provider.dart';
import '../services/file_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_search_bar.dart';
import '../widgets/dialogs_and_sheets.dart';
import '../widgets/list_tiles.dart';
import '../widgets/state_views.dart';

/// Centralized file manager. Every output produced anywhere in the app
/// (merged/split/compressed/converted PDFs, generated QR images,
/// scans, exports, ...) is registered through the same [FileService] /
/// [LibraryProvider] storage layer and surfaces here automatically.
class MyWorkScreen extends StatefulWidget {
  final int initialTab;

  const MyWorkScreen({
    super.key,
    this.initialTab = 0,
  });

  @override
  State<MyWorkScreen> createState() => _MyWorkScreenState();
}

class _MyWorkScreenState extends State<MyWorkScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  bool _gridView = false;
  String _query = '';
  FileTypeFilter _filter = FileTypeFilter.all;
  FileSortOrder _sort = FileSortOrder.dateNewest;

  List<LibraryFile> _allFiles = [];
  List<LibraryFile> _trashFiles = [];
  bool _loading = true;
  ({int usedBytes, int fileCount})? _storage;

  LibraryProvider? _library;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTab,
    );
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Every tool registers its output with LibraryProvider right after
    // writing it to disk (merge/split/compress/sign/scan/OCR/QR/etc.).
    // Listening here -- on top of the disk scan already run on every
    // mount -- means a newly created file shows up immediately even if
    // this screen was already mounted underneath a pushed tool route
    // when the file was created, instead of only refreshing on the next
    // tab switch.
    final library = context.read<LibraryProvider>();
    if (!identical(_library, library)) {
      _library?.removeListener(_onLibraryChanged);
      _library = library;
      _library!.addListener(_onLibraryChanged);
    }
  }

  void _onLibraryChanged() {
    if (mounted) _load();
  }

  @override
  void dispose() {
    _library?.removeListener(_onLibraryChanged);
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final files = await FileService.listAll();
    final trash = await FileService.listTrashFiles();
    final storage = await FileService.storageSummary();
    if (!mounted) return;
    setState(() {
      _allFiles = files;
      _trashFiles = trash;
      _storage = storage;
      _loading = false;
    });
  }

  /// "Add Files": opens the platform file picker so the user can
  /// manually choose PDFs, images, or other files to bring into the
  /// Library. This never scans the device on its own -- only files the
  /// user explicitly selects here are imported.
  Future<void> _addFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: const [
        'pdf',
        'jpg',
        'jpeg',
        'png',
        'heic',
        'webp',
        'bmp',
      ],
    );
    final paths = result?.files.map((f) => f.path).whereType<String>().toList() ?? [];
    if (paths.isEmpty) return;

    final imported = await FileService.importFiles(paths);
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(imported == 0
            ? 'No files were added.'
            : '$imported file${imported == 1 ? '' : 's'} added to your Library.'),
      ),
    );
  }

  List<LibraryFile> get _visibleFiles {
    var files = FileService.applyFilterAndSearch(_allFiles, filter: _filter, query: _query);
    files = FileService.applySort(files, _sort);
    return files;
  }

  String _relativeDate(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return DateFormat.yMMMd().format(dt);
  }

  /// Buckets files into the four standard groups, in display order.
  /// Groups with no files are omitted entirely.
  List<MapEntry<String, List<LibraryFile>>> _grouped(List<LibraryFile> files) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final weekStart = today.subtract(const Duration(days: 7));

    final groups = <String, List<LibraryFile>>{
      'Today': [],
      'Yesterday': [],
      'This Week': [],
      'Older': [],
    };

    for (final f in files) {
      final day = DateTime(f.modifiedAt.year, f.modifiedAt.month, f.modifiedAt.day);
      if (day == today) {
        groups['Today']!.add(f);
      } else if (day == yesterday) {
        groups['Yesterday']!.add(f);
      } else if (day.isAfter(weekStart)) {
        groups['This Week']!.add(f);
      } else {
        groups['Older']!.add(f);
      }
    }

    return groups.entries.where((e) => e.value.isNotEmpty).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final library = context.watch<LibraryProvider>();
    final visible = _visibleFiles;
    final favorites = visible.where((f) => library.isFavorite(f.path)).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('My Work', style: AppTextStyles.headline(theme.colorScheme.onSurface)),
        actions: [
          IconButton(
            tooltip: 'Add files',
            icon: const Icon(Icons.add_rounded),
            onPressed: _addFiles,
          ),
          IconButton(
            tooltip: _gridView ? 'Switch to list view' : 'Switch to grid view',
            icon: Icon(_gridView ? Icons.view_list_rounded : Icons.grid_view_rounded),
            onPressed: () => setState(() => _gridView = !_gridView),
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelColor: AppColors.brandIndigo,
          unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
          labelStyle: AppTextStyles.label(AppColors.brandIndigo),
          indicatorColor: AppColors.brandIndigo,
          tabs: const [Tab(text: 'All Files'), Tab(text: 'Favorites'), Tab(text: 'Recently Deleted')],
        ),
      ),
      body: SafeArea(
        child: _loading
            ? const LoadingStateView()
            : RefreshIndicator(
                onRefresh: _load,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                      child: _StorageIndicator(
                        usedBytes: _storage?.usedBytes ?? 0,
                        fileCount: _storage?.fileCount ?? 0,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: AppSearchBar(
                        hint: 'Search files…',
                        onChanged: (v) => setState(() => _query = v),
                        onFilterTap: () => _showSortFilterSheet(context),
                      ),
                    ),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _FileGroupedView(
                            groups: _grouped(visible),
                            gridView: _gridView,
                            isFavorite: library.isFavorite,
                            relativeDate: _relativeDate,
                            onMore: (f) => _showFileActions(context, f),
                          ),
                          _FileGroupedView(
                            groups: _grouped(favorites),
                            gridView: _gridView,
                            isFavorite: library.isFavorite,
                            relativeDate: _relativeDate,
                            onMore: (f) => _showFileActions(context, f),
                          ),
                          _FileGroupedView(
                            groups: _grouped(_trashFiles),
                            gridView: _gridView,
                            isFavorite: library.isFavorite,
                            relativeDate: _relativeDate,
                            onMore: (f) => _showTrashActions(context, f),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  void _showSortFilterSheet(BuildContext context) {
    AppBottomSheet.show(
      context,
      title: 'Sort & filter',
      children: [
        Text('Sort by', style: AppTextStyles.subtitle(Theme.of(context).colorScheme.onSurface)),
        SheetAction(
          icon: Icons.sort_by_alpha_rounded,
          label: 'Name (A–Z)',
          onTap: () {
            setState(() => _sort = FileSortOrder.nameAsc);
            Navigator.pop(context);
          },
        ),
        SheetAction(
          icon: Icons.schedule_rounded,
          label: 'Date modified (newest)',
          onTap: () {
            setState(() => _sort = FileSortOrder.dateNewest);
            Navigator.pop(context);
          },
        ),
        SheetAction(
          icon: Icons.sd_storage_rounded,
          label: 'File size (largest)',
          onTap: () {
            setState(() => _sort = FileSortOrder.sizeLargest);
            Navigator.pop(context);
          },
        ),
        const Divider(),
        Text('Filter', style: AppTextStyles.subtitle(Theme.of(context).colorScheme.onSurface)),
        SheetAction(
          icon: Icons.select_all_rounded,
          label: 'All files',
          onTap: () {
            setState(() => _filter = FileTypeFilter.all);
            Navigator.pop(context);
          },
        ),
        SheetAction(
          icon: Icons.picture_as_pdf_rounded,
          label: 'PDFs only',
          onTap: () {
            setState(() => _filter = FileTypeFilter.pdf);
            Navigator.pop(context);
          },
        ),
        SheetAction(
          icon: Icons.image_rounded,
          label: 'Images only',
          onTap: () {
            setState(() => _filter = FileTypeFilter.image);
            Navigator.pop(context);
          },
        ),
      ],
    );
  }

  void _showFileActions(BuildContext context, LibraryFile file) {
    final library = context.read<LibraryProvider>();
    AppBottomSheet.show(
      context,
      title: file.name,
      children: [
        SheetAction(
          icon: Icons.open_in_new_rounded,
          label: 'Open',
          onTap: () async {
            Navigator.pop(context);
            try {
              await FileService.openFile(file.path);
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not open this file: $e')));
              }
            }
          },
        ),
        SheetAction(
          icon: Icons.ios_share_rounded,
          label: 'Share',
          onTap: () {
            Navigator.pop(context);
            FileService.shareFile(file.path);
          },
        ),
        SheetAction(
          icon: Icons.drive_file_rename_outline_rounded,
          label: 'Rename',
          onTap: () {
            Navigator.pop(context);
            _showRenameDialog(file);
          },
        ),
        SheetAction(
          icon: Icons.copy_rounded,
          label: 'Copy',
          onTap: () async {
            Navigator.pop(context);
            try {
              await library.copyFile(file.path);
              await _load();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('File copied.')));
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not copy this file: $e')));
              }
            }
          },
        ),
        SheetAction(
          icon: Icons.drive_file_move,
          label: 'Move',
          onTap: () async {
            Navigator.pop(context);
            final destination = await FilePicker.platform.getDirectoryPath();
            if (destination == null) return;
            try {
              await library.moveFile(file.path, destination);
              await _load();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('File moved.')));
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not move this file: $e')));
              }
            }
          },
        ),
        SheetAction(
          icon: library.isFavorite(file.path) ? Icons.star_rounded : Icons.star_border_rounded,
          label: library.isFavorite(file.path) ? 'Remove from Favorites' : 'Add to Favorites',
          onTap: () {
            Navigator.pop(context);
            library.toggleFavorite(file);
          },
        ),
        SheetAction(
          icon: Icons.info_outline_rounded,
          label: 'File Details',
          onTap: () {
            Navigator.pop(context);
            _showDetailsDialog(file);
          },
        ),
        SheetAction(
          icon: Icons.delete_outline_rounded,
          label: 'Delete',
          color: AppColors.error,
          onTap: () {
            Navigator.pop(context);
            AppDialog.show(
              context,
              AppDialog(
                icon: Icons.delete_outline_rounded,
                iconColor: AppColors.error,
                title: 'Delete "${file.name}"?',
                message: 'This file will be permanently removed from your device.',
                confirmLabel: 'Delete',
                destructive: true,
                onConfirm: () async {
                  await FileService.moveToTrash(file.path);
                  await library.refresh();
                  await _load();
                },
              ),
            );
          },
        ),
      ],
    );
  }

  void _showDetailsDialog(LibraryFile file) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('File Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DetailRow(label: 'Name', value: file.name),
            _DetailRow(label: 'Type', value: file.type == LibraryFileType.pdf ? 'PDF document' : 'Image'),
            _DetailRow(label: 'Size', value: file.readableSize),
            _DetailRow(label: 'Modified', value: DateFormat.yMMMd().add_jm().format(file.modifiedAt)),
            _DetailRow(label: 'Location', value: file.path),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  void _showRenameDialog(LibraryFile file) {
    final controller = TextEditingController(
      text: file.name.contains('.') ? file.name.substring(0, file.name.lastIndexOf('.')) : file.name,
    );
    showDialog(
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
                // Goes through LibraryProvider (not FileService.rename
                // directly) so any Favorite/Recent entry pointing at the
                // old path is rewritten to the new one instead of going
                // stale/dangling.
                await context.read<LibraryProvider>().renameFile(file.path, name);
                await _load();
              } catch (e) {
                if (mounted) {
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

  void _showTrashActions(BuildContext context, LibraryFile file) {
    AppBottomSheet.show(
      context,
      title: file.name,
      children: [
        SheetAction(
          icon: Icons.restore_rounded,
          label: 'Restore',
          onTap: () async {
            Navigator.pop(context);
            if (file.originalPath != null) {
              await FileService.restoreFromTrash(
                file.path,
                file.originalPath!,
              );
              await _load();
            }
          },
        ),
        SheetAction(
          icon: Icons.delete_forever_rounded,
          label: 'Delete Forever',
          color: AppColors.error,
          onTap: () async {
            Navigator.pop(context);
            await FileService.deleteForever(file.path);
            await _load();
          },
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.caption(theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 2),
          Text(value, style: AppTextStyles.bodyMedium(theme.colorScheme.onSurface)),
        ],
      ),
    );
  }
}

/// Renders a list/grid of files split into "Today / Yesterday / This
/// Week / Older" sections, each under its own header.
class _FileGroupedView extends StatelessWidget {
  final List<MapEntry<String, List<LibraryFile>>> groups;
  final bool gridView;
  final bool Function(String path) isFavorite;
  final String Function(DateTime) relativeDate;
  final ValueChanged<LibraryFile> onMore;

  const _FileGroupedView({
    required this.groups,
    required this.gridView,
    required this.isFavorite,
    required this.relativeDate,
    required this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    if (groups.isEmpty) {
      return const EmptyStateView(
        icon: Icons.folder_open_rounded,
        title: 'No files yet',
        message: 'Files you scan, create or convert will show up here.',
      );
    }
    final theme = Theme.of(context);
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      itemCount: groups.length,
      itemBuilder: (context, groupIndex) {
        final group = groups[groupIndex];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 10),
              child: Text(group.key, style: AppTextStyles.subtitle(theme.colorScheme.onSurface)),
            ),
            gridView
                ? GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: group.value.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      childAspectRatio: 0.82,
                    ),
                    itemBuilder: (context, i) => _FileGridCard(
                      file: group.value[i],
                      isFavorite: isFavorite(group.value[i].path),
                      meta: '${group.value[i].readableSize} · ${relativeDate(group.value[i].modifiedAt)}',
                      onTap: () async => await FileService.openFile(group.value[i].path),
                      onMore: () => onMore(group.value[i]),
                    ),
                  )
                : Column(
                    children: group.value
                        .map(
                          (f) => Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: FileListTile(
                              name: f.name,
                              meta: '${f.readableSize} · ${relativeDate(f.modifiedAt)}',
                              icon: f.type == LibraryFileType.pdf ? Icons.picture_as_pdf_rounded : Icons.image_rounded,
                              iconColor: f.type == LibraryFileType.pdf ? AppColors.pdfPrimary : AppColors.scanPrimary,
                              iconBg: f.type == LibraryFileType.pdf ? AppColors.pdfSoft : AppColors.scanSoft,
                              isFavorite: isFavorite(f.path),
                              onTap: () => FileService.openFile(f.path),
                              onMoreTap: () => onMore(f),
                            ),
                          ),
                        )
                        .toList(),
                  ),
            const SizedBox(height: 12),
          ],
        );
      },
    );
  }
}

class _FileGridCard extends StatelessWidget {
  final LibraryFile file;
  final bool isFavorite;
  final String meta;
  final VoidCallback onTap;
  final VoidCallback onMore;
  const _FileGridCard({
    required this.file,
    required this.isFavorite,
    required this.meta,
    required this.onTap,
    required this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPdf = file.type == LibraryFileType.pdf;
    final iconColor = isPdf ? AppColors.pdfPrimary : AppColors.scanPrimary;
    final iconBg = isPdf ? AppColors.pdfSoft : AppColors.scanSoft;
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        onLongPress: onMore,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: theme.colorScheme.outlineVariant),
            boxShadow: AppColors.cardShadow(theme.brightness, tint: iconColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(12)),
                  child: Stack(
                    children: [
                      Center(child: Icon(isPdf ? Icons.picture_as_pdf_rounded : Icons.image_rounded, color: iconColor, size: 30)),
                      if (isFavorite)
                        const Positioned(
                          top: 6,
                          right: 6,
                          child: Icon(Icons.star_rounded, color: Color(0xFFF5A623), size: 16),
                        ),
                      Positioned(
                        bottom: 2,
                        right: 2,
                        child: IconButton(
                          icon: const Icon(Icons.more_vert_rounded, size: 18),
                          onPressed: onMore,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(file.name,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.bodyMedium(theme.colorScheme.onSurface)),
              Text(meta, style: AppTextStyles.caption(theme.colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }
}

class _StorageIndicator extends StatelessWidget {
  final int usedBytes;
  final int fileCount;
  const _StorageIndicator({required this.usedBytes, required this.fileCount});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // No reliable cross-platform "total device storage" API without extra
    // native plugins, so this shows app-managed usage plus file count
    // rather than a potentially-wrong device-capacity fraction.
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: AppColors.brandIndigoSoft, borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.sd_storage_rounded, color: AppColors.brandIndigo, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Storage used', style: AppTextStyles.label(theme.colorScheme.onSurface)),
                const SizedBox(height: 2),
                Text('${FileService.readableSize(usedBytes)} across $fileCount file${fileCount == 1 ? '' : 's'}',
                    style: AppTextStyles.caption(theme.colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
