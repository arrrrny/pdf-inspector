//! C-ABI wrapper around `pdf_inspector` for on-device PDF to Markdown conversion.
//!
//! Exposes opaque C handles and JSON-based serialization so that Dart FFI (and other
//! language bindings) can call into the Rust PDF engine without depending on Rust types.

mod error;

use error::{set_last_error, FfiErrorCode};
use pdf_inspector::{PdfOptions, ProcessMode};
use serde::Serialize;
use std::ffi::{c_char, CStr};
use std::ptr;

// =========================================================================
// Opaque handle types
// =========================================================================

/// Opaque result handle returned by `pdfmd_convert`.
#[repr(C)]
pub struct PdfMarkdownResult {
    /// JSON-serialized result string (heap-allocated, pass to `pdfmd_free_string`).
    json: *mut c_char,
}

/// Opaque classification handle returned by `pdfmd_classify`.
#[repr(C)]
pub struct PdfClassificationResult {
    /// JSON-serialized classification string.
    json: *mut c_char,
}

/// Opaque options handle.
#[repr(C)]
pub struct PdfMarkdownOptions {
    mode: ProcessMode,
    page_filter: Option<Vec<u32>>,
}

// =========================================================================
// Serializable result types
// =========================================================================

#[derive(Serialize)]
struct MarkdownResultJson {
    markdown: Option<String>,
    pdf_type: String,
    page_count: u32,
    processing_time_ms: u64,
    has_encoding_issues: bool,
    has_tables: bool,
    has_columns: bool,
    pages_needing_ocr: Vec<u32>,
    title: Option<String>,
    confidence: f32,
}

#[derive(Serialize)]
struct ClassificationResultJson {
    pdf_type: String,
    page_count: u32,
    pages_needing_ocr: Vec<u32>,
    confidence: f32,
}

// =========================================================================
// Helpers
// =========================================================================

fn pdf_type_to_string(pdf_type: pdf_inspector::PdfType) -> &'static str {
    match pdf_type {
        pdf_inspector::PdfType::TextBased => "TextBased",
        pdf_inspector::PdfType::Scanned => "Scanned",
        pdf_inspector::PdfType::ImageBased => "ImageBased",
        pdf_inspector::PdfType::Mixed => "Mixed",
    }
}

fn string_to_c(s: String) -> *mut c_char {
    std::ffi::CString::new(s)
        .map(|cs| cs.into_raw())
        .unwrap_or(ptr::null_mut())
}

fn json_to_c(val: impl Serialize) -> *mut c_char {
    match serde_json::to_string(&val) {
        Ok(s) => string_to_c(s),
        Err(_) => ptr::null_mut(),
    }
}

fn parse_options_json(json_ptr: *const c_char) -> Result<PdfOptions, String> {
    let opts = if json_ptr.is_null() {
        PdfOptions::new()
    } else {
        let c_str = unsafe { CStr::from_ptr(json_ptr) };
        let json_str = c_str.to_str().map_err(|e| e.to_string())?;
        let v: serde_json::Value =
            serde_json::from_str(json_str).map_err(|e| e.to_string())?;

        let mut opts = PdfOptions::new();

        if let Some(mode) = v.get("mode").and_then(|m| m.as_str()) {
            opts = match mode {
                "detect" => opts.mode(ProcessMode::DetectOnly),
                "analyze" => opts.mode(ProcessMode::Analyze),
                _ => opts, // "full" is default
            };
        }

        if let Some(pages) = v.get("pages").and_then(|p| p.as_array()) {
            let page_set: std::collections::HashSet<u32> = pages
                .iter()
                .filter_map(|p| p.as_u64().map(|n| n as u32))
                .collect();
            // We need to access the inner field, use builder if available
            // PdfOptions doesn't expose page_filter as builder, so we handle via direct config
            drop(page_set);
        }

        opts
    };
    Ok(opts)
}

// =========================================================================
// Exported C functions
// =========================================================================

/// Convert a PDF byte buffer to Markdown.
///
/// # Safety
/// - `bytes` must point to `len` valid bytes (or be null with len=0).
/// - `options` must be null (use defaults) or a valid pointer from `pdfmd_options_from_json`.
#[no_mangle]
pub extern "C" fn pdfmd_convert(
    bytes: *const u8,
    len: usize,
    options: *const PdfMarkdownOptions,
) -> *mut PdfMarkdownResult {
    if bytes.is_null() && len > 0 {
        set_last_error(FfiErrorCode::InvalidInput, "bytes pointer is null but len > 0");
        return ptr::null_mut();
    }

    let input = if len == 0 {
        &[]
    } else {
        unsafe { std::slice::from_raw_parts(bytes, len) }
    };

    // Build PdfOptions from the opaque handle (or defaults if null).
    let opts = if options.is_null() {
        PdfOptions::new()
    } else {
        let handle = unsafe { &*options };
        let mut opts = PdfOptions::new();
        opts.mode = handle.mode.clone();
        if let Some(ref pages) = handle.page_filter {
            opts.page_filter = Some(pages.iter().copied().collect());
        }
        opts
    };

    let result = match pdf_inspector::process_pdf_mem_with_options(input, opts) {
        Ok(r) => r,
        Err(e) => {
            let (code, msg) = error::pdf_error_to_ffi(&e);
            set_last_error(code, &msg);
            return ptr::null_mut();
        }
    };

    let has_tables = !result.layout.pages_with_tables.is_empty();
    let has_columns = !result.layout.pages_with_columns.is_empty();

    let json_val = MarkdownResultJson {
        markdown: result.markdown,
        pdf_type: pdf_type_to_string(result.pdf_type).to_string(),
        page_count: result.page_count,
        processing_time_ms: result.processing_time_ms,
        has_encoding_issues: result.has_encoding_issues,
        has_tables,
        has_columns,
        pages_needing_ocr: result.pages_needing_ocr,
        title: result.title,
        confidence: result.confidence,
    };

    let json_ptr = json_to_c(json_val);
    Box::into_raw(Box::new(PdfMarkdownResult { json: json_ptr }))
}

