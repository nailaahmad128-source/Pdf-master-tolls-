import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/storage/app_data_controller.dart';
import '../../../core/services/file_storage_service.dart';
import '../../../models/document_item.dart';

/// Lets the user pick file(s) either from the in-app Library or straight
/// from device storage via the system file picker. Returns absolute paths
/// on disk (device-picked files are copied into the app's own tmp dir
/// first, since some Android providers hand back non-persistent URIs).
Future<List<String>> pickSourceFiles(
  BuildContext context, {
  required bool allowMultiple,
  List<String> extensions = const ['pdf'],
}) async {
  final choice = await showModalBottomSheet<String>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(width: 40, height: 4, decoration: BoxDecoration(
            color: Theme.of(ctx).dividerColor, borderRadius: BorderRadius.circular(2))),
          ListTile(
            leading: const Icon(Icons.folder_rounded),
            title: const Text('Choose from Library'),
            onTap: () => Navigator.pop(ctx, 'library'),
          ),
          ListTile(
            leading: const Icon(Icons.smartphone_rounded),
            title: const Text('Choose from device'),
            onTap: () => Navigator.pop(ctx, 'device'),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );

  if (choice == 'library') {
    if (!context.mounted) return [];
    return _pickFromLibrary(context, allowMultiple: allowMultiple, extensions: extensions);
  } else if (choice == 'device') {
    return _pickFromDevice(context, allowMultiple: allowMultiple, extensions: extensions);
  }
  return [];
}

Future<List<String>> _pickFromLibrary(
  BuildContext context, {
  required bool allowMultiple,
  required List<String> extensions,
}) async {
  final data = context.read<AppDataController>();
  final wantImages = extensions.contains('jpg') || extensions.contains('png');
  final docs = data.documents.where((d) {
    if (wantImages) return d.type == 'image';
    return d.type == 'pdf';
  }).toList();

  if (!context.mounted) return [];
  final selected = await Navigator.push<List<DocumentItem>>(
    context,
    MaterialPageRoute(
      builder: (_) => _LibraryPickerScreen(docs: docs, allowMultiple: allowMultiple),
    ),
  );
  return selected?.map((d) => d.filePath).toList() ?? [];
}

Future<List<String>> _pickFromDevice(
  BuildContext context, {
  required bool allowMultiple,
  required List<String> extensions,
}) async {
  final result = await FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions: extensions,
    allowMultiple: allowMultiple,
  );
  if (result == null) return [];
  final storage = context.read<FileStorageService>();
  final paths = <String>[];
  for (final f in result.files) {
    if (f.path == null) continue;
    final copied = await storage.importIntoLibrary(File(f.path!), preferredName: f.name);
    paths.add(copied);
  }
  return paths;
}

class _LibraryPickerScreen extends StatefulWidget {
  final List<DocumentItem> docs;
  final bool allowMultiple;
  const _LibraryPickerScreen({required this.docs, required this.allowMultiple});

  @override
  State<_LibraryPickerScreen> createState() => _LibraryPickerScreenState();
}

class _LibraryPickerScreenState extends State<_LibraryPickerScreen> {
  final Set<String> _selectedIds = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.allowMultiple ? 'Select files' : 'Select a file'),
        actions: [
          if (widget.allowMultiple && _selectedIds.isNotEmpty)
            TextButton(
              onPressed: () {
                final chosen = widget.docs.where((d) => _selectedIds.contains(d.id)).toList();
                Navigator.pop(context, chosen);
              },
              child: Text('Done (${_selectedIds.length})'),
            ),
        ],
      ),
      body: widget.docs.isEmpty
          ? const Center(child: Text('Your Library is empty.'))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: widget.docs.length,
              itemBuilder: (ctx, i) {
                final doc = widget.docs[i];
                final selected = _selectedIds.contains(doc.id);
                return Card(
                  child: ListTile(
                    leading: Icon(
                      doc.type == 'image' ? Icons.image_rounded : Icons.picture_as_pdf_rounded,
                    ),
                    title: Text(doc.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: widget.allowMultiple
                        ? Checkbox(
                            value: selected,
                            onChanged: (_) => setState(() {
                              selected ? _selectedIds.remove(doc.id) : _selectedIds.add(doc.id);
                            }),
                          )
                        : null,
                    onTap: () {
                      if (widget.allowMultiple) {
                        setState(() {
                          selected ? _selectedIds.remove(doc.id) : _selectedIds.add(doc.id);
                        });
                      } else {
                        Navigator.pop(context, [doc]);
                      }
                    },
                  ),
                );
              },
            ),
    );
  }
}
