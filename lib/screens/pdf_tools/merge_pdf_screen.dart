import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/library_provider.dart';
import '../../services/ads_service.dart';
import '../../services/file_service.dart';
import '../../services/pdf_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/dialogs_and_sheets.dart';
import '../../widgets/state_views.dart';

class MergePdfScreen extends StatefulWidget {
  const MergePdfScreen({super.key});

  @override
  State<MergePdfScreen> createState() => _MergePdfScreenState();
}

class _MergePdfScreenState extends State<MergePdfScreen> {
  final List<String> _paths = [];
  bool _merging = false;

  Future<void> _pickPdfs() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      allowMultiple: true,
    );
    if (result == null) return;
    final picked = result.files.map((f) => f.path).whereType<String>().toList();
    setState(() => _paths.addAll(picked));
  }

  void _remove(int index) => setState(() => _paths.removeAt(index));

  void _reorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _paths.removeAt(oldIndex);
      _paths.insert(newIndex, item);
    });
  }

  Future<void> _merge() async {
    setState(() => _merging = true);
    try {
      final outputPath = await PdfService.mergePdfs(_paths, outputName: 'Merged_PDF');
      if (!mounted) return;
      await context.read<LibraryProvider>().registerFile(outputPath);
      if (!mounted) return;
      setState(() {
        _merging = false;
        _paths.clear();
      });
      await AppDialog.show(
        context,
        AppDialog(
          icon: Icons.check_circle_rounded,
          iconColor: AppColors.pdfPrimary,
          title: 'PDFs merged',
          message: 'Your combined document is ready to share or save.',
          confirmLabel: 'Share',
          cancelLabel: 'Done',
          onConfirm: () => FileService.shareFile(outputPath),
        ),
      );
      // Safe placement: only after the user has dismissed the success
      // dialog (task fully complete, nothing left to interrupt), and
      // gated by AdsService's own frequency cap so it won't show on
      // every single merge in a session.
      await AdsService.maybeShowInterstitial();
    } on PdfOperationException catch (e) {
      setState(() => _merging = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      setState(() => _merging = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Something went wrong merging these PDFs.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('Merge PDF', style: AppTextStyles.headline(theme.colorScheme.onSurface))),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Add PDFs in the order you want them combined',
                  style: AppTextStyles.bodyMedium(theme.colorScheme.onSurfaceVariant)),
              const SizedBox(height: 16),
              Expanded(
                child: _paths.isEmpty
                    ? EmptyStateView(
                        icon: Icons.merge_type_rounded,
                        title: 'No PDFs added yet',
                        message: 'Add at least two PDF files to merge them into one document.',
                        actionLabel: 'Add PDFs',
                        onAction: _pickPdfs,
                      )
                    : ReorderableListView.builder(
                        itemCount: _paths.length,
                        onReorder: _reorder,
                        itemBuilder: (context, i) {
                          final path = _paths[i];
                          final name = path.split(Platform.pathSeparator).last;
                          return Card(
                            key: ValueKey(path),
                            margin: const EdgeInsets.only(bottom: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(color: theme.colorScheme.outlineVariant),
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: AppColors.pdfSoft,
                                child: Text('${i + 1}', style: AppTextStyles.label(AppColors.pdfPrimary)),
                              ),
                              title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
                              trailing: IconButton(
                                icon: const Icon(Icons.close_rounded),
                                onPressed: () => _remove(i),
                              ),
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 12),
              if (_paths.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SecondaryButton(
                    label: 'Add more PDFs',
                    icon: Icons.add_rounded,
                    onPressed: _pickPdfs,
                  ),
                ),
              PrimaryButton(
                label: _merging ? 'Merging…' : 'Merge ${_paths.length} PDFs',
                icon: Icons.merge_type_rounded,
                loading: _merging,
                onPressed: _paths.length < 2 ? null : _merge,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
