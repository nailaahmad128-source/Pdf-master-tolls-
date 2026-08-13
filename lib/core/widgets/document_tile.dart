import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/document_item.dart';
import '../utils/format_utils.dart';

class DocumentTile extends StatelessWidget {
  final DocumentItem doc;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onToggleFavorite;

  const DocumentTile({
    super.key,
    required this.doc,
    required this.onTap,
    required this.onDelete,
    required this.onToggleFavorite,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Slidable(
      key: ValueKey(doc.id),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.6,
        children: [
          SlidableAction(
            onPressed: (_) => Share.shareXFiles([XFile(doc.filePath)]),
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: Colors.white,
            icon: Icons.ios_share_rounded,
            label: 'Share',
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(20)),
          ),
          SlidableAction(
            onPressed: (_) => onToggleFavorite(),
            backgroundColor: Colors.amber.shade600,
            foregroundColor: Colors.white,
            icon: doc.isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
            label: 'Favorite',
          ),
          SlidableAction(
            onPressed: (_) => onDelete(),
            backgroundColor: theme.colorScheme.error,
            foregroundColor: Colors.white,
            icon: Icons.delete_outline_rounded,
            label: 'Delete',
            borderRadius: const BorderRadius.horizontal(right: Radius.circular(20)),
          ),
        ],
      ),
      child: Card(
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          onTap: onTap,
          leading: _Thumb(doc: doc),
          title: Text(
            doc.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall,
          ),
          subtitle: Text(
            [
              formatBytes(doc.sizeBytes),
              if (doc.pageCount != null) '${doc.pageCount} pages',
              formatRelativeDate(doc.modifiedAt),
            ].join(' · '),
            style: theme.textTheme.bodySmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: doc.isFavorite
              ? const Icon(Icons.star_rounded, color: Colors.amber, size: 20)
              : null,
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  final DocumentItem doc;
  const _Thumb({required this.doc});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = BorderRadius.circular(12);
    if (doc.thumbnailPath != null && File(doc.thumbnailPath!).existsSync()) {
      return ClipRRect(
        borderRadius: radius,
        child: Image.file(
          File(doc.thumbnailPath!),
          width: 44,
          height: 52,
          fit: BoxFit.cover,
        ),
      );
    }
    return Container(
      width: 44,
      height: 52,
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: radius,
      ),
      child: Icon(
        doc.type == 'image' ? Icons.image_rounded : Icons.picture_as_pdf_rounded,
        color: theme.colorScheme.primary,
        size: 22,
      ),
    );
  }
}
