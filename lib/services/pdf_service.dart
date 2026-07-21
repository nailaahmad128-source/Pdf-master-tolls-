import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Offset, Rect, Size;

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart' hide PdfDocument;
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// Thrown for any PDF operation failure so callers can show a single,
/// consistent error message/dialog instead of leaking raw exceptions.
class PdfOperationException implements Exception {
  final String message;
  PdfOperationException(this.message);
  @override
  String toString() => message;
}

/// Result of a PDF-to-image export: one file per rendered page.
class RasterPage {
  final String path;
  final int pageNumber;
  const RasterPage({required this.path, required this.pageNumber});
}

/// All PDF file manipulation lives here so screens stay thin (pick input,
/// show progress, call a service method, display the result) and every
/// tool shares one tested implementation of "how do I write output next
/// to a unique, collision-free filename".
class PdfService {
  PdfService._();

  static Future<Directory> _outputDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'PDFMasterTools'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static Future<String> _uniquePath(String baseName, String extension) async {
    final dir = await _outputDir();
    var candidate = p.join(dir.path, '$baseName.$extension');
    var counter = 1;
    while (await File(candidate).exists()) {
      candidate = p.join(dir.path, '$baseName ($counter).$extension');
      counter++;
    }
    return candidate;
  }

  // ---------------------------------------------------------------------
  // Image(s) -> PDF
  // ---------------------------------------------------------------------

  /// Builds a single multi-page PDF from [imagePaths], one image per page,
  /// each page sized to fit the image at A4-equivalent scaling so photos
  /// of any aspect ratio look correct rather than stretched.
  static Future<String> imagesToPdf(
    List<String> imagePaths, {
    String outputName = 'Document',
    PdfPageFormat pageFormat = PdfPageFormat.a4,
  }) async {
    if (imagePaths.isEmpty) {
      throw PdfOperationException('Select at least one image to build a PDF.');
    }
    try {
      final document = pw.Document();
      for (final path in imagePaths) {
        final bytes = await File(path).readAsBytes();
        final image = pw.MemoryImage(bytes);
        document.addPage(
          pw.Page(
            pageFormat: pageFormat,
            build: (context) => pw.Center(
              child: pw.Image(image, fit: pw.BoxFit.contain),
            ),
          ),
        );
      }
      final outPath = await _uniquePath(outputName, 'pdf');
      await File(outPath).writeAsBytes(await document.save());
      return outPath;
    } catch (e) {
      throw PdfOperationException('Could not build PDF from the selected images: $e');
    }
  }

  // ---------------------------------------------------------------------
  // Merge
  // ---------------------------------------------------------------------

  /// Merges [pdfPaths] in order into a single document. Each source page
  /// is rendered onto a new page sized to match the source page exactly
  /// (Syncfusion's Flutter PDF has no direct page-import API, so this
  /// uses the officially recommended createTemplate approach — matching
  /// page size avoids the cropping/truncation that a fixed-size template
  /// page would cause).
  static Future<String> mergePdfs(
    List<String> pdfPaths, {
    String outputName = 'Merged',
  }) async {
    if (pdfPaths.length < 2) {
      throw PdfOperationException('Select at least two PDFs to merge.');
    }
    // PdfDocument() starts with zero pages/sections; every page comes from
    // a source file, added into a section whose page size matches that
    // source page exactly (a plain `pages.add()` uses the document's
    // default page settings and would crop/stretch non-A4 sources).
    final newDocument = PdfDocument();
    try {
      PdfSection? currentSection;
      Size? currentSectionSize;
      for (final path in pdfPaths) {
        final bytes = await File(path).readAsBytes();
        final loaded = PdfDocument(inputBytes: bytes);
        for (var i = 0; i < loaded.pages.count; i++) {
          final sourcePage = loaded.pages[i];
          final template = sourcePage.createTemplate();
          if (currentSection == null || currentSectionSize != sourcePage.size) {
            currentSection = newDocument.sections!.add();
            currentSection.pageSettings.size = sourcePage.size;
            currentSection.pageSettings.margins.all = 0;
            currentSectionSize = sourcePage.size;
          }
          currentSection.pages.add().graphics.drawPdfTemplate(template, const Offset(0, 0));
        }
        loaded.dispose();
      }
      final outPath = await _uniquePath(outputName, 'pdf');
      final savedBytes = await newDocument.save();
      await File(outPath).writeAsBytes(savedBytes);
      return outPath;
    } catch (e) {
      throw PdfOperationException('Could not merge the selected PDFs: $e');
    } finally {
      newDocument.dispose();
    }
  }

