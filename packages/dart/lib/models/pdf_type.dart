/// PDF type classification result.
enum PdfType {
  /// PDF has extractable text (Tj/TJ operators found).
  textBased,

  /// PDF appears to be scanned (images only, no text operators).
  scanned,

  /// PDF contains mostly images with minimal/no text.
  imageBased,

  /// PDF has mix of text and image-heavy pages.
  mixed,
  ;

  static PdfType fromString(String value) {
    switch (value) {
      case 'TextBased':
        return PdfType.textBased;
      case 'Scanned':
        return PdfType.scanned;
      case 'ImageBased':
        return PdfType.imageBased;
      case 'Mixed':
        return PdfType.mixed;
      default:
        return PdfType.mixed;
    }
  }
}
