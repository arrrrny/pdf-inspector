import 'pdf_type.dart';

/// Lightweight classification result for routing decisions.
///
/// Obtained via fast classify (~10-50ms) without full text extraction.
class PdfClassificationResult {
  /// Detected PDF type.
  final PdfType pdfType;

  /// Total page count.
  final int pageCount;

  /// 0-indexed page numbers that need OCR.
  final List<int> pagesNeedingOcr;

  /// Detection confidence (0.0–1.0).
  final double confidence;

  PdfClassificationResult({
    required this.pdfType,
    required this.pageCount,
    required this.pagesNeedingOcr,
    required this.confidence,
  });

  factory PdfClassificationResult.fromJson(Map<String, dynamic> json) {
    return PdfClassificationResult(
      pdfType: PdfType.fromString(json['pdf_type'] as String),
      pageCount: json['page_count'] as int,
      pagesNeedingOcr: (json['pages_needing_ocr'] as List<dynamic>)
          .map((e) => e as int)
          .toList(),
      confidence: (json['confidence'] as num).toDouble(),
    );
  }

  @override
  String toString() =>
      'PdfClassificationResult(type: $pdfType, pages: $pageCount, '
      'ocrPages: $pagesNeedingOcr, confidence: $confidence)';
}
