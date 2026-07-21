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

class CompressPdfScreen extends StatefulWidget {
  const CompressPdfScreen({super.key});

  @override
  State<CompressPdfScreen> createState() => _CompressPdfScreenState();
}

class _CompressPdfScreenState extends State<CompressPdfScreen> {
  String? _path;
  int? _originalSize;
  PdfCompressQuality _quality = PdfCompressQuality.medium;
  bool _compressing = false;

  Future<void> _pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
    );
    final path = result?.files.single.path;
    if (path == null) return;
    final size = await File(path).length();
    setState(() {
      _path = path;
      _originalSize = size;
    });
  }

  Future<void> _compress() async {
    if (_path == null) return;
    setState(() => _compressing = true);
    try {
      final outputPath = await PdfService.compressPdf(
        _path!,
        quality: _quality,
        outputName: 'Compressed_PDF',
      );
      if (!mounted) return;
      await context.read<LibraryProvider>().registerFile(outputPath);
      final newSize = await File(outputPath).length();
      if (!mounted) return;
      setState(() => _compressing = false);
      final savedPct = _originalSize == null || _originalSize == 0
          ? 0
          : (100 - (newSize / _originalSize! * 100)).clamp(0, 99).round();
      await AppDialog.show(
        context,
        AppDialog(
          icon: Icons.check_circle_rounded,
          iconColor: AppColors.pdfPrimary,
          title: 'PDF compressed',
          message: savedPct > 0
              ? '${FileService.readableSize(newSize)} (down $savedPct% from ${FileService.readableSize(_originalSize!)})'
              : 'Compressed file saved as ${FileService.readableSize(newSize)}.',
          confirmLabel: 'Share',
          cancelLabel: 'Done',
          onConfirm: () => FileService.shareFile(outputPath),
        ),
      );
    } on PdfOperationException catch (e) {
      setState(() => _compressing = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      setState(() => _compressing = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Something went wrong compressing this PDF.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('Compress PDF', style: AppTextStyles.headline(theme.colorScheme.onSurface))),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: _path == null
              ? EmptyStateView(
                  icon: Icons.compress_rounded,
                  title: 'No PDF selected',
                  message: 'Choose a PDF to shrink its file size for easier sharing and storage.',
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
                        subtitle: Text(FileService.readableSize(_originalSize ?? 0)),
                        trailing: TextButton(onPressed: _pickPdf, child: const Text('Change')),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text('Compression level', style: AppTextStyles.subtitle(theme.colorScheme.onSurface)),
                    const SizedBox(height: 4),
                    Text(
                      'Pages are re-rendered as images at the chosen quality — great for scans and photo PDFs. '
                      'Selectable text in text-based PDFs will not remain selectable after compression.',
                      style: AppTextStyles.bodySmall(theme.colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 8),
                    ...PdfCompressQuality.values.map(
                      (q) => RadioListTile<PdfCompressQuality>(
                        contentPadding: EdgeInsets.zero,
                        value: q,
                        groupValue: _quality,
                        title: Text(switch (q) {
                          PdfCompressQuality.low => 'Maximum compression (smallest file, lower quality)',
                          PdfCompressQuality.medium => 'Balanced (recommended)',
                          PdfCompressQuality.high => 'Best quality (larger file)',
                        }),
                        onChanged: (v) => setState(() => _quality = v!),
                      ),
                    ),
                    const Spacer(),
                    PrimaryButton(
                      label: _compressing ? 'Compressing…' : 'Compress PDF',
                      icon: Icons.compress_rounded,
                      loading: _compressing,
                      onPressed: _compress,
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
