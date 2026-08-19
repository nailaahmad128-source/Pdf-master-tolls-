import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/tools_catalog.dart';
import '../../../core/storage/app_data_controller.dart';
import '../../../core/utils/format_utils.dart';
import '../../../core/widgets/empty_state.dart';

/// A collapsible "Recent" section shown at the bottom of every tool
/// screen. Removing an entry here only deletes the history record — the
/// underlying saved file in the Library is left untouched, per spec.
///
/// Some tools (QR Scanner) produce history entries with no associated
/// file — just a scanned value stored in [ToolHistoryEntry.note]. Those
/// entries render with the value itself as the subtitle, and tapping one
/// copies it to the clipboard instead of trying to open a file.
class ToolHistorySection extends StatelessWidget {
  final ToolId toolId;
  const ToolHistorySection({super.key, required this.toolId});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppDataController>();
    final entries = data.historyForTool(toolId.name);
    final theme = Theme.of(context);

    if (entries.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: EmptyState(
          icon: Icons.history_rounded,
          title: 'No history yet',
          message: 'Your activity with this tool will appear here.',
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Recent', style: theme.textTheme.titleMedium),
            TextButton(
              onPressed: () => data.clearHistoryForTool(toolId.name),
              child: const Text('Clear'),
            ),
          ],
        ),
        ...entries.map((e) {
          final doc = e.resultDocumentId != null ? data.documentById(e.resultDocumentId!) : null;
          final hasNoteOnly = doc == null && e.note != null && e.note!.isNotEmpty;
          return Card(
            child: ListTile(
              leading: Icon(
                e.success ? Icons.check_circle_rounded : Icons.error_rounded,
                color: e.success ? Colors.green : theme.colorScheme.error,
              ),
              title: Text(e.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                hasNoteOnly
                    ? '${e.note} · ${formatRelativeDate(e.createdAt)}'
                    : doc != null
                        ? '${formatBytes(doc.sizeBytes)} · ${formatRelativeDate(e.createdAt)}'
                        : formatRelativeDate(e.createdAt),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                onPressed: () => data.removeHistoryEntry(e.id),
                tooltip: 'Remove from history',
              ),
              onTap: doc != null
                  ? () => OpenFilex.open(doc.filePath)
                  : hasNoteOnly
                      ? () async {
                          await Clipboard.setData(ClipboardData(text: e.note!));
                          if (context.mounted) {
                            ScaffoldMessenger.of(context)
                                .showSnackBar(const SnackBar(content: Text('Copied to clipboard')));
                          }
                        }
                      : null,
            ),
          );
        }),
      ],
    );
  }
}

/// Full-screen wrapper around [ToolHistorySection], used by tools whose
/// primary screen is a full-bleed canvas/camera view (Fill & Sign, QR
/// Scanner, QR Generator) where the history list can't just live inline
/// at the bottom of the screen.
class ToolHistoryScreen extends StatelessWidget {
  final ToolId toolId;
  final String title;
  const ToolHistoryScreen({super.key, required this.toolId, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [ToolHistorySection(toolId: toolId)],
        ),
      ),
    );
  }
}
