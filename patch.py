from pathlib import Path

path = Path("lib/services/ocr_service.dart")
text = path.read_text()

old = """    if (language.tesseractCode != null) {
      try {
        return await _recognizeWithTesseract(imagePath, language);
      } catch (e) {
        throw OcrException(
          'Could not read ${language.label} text: $e',
        );
      }
    }"""

new = """    if (language.tesseractCode != null) {
      final bytes = await File(imagePath).readAsBytes();
      final base64Image = base64Encode(bytes);
      final response = await http.post(
        Uri.parse(_visionApi),
        headers: {
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "image": base64Image,
        }),
      );

      if (response.statusCode != 200) {
        throw OcrException("OCR server error: ${response.statusCode}");
      }

      final data = jsonDecode(response.body);
      if (data["success"] != true) {
        throw OcrException(
          data["message"] ?? "OCR failed.",
        );
      }

      return data["text"] ?? "";
    }"""
if old not in text:
    raise SystemExit("Old block not found!")

text = text.replace(old, new)

path.write_text(text)

print("Patch applied successfully.")
