import 'dart:io';
import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:pdf_to_markdown_ffi/pdf_to_markdown.dart';

void main() {
  /// Load the fixture PDF bytes.
  Uint8List loadFixture() {
    // Walk up from test/ to repo root, then into tests/fixtures/
    const fixturePath = '../../tests/fixtures/bare_name_struct.pdf';
    final file = File(fixturePath);
    if (!file.existsSync()) {
      throw StateError('Fixture PDF not found at $fixturePath');
    }
    return file.readAsBytesSync();
  }

  test('convert returns non-null result', () {
    final pdfBytes = loadFixture();
    final result = convert(pdfBytes);
    expect(result, isNotNull);
    expect(result.markdown, isNotNull);
  });

  test('convert result has expected fields', () {
    final pdfBytes = loadFixture();
    final result = convert(pdfBytes);
    expect(result.pdfType, PdfType.textBased);
    expect(result.pageCount, greaterThan(0));
    expect(result.confidence, greaterThan(0.0));
  });

  test('classify returns non-null result', () {
    final pdfBytes = loadFixture();
    final result = classify(pdfBytes);
    expect(result, isNotNull);
    expect(result.pdfType, PdfType.textBased);
    expect(result.pageCount, greaterThan(0));
  });
}
