import 'package:flutter/material.dart';
import '../models/tool_item.dart';
import 'app_colors.dart';

class CategoryPalette {
  final Color primary;
  final Color soft;
  const CategoryPalette(this.primary, this.soft);
}

CategoryPalette categoryPalette(ToolCategory category) {
  switch (category) {
    case ToolCategory.pdf:
      return const CategoryPalette(AppColors.pdfPrimary, AppColors.pdfSoft);
    case ToolCategory.scan:
      return const CategoryPalette(AppColors.scanPrimary, AppColors.scanSoft);
    case ToolCategory.qr:
      return const CategoryPalette(AppColors.qrPrimary, AppColors.qrSoft);
    case ToolCategory.convert:
      return const CategoryPalette(AppColors.convertPrimary, AppColors.convertSoft);
  }
}

String categoryLabel(ToolCategory category) {
  switch (category) {
    case ToolCategory.pdf:
      return 'PDF Tools';
    case ToolCategory.scan:
      return 'Scan & OCR';
    case ToolCategory.qr:
      return 'QR Tools';
    case ToolCategory.convert:
      return 'Converters';
  }
}
