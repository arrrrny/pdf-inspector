# Changelog

## 0.1.0

- Initial release of the Dart/Flutter bindings for pdf-inspector (PDF → Markdown).
- Core `convert(Uint8List pdfBytes, {PdfMarkdownOptions? options})` via `dart:ffi`.
- `classify(Uint8List)` for fast text-based vs scanned PDF routing.
- `PdfMarkdownOptions` (mode: full/detect/analyze, page filter) wired through the FFI layer.
- Structured `PdfMarkdownResult` (markdown, pdfType, pageCount, confidence, pagesNeedingOcr).
- Typed exceptions for invalid input, parse errors, encrypted PDFs, and structural errors.
- Thread-local error reporting (code + context).
- Platform support: macOS, Linux, Windows, Android, iOS (native lib built + bundled per platform).
