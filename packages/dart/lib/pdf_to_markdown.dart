/// On-device PDF to Markdown conversion via dart:ffi.
///
/// Wraps the Rust `pdf-inspector` crate through a C-ABI layer.
/// Call [convert] with raw PDF bytes to get structured Markdown output.
library pdf_to_markdown_ffi;

export 'convert.dart';
export 'models/pdf_type.dart';
export 'models/pdf_markdown_result.dart';
export 'models/pdf_markdown_options.dart';
export 'models/pdf_classification_result.dart';
export 'exceptions.dart';
