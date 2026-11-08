# Code Generation Plan: Staff Web Not-Found Diagnostic

## Unit Context

- Unit: `staff-web-not-found-diagnostic`.
- Scope: add a stable, privacy-safe diagnostic report and browser clipboard action to the unmatched-route page.
- Contract: use the shared allow-listed diagnostic fields; never read or include the browser URL or query values.
- Tests: verify code, report content, copy action, and absence of route/query secrets.
- No API, backend, Flutter, authorization, or routing behavior changes beyond the not-found view.

## Steps

1. [x] Confirm PR #51 is open, fetch its current head, and inspect staff-web conventions and existing diagnostic contract.
2. [x] Define report fields and privacy boundary for a route failure with no API request.
3. [x] Implement the not-found diagnostic and accessible browser copy action with manual-copy fallback.
4. [x] Add component tests for stable code, copied report, URL/query privacy, and clipboard failure.
5. [x] Run staff-web lint, typecheck, tests, build, and diff checks.
6. [x] Review the intended source, styles, test, and task records; no Flutter/backend files changed.
7. [x] Publish the fix to the existing PR branch.

## Verification Results

- Focused diagnostic tests: 2 passed.
- Staff-web suite: 4 test files and 9 tests passed.
- Lint, typecheck, and production build passed.
- `git diff --check`: passed.
- Security Baseline: compliant for this scope; the report contains only fixed/allow-listed values and omits the browser path, query, user input, and clipboard exception details.
- PR #51 head: `b79955931279c1426e8ac85970eb5b3af10ea6b6`; frontend quality checks were pending at the last status read.
