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

class FileManagerScreen extends StatefulWidget {
  const FileManagerScreen({super.key});

  @override
  State<FileManagerScreen> createState() => _FileManagerScreenState();
}

class _FileManagerScreenState extends State<FileManagerScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(length: 3, vsync: this);
  bool _gridView = false;
  String _query = '';
  FileTypeFilter _filter = FileTypeFilter.all;
  FileSortOrder _sort = FileSortOrder.dateNewest;

  List<LibraryFile> _allFiles = [];
  bool _loading = true;
  ({int usedBytes, int fileCount})? _storage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final files = await FileService.listAll();
    final storage = await FileService.storageSummary();
    if (!mounted) return;
    setState(() {
      _allFiles = files;
      _storage = storage;
      _loading = false;
    });
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final library = context.watch<LibraryProvider>();
    final visible = _visibleFiles;
    final favorites = visible.where((f) => library.isFavorite(f.path)).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('File Manager', style: AppTextStyles.headline(theme.colorScheme.onSurface)),
        actions: [
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
                          _FileGridOrList(
                            files: visible,
                            gridView: _gridView,
                            isFavorite: library.isFavorite,
                            relativeDate: _relativeDate,
                            onMore: (f) => _showFileActions(context, f),
                          ),
                          _FileGridOrList(
                            files: favorites,
                            gridView: _gridView,
                            isFavorite: library.isFavorite,
                            relativeDate: _relativeDate,
                            onMore: (f) => _showFileActions(context, f),
                          ),
                          const EmptyStateView(
                            icon: Icons.delete_outline_rounded,
                            title: 'No recently deleted files',
                            message:
                                'Deleted files are removed from your device right away in this version — a 30-day recycle bin is planned for an upcoming update.',
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
          icon: library.isFavorite(file.path) ? Icons.star_rounded : Icons.star_border_rounded,
          label: library.isFavorite(file.path) ? 'Remove from Favorites' : 'Add to Favorites',
          onTap: () {
            Navigator.pop(context);
            library.toggleFavorite(file);
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
                  await library.deleteFile(file.path);
                  await _load();
                },
              ),
            );
          },
        ),
      ],
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
}

class _FileGridOrList extends StatelessWidget {
  final List<LibraryFile> files;
  final bool gridView;
  final bool Function(String path) isFavorite;
  final String Function(DateTime) relativeDate;
  final ValueChanged<LibraryFile> onMore;

  const _FileGridOrList({
    required this.files,
    required this.gridView,
    required this.isFavorite,
    required this.relativeDate,
    required this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    if (files.isEmpty) {
      return const EmptyStateView(
        icon: Icons.folder_open_rounded,
        title: 'No files yet',
        message: 'Files you scan, create or convert will show up here.',
      );
    }
    if (gridView) {
      return GridView.builder(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
        itemCount: files.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 0.82,
        ),
        itemBuilder: (context, i) => _FileGridCard(
          file: files[i],
          isFavorite: isFavorite(files[i].path),
          meta: '${files[i].readableSize} · ${relativeDate(files[i].modifiedAt)}',
          onTap: () => onMore(files[i]),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      itemCount: files.length,
      separatorBuilder: (_, __) => const SizedBox(height: 2),
      itemBuilder: (context, i) => FileListTile(
        name: files[i].name,
        meta: '${files[i].readableSize} · ${relativeDate(files[i].modifiedAt)}',
        icon: files[i].type == LibraryFileType.pdf ? Icons.picture_as_pdf_rounded : Icons.image_rounded,
        iconColor: files[i].type == LibraryFileType.pdf ? AppColors.pdfPrimary : AppColors.scanPrimary,
        iconBg: files[i].type == LibraryFileType.pdf ? AppColors.pdfSoft : AppColors.scanSoft,
        isFavorite: isFavorite(files[i].path),
        onMoreTap: () => onMore(files[i]),
      ),
    );
  }
}

class _FileGridCard extends StatelessWidget {
  final LibraryFile file;
  final bool isFavorite;
  final String meta;
  final VoidCallback onTap;
  const _FileGridCard({required this.file, required this.isFavorite, required this.meta, required this.onTap});

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
