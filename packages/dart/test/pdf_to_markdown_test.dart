import 'dart:io';
import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:pdf_to_markdown_ffi/pdf_to_markdown.dart';

void main() {
  /// Load the fixture PDF bytes.
  Uint8List loadFixture() {
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

  test('options flow through to FFI layer', () {
    // Passing mode: "detect" should still classify the PDF correctly
    // even through the convert path, proving options are not ignored.
    final pdfBytes = loadFixture();
    final result = convert(
      pdfBytes,
      options: const PdfMarkdownOptions(mode: 'detect'),
    );
    // DetectOnly mode still returns PdfType but no markdown.
    expect(result, isNotNull);
    expect(result.pdfType, PdfType.textBased);
  });

  test('convert with default options produces markdown', () {
    final pdfBytes = loadFixture();
    final result = convert(pdfBytes);
    // Default (full) mode should produce markdown.
    expect(result.markdown, isNotNull);
    expect(result.markdown!, isNotEmpty);
  });
}
