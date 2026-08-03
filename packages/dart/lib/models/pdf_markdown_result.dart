import 'pdf_type.dart';

/// Result of converting a PDF to Markdown.
class PdfMarkdownResult {
  /// The extracted Markdown content. `null` if the mode was not `full`.
  final String? markdown;

  /// Detected PDF type.
  final PdfType pdfType;

  /// Total page count.
  final int pageCount;

  /// Processing time in milliseconds.
  final int processingTimeMs;

  /// Whether broken font encodings were detected.
  final bool hasEncodingIssues;

  /// Whether any page contains tables.
  final bool hasTables;

  /// Whether any page has multi-column text.
  final bool hasColumns;

  /// 1-indexed page numbers that need OCR.
  final List<int> pagesNeedingOcr;

  /// Title from PDF metadata (if available).
  final String? title;

  /// Detection confidence score (0.0–1.0).
  final double confidence;

  PdfMarkdownResult({
    required this.markdown,
    required this.pdfType,
    required this.pageCount,
    required this.processingTimeMs,
    required this.hasEncodingIssues,
    required this.hasTables,
    required this.hasColumns,
    required this.pagesNeedingOcr,
    required this.title,
    required this.confidence,
  });

  factory PdfMarkdownResult.fromJson(Map<String, dynamic> json) {
    return PdfMarkdownResult(
      markdown: json['markdown'] as String?,
      pdfType: PdfType.fromString(json['pdf_type'] as String),
      pageCount: json['page_count'] as int,
      processingTimeMs: json['processing_time_ms'] as int,
      hasEncodingIssues: json['has_encoding_issues'] as bool? ?? false,
      hasTables: json['has_tables'] as bool? ?? false,
      hasColumns: json['has_columns'] as bool? ?? false,
      pagesNeedingOcr: (json['pages_needing_ocr'] as List<dynamic>)
          .map((e) => e as int)
          .toList(),
      title: json['title'] as String?,
      confidence: (json['confidence'] as num).toDouble(),
    );
  }

  @override
  String toString() =>
      'PdfMarkdownResult(type: $pdfType, pages: $pageCount, '
      'hasTables: $hasTables, hasColumns: $hasColumns, '
      'encodingIssues: $hasEncodingIssues, confidence: $confidence)';
}
