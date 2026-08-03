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

    // 2. Bundled native library shipped inside this package
    //    (`native/<rid>/libpdf_to_markdown_ffi.*`). Resolves the package's own
    //    directory so the binary "just works" without manual setup on the
    //    platforms we publish prebuilt artifacts for.
    final bundled = _bundledLibraryPath();
    if (bundled != null && File(bundled).existsSync()) {
      return DynamicLibrary.open(bundled);
    }

    // 3. Try loading from the process (works when linked at build time).
    try {
      return DynamicLibrary.process();
    } catch (_) {
      // fall through
    }

    // 4. Platform-specific default names (loader search path).
    final name = _defaultLibraryName();
    return DynamicLibrary.open(name);
  }

  /// Resolves the path of the bundled native library for this platform's
  /// "runtime identifier" (e.g. `native/macos-x64/libpdf_to_markdown_ffi.dylib`).
  /// Returns null when the package can't be located or the RID is unknown.
  static String? _bundledLibraryPath() {
    final rid = _platformRid();
    if (rid == null) return null;
    final packageDir = _resolvePackageDir();
    if (packageDir == null) return null;
    final libName = _defaultLibraryName();
    return '$packageDir${Platform.pathSeparator}'
        'native${Platform.pathSeparator}$rid'
        '${Platform.pathSeparator}$libName';
  }

  /// Finds this package's root directory. Tries, in order:
  ///  1. the current working directory (works in `dart test` / `flutter test`,
  ///     where CWD is the package dir), and
  ///  2. walking up from the running script (works in `dart run`).
  /// Stops at the first `pubspec.yaml` declaring `name: pdf_to_markdown_ffi`.
  static String? _resolvePackageDir() {
    final candidates = <String>{
      Directory.current.path,
      File(Platform.script.toFilePath()).parent.path,
    };
    for (final start in candidates) {
      var dir = Directory(start);
      for (var i = 0; i < 12; i++) {
        final pubspec = File('${dir.path}${Platform.pathSeparator}pubspec.yaml');
        if (pubspec.existsSync() &&
            pubspec.readAsStringSync().contains('name: pdf_to_markdown_ffi')) {
          return dir.path;
        }
        final parent = dir.parent;
        if (parent.path == dir.path) break;
        dir = parent;
      }
    }
    return null;
  }

  /// Platform runtime identifier matching the `native/` subdirectory names
  /// (e.g. `macos-x64`, `linux-x64`, `windows-x64`). Null when unsupported.
  ///
  /// Android/iOS intentionally return null here: on those platforms the lib
  /// is NOT dlopen'd from a bundled path.
  ///   - Android: the app ships `libpdf_to_markdown_ffi.so` in
  ///     `android/app/src/main/jniLibs/<abi>/`; `DynamicLibrary.open(name)`
  ///     (step 4) resolves it from the jniLibs loader path.
  ///   - iOS: the `.a` is statically linked into the app; `DynamicLibrary
  ///     .process()` (step 3) finds the symbols.
  static String? _platformRid() {
    if (Platform.isMacOS) {
      return _is64Bit() ? 'macos-x64' : 'macos-arm64';
    }
    if (Platform.isLinux) {
      return _is64Bit() ? 'linux-x64' : 'linux-arm64';
    }
    if (Platform.isWindows) {
      return 'windows-x64';
    }
    return null;
  }

  static bool _is64Bit() => sizeOf<IntPtr>() == 8;

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
