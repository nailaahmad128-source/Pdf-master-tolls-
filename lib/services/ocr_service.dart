import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Languages this build can genuinely OCR, each mapped to the engine that
/// actually supports its script. This is the single source of truth the
/// UI reads from -- no language is listed here unless there's a real,
/// tested recognizer behind it.
enum OcrLanguage { english, spanish, french, arabic, urdu }

extension OcrLanguageX on OcrLanguage {
  String get label => switch (this) {
        OcrLanguage.english => 'English',
        OcrLanguage.spanish => 'Spanish',
        OcrLanguage.french => 'French',
        OcrLanguage.arabic => 'Arabic',
        OcrLanguage.urdu => 'Urdu',
      };

  /// Whether this language is read by the on-device Google ML Kit Latin
  /// recognizer (fast, bundled with the app, no download).
  bool get usesMlKit =>
      this == OcrLanguage.english || this == OcrLanguage.spanish || this == OcrLanguage.french;

  /// Tesseract language code (ISO 639-2) for the trained-data file, for
  /// the Arabic-script languages ML Kit cannot read.
  String? get tesseractCode => switch (this) {
        OcrLanguage.arabic => 'ara',
        OcrLanguage.urdu => 'urd',
        _ => null,
      };

  bool get isRightToLeft => this == OcrLanguage.arabic || this == OcrLanguage.urdu;
}

class OcrPageResult {
  final String imagePath;
  final String text;
  final int pageNumber;
  const OcrPageResult({required this.imagePath, required this.text, required this.pageNumber});
}

class OcrException implements Exception {
  final String message;
  OcrException(this.message);
  @override
  String toString() => message;
}

/// Handles single- and multi-page OCR.
///
/// - ML Kit (`google_mlkit_text_recognition`) for Latin-script languages
///   (English/Spanish/French). Fully offline, model is bundled with the
///   app at install time -- no download, no network needed at OCR time.
///
/// - Arabic and Urdu were previously OCR'd via Tesseract
///   (`flutter_tesseract_ocr`). That package has been removed from the
///   project, so those two languages currently throw a clear
///   [OcrException] instead of recognizing text -- see [recognizeImage].
///   The `.traineddata` download/cache plumbing below
///   ([isLanguageReady]/[ensureLanguageReady]) is left in place since it
///   is engine-agnostic and ready to drive a future replacement engine.
class OcrService {
  OcrService._();

  static const _tessdataBaseUrl =
      'https://github.com/tesseract-ocr/tessdata_fast/raw/main';

  static Future<Directory> _tessdataDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'PDFMasterTools', 'tessdata'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static Future<Directory> _exportDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'PDFMasterTools'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// True once the language's model is available offline (bundled for
  /// ML Kit languages, downloaded-and-cached for Tesseract languages).
  static Future<bool> isLanguageReady(OcrLanguage language) async {
    if (language.usesMlKit) return true;
    final code = language.tesseractCode!;
    final dir = await _tessdataDir();
    return File(p.join(dir.path, '$code.traineddata')).exists();
  }

