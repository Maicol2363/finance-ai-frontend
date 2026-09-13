# Finance AI Frontend Agent Guide

This repository owns the shared Flutter client for Android and Windows, native platform runners, secure client storage, and frontend tests. Product requirements and architecture decisions live in `NullCorvus/finance-ai`; the API and OpenAPI contract live in `Maicol2363/finance-ai-backend`.

## Branch workflow

- Start story branches from `develop` and target `develop` in feature pull requests.
- Merge `develop` into `main` only for fully tested, release-ready work.
- Preserve completed feature branches unless the team explicitly chooses to remove them.

## Mandatory copyable diagnostics

- Every user-visible failure uses the shared diagnostic contract and copy UI under `lib/core/diagnostics/`.
- Reports include only allow-listed fields: stable code, operation, UTC time, client platform, sanitized API location, request/correlation ID, and a bounded safe technical reason when applicable.
- Never include passwords, confirmations, email addresses, credentials, authorization headers, form values, request bodies, URL query values, environment values, stack traces, raw exceptions, or database details.
- Test each new failure path for its stable code, safe message/report, correlation propagation when applicable, and absence of entered values or secrets.

## Client rules

- Android and Windows use the same Dart feature code; do not create platform forks for product behavior.
- The backend OpenAPI contract is authoritative. Do not invent a second client-only version of server validation or business rules.
- The manual workflow is complete and authoritative. Future AI only proposes values for the same forms and remains optional.
- Access credentials stay in memory. Only renewable credentials may use the approved native secure-storage adapter.
- Keep the API base URL configurable for emulator, desktop, physical-device, and future synchronization environments.

## Required verification

Run `tool/verify_shared.ps1`, `tool/build_android.ps1`, and `tool/test_windows_and_restore.ps1` as appropriate. Native Windows tests temporarily replace the debug bundle with a test harness; always use the restoration helper before handing the `.exe` to a user. Maintain at least 80% line coverage and preserve the privacy assertions.