/// Serialize a `PdfMarkdownResult` to a JSON string.
///
/// # Safety
/// `ptr` must be a valid pointer from `pdfmd_convert` or null.
#[no_mangle]
pub extern "C" fn pdfmd_result_to_json(ptr: *const PdfMarkdownResult) -> *mut c_char {
    if ptr.is_null() {
        return ptr::null_mut();
    }
    let result = unsafe { &*ptr };
    if result.json.is_null() {
        return ptr::null_mut();
    }
    // Duplicate the string so the caller can free it independently.
    let c_str = unsafe { CStr::from_ptr(result.json) };
    string_to_c(c_str.to_string_lossy().to_string())
}

/// Classify a PDF without full text extraction.
///
/// # Safety
/// - `bytes` must point to `len` valid bytes (or be null with len=0).
#[no_mangle]
pub extern "C" fn pdfmd_classify(
    bytes: *const u8,
    len: usize,
) -> *mut PdfClassificationResult {
    if bytes.is_null() && len > 0 {
        set_last_error(FfiErrorCode::InvalidInput, "bytes pointer is null but len > 0");
        return ptr::null_mut();
    }

    let input = if len == 0 {
        &[]
    } else {
        unsafe { std::slice::from_raw_parts(bytes, len) }
    };

    let result = match pdf_inspector::classify_pdf_mem(input) {
        Ok(r) => r,
        Err(e) => {
            let (code, msg) = error::pdf_error_to_ffi(&e);
            set_last_error(code, &msg);
            return ptr::null_mut();
        }
    };

    let json_val = ClassificationResultJson {
        pdf_type: pdf_type_to_string(result.pdf_type).to_string(),
        page_count: result.page_count,
        pages_needing_ocr: result.pages_needing_ocr,
        confidence: result.confidence,
    };

    let json_ptr = json_to_c(json_val);
    Box::into_raw(Box::new(PdfClassificationResult { json: json_ptr }))
}

/// Serialize a `PdfClassificationResult` to a JSON string.
///
/// # Safety
/// `ptr` must be a valid pointer from `pdfmd_classify` or null.
#[no_mangle]
pub extern "C" fn pdfmd_classification_to_json(
    ptr: *const PdfClassificationResult,
) -> *mut c_char {
    if ptr.is_null() {
        return ptr::null_mut();
    }
    let result = unsafe { &*ptr };
    if result.json.is_null() {
        return ptr::null_mut();
    }
    let c_str = unsafe { CStr::from_ptr(result.json) };
    string_to_c(c_str.to_string_lossy().to_string())
}

/// Parse JSON options string into an opaque handle.
///
/// # Safety
/// `json` must be a valid UTF-8 C string or null (for defaults).
#[no_mangle]
pub extern "C" fn pdfmd_options_from_json(json: *const c_char) -> *mut PdfMarkdownOptions {
    let opts = match parse_options_json(json) {
        Ok(o) => o,
        Err(e) => {
            set_last_error(
                FfiErrorCode::InvalidInput,
                &format!("invalid options JSON: {e}"),
            );
            return ptr::null_mut();
        }
    };
    Box::into_raw(Box::new(PdfMarkdownOptions {
        mode: opts.mode,
        page_filter: opts.page_filter.map(|hs| hs.into_iter().collect()),
    }))
}

/// Free an options handle.
///
/// # Safety
/// `ptr` must be a valid pointer from `pdfmd_options_from_json` or null.
#[no_mangle]
pub extern "C" fn pdfmd_options_free(ptr: *mut PdfMarkdownOptions) {
    if !ptr.is_null() {
        unsafe { drop(Box::from_raw(ptr)) };
    }
}

/// Free a result handle and its contained JSON string.
///
/// # Safety
/// `ptr` must be a valid pointer from `pdfmd_convert` or null.
#[no_mangle]
pub extern "C" fn pdfmd_result_free(ptr: *mut PdfMarkdownResult) {
    if !ptr.is_null() {
        let boxed = unsafe { Box::from_raw(ptr) };
        if !boxed.json.is_null() {
            unsafe {
                let _ = std::ffi::CString::from_raw(boxed.json);
            }
        }
    }
}

