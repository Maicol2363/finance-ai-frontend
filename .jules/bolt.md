## 2026-09-15 - Batch Canvas Draw Calls in Custom Painters
**Learning:** Extracting individual paths inside a drawing loop generates O(N) canvas draw calls and path allocations per repaint frame.
**Action:** Combine extracted subpaths into a single `Path` object before invoking `canvas.drawPath` once to reduce drawing calls to O(1).
