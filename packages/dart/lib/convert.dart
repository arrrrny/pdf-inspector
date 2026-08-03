import 'dart:convert';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'models/pdf_classification_result.dart';
import 'models/pdf_markdown_options.dart';
import 'models/pdf_markdown_result.dart';
import 'native_library.dart';
import 'exceptions.dart';

// =========================================================================
// FFI typedefs — all opaque pointers as Pointer<Void> on the C side
// =========================================================================

typedef _ConvertNative = Pointer<Void> Function(
    Pointer<Uint8> bytes, IntPtr len, Pointer<Void> options);
typedef _ConvertDart = Pointer<Void> Function(
    Pointer<Uint8> bytes, int len, Pointer<Void> options);

typedef _ResultToJsonNative = Pointer<Void> Function(Pointer<Void> result);
typedef _ResultToJsonDart = Pointer<Void> Function(Pointer<Void> result);

typedef _FreeStringNative = Void Function(Pointer<Void> ptr);
typedef _FreeStringDart = void Function(Pointer<Void> ptr);

typedef _ResultFreeNative = Void Function(Pointer<Void> result);
typedef _ResultFreeDart = void Function(Pointer<Void> result);

typedef _ClassifyNative = Pointer<Void> Function(Pointer<Uint8> bytes, IntPtr len);
typedef _ClassifyDart = Pointer<Void> Function(Pointer<Uint8> bytes, int len);

typedef _ClassificationToJsonNative = Pointer<Void> Function(Pointer<Void> result);
typedef _ClassificationToJsonDart = Pointer<Void> Function(Pointer<Void> result);

typedef _ClassificationFreeNative = Void Function(Pointer<Void> result);
typedef _ClassificationFreeDart = void Function(Pointer<Void> result);

// =========================================================================
// Bound function pointers
// =========================================================================

final _nativeLib = NativeLibrary.instance;

final _convert = _nativeLib
    .lookupFunction<_ConvertNative, _ConvertDart>('pdfmd_convert');
final _resultToJson = _nativeLib
    .lookupFunction<_ResultToJsonNative, _ResultToJsonDart>('pdfmd_result_to_json');
final _freeString = _nativeLib
    .lookupFunction<_FreeStringNative, _FreeStringDart>('pdfmd_free_string');
final _resultFree = _nativeLib
    .lookupFunction<_ResultFreeNative, _ResultFreeDart>('pdfmd_result_free');
final _classify = _nativeLib
    .lookupFunction<_ClassifyNative, _ClassifyDart>('pdfmd_classify');
final _classificationToJson = _nativeLib.lookupFunction<
    _ClassificationToJsonNative,
    _ClassificationToJsonDart>('pdfmd_classification_to_json');
final _classificationFree = _nativeLib
    .lookupFunction<_ClassificationFreeNative, _ClassificationFreeDart>(
        'pdfmd_classification_free');

// =========================================================================
// Helpers
// =========================================================================

/// Read a null-terminated C string from a Pointer<Void>.
String _readCString(Pointer<Void> ptr) {
  final addr = ptr.address;
  if (addr == 0) return '';
  final charPtr = Pointer<Uint8>.fromAddress(addr);
  final buffer = <int>[];
  int i = 0;
  while (true) {
    final byte = charPtr[i];
    if (byte == 0) break;
    buffer.add(byte);
    i++;
  }
  return utf8.decode(buffer);
}

// =========================================================================
// Public API
// =========================================================================

/// Convert a PDF byte buffer to Markdown.
///
/// Synchronous, blocking on the calling isolate.
/// The zik_zak caller should wrap in `compute()` or `Isolate.run()` if needed.
PdfMarkdownResult convert(Uint8List pdfBytes,
    {PdfMarkdownOptions? options}) {
  // Allocate a native buffer and copy the PDF bytes.
  final nativeBytes = malloc<Uint8>(pdfBytes.length);
  nativeBytes.asTypedList(pdfBytes.length).setAll(0, pdfBytes);

  final resultPtr = _convert(
    nativeBytes,
    pdfBytes.length,
    nullptr,
  );

  malloc.free(nativeBytes);

  if (resultPtr == nullptr) {
    checkLastError();
  }

  final jsonPtr = _resultToJson(resultPtr);
  if (jsonPtr == nullptr) {
    _resultFree(resultPtr);
    throw PdfFfiException(0, 'result_to_json returned null');
  }

  final jsonString = _readCString(jsonPtr);
  _freeString(jsonPtr);
  _resultFree(resultPtr);

  final json = jsonDecode(jsonString) as Map<String, dynamic>;
  return PdfMarkdownResult.fromJson(json);
}

/// Classify a PDF without full text extraction (~10-50ms).
///
/// Useful for fast routing decisions (text-based vs scanned).
PdfClassificationResult classify(Uint8List pdfBytes) {
  final nativeBytes = malloc<Uint8>(pdfBytes.length);
  nativeBytes.asTypedList(pdfBytes.length).setAll(0, pdfBytes);

  final resultPtr = _classify(
    nativeBytes,
    pdfBytes.length,
  );

  malloc.free(nativeBytes);

  if (resultPtr == nullptr) {
    checkLastError();
  }

  final jsonPtr = _classificationToJson(resultPtr);
  if (jsonPtr == nullptr) {
    _classificationFree(resultPtr);
    throw PdfFfiException(0, 'classification_to_json returned null');
  }

  final jsonString = _readCString(jsonPtr);
  _freeString(jsonPtr);
  _classificationFree(resultPtr);

  final json = jsonDecode(jsonString) as Map<String, dynamic>;
  return PdfClassificationResult.fromJson(json);
}
