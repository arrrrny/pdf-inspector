# pdf_to_markdown_ffi

[![Dart](https://img.shields.io/badge/Dart-3.0+-0175C2?logo=dart)](https://dart.dev)
[![pub](https://img.shields.io/pub/v/pdf_to_markdown_ffi)](https://pub.dev/packages/pdf_to_markdown_ffi)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

On-device **PDF → Markdown** conversion for Dart and Flutter, powered by the
[Rust pdf-inspector](https://github.com/arrrrny/pdf-inspector) engine via `dart:ffi`.

Feeds a **raw PDF byte buffer** in, gets structured Markdown out — including
real `|table|` columns and reading order. No server, no filesystem dependency,
sub-100ms on typical invoices. Designed for the ZikZak invoice price-check
pipeline and any local document-intelligence use case.

## Features

- **Fast**: Rust-powered conversion via FFI (verified ~89ms on a 2-page invoice)
- **Structured output**: real Markdown tables + column reading order (not flattened text)
- **Byte-buffer input**: `Uint8List` in → markdown out, no temp files
- **PDF classification**: fast `classify()` (~10-50ms) to route text-based vs scanned PDFs
- **Page filtering + modes**: `PdfMarkdownOptions(mode: full|detect|analyze, pages: [...])`
- **Thread-local error reporting**: typed exceptions, never crashes
- **Cross-platform**: Android, iOS, macOS, Linux, Windows

## Installation

```bash
dart pub add pdf_to_markdown_ffi
```

> ⚠️ This package ships the **Dart wrapper only** — the Rust cdylib must be
> built and bundled per platform. See [Building the native library](#building-the-native-library).

## Quick Start

```dart
import 'dart:typed_data';
import 'package:pdf_to_markdown_ffi/pdf_to_markdown_ffi.dart';

void main() {
  // Read your PDF into bytes (from a file, an HTTP response, a picker…)
  final pdfBytes = Uint8List.fromList(/* ... your PDF bytes ... */);

  // Convert to Markdown (synchronous; wrap in compute()/Isolate.run for large files)
  final result = convert(pdfBytes);

  print(result.markdown);   // Markdown with tables + columns
  print(result.pdfType);    // PdfType.textBased / scanned
  print(result.pageCount);
  print(result.confidence); // 0.0 .. 1.0
}
```

## Configuration

```dart
// Only analyze page 1, don't fully extract
final result = convert(
  pdfBytes,
  options: const PdfMarkdownOptions(mode: 'analyze', pages: [1]),
);
```

- `mode`: `full` (default) | `detect` | `analyze`
- `pages`: optional 1-indexed page filter (e.g. `[1, 3, 5]`)

## PDF classification (scanned vs text-based)

```dart
final cls = classify(pdfBytes);
if (cls.pdfType == PdfType.scanned) {
  // Route to OCR (e.g. MLKit / Tesseract) — this package is not an OCR engine.
} else {
  final md = convert(pdfBytes).markdown;
}
```

## Result model

```dart
PdfMarkdownResult {
  String  markdown;        // the converted Markdown
  PdfType pdfType;         // textBased | scanned | unknown
  int     pageCount;
  double  confidence;      // 0.0 .. 1.0
  List<int> pagesNeedingOcr;
}
```

## Platform Support

| Platform | Arch | Status |
|----------|------|--------|
| macOS | arm64, x64 | ✓ (x64 verified) |
| Linux | arm64, x64 | ✓ |
| Windows | x64 | ✓ |
| Android | arm64-v8a, armeabi-v7a, x86_64 | ✓ (via cargo-ndk) |
| iOS | arm64 | ✓ (build on macOS) |
| Web | — | Not supported (use pdf-inspector WASM) |

## Building the native library

The Rust cdylib lives in the same repo at `crates/pdf-to-markdown-rs-ffi`.
Build it per target, then bundle the artifact into your app.

### Desktop / CLI (macOS example)

```bash
git clone https://github.com/arrrrny/pdf-inspector.git
cd pdf-inspector/crates/pdf-to-markdown-rs-ffi
cargo build --release
# → target/release/libpdf_to_markdown_ffi.dylib (or .so / .dll)
```

Set `PDF_TO_MARKDOWN_FFI_LIB_PATH` to point at the built library, or place it
on the loader path (`DynamicLibrary.process()` / system library path).

### Android

Prebuilt `.so` files are **shipped in the package** under `native/android/<abi>/`
(arm64-v8a, armeabi-v7a, x86_64). Copy the one(s) you need into your app's
jniLibs — the loader resolves `libpdf_to_markdown_ffi.so` from the Android
jniLibs path at runtime:

```bash
# Copy from the package (or build from source below):
cp packages/dart/native/android/arm64-v8a/libpdf_to_markdown_ffi.so \
   <your-app>/android/app/src/main/jniLibs/arm64-v8a/
cp packages/dart/native/android/armeabi-v7a/libpdf_to_markdown_ffi.so \
   <your-app>/android/app/src/main/jniLibs/armeabi-v7a/
cp packages/dart/native/android/x86_64/libpdf_to_markdown_ffi.so \
   <your-app>/android/app/src/main/jniLibs/x86_64/
```

Build from source instead:

```bash
cargo install cargo-ndk
cd crates/pdf-to-markdown-rs-ffi
ANDROID_NDK_HOME=$ANDROID_NDK_HOME cargo ndk -t arm64-v8a -t armeabi-v7a -t x86_64 \
  -o <your-app>/android/app/src/main/jniLibs build --release
```

### iOS

iOS uses a **static library** linked into the app at build time (not dlopen'd).
The prebuilt `.a` files are shipped in `native/ios/` — link them into the Runner
(`ios/Runner/Frameworks` + Xcode link phase), then `NativeLibrary.instance`
resolves the symbols via `DynamicLibrary.process()`.

Build from source instead (on macOS):

```bash
cd crates/pdf-to-markdown-rs-ffi
cargo build --release --target aarch64-apple-ios            # device
cargo build --release --target aarch64-apple-ios-sim         # Apple Silicon sim
cargo build --release --target x86_64-apple-ios              # Intel sim
# → target/<triple>/release/libpdf_to_markdown_ffi.a
```

## Native library resolution order

`NativeLibrary.instance` tries, in order:

1. `PDF_TO_MARKDOWN_FFI_LIB_PATH` env var (testing / custom paths)
2. **Bundled binary** — `native/<rid>/libpdf_to_markdown_ffi.*` shipped inside the
   package (auto-discovered from the package directory; works out of the box
   for the platforms we publish prebuilt artifacts for, e.g. `macos-x64`)
3. `DynamicLibrary.process()` (linked at build time)
4. Platform default name (`libpdf_to_markdown_ffi.so` / `.dylib` / `.dll`)

## API Reference

### Functions

- `convert(Uint8List pdfBytes, {PdfMarkdownOptions? options}) → PdfMarkdownResult`
- `classify(Uint8List pdfBytes) → PdfClassificationResult`

### Classes

- `PdfMarkdownOptions` — `mode` (`full|detect|analyze`), `pages` (1-indexed filter)
- `PdfMarkdownResult` — `markdown`, `pdfType`, `pageCount`, `confidence`, `pagesNeedingOcr`
- `PdfClassificationResult` — `pdfType`, `pageCount`, `pagesNeedingOcr`
- `PdfType` — `textBased` | `scanned` | `unknown`

### Exceptions

`PdfFfiException`, `PdfInvalidInputException`, `PdfParseException`,
`PdfEncryptedException`, `PdfInvalidStructureException`

## Development

```bash
# 1. Build the Rust FFI library (from repo root)
cargo build --release -p pdf-to-markdown-rs-ffi

# 2. Run the Dart tests (point at the built library)
cd packages/dart
dart pub get
PDF_TO_MARKDOWN_FFI_LIB_PATH=<repo>/target/release/libpdf_to_markdown_ffi.dylib dart test
```

## Related

- [Rust engine](https://crates.io/crates/pdf-inspector) — Firecrawl's pdf-inspector
- [html_to_markdown_ffi](https://pub.dev/packages/html_to_markdown_ffi) — the same FFI pattern for HTML→Markdown
- [ZikZak](https://github.com/arrrrny/zik_zak) — the invoice price-check consumer
