import 'package:flutter/material.dart';

/// Category families drive color coding across the dashboard grid.
enum ToolCategory { pdf, scan, qr, convert }

/// Static UI descriptor for a tool card (title/subtitle/icon/category).
/// Navigation is resolved by matching `title` in `tool_navigation.dart`
/// rather than storing a route here.
@immutable
class ToolItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final ToolCategory category;
  final bool isNew;

  const ToolItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.category,
    this.isNew = false,
  });
}

/// Static catalogue used to populate the Home & PDF Tools grids.
class ToolCatalog {
  ToolCatalog._();

  static const List<ToolItem> all = [
    ToolItem(
      title: 'Document Scanner',
      subtitle: 'Scan crisp, cropped pages',
      icon: Icons.document_scanner_rounded,
      category: ToolCategory.scan,
    ),
    ToolItem(
      title: 'Smart ID Scanner',
      subtitle: 'Auto-detect ID cards',
      icon: Icons.badge_rounded,
      category: ToolCategory.scan,
      isNew: true,
    ),
    ToolItem(
      title: 'OCR — Image to Text',
      subtitle: 'Extract text instantly',
      icon: Icons.text_snippet_rounded,
      category: ToolCategory.scan,
    ),
    ToolItem(
      title: 'Image to PDF',
      subtitle: 'Combine photos into PDF',
      icon: Icons.image_rounded,
      category: ToolCategory.pdf,
    ),
    ToolItem(
      title: 'Merge PDF',
      subtitle: 'Join files in one document',
      icon: Icons.merge_type_rounded,
      category: ToolCategory.pdf,
    ),
    ToolItem(
      title: 'Split PDF',
      subtitle: 'Extract pages or ranges',
      icon: Icons.call_split_rounded,
      category: ToolCategory.pdf,
    ),
    ToolItem(
      title: 'Compress PDF',
      subtitle: 'Shrink file size, keep quality',
      icon: Icons.compress_rounded,
      category: ToolCategory.pdf,
    ),
    ToolItem(
      title: 'PDF to Image',
      subtitle: 'Export pages as JPG/PNG',
      icon: Icons.photo_library_rounded,
      category: ToolCategory.pdf,
    ),
    ToolItem(
      title: 'Fill & Sign',
      subtitle: 'Add text, signature, initials',
      icon: Icons.draw_rounded,
      category: ToolCategory.pdf,
    ),
    ToolItem(
      title: 'Lock & Unlock',
      subtitle: 'Password-protect your files',
      icon: Icons.lock_rounded,
      category: ToolCategory.pdf,
    ),
    ToolItem(
      title: 'QR Scanner',
      subtitle: 'Scan any QR instantly',
      icon: Icons.qr_code_scanner_rounded,
      category: ToolCategory.qr,
    ),
    ToolItem(
      title: 'QR Generator',
      subtitle: 'Create custom QR codes',
      icon: Icons.qr_code_2_rounded,
      category: ToolCategory.qr,
    ),
    ToolItem(
      title: 'Unit Converter',
      subtitle: 'Length, weight, area & more',
      icon: Icons.straighten_rounded,
      category: ToolCategory.convert,
    ),
    ToolItem(
      title: 'Currency Converter',
      subtitle: 'Live-style exchange rates',
      icon: Icons.currency_exchange_rounded,
      category: ToolCategory.convert,
    ),
  ];

  static List<ToolItem> favorites() => all.take(4).toList();
  static List<ToolItem> byCategory(ToolCategory c) =>
      all.where((t) => t.category == c).toList();
}
