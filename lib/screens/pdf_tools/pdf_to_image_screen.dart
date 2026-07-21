import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/library_provider.dart';
import '../../services/file_service.dart';
import '../../services/pdf_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/dialogs_and_sheets.dart';
import '../../widgets/state_views.dart';

class PdfToImageScreen extends StatefulWidget {
  const PdfToImageScreen({super.key});

  @override
  State<PdfToImageScreen> createState() => _PdfToImageScreenState();
}

class _PdfToImageScreenState extends State<PdfToImageScreen> {
  String? _path;
  int? _pageCount;
  String _format = 'PNG';
  double _dpi = 200;
  bool _exporting = false;

  Future<void> _pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
    );
    final path = result?.files.single.path;
    if (path == null) return;
    final count = await PdfService.pageCount(path);
    setState(() {
      _path = path;
      _pageCount = count;
    });
  }

  Future<void> _export() async {
    if (_path == null) return;
    setState(() => _exporting = true);
    try {
      final pages = await PdfService.pdfToImages(
        _path!,
        dpi: _dpi,
        format: _format == 'PNG' ? ImageExportFormat.png : ImageExportFormat.jpg,
        outputName: 'Page',
      );
      if (!mounted) return;
      final library = context.read<LibraryProvider>();
      for (final page in pages) {
        await library.registerFile(page.path);
      }
      if (!mounted) return;
      setState(() => _exporting = false);
      await AppDialog.show(
        context,
        AppDialog(
          icon: Icons.check_circle_rounded,
          iconColor: AppColors.pdfPrimary,
          title: '${pages.length} image${pages.length == 1 ? '' : 's'} exported',
          message: 'Pages are saved to your image library and Recent Files.',
          confirmLabel: 'Share all',
          cancelLabel: 'Done',
          onConfirm: () async {
            for (final page in pages) {
              await FileService.shareFile(page.path);
            }
          },
        ),
      );
    } on PdfOperationException catch (e) {
      setState(() => _exporting = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      setState(() => _exporting = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Something went wrong exporting these pages.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('PDF to Image', style: AppTextStyles.headline(theme.colorScheme.onSurface))),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: _path == null
              ? EmptyStateView(
                  icon: Icons.photo_library_rounded,
                  title: 'No PDF selected',
                  message: 'Choose a PDF to export its pages as JPG or PNG images.',
                  actionLabel: 'Choose PDF',
                  onAction: _pickPdf,
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: theme.colorScheme.outlineVariant),
                      ),
                      child: ListTile(
                        leading: const Icon(Icons.picture_as_pdf_rounded, color: AppColors.pdfPrimary),
                        title: Text(_path!.split(Platform.pathSeparator).last,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text('$_pageCount pages'),
                        trailing: TextButton(onPressed: _pickPdf, child: const Text('Change')),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Text('Format', style: AppTextStyles.subtitle(theme.colorScheme.onSurface)),
                        const Spacer(),
                        DropdownButton<String>(
                          value: _format,
                          underline: const SizedBox.shrink(),
                          items: ['PNG', 'JPG'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                          onChanged: (v) => setState(() => _format = v!),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('Quality (DPI)', style: AppTextStyles.subtitle(theme.colorScheme.onSurface)),
                    Slider(
                      value: _dpi,
                      min: 72,
                      max: 300,
                      divisions: 4,
                      label: '${_dpi.round()} DPI',
                      onChanged: (v) => setState(() => _dpi = v),
                    ),
                    const Spacer(),
                    PrimaryButton(
                      label: _exporting ? 'Exporting…' : 'Export $_pageCount page${_pageCount == 1 ? '' : 's'}',
                      icon: Icons.photo_library_rounded,
                      loading: _exporting,
                      onPressed: _export,
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
