import 'dart:ffi';
import 'dart:io';

/// Singleton that opens the native `pdf_to_markdown_ffi` shared library.
class NativeLibrary {
  static DynamicLibrary? _instance;

  /// Get the native library handle. Loads once, then caches.
  static DynamicLibrary get instance {
    if (_instance != null) return _instance!;
    _instance = _open();
    return _instance!;
  }

  static DynamicLibrary _open() {
    // 1. Environment variable (useful for testing / custom paths).
    const envKey = 'PDF_TO_MARKDOWN_FFI_LIB_PATH';
    final envPath = Platform.environment[envKey];
    if (envPath != null && envPath.isNotEmpty) {
      return DynamicLibrary.open(envPath);
    }

    // 2. Try loading from the process (works when linked at build time).
    try {
      return DynamicLibrary.process();
    } catch (_) {
      // fall through
    }

    // 3. Platform-specific default names.
    final name = _defaultLibraryName();
    return DynamicLibrary.open(name);
  }

  static String _defaultLibraryName() {
    if (Platform.isLinux) return 'libpdf_to_markdown_ffi.so';
    if (Platform.isAndroid) return 'libpdf_to_markdown_ffi.so';
    if (Platform.isMacOS || Platform.isIOS) return 'libpdf_to_markdown_ffi.dylib';
    if (Platform.isWindows) return 'pdf_to_markdown_ffi.dll';
    throw UnsupportedError('Unsupported platform: ${Platform.operatingSystem}');
  }

  /// Reset the cached instance (for testing).
  static void reset() {
    _instance = null;
  }
}