  // ---------------------------------------------------------------------
  // Split
  // ---------------------------------------------------------------------

  /// Splits [pdfPath] into one output file per contiguous range in
  /// [ranges] (1-based, inclusive). Passing a single range covering the
  /// whole document with size 1 each yields "one PDF per page".
  static Future<List<String>> splitPdf(
    String pdfPath, {
    required List<(int start, int end)> ranges,
    String outputName = 'Split',
  }) async {
    if (ranges.isEmpty) {
      throw PdfOperationException('Choose at least one page range to split out.');
    }
    final bytes = await File(pdfPath).readAsBytes();
    final source = PdfDocument(inputBytes: bytes);
    final outputs = <String>[];
    try {
      for (var r = 0; r < ranges.length; r++) {
        final (start, end) = ranges[r];
        if (start < 1 || end > source.pages.count || start > end) {
          throw PdfOperationException('Range $start-$end is outside the document (1-${source.pages.count}).');
        }
        final rangeDoc = PdfDocument();
        PdfSection? currentSection;
        Size? currentSectionSize;
        for (var pageIndex = start - 1; pageIndex < end; pageIndex++) {
          final sourcePage = source.pages[pageIndex];
          final template = sourcePage.createTemplate();
          if (currentSection == null || currentSectionSize != sourcePage.size) {
            currentSection = rangeDoc.sections!.add();
            currentSection.pageSettings.size = sourcePage.size;
            currentSection.pageSettings.margins.all = 0;
            currentSectionSize = sourcePage.size;
          }
          currentSection.pages.add().graphics.drawPdfTemplate(template, const Offset(0, 0));
        }
        final label = start == end ? 'page $start' : 'pages $start-$end';
        final outPath = await _uniquePath('$outputName ($label)', 'pdf');
        await File(outPath).writeAsBytes(await rangeDoc.save());
        rangeDoc.dispose();
        outputs.add(outPath);
      }
      return outputs;
    } catch (e) {
      if (e is PdfOperationException) rethrow;
      throw PdfOperationException('Could not split the PDF: $e');
    } finally {
      source.dispose();
    }
  }

  static Future<int> pageCount(String pdfPath) async {
    final bytes = await File(pdfPath).readAsBytes();
    final doc = PdfDocument(inputBytes: bytes);
    final count = doc.pages.count;
    doc.dispose();
    return count;
  }

  // ---------------------------------------------------------------------
  // Fill & Sign
  // ---------------------------------------------------------------------

  /// Renders a single page as a PNG for on-screen preview/placement.
  /// `Printing.raster` streams pages in order with no random-access seek,
  /// so this walks the stream and stops at [pageIndex] rather than
  /// rendering the whole document -- fine for the page counts Fill & Sign
  /// is used on (a handful of pages in a contract/form), but would be
  /// wasteful for very long documents.
  static Future<Uint8List> renderPagePng(String pdfPath, int pageIndex, {double dpi = 150}) async {
    final bytes = await File(pdfPath).readAsBytes();
    var i = 0;
    await for (final page in Printing.raster(bytes, dpi: dpi)) {
      if (i == pageIndex) return await page.toPng();
      i++;
    }
    throw PdfOperationException('Page ${pageIndex + 1} does not exist in this PDF.');
  }

