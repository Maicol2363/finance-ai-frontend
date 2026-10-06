## 2026-09-15 - Batch Canvas Draw Calls in Custom Painters
**Learning:** Extracting individual paths inside a drawing loop generates O(N) canvas draw calls and path allocations per repaint frame.
**Action:** Combine extracted subpaths into a single `Path` object before invoking `canvas.drawPath` once to reduce drawing calls to O(1).

## 2026-09-17 - Pre-compile RegExp in Hot Parsing and Validation Loops
**Learning:** Instantiating `RegExp` inside factory functions (like `MoneyAmount.parseApi` or `tryParseUserInput`) or error sanitizers recompiles regex state on every invocation/keystroke.
**Action:** Extract regular expression patterns into `static final` compiled instances to avoid repeated RegExp engine compilation overhead during list deserialization and real-time form validation.