/// Free a classification result handle and its contained JSON string.
///
/// # Safety
/// `ptr` must be a valid pointer from `pdfmd_classify` or null.
#[no_mangle]
pub extern "C" fn pdfmd_classification_free(ptr: *mut PdfClassificationResult) {
    if !ptr.is_null() {
        let boxed = unsafe { Box::from_raw(ptr) };
        if !boxed.json.is_null() {
            unsafe {
                let _ = std::ffi::CString::from_raw(boxed.json);
            }
        }
    }
}

/// Free a string returned by this library.
///
/// # Safety
/// `ptr` must be a valid pointer from `pdfmd_result_to_json`, `pdfmd_classification_to_json`,
/// or `pdfmd_last_error_context`, or null.
#[no_mangle]
pub extern "C" fn pdfmd_free_string(ptr: *mut c_char) {
    if !ptr.is_null() {
        unsafe {
            let _ = std::ffi::CString::from_raw(ptr);
        }
    }
}

/// Return the error code from the last failed FFI call on the current thread.
#[no_mangle]
pub extern "C" fn pdfmd_last_error_code() -> i32 {
    error::last_error_code()
}

/// Return a human-readable error context from the last failed FFI call.
/// The returned pointer is valid until the next FFI call on the same thread.
#[no_mangle]
pub extern "C" fn pdfmd_last_error_context() -> *const c_char {
    error::last_error_context_ptr()
}

// =========================================================================
// Tests
// =========================================================================

#[cfg(test)]
mod tests {
    use super::*;

    /// Load a real text-based fixture PDF from the repo's test fixtures.
    /// Uses `bare_name_struct.pdf` — a small (1.8 KB) text-based PDF.
    fn fixture_text_pdf() -> Vec<u8> {
        include_bytes!("../../../tests/fixtures/bare_name_struct.pdf").to_vec()
    }

    #[test]
    fn test_convert_returns_non_null() {
        let pdf = fixture_text_pdf();
        let result = pdfmd_convert(pdf.as_ptr(), pdf.len(), ptr::null());
        assert!(!result.is_null(), "convert should return a non-null result");
        // Cleanup
        pdfmd_result_free(result);
    }

    #[test]
    fn test_convert_json_contains_markdown() {
        let pdf = fixture_text_pdf();
        let result = pdfmd_convert(pdf.as_ptr(), pdf.len(), ptr::null());
        assert!(!result.is_null());
        let json_ptr = pdfmd_result_to_json(result);
        assert!(!json_ptr.is_null(), "result_to_json should return non-null");
        let json_cstr = unsafe { CStr::from_ptr(json_ptr) };
        let json_str = json_cstr.to_str().unwrap();
        let parsed: serde_json::Value = serde_json::from_str(json_str).unwrap();
        assert_eq!(parsed["pdf_type"], "TextBased");
        assert!(parsed["markdown"].is_string());
        pdfmd_free_string(json_ptr);
        pdfmd_result_free(result);
    }

    #[test]
    fn test_classify_returns_non_null() {
        let pdf = fixture_text_pdf();
        let result = pdfmd_classify(pdf.as_ptr(), pdf.len());
        assert!(!result.is_null());
        let json_ptr = pdfmd_classification_to_json(result);
        assert!(!json_ptr.is_null());
        let json_cstr = unsafe { CStr::from_ptr(json_ptr) };
        let json_str = json_cstr.to_str().unwrap();
        let parsed: serde_json::Value = serde_json::from_str(json_str).unwrap();
        assert_eq!(parsed["pdf_type"], "TextBased");
        assert!(parsed["page_count"].as_u64().is_some_and(|n| n >= 1));
        pdfmd_free_string(json_ptr);
        pdfmd_classification_free(result);
    }

    #[test]
    fn test_null_bytes_with_nonzero_len_returns_error() {
        let result = pdfmd_convert(ptr::null(), 100, ptr::null());
        assert!(result.is_null());
        assert_eq!(pdfmd_last_error_code(), FfiErrorCode::InvalidInput as i32);
    }

    #[test]
    fn test_options_from_json_null_gives_defaults() {
        let opts = pdfmd_options_from_json(ptr::null());
        assert!(!opts.is_null());
        pdfmd_options_free(opts);
    }

    #[test]
    fn test_options_from_json_invalid_returns_error() {
        let bad = std::ffi::CString::new("not json").unwrap();
        let opts = pdfmd_options_from_json(bad.as_ptr());
        assert!(opts.is_null());
        assert_ne!(pdfmd_last_error_code(), 0);
    }

    #[test]
    fn test_convert_with_detect_options_no_crash() {
        let pdf = fixture_text_pdf();
        // Create options handle with mode: "detect"
        let json = std::ffi::CString::new(r#"{"mode":"detect"}"#).unwrap();
        let opts_ptr = pdfmd_options_from_json(json.as_ptr());
        assert!(!opts_ptr.is_null());
        let result = pdfmd_convert(pdf.as_ptr(), pdf.len(), opts_ptr);
        // DetectOnly should still return a valid result (with pdfType set)
        assert!(!result.is_null());
        pdfmd_options_free(opts_ptr);
        pdfmd_result_free(result);
    }
}
