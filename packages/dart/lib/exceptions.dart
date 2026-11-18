import 'dart:convert';
import 'dart:ffi';
import 'native_library.dart';

/// Base exception for pdf_to_markdown_ffi errors.
class PdfFfiException implements Exception {
  final int errorCode;
  final String message;

  const PdfFfiException(this.errorCode, this.message);

  @override
  String toString() => 'PdfFfiException($errorCode): $message';
}

/// The input bytes are not a valid PDF.
class PdfInvalidInputException extends PdfFfiException {
  const PdfInvalidInputException(super.code, super.message);
}

/// The PDF could not be parsed.
class PdfParseException extends PdfFfiException {
  const PdfParseException(super.code, super.message);
}

/// The PDF is encrypted and no password was provided.
class PdfEncryptedException extends PdfFfiException {
  const PdfEncryptedException(super.code, super.message);
}

/// The PDF has invalid internal structure.
class PdfInvalidStructureException extends PdfFfiException {
  const PdfInvalidStructureException(super.code, super.message);
}

/// Check the last error from the FFI layer and throw if non-zero.
///
/// Call after any FFI function that returns null/0 on failure.
void checkLastError() {
  final code = _lastErrorCode();
  if (code == 0) return;

  final contextPtr = _lastErrorContext();
  final message = contextPtr.address != 0
      ? _readCString(contextPtr)
      : 'unknown error';

  switch (code) {
    case 1:
      throw PdfInvalidInputException(code, message);
    case 2:
      throw PdfParseException(code, message);
    case 3:
      throw PdfEncryptedException(code, message);
    case 4:
      throw PdfInvalidStructureException(code, message);
    default:
      throw PdfFfiException(code, message);
  }
}

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
  // utf8 decode
  return utf8.decode(buffer);
}

// FFI function pointers
typedef _LastErrorCodeNative = Int32 Function();
typedef _LastErrorCodeDart = int Function();

typedef _LastErrorContextNative = Pointer<Void> Function();
typedef _LastErrorContextDart = Pointer<Void> Function();

final _nativeLib = NativeLibrary.instance;

final _lastErrorCode = _nativeLib
    .lookupFunction<_LastErrorCodeNative, _LastErrorCodeDart>('pdfmd_last_error_code');

final _lastErrorContext = _nativeLib
    .lookupFunction<_LastErrorContextNative, _LastErrorContextDart>('pdfmd_last_error_context');
