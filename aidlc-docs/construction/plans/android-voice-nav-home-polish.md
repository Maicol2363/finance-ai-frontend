# Autonomous Android voice, navigation and Home plan

User authorized implementation, delegation, build, safe installation and draft PR without intermediate questions. Base: ed51988 (origin/develop). Worktree isolated from existing local changes.

- [x] Read master prompt, rules, frontend instructions, PR 31/32/33, architecture handoff and references.
- [x] Detect workspace and create fix/android-voice-nav-home-polish from current origin/develop.
- [x] Define requirements and acceptance: microphone Spanish transcript, explicit proposal, safe insets/back, option 2, deterministic metrics, reusable camera help, no data loss.
- [x] Define units, ownership and design: Sol owns voice/router/platform; Luna UI owns palette/dashboard presentation; Luna camera owns camera/guide tests; Luna metrics owns pure metric models/tests. Analysis moves to /analysis. No new backend endpoints.
- [x] Run and classify baseline suite and CI failure: 501 pass/11 fail locally and CI. Nine Spanish diagnostic labels, semantic heading, 48dp selectors; all fixed in production code.
- [x] Delegate three real Luna implementations; camera/metrics returned and inspected, UI integration ongoing.
- [x] Diagnose and repair native audio and navigation with targeted tests.
- [x] Integrate dashboard metrics, refresh behavior, separate analysis route and camera help.
- [x] Format, analyze, full suite with coverage, native tests and APK build.
- [x] Verify signatures, preserve data, install and exercise physical device with before/after captures.
- [x] Audit, correct regressions and record requirement matrix with honest blocked cases.
- [x] Commit coherent changes, push and create draft PR targeting develop: #34, no merge.

Workflow: workspace detection -> requirements/stories/design -> code generation -> build/test -> safe ADB verification -> draft PR. Infrastructure design and Operations skipped: no deployment/backend change. Stories: as a user I dictate then review explicitly; navigate back to Inicio; inspect honest finances; reopen photo guidance.

Extension configuration inherited: Security enabled, Resiliency disabled (skip logged), PBT partial for pure calculations. SECURITY 03/09/11/13/15 applicable: safe diagnostics, no secrets/transcript logs, bounded model validation and isolated financial confirmation. Other infrastructure/web/backend rules N/A: unchanged resources/endpoints. No optional extension added without opt-in.

Operational exception: main credential preservation failed during initial API mismatch; final endpoint restored and manual main login required. No financial data was changed.

## User extension: currency and populated test profile
- [x] Make supported currency choices available before movements exist and share selection with Análisis.
- [x] Guard synthetic seed writes to the local SOL fixture identity and checkpoint completed actions.
- [x] Append six months through 2026-10-13: 115 expenses, 18 incomes, 11 transfers, four budgets, two additional COP/USD accounts, six categories and two income sources.
- [x] Verify populated COP/USD Home, Análisis, budgets and history on device; final full 539/0, coverage 84.83%, both artifacts installed with their intended servers.

## Final visual and audit regressions
- [x] Expose currency selector as an independent accessible button and verify COP/USD navigation on phone.
- [x] Guard seed rerun with identical checkpoint; no duplicate financial entries.
- [x] Match Análisis month projection to Home deterministic formula and local date cutoff.
- [x] Exclude voided expenses from both windows, all chart granularities and category breakdown; targeted tests passed.
- [x] Prevent previous-window totals from appearing under a newly selected period while loading; deferred-Future widget regression passed.
- [x] Run final suite (539/0, 84.83%), analyze/format, rebuild/install both intended-server APKs, and verify USD projection physically.
- [x] Inspect draft CI jobs; Windows checks/build passed on the first draft head. Final source-run results are linked in the PR description when completed.
