import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:provider/provider.dart';

import '../core/permissions/permission_service.dart';
import '../providers/library_provider.dart';
import '../services/file_service.dart';
import '../services/pdf_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_buttons.dart';
import '../widgets/dialogs_and_sheets.dart';

class ImageToolsScreen extends StatefulWidget {
  const ImageToolsScreen({super.key});

  @override
  State<ImageToolsScreen> createState() => _ImageToolsScreenState();
}

class _ImageToolsScreenState extends State<ImageToolsScreen> {
  static const _tools = [
    ('Image to PDF', Icons.picture_as_pdf_rounded),  ];

  final List<String> _imagePaths = [];
  String _pageSize = 'A4';
  bool _creating = false;

  PdfPageFormat get _pageFormat => switch (_pageSize) {
        'Letter' => PdfPageFormat.letter,
        'Legal' => PdfPageFormat.legal,
        _ => PdfPageFormat.a4,
      };

  Future<void> _addImages() async {
    final outcome = await PermissionService.photosOrStorage();
    if (outcome != PermissionOutcome.granted) {
      if (!mounted) return;
      await PermissionService.handleDenied(context, outcome, featureName: 'Adding photos');
      return;
    }
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage(imageQuality: 95);
    if (picked.isEmpty) return;
    setState(() => _imagePaths.addAll(picked.map((x) => x.path)));
  }

  Future<void> _captureImage() async {
    final outcome = await PermissionService.camera();
    if (outcome != PermissionOutcome.granted) {
      if (!mounted) return;
      await PermissionService.handleDenied(context, outcome, featureName: 'Camera capture');
      return;
    }
    final picker = ImagePicker();
    final shot = await picker.pickImage(source: ImageSource.camera, imageQuality: 95);
    if (shot == null) return;
    setState(() => _imagePaths.add(shot.path));
  }

  void _removeImage(int index) => setState(() => _imagePaths.removeAt(index));

  void _reorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _imagePaths.removeAt(oldIndex);
      _imagePaths.insert(newIndex, item);
    });
  }

  Future<void> _createPdf() async {
    if (_imagePaths.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one image first.')),
      );
      return;
    }
    setState(() => _creating = true);
    try {
      final outputPath = await PdfService.imagesToPdf(
        _imagePaths,
        outputName: 'Image_to_PDF',
        pageFormat: _pageFormat,
      );
      if (!mounted) return;
      await context.read<LibraryProvider>().registerFile(outputPath);
      if (!mounted) return;
      setState(() {
        _creating = false;
        _imagePaths.clear();
      });
      await AppDialog.show(
        context,
        AppDialog(
          icon: Icons.check_circle_rounded,
          iconColor: AppColors.pdfPrimary,
          title: 'PDF created',
          message: 'Your document is ready to share or save.',
          confirmLabel: 'Share',
          cancelLabel: 'Done',
          onConfirm: () => FileService.shareFile(outputPath),
        ),
      );
    } on PdfOperationException catch (e) {
      setState(() => _creating = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      setState(() => _creating = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Something went wrong creating the PDF.')),
      );
    }
  }

  void _comingSoon(String tool) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$tool is coming in the next update.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('Image to PDF', style: AppTextStyles.headline(theme.colorScheme.onSurface))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          children: [
            
            Row(
              children: [
                Expanded(
                  child: Text('Reorder pages', style: AppTextStyles.title(theme.colorScheme.onSurface)),
                ),
                CircleIconButton(icon: Icons.add_photo_alternate_rounded, onPressed: _addImages),
                const SizedBox(width: 8),
                CircleIconButton(icon: Icons.camera_alt_rounded, onPressed: _captureImage),
              ],
            ),
            const SizedBox(height: 6),
            Text('Drag thumbnails to change page order before export.',
                style: AppTextStyles.bodyMedium(theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 16),
            SizedBox(
              height: 140,
              child: _imagePaths.isEmpty
                  ? Container(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: theme.colorScheme.outlineVariant),
                      ),
                      child: Center(
                        child: Text('No images yet — tap + to add some',
                            style: AppTextStyles.bodySmall(theme.colorScheme.onSurfaceVariant)),
                      ),
                    )
                  : ReorderableListView(
                      scrollDirection: Axis.horizontal,
                      onReorder: _reorder,
                      children: List.generate(
                        _imagePaths.length,
                        (i) => Padding(
                          key: ValueKey(_imagePaths[i]),
                          padding: const EdgeInsets.only(right: 12),
                          child: Container(
                            width: 96,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: theme.colorScheme.outlineVariant),
                            ),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: Image.file(File(_imagePaths[i]), fit: BoxFit.cover),
                                ),
                                Positioned(
                                  top: 6,
                                  left: 6,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.brandIndigo,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text('${i + 1}', style: AppTextStyles.caption(Colors.white)),
                                  ),
                                ),
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: InkWell(
                                    onTap: () => _removeImage(i),
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                      child: const Icon(Icons.close_rounded, size: 14, color: Colors.white),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Text('Page size', style: AppTextStyles.subtitle(theme.colorScheme.onSurface)),
                const Spacer(),
                DropdownButton<String>(
                  value: _pageSize,
                  underline: const SizedBox.shrink(),
                  items: ['A4', 'Letter', 'Legal'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _pageSize = v);
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              label: _creating ? 'Creating PDF…' : 'Create PDF',
              icon: Icons.picture_as_pdf_rounded,
              loading: _creating,
              onPressed: _imagePaths.isEmpty ? null : _createPdf,
            ),
          ],
        ),
      ),
    );
  }
}