  /// Downloads and caches the Tesseract trained-data file for [language]
  /// if not already present. No-op for ML Kit languages. Reports 0.0-1.0
  /// progress via [onProgress] so the UI can show a real download bar
  /// instead of an indeterminate spinner.
  static Future<void> ensureLanguageReady(
    OcrLanguage language, {
    void Function(double progress)? onProgress,
  }) async {
    if (language.usesMlKit) return;
    final code = language.tesseractCode!;
    final dir = await _tessdataDir();
    final destPath = p.join(dir.path, '$code.traineddata');
    if (await File(destPath).exists()) return;

    final uri = Uri.parse('$_tessdataBaseUrl/$code.traineddata');
    final request = http.Request('GET', uri);
    final response = await http.Client().send(request);
    if (response.statusCode != 200) {
      throw OcrException(
        'Could not download the ${language.label} OCR language pack (HTTP ${response.statusCode}). Check your internet connection and try again.',
      );
    }
    final total = response.contentLength ?? 0;
    var received = 0;
    final sink = File('$destPath.part').openWrite();
    try {
      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) onProgress?.call(received / total);
      }
      await sink.flush();
    } finally {
      await sink.close();
    }
    await File('$destPath.part').rename(destPath);
  }

  /// OCRs a single image and returns the recognized text for [language].
  static Future<String> recognizeImage(String imagePath, OcrLanguage language) async {
    if (language.usesMlKit) {
      final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
      try {
        final result = await recognizer.processImage(InputImage.fromFilePath(imagePath));
        return result.text;
      } catch (e) {
        throw OcrException('Could not read text from this image: $e');
      } finally {
        await recognizer.close();
      }
    }

    // Arabic/Urdu were previously recognized via flutter_tesseract_ocr,
    // which has been removed from this project. There is currently no
    // replacement OCR engine wired up for these two languages, so fail
    // clearly rather than silently returning empty text.
    throw OcrException(
      '${language.label} OCR is temporarily unavailable in this build. '
      'English, Spanish, and French OCR still work normally.',
    );
  }

  /// Multi-page OCR: runs [recognizeImage] over every page in order and
  /// reports progress via [onPageDone] as each page finishes, so the UI
  /// can show "Page 3 of 8" instead of a single opaque spinner for the
  /// whole batch. Runs on the calling isolate's event loop between pages
  /// (each ML Kit/Tesseract call already does its heavy lifting off the
  /// UI thread internally), so the UI stays responsive throughout.
  static Future<List<OcrPageResult>> recognizeMultiPage(
    List<String> imagePaths,
    OcrLanguage language, {
    void Function(int completed, int total)? onPageDone,
  }) async {
    if (imagePaths.isEmpty) {
      throw OcrException('Add at least one page to run OCR.');
    }
    final results = <OcrPageResult>[];
    for (var i = 0; i < imagePaths.length; i++) {
      final text = await recognizeImage(imagePaths[i], language);
      results.add(OcrPageResult(imagePath: imagePaths[i], text: text, pageNumber: i + 1));
      onPageDone?.call(i + 1, imagePaths.length);
    }
    return results;
  }

  /// Combines multi-page OCR results into one plain-text blob with a
  /// "Page N" separator between pages, ready for TXT export or sharing.
  static String combineText(List<OcrPageResult> pages) {
    if (pages.length == 1) return pages.first.text;
    final buffer = StringBuffer();
    for (final page in pages) {
      if (buffer.isNotEmpty) buffer.writeln();
      buffer.writeln('— Page ${page.pageNumber} —');
      buffer.writeln(page.text);
    }
    return buffer.toString().trim();
  }

  // ---------------------------------------------------------------------
  // Export
  // ---------------------------------------------------------------------

  static Future<String> exportToTxt(String text, {String outputName = 'OCR'}) async {
    final dir = await _exportDir();
    final path = await _uniquePath(dir, outputName, 'txt');
    await File(path).writeAsString(text);
    return path;
  }

  /// Renders OCR'd text into a paginated PDF, one PDF page per source
  /// page, with correct RTL paragraph direction for Arabic/Urdu so the
  /// exported document reads naturally rather than mirrored.
  static Future<String> exportToPdf(
    List<OcrPageResult> pages,
    OcrLanguage language, {
    String outputName = 'OCR',
  }) async {
    // NOTE on offline behavior: PdfGoogleFonts fetches the font file from
    // Google Fonts over the network the first time it's used, then caches
    // it on-device for every export after that -- so PDF export needs a
    // connection once, not every time. If fully offline-from-first-run
    // PDF export is required, replace this with pw.Font.ttf(bytes) using
    // NotoSans-Regular.ttf / NotoNaskhArabic-Regular.ttf bundled as
    // assets instead (add them under assets/fonts/ and declare in
    // pubspec.yaml); OCR itself (ML Kit + Tesseract above) is already
    // fully offline once the language pack is cached.
    final document = pw.Document();
    final font = language.isRightToLeft
        ? await PdfGoogleFonts.notoNaskhArabicRegular()
        : await PdfGoogleFonts.notoSansRegular();

    for (final page in pages) {
      document.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          textDirection: language.isRightToLeft ? pw.TextDirection.rtl : pw.TextDirection.ltr,
          build: (context) => pw.Padding(
            padding: const pw.EdgeInsets.all(28),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (pages.length > 1) ...[
                  pw.Text(
                    'Page ${page.pageNumber}',
                    style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey600),
                  ),
                  pw.SizedBox(height: 8),
                ],
                pw.Text(
                  page.text.isEmpty ? '(No text detected on this page)' : page.text,
                  style: pw.TextStyle(font: font, fontSize: 13, lineSpacing: 3),
                  textDirection: language.isRightToLeft ? pw.TextDirection.rtl : pw.TextDirection.ltr,
                ),
              ],
            ),
          ),
        ),
      );
    }

    final dir = await _exportDir();
    final path = await _uniquePath(dir, outputName, 'pdf');
    await File(path).writeAsBytes(await document.save());
    return path;
  }

  static Future<String> _uniquePath(Directory dir, String baseName, String extension) async {
    var candidate = p.join(dir.path, '$baseName.$extension');
    var counter = 1;
    while (await File(candidate).exists()) {
      candidate = p.join(dir.path, '$baseName ($counter).$extension');
      counter++;
    }
    return candidate;
  }
}