  /// Bakes a signature image and/or typed text fields onto one page of
  /// the PDF at normalized (0..1) positions, so callers can place items
  /// on whatever preview resolution they rendered without worrying about
  /// the PDF's actual point-based page size.
  static Future<String> signPdf(
    String pdfPath, {
    required int pageIndex,
    List<SignaturePlacement> signatures = const [],
    List<TextPlacement> texts = const [],
    String outputName = 'Signed',
  }) async {
    if (signatures.isEmpty && texts.isEmpty) {
      throw PdfOperationException('Add a signature or text field before saving.');
    }
    try {
      final bytes = await File(pdfPath).readAsBytes();
      final document = PdfDocument(inputBytes: bytes);
      if (pageIndex < 0 || pageIndex >= document.pages.count) {
        document.dispose();
        throw PdfOperationException('Page ${pageIndex + 1} does not exist in this PDF.');
      }
      final page = document.pages[pageIndex];
      final pageSize = page.size;

      for (final s in signatures) {
        final bitmap = PdfBitmap(s.pngBytes);
        page.graphics.drawImage(
          bitmap,
          Rect.fromLTWH(
            s.xFraction * pageSize.width,
            s.yFraction * pageSize.height,
            s.widthFraction * pageSize.width,
            s.heightFraction * pageSize.height,
          ),
        );
      }
      for (final t in texts) {
        page.graphics.drawString(
          t.text,
          PdfStandardFont(PdfFontFamily.helvetica, t.fontSize),
          brush: PdfBrushes.black,
          bounds: Rect.fromLTWH(
            t.xFraction * pageSize.width,
            t.yFraction * pageSize.height,
            pageSize.width * (1 - t.xFraction),
            t.fontSize * 1.6,
          ),
        );
      }

      final outPath = await _uniquePath(outputName, 'pdf');
      await File(outPath).writeAsBytes(await document.save());
      document.dispose();
      return outPath;
    } catch (e) {
      if (e is PdfOperationException) rethrow;
      throw PdfOperationException('Could not save the signed PDF: $e');
    }
  }

  // ---------------------------------------------------------------------
  // Compress
  // ---------------------------------------------------------------------

  /// Real, size-reducing compression for image-heavy PDFs (scans,
  /// photo-to-PDF exports): each page is rasterized at a quality-dependent
  /// DPI, the resulting bitmap is re-encoded as a compressed JPEG, and a
  /// brand-new PDF is rebuilt from those JPEGs. Syncfusion's Flutter PDF
  /// library only exposes structural compression (cross-reference/stream
  /// compaction) with no image-downsampling API, which saves only a small
  /// fraction on scanned documents — rasterize-and-recompress is the
  /// approach that actually shrinks file size for this app's use case.
  /// Vector/text-only PDFs will still shrink somewhat but lose text
  /// selectability, which the UI should disclose before running.
  static Future<String> compressPdf(
    String pdfPath, {
    required PdfCompressQuality quality,
    String outputName = 'Compressed',
  }) async {
    try {
      final bytes = await File(pdfPath).readAsBytes();
      final dpi = switch (quality) {
        PdfCompressQuality.low => 72.0,
        PdfCompressQuality.medium => 110.0,
        PdfCompressQuality.high => 150.0,
      };
      final jpegQuality = switch (quality) {
        PdfCompressQuality.low => 45,
        PdfCompressQuality.medium => 65,
        PdfCompressQuality.high => 80,
      };

      final document = pw.Document();
      await for (final page in Printing.raster(bytes, dpi: dpi)) {
        final rawPng = await page.toPng();
        final compressed = await FlutterImageCompress.compressWithList(
          rawPng,
          quality: jpegQuality,
          format: CompressFormat.jpeg,
        );
        final image = pw.MemoryImage(compressed);
        // Raster pixel dims are in `dpi` dots-per-inch; PDF points are
        // 72-per-inch, so convert back to keep the physical page size
        // the same as the source page (just image-quality is reduced).
        final pageFormat = PdfPageFormat(page.width * 72 / dpi, page.height * 72 / dpi);
        document.addPage(
          pw.Page(
            pageFormat: pageFormat,
            build: (context) => pw.Image(image, fit: pw.BoxFit.fill),
          ),
        );
      }
      final outPath = await _uniquePath(outputName, 'pdf');
      await File(outPath).writeAsBytes(await document.save());
      return outPath;
    } catch (e) {
      throw PdfOperationException('Could not compress the PDF: $e');
    }
  }

