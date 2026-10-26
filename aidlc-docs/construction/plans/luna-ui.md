# Luna UI implementation checklist

- [x] Confirm exclusive file ownership with Sol and inspect the option 2 reference.
- [x] Restore accessible olive/light and dark palette tokens; contrast assertions cover primary text, card text, and muted text.
- [x] Replace the large dashboard hero and embedded analysis with a compact account balance and monthly flow row, honest weekly insight, completeness-gated month projection, and budget link.
- [x] Preserve analysis periods, trend, category breakdown/drill-down on `DashboardAnalysisScreen`; direct links have a `/dashboard` back fallback.
- [x] Update focused presentation/theme tests and run formatter, focused analysis, and 26 focused tests successfully.
- [x] Regenerate and inspect the golden after replacing the rendered analysis action; the compact CTA now renders readable text and arrow.
- [x] Home errors retry the actual month totals provider and stay visible if the summary endpoint succeeds independently.
- [x] Share the selected currency across Inicio and Análisis; expose every backend-supported currency and verify an empty USD view remains zero without creating USD accounts or transactions.
- [x] Suppress a retained summary value while its selected-currency request is loading; focused dashboard tests and analyzer pass.
