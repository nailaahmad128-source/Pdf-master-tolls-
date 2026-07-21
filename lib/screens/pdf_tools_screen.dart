import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/library_file.dart';
import '../models/tool_item.dart';
import '../providers/library_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/dialogs_and_sheets.dart';
import '../widgets/list_tiles.dart';
import '../widgets/state_views.dart';
import '../widgets/tool_card.dart';
import '../widgets/tool_navigation.dart';
import 'image_tools_screen.dart';

class PdfToolsScreen extends StatefulWidget {
  const PdfToolsScreen({super.key});

  @override
  State<PdfToolsScreen> createState() => _PdfToolsScreenState();
}

class _PdfToolsScreenState extends State<PdfToolsScreen> {
  bool _gridView = true;

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
    final tools = ToolCatalog.byCategory(ToolCategory.pdf);
    final recentPdfs = context
        .watch<LibraryProvider>()
        .recentsByType(LibraryFileType.pdf)
        .take(5)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('PDF Tools', style: AppTextStyles.headline(theme.colorScheme.onSurface)),
        actions: [
          IconButton(
            tooltip: _gridView ? 'Switch to list view' : 'Switch to grid view',
            icon: Icon(_gridView ? Icons.view_list_rounded : Icons.grid_view_rounded),
            onPressed: () => setState(() => _gridView = !_gridView),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: tools.isEmpty
          ? const EmptyStateView(
              icon: Icons.picture_as_pdf_outlined,
              title: 'No PDF tools available',
              message: 'Tools you unlock or install will appear here.',
            )
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                children: [
                  Text('Recent PDFs', style: AppTextStyles.title(theme.colorScheme.onSurface)),
                  const SizedBox(height: 4),
                  Text('Pick up where you left off',
                      style: AppTextStyles.bodySmall(theme.colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 12),
                  if (recentPdfs.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text('No PDFs yet — create one below to get started.',
                          style: AppTextStyles.bodySmall(theme.colorScheme.onSurfaceVariant)),
                    )
                  else
                    ...recentPdfs.map(
                      (f) => FileListTile(
                        name: f.name,
                        meta: '${f.readableSize} · ${_relativeDate(f.modifiedAt)}',
                        isFavorite: context.watch<LibraryProvider>().isFavorite(f.path),
                        onTap: () {},
                        onMoreTap: () => _showFileActions(context, f),
                      ),
                    ),
                  const SizedBox(height: 24),
                  Text('All PDF Tools', style: AppTextStyles.title(theme.colorScheme.onSurface)),
                  const SizedBox(height: 12),
                  _gridView
                      ? GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: tools.length,
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 14,
                            crossAxisSpacing: 14,
                            childAspectRatio: 0.98,
                          ),
                          itemBuilder: (context, i) =>
                              ToolCard(item: tools[i], onTap: () => openTool(context, tools[i])),
                        )
                      : Column(
                          children: tools
                              .map(
                                (t) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _PdfToolListRow(item: t, onTap: () => openTool(context, t)),
                                ),
                              )
                              .toList(),
                        ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ImageToolsScreen())),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New PDF'),
      ),
    );
  }

  void _showFileActions(BuildContext context, LibraryFile file) {
    final library = context.read<LibraryProvider>();
    AppBottomSheet.show(
      context,
      title: file.name,
      children: [
        SheetAction(
          icon: Icons.share_rounded,
          label: 'Share',
          onTap: () {
            Navigator.pop(context);
            Share.shareXFiles([XFile(file.path)]);
          },
        ),
        SheetAction(
          icon: library.isFavorite(file.path) ? Icons.star_rounded : Icons.star_border_rounded,
          label: library.isFavorite(file.path) ? 'Remove from favorites' : 'Add to favorites',
          onTap: () {
            Navigator.pop(context);
            library.toggleFavorite(file);
          },
        ),
        SheetAction(
          icon: Icons.drive_file_rename_outline_rounded,
          label: 'Rename',
          onTap: () {
            Navigator.pop(context);
            _showRenameDialog(context, file);
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
                icon: Icons.delete_rounded,
                iconColor: AppColors.error,
                title: 'Delete this PDF?',
                message: '"${file.name}" will be permanently removed from your device.',
                confirmLabel: 'Delete',
                destructive: true,
                onConfirm: () => library.deleteFile(file.path),
              ),
            );
          },
        ),
      ],
    );
  }

  void _showRenameDialog(BuildContext context, LibraryFile file) {
    final controller = TextEditingController(
      text: file.name.contains('.') ? file.name.substring(0, file.name.lastIndexOf('.')) : file.name,
    );
    final library = context.read<LibraryProvider>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename PDF'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final name = controller.text.trim();
              if (name.isEmpty) return;
              try {
                await library.renameFile(file.path, name);
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(const SnackBar(content: Text('Could not rename this file.')));
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

class _PdfToolListRow extends StatelessWidget {
  final ToolItem item;
  final VoidCallback onTap;
  const _PdfToolListRow({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.colorScheme.outlineVariant),
            boxShadow: AppColors.cardShadow(theme.brightness, tint: AppColors.pdfPrimary),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.pdfPrimary, AppColors.pdfPrimary.withOpacity(0.75)],
                  ),
                ),
                child: Icon(item.icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.title, style: AppTextStyles.bodyLarge(theme.colorScheme.onSurface)),
                    Text(item.subtitle, style: AppTextStyles.bodySmall(theme.colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
