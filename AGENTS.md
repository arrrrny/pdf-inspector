# ⚠️ LANGUAGE RULE — MANDATORY

**ALL responses MUST be in English ONLY. Never respond in Turkish, Chinese, or any other language, regardless of the user's locale or the presence of non-English content in the codebase. This is a hard rule with no exceptions.**

---

# pdf-inspector

Fast PDF text extraction to structured Markdown. CLI binary: `pdf2md`. Detection binary: `detect-pdf`.

## Build & Test

```bash
cargo fmt                                    # format
cargo clippy -- -D warnings                  # lint (enforced, zero warnings)
cargo test                                   # unit + integration tests (267+ unit, 73+ integration)
cargo build --release                        # release binary for benchmarks
```

All three must pass before committing.

## Binaries

- `pdf2md` — extract PDF → Markdown. Supports `--json` for structured output.
- `detect-pdf` — classify PDF type (TextBased/Scanned/Mixed/ImageBased). Supports `--analyze --json`.

## Architecture

```
src/
  lib.rs                        – public API, process_pdf_with_options, encoding issue detection
  detector.rs                   – PDF type classification, tiled-scan detection, page sampling
  types.rs                      – TextItem, TextLine, PdfRect, PdfLine
  tounicode.rs                  – CMap/ToUnicode parsing, CID decoding
  text_utils.rs                 – CJK/RTL handling, Otsu threshold, ligature expansion, NFKC
  extractor/
    mod.rs                      – top-level extraction orchestrator
    content_stream.rs           – PDF operator state machine (Tj/TJ/Td/Tm/q/Q)
    fonts.rs                    – font width/encoding, CMapDecisionCache, TrueType cmap fallback
    layout.rs                   – column detection (histogram), newspaper/tabular classification,
                                  spanning-line pre-masking, sidebar detection
  tables/
    detect_rects.rs             – rect-based table detection (union-find clustering)
    detect_heuristic.rs         – heuristic table detection (gap-histogram, body-font tables)
    detect_lines.rs             – line-based table detection (H/V line grids)
    grid.rs                     – column/row boundaries, cell assignment
    format.rs                   – table→Markdown formatting, continuation row merging
  markdown/
    convert.rs                  – core line→Markdown loop, struct-tree role support
    analysis.rs                 – font stats, heading tiers, paragraph thresholds
    classify.rs                 – line classification (header, list, code, caption)
    preprocess.rs               – drop cap merging, heading line merging
    postprocess.rs              – dot leaders, hyphenation, page numbers, URL formatting
```

## Key design decisions

- **Primary audience is AI agents.** Output optimized for token efficiency and semantic quality, not visual formatting. No cosmetic padding.
- **Three table detection strategies** run in priority order: rect-based → line-based → heuristic. First valid result wins.
- **Column detection** uses horizontal projection histograms with valley detection. Multi-item spanning lines (titles, headers) are pre-masked using column-aware thresholds before column assignment.
- **Newspaper vs tabular** classification determines reading order: newspaper reads columns sequentially, tabular Y-interleaves them.
- **Tiled-scan detection** catches scanned PDFs with JBIG2/strip images where no single tile exceeds the template threshold but aggregate area does (≥2M pixels).
- **Garbage text upgrade** reclassifies Mixed PDFs as Scanned when extracted text is <50% alphanumeric.
- **Tagged PDF support** uses structure tree roles (H1-H6, P, L, Code, BlockQuote) when available, falling back to font-size heuristics.

## Testing

- **Unit tests**: inline `#[cfg(test)] mod tests` in each module with synthetic data.
- **Integration tests**: `tests/integration_tests.rs` with fixture PDFs in `tests/fixtures/`.
- **Regression suite**: sibling repo `pdf-evals` with 179+ snapshot PDFs. Run `cargo build --release` then `bench.py test` in that repo before committing.

## Debugging

```bash
RUST_LOG=pdf_inspector::extractor::layout=debug cargo run --bin pdf2md -- file.pdf
RUST_LOG=pdf_inspector::tables=debug cargo run --bin pdf2md -- file.pdf
RUST_LOG=pdf_inspector::detector=debug cargo run --release --bin detect-pdf -- file.pdf
```

## Conventions

- Clippy: use `is_some_and(...)` not `map_or(false, ...)`
- lopdf quirk: `ParseError` is private — match by string for `InvalidFileHeader`
- Column limit for tables: 25 (wide statistical tables)
- `propagate_merged_cells` skipped for >10 columns (spanning rects = background fills)

# Shared terminal (`pallet`)
Long-running or user-visible commands (e.g. `flutter run`, `dart run build_runner build`, `bun run watch:dev`) should run in the **shared `pallet` tmux session** so both the human and agents see the same terminal. The human attaches with `pallet up` (in their terminal, e.g. Zap); agents drive it via the `pallet` CLI or the `pallet` MCP server (`~/Developer/forklift/scripts/pallet/pallet_mcp_server.dart`):

```bash
pallet ensure                 # create the shared session if missing
pallet run -n 'cmd'           # run in a fresh window (visible to the human)
pallet wait -w N              # wait until that window goes idle
pallet read -w N              # capture the window's output
```

See `~/Developer/forklift/scripts/pallet/README.md` for the full workflow
and CLI reference.




## 🔍 Code Search — MANDATORY FIRST STEP

**STOP. Before using `grep`, `find`, `rg`, `ripgrep`, or ANY shell-based search, you MUST use semantic search first.**

```bash
# THIS is how you search code — ALWAYS FIRST:
mcp__claude_context__search_code(query="what you're looking for", path="/absolute/path/to/repo")
```

**Why?** Semantic search understands code relationships, finds implementations by meaning (not just text), and catches things grep misses entirely.

**Rules:**
1. **ALWAYS** start with `mcp__claude_context__search_code` for code discovery
2. **ONLY** fall back to `grep`/`find`/`rg` when:
   - You need an EXACT literal string match (e.g., a specific error message)
   - The semantic search index is unavailable/broken
   - You're searching for file names, not code content
3. **NEVER** use grep as your first code search tool — it's slower and less accurate

**Indexing:** If search fails with "not indexed", run `mcp__claude_context__index_codebase(path="/absolute/path")` first, then retry.

## 📚 Zread Wiki — Check First

**Before diving into source code, check if a zread wiki exists for this project:**

```bash
# Check if wiki exists:
cat .zread/wiki/current 2>/dev/null && echo "Wiki exists" || echo "No wiki"

# If wiki exists, read the pages directly:
ls .zread/wiki/versions/$(cat .zread/wiki/current)/

# To regenerate wiki (if stale):
zread generate --stdio
```

**Why?** Zread generates comprehensive documentation from code. Reading the wiki is faster than crawling source files manually.

**Rules:**
1. **ALWAYS** check `.zread/wiki/current` before reading source files
2. If wiki exists, read the markdown pages directly — they're already indexed
3. If wiki is missing or stale, run `zread generate --stdio` to create it
4. Wiki pages live in `.zread/wiki/versions/<id>/` — read `wiki.json` for the TOC
