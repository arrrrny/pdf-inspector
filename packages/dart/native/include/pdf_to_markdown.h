#ifndef PDF_TO_MARKDOWN_H
#define PDF_TO_MARKDOWN_H

#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Opaque handle types — never dereference on the C side. */
typedef struct PdfMarkdownResult PdfMarkdownResult;
typedef struct PdfMarkdownOptions PdfMarkdownOptions;
typedef struct PdfClassificationResult PdfClassificationResult;

/* Error codes returned by pdfmd_last_error_code(). */
#define PDFMD_OK                0
#define PDFMD_ERR_INVALID_INPUT  1
#define PDFMD_ERR_PARSE          2
#define PDFMD_ERR_ENCRYPTED      3
#define PDFMD_ERR_INVALID_STRUCTURE 4
#define PDFMD_ERR_UNKNOWN        99

/*
 * Convert a PDF byte buffer to Markdown.
 *
 * Returns an opaque PdfMarkdownResult* on success (check markdown != NULL).
 * On failure returns NULL; call pdfmd_last_error_code() / pdfmd_last_error_context().
 * The caller must free the result with pdfmd_result_free().
 */
PdfMarkdownResult *pdfmd_convert(
    const uint8_t *bytes,
    size_t len,
    const PdfMarkdownOptions *options
);

/*
 * Serialize a PdfMarkdownResult to a JSON string.
 * Caller must free with pdfmd_free_string().
 */
char *pdfmd_result_to_json(const PdfMarkdownResult *ptr);

/*
 * Classify a PDF without full extraction (~10-50ms).
 * Returns an opaque PdfClassificationResult*; free with pdfmd_classification_free().
 */
PdfClassificationResult *pdfmd_classify(
    const uint8_t *bytes,
    size_t len
);

/*
 * Serialize a PdfClassificationResult to a JSON string.
 * Caller must free with pdfmd_free_string().
 */
char *pdfmd_classification_to_json(const PdfClassificationResult *ptr);

/*
 * Parse JSON options string into an opaque PdfMarkdownOptions handle.
 * Pass NULL for defaults. Caller must free with pdfmd_options_free().
 *
 * Accepted JSON keys (all optional):
 *   "mode": "full" | "detect" | "analyze"
 *   "pages": [1, 3, 5]   // 1-indexed page filter
 */
PdfMarkdownOptions *pdfmd_options_from_json(const char *json);

/* Free an options handle. */
void pdfmd_options_free(PdfMarkdownOptions *ptr);

/* Free a result handle. */
void pdfmd_result_free(PdfMarkdownResult *ptr);

/* Free a classification result handle. */
void pdfmd_classification_free(PdfClassificationResult *ptr);

/* Free a string returned by this library. */
void pdfmd_free_string(char *ptr);

/*
 * Thread-local last error. Returns an error code (0 = no error).
 * The context string is valid until the next FFI call on the same thread.
 */
int32_t pdfmd_last_error_code(void);
const char *pdfmd_last_error_context(void);

#ifdef __cplusplus
}
#endif

#endif /* PDF_TO_MARKDOWN_H */
