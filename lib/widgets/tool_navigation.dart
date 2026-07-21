import 'package:flutter/material.dart';
import '../models/tool_item.dart';
import '../screens/converter_screen.dart';
import '../screens/image_tools_screen.dart';
import '../screens/ocr_screen.dart';
import '../screens/pdf_tools/compress_pdf_screen.dart';
import '../screens/pdf_tools/fill_sign_screen.dart';
import '../screens/pdf_tools/lock_unlock_pdf_screen.dart';
import '../screens/pdf_tools/merge_pdf_screen.dart';
import '../screens/pdf_tools/pdf_to_image_screen.dart';
import '../screens/pdf_tools/split_pdf_screen.dart';
import '../screens/qr_tools_screen.dart';
import '../screens/scanner_screen.dart';

/// Maps a [ToolItem] to the screen that implements it. Every PDF-family
/// tool now opens a real, functional screen rather than a UI mock.
void openTool(BuildContext context, ToolItem item) {
  Widget? screen;
  switch (item.title) {
    case 'Document Scanner':
    case 'Smart ID Scanner':
      screen = const ScannerScreen();
      break;
    case 'OCR — Image to Text':
      screen = const OcrScreen();
      break;
    case 'Image to PDF':
      screen = const ImageToolsScreen();
      break;
    case 'Merge PDF':
      screen = const MergePdfScreen();
      break;
    case 'Split PDF':
      screen = const SplitPdfScreen();
      break;
    case 'Compress PDF':
      screen = const CompressPdfScreen();
      break;
    case 'PDF to Image':
      screen = const PdfToImageScreen();
      break;
    case 'Fill & Sign':
      screen = const FillSignScreen();
      break;
    case 'Lock & Unlock':
      screen = const LockUnlockPdfScreen();
      break;
    case 'QR Scanner':
    case 'QR Generator':
      screen = const QrToolsScreen();
      break;
    case 'Unit Converter':
    case 'Currency Converter':
      screen = const ConverterScreen();
      break;
    default:
      screen = null;
  }
  if (screen != null) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen!));
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${item.title} is coming in the next update.')),
    );
  }
}
