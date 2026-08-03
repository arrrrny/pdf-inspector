import 'dart:convert';

/// Options for PDF processing.
///
/// Pass to [convert] to customize behaviour. Use `PdfMarkdownOptions()` for defaults.
class PdfMarkdownOptions {
  /// Processing mode: `full` (default), `detect`, or `analyze`.
  final String mode;

  /// Optional 1-indexed page filter. `null` = all pages.
  final List<int>? pages;

  const PdfMarkdownOptions({
    this.mode = 'full',
    this.pages,
  });

  /// Serialize to JSON string for the C ABI.
  String toJsonString() {
    final map = <String, dynamic>{'mode': mode};
    if (pages != null) {
      map['pages'] = pages;
    }
    return jsonEncode(map);
  }
}
