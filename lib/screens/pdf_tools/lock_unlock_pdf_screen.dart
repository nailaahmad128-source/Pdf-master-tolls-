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

enum _Mode { lock, unlock }

class LockUnlockPdfScreen extends StatefulWidget {
  const LockUnlockPdfScreen({super.key});

  @override
  State<LockUnlockPdfScreen> createState() => _LockUnlockPdfScreenState();
}

class _LockUnlockPdfScreenState extends State<LockUnlockPdfScreen> {
  String? _path;
  _Mode _mode = _Mode.lock;
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscure = true;
  bool _busy = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
    );
    final path = result?.files.single.path;
    if (path == null) return;
    setState(() => _path = path);
  }

  Future<void> _run() async {
    if (_path == null) return;
    final password = _passwordController.text;
    if (password.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_mode == _Mode.lock ? 'Enter a password to protect the PDF.' : 'Enter the current password.')),
      );
      return;
    }
    if (_mode == _Mode.lock && password != _confirmController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match.')),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      final outputPath = _mode == _Mode.lock
          ? await PdfService.lockPdf(_path!, password: password, outputName: 'Protected_PDF')
          : await PdfService.unlockPdf(_path!, currentPassword: password, outputName: 'Unlocked_PDF');
      if (!mounted) return;
      await context.read<LibraryProvider>().registerFile(outputPath);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _passwordController.clear();
        _confirmController.clear();
      });
      await AppDialog.show(
        context,
        AppDialog(
          icon: Icons.check_circle_rounded,
          iconColor: AppColors.pdfPrimary,
          title: _mode == _Mode.lock ? 'PDF protected' : 'PDF unlocked',
          message: _mode == _Mode.lock
              ? 'Your PDF now requires a password to open.'
              : 'Password protection has been removed.',
          confirmLabel: 'Share',
          cancelLabel: 'Done',
          onConfirm: () => FileService.shareFile(outputPath),
        ),
      );
    } on PdfOperationException catch (e) {
      setState(() => _busy = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      setState(() => _busy = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Something went wrong. Double-check the file and password.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('Lock & Unlock', style: AppTextStyles.headline(theme.colorScheme.onSurface))),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: _path == null
              ? EmptyStateView(
                  icon: Icons.lock_rounded,
                  title: 'No PDF selected',
                  message: 'Choose a PDF to add or remove password protection.',
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
                        trailing: TextButton(onPressed: _pickPdf, child: const Text('Change')),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SegmentedButton<_Mode>(
                      segments: const [
                        ButtonSegment(value: _Mode.lock, label: Text('Lock'), icon: Icon(Icons.lock_rounded)),
                        ButtonSegment(value: _Mode.unlock, label: Text('Unlock'), icon: Icon(Icons.lock_open_rounded)),
                      ],
                      selected: {_mode},
                      onSelectionChanged: (s) => setState(() => _mode = s.first),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _passwordController,
                      obscureText: _obscure,
                      decoration: InputDecoration(
                        labelText: _mode == _Mode.lock ? 'New password' : 'Current password',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        suffixIcon: IconButton(
                          icon: Icon(_obscure ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                    ),
                    if (_mode == _Mode.lock) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: _confirmController,
                        obscureText: _obscure,
                        decoration: InputDecoration(
                          labelText: 'Confirm password',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                    const Spacer(),
                    PrimaryButton(
                      label: _busy
                          ? (_mode == _Mode.lock ? 'Locking…' : 'Unlocking…')
                          : (_mode == _Mode.lock ? 'Lock PDF' : 'Unlock PDF'),
                      icon: _mode == _Mode.lock ? Icons.lock_rounded : Icons.lock_open_rounded,
                      loading: _busy,
                      onPressed: _run,
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
