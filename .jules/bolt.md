## 2026-09-15 - Batch Canvas Draw Calls in Custom Painters
**Learning:** Extracting individual paths inside a drawing loop generates O(N) canvas draw calls and path allocations per repaint frame.
**Action:** Combine extracted subpaths into a single `Path` object before invoking `canvas.drawPath` once to reduce drawing calls to O(1).

## 2026-09-16 - Cache Static RegExp Instances in High-Frequency Parsers
**Learning:** Constructing `RegExp(r'...')` instances inline inside frequently called functions (such as `MoneyAmount.parseApi` or `ErrorDiagnostic.capture`) repeatedly re-compiles regex patterns on every invocation.
**Action:** Extract `RegExp` objects as `static final` constants to compile the regular expressions once and reuse them safely across function calls.
