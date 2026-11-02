# Frontend CI and Android Release Testing Workflow

## Brownfield review

- [x] Reuse the existing Flutter CI workflow and coverage gate; keep APK creation in the developer's hands-on story testing.
- [x] Inventory current Android integration tests, widget tests, and backend API integration coverage before adding journeys.
- [x] Confirm that the previous emulator job ran on every pull request and checked out a fixed backend SHA.

## Implementation plan

- [x] Restrict regular CI to PRs targeting `develop` and `main`.
- [x] Keep the PR workflow focused on Flutter quality/test/coverage; omit the APK build and artifact because it adds little value to this team's review/testing flow.
- [x] Remove the Android emulator job from everyday CI and use a dedicated release integration workflow gated to a same-repository `develop` → `main` PR.
- [x] Add a manual release integration entry point that accepts the backend branch, tag, or SHA.
- [x] Resolve backend `main` at run time for release PRs and log the checked-out commit; use isolated Compose PostgreSQL data and keep provider keys empty.
- [x] Reuse the real API registration/login integration test and extend it to deny a protected account route after logout.
- [x] Add expense and transfer journeys that reuse accessible widget keys and assert user-visible history and balances.
- [x] Run workflow validation, Flutter quality/tests/coverage, local APK build, diff review and final trigger/security checks. PyYAML parsing and trigger/job assertions, formatter, analyzer, full Flutter suite, coverage threshold, local APK build and `git diff --check` passed; `actionlint` is not installed.
- [x] Check local Android execution availability. No AVD/emulator is available (only Linux device detected); local Android integration tests were not run and are not reported as passing.

## Scope checks

- No backend source, production deploy workflow, Cloud Run/Neon resource or credential is changed.
- No GitHub branch protection, merge, push, or deployment action is performed.
- Existing API transfer retry/idempotency tests remain the lower-level validation for replay behavior.
- [x] After user clarification, removed the routine PR APK build/artifact job; APK build/install is reserved for user-story hands-on QA.
