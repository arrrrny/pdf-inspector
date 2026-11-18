//! Thread-local error handling for the FFI layer.

use std::cell::RefCell;
use std::ffi::c_char;

/// Error codes exposed through the C ABI.
#[repr(i32)]
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum FfiErrorCode {
    Ok = 0,
    InvalidInput = 1,
    Parse = 2,
    Encrypted = 3,
    InvalidStructure = 4,
    Unknown = 99,
}

struct LastError {
    code: FfiErrorCode,
    #[allow(dead_code)]
    context: String,
    c_context: std::ffi::CString,
}

impl LastError {
    fn new(code: FfiErrorCode, context: &str) -> Self {
        let c_context = std::ffi::CString::new(context).unwrap_or_else(|_| {
            std::ffi::CString::new("<error context contained NUL>").unwrap()
        });
        Self {
            code,
            context: context.to_string(),
            c_context,
        }
    }

    fn clear() -> Self {
        Self::new(FfiErrorCode::Ok, "")
    }
}

thread_local! {
    static LAST_ERROR: RefCell<LastError> = RefCell::new(LastError::clear());
}

/// Set the thread-local last error.
pub fn set_last_error(code: FfiErrorCode, context: &str) {
    LAST_ERROR.with(|le| {
        *le.borrow_mut() = LastError::new(code, context);
    });
}

/// Get the thread-local last error code.
pub fn last_error_code() -> i32 {
    LAST_ERROR.with(|le| le.borrow().code as i32)
}

/// Get a raw pointer to the thread-local last error context string.
/// Valid until the next FFI call on the same thread.
pub fn last_error_context_ptr() -> *const c_char {
    LAST_ERROR.with(|le| le.borrow().c_context.as_ptr())
}

/// Map a `pdf_inspector::PdfError` to an FFI error code and message.
pub fn pdf_error_to_ffi(e: &pdf_inspector::PdfError) -> (FfiErrorCode, String) {
    use pdf_inspector::PdfError;
    let msg = e.to_string();
    let code = match e {
        PdfError::NotAPdf(_) => FfiErrorCode::InvalidInput,
        PdfError::Encrypted => FfiErrorCode::Encrypted,
        PdfError::InvalidStructure => FfiErrorCode::InvalidStructure,
        PdfError::Parse(_) => FfiErrorCode::Parse,
        PdfError::Io(_) => FfiErrorCode::Unknown,
    };
    (code, msg)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_error_roundtrip() {
        set_last_error(FfiErrorCode::InvalidInput, "bad PDF");
        assert_eq!(last_error_code(), FfiErrorCode::InvalidInput as i32);
        let ctx = unsafe {
            let ptr = last_error_context_ptr();
            std::ffi::CStr::from_ptr(ptr).to_str().unwrap()
        };
        assert_eq!(ctx, "bad PDF");
    }

    #[test]
    fn test_error_clears_on_new_set() {
        set_last_error(FfiErrorCode::Parse, "old error");
        set_last_error(FfiErrorCode::Ok, "");
        assert_eq!(last_error_code(), 0);
    }
}
