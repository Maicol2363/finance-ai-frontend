# Frontend CI and Android Release Testing Requirements

## Objective

Keep checks on everyday frontend pull requests short and validate a small set of critical real-device journeys before promoting `develop` to `main`.

## Requirements

1. Every pull request targeting `develop` or `main` runs Flutter formatting, static analysis, the existing unit and widget suite, and the existing 80% line coverage gate.
2. Android emulator journeys do not start on ordinary feature pull requests. They run only for same-repository pull requests from `develop` to `main`, or through explicit manual dispatch.
3. Release journeys use a disposable local FastAPI and PostgreSQL stack. The workflow checks out backend `main` by default for a release PR and records the resolved commit SHA. Manual runs may select a backend branch, tag, or SHA.
4. The Android journeys cover registration/login/session restore/logout/protected-route denial, expense entry and synchronized 100,000→80,000 COP balances, and a 30,000 COP transfer between accounts with history and navigation consistency.
5. Tests use the actual Flutter UI and local API, unique test users, synthetic financial records, and no AI-provider credentials or live provider calls.
6. Backend API tests remain the place to validate retry/idempotency behavior; existing backend transfer replay tests are not duplicated in the UI suite.
7. APK compilation and installation happen during hands-on user-story testing, not as routine PR checks.
8. Backend deployment triggers, production credentials, cloud resources, branch protection, and merge settings are out of scope.

## Acceptance

- `ci.yml` runs the existing quality/test/coverage job for PRs targeting `develop` and `main` and does not build or upload an APK.
- The emulator workflow is isolated from routine CI, and its job condition narrows pull-request execution to `develop` → `main`.
- Workflow YAML parses, workflow trigger assertions pass, and `actionlint` is used when installed.
- Formatting, analysis, the existing Flutter suite and coverage threshold pass.
- Local Android journey results are reported only if an Android emulator is available.
- The final diff contains no backend production deployment changes.
