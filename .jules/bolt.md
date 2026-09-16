## 2026-09-15 - Batch Canvas Draw Calls in Custom Painters
**Learning:** Extracting individual paths inside a drawing loop generates O(N) canvas draw calls and path allocations per repaint frame.
**Action:** Combine extracted subpaths into a single `Path` object before invoking `canvas.drawPath` once to reduce drawing calls to O(1).

## 2026-09-16 - Reuse Compiled RegExp Instances in Domain Models and Diagnostics
**Learning:** Instantiating `RegExp` inline inside factory constructors or helper functions recompiles regular expressions on every execution, adding allocation and CPU overhead in list parsing loops.
**Action:** Declare `RegExp` patterns as `static final` constants to compile them once lazily and reuse across calls.