  // ---------------------------------------------------------------------
  // PDF -> Image
  // ---------------------------------------------------------------------

  static Future<List<RasterPage>> pdfToImages(
    String pdfPath, {
    double dpi = 200,
    ImageExportFormat format = ImageExportFormat.png,
    String outputName = 'Page',
  }) async {
    try {
      final bytes = await File(pdfPath).readAsBytes();
      final results = <RasterPage>[];
      var pageNumber = 1;
      await for (final page in Printing.raster(bytes, dpi: dpi)) {
        final pngBytes = await page.toPng();
        Uint8List outBytes = pngBytes;
        final ext = format == ImageExportFormat.png ? 'png' : 'jpg';
        if (format == ImageExportFormat.jpg) {
          final decoded = img.decodePng(pngBytes);
          if (decoded != null) {
            outBytes = Uint8List.fromList(img.encodeJpg(decoded, quality: 92));
          }
        }
        final outPath = await _uniquePath('$outputName $pageNumber', ext);
        await File(outPath).writeAsBytes(outBytes);
        results.add(RasterPage(path: outPath, pageNumber: pageNumber));
        pageNumber++;
      }
      return results;
    } catch (e) {
      throw PdfOperationException('Could not export PDF pages as images: $e');
    }
  }

  // ---------------------------------------------------------------------
  // Lock / Unlock
  // ---------------------------------------------------------------------

  static Future<String> lockPdf(
    String pdfPath, {
    required String password,
    String? ownerPassword,
    String outputName = 'Protected',
  }) async {
    if (password.trim().isEmpty) {
      throw PdfOperationException('Enter a password to protect the PDF.');
    }
    try {
      final bytes = await File(pdfPath).readAsBytes();
      final document = PdfDocument(inputBytes: bytes);
      final security = document.security;
      security.userPassword = password;
      security.ownerPassword = ownerPassword?.trim().isNotEmpty == true ? ownerPassword! : password;
      security.algorithm = PdfEncryptionAlgorithm.aesx256Bit;
      final outPath = await _uniquePath(outputName, 'pdf');
      await File(outPath).writeAsBytes(await document.save());
      document.dispose();
      return outPath;
    } catch (e) {
      throw PdfOperationException('Could not lock the PDF: $e');
    }
  }

  /// Removes password protection. Requires the correct current password
  /// (user or owner) to open the encrypted source document.
  static Future<String> unlockPdf(
    String pdfPath, {
    required String currentPassword,
    String outputName = 'Unlocked',
  }) async {
    if (currentPassword.trim().isEmpty) {
      throw PdfOperationException('Enter the current password to unlock this PDF.');
    }
    try {
      final bytes = await File(pdfPath).readAsBytes();
      final document = PdfDocument(inputBytes: bytes, password: currentPassword);
      document.security.userPassword = '';
      document.security.ownerPassword = '';
      final outPath = await _uniquePath(outputName, 'pdf');
      await File(outPath).writeAsBytes(await document.save());
      document.dispose();
      return outPath;
    } catch (e) {
      throw PdfOperationException(
        'Could not unlock the PDF. Double-check the password and try again.',
      );
    }
  }
}

enum PdfCompressQuality { low, medium, high }

enum ImageExportFormat { png, jpg }

/// A signature image placed at a normalized (0..1) position/size on one
/// page -- normalized so the caller's preview resolution never has to
/// match the PDF's actual point-based page size.
class SignaturePlacement {
  final Uint8List pngBytes;
  final double xFraction;
  final double yFraction;
  final double widthFraction;
  final double heightFraction;

  const SignaturePlacement({
    required this.pngBytes,
    required this.xFraction,
    required this.yFraction,
    required this.widthFraction,
    required this.heightFraction,
  });
}

/// A typed text field (date, name, initials) placed at a normalized
/// (0..1) position on one page.
class TextPlacement {
  final String text;
  final double xFraction;
  final double yFraction;
  final double fontSize;

  const TextPlacement({
    required this.text,
    required this.xFraction,
    required this.yFraction,
    this.fontSize = 14,
  });
}
