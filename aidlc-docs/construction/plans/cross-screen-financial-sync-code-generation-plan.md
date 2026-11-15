# Cross-Screen Financial Sync — Code Generation Plan

## Unit Context

- **Unit**: Frontend financial state synchronization.
- **Stories**: FSYNC-01.
- **Dependencies**: Existing Riverpod providers/controllers and authenticated repositories; no new package or API contract.
- **Owned data**: No financial records. The client adds revision signals only and continues to fetch authoritative state from repositories.
- **Scope**: Shared account/history refreshes; AI expense-feed refresh; mutation-boundary publication; focused tests and documentation.

## Steps

- [x] 1. Identify the account, history, expense, income, transfer, and capture files that own state and mutations.
- [x] 2. Add a visible Accounts-screen regression test that changes fake server balance and publishes a movement revision.
- [x] 3. Add independent shared revisions for confirmed financial movements and out-of-band expense-feed changes.
- [x] 4. Make loaded Accounts and History controllers subscribe to movement revisions and reload canonical server data.
- [x] 5. Queue account and expense list reload requests that arrive while those lists are loading; retain History's existing queue.
- [x] 6. Publish revisions after confirmed income, expense, transfer, text-capture, and receipt-capture writes; keep income invalidation specific to income.
- [x] 7. Remove caller-specific duplicate history/account refreshes made redundant by controller subscriptions.
- [x] 8. Add controller tests for refresh coalescing and mutation event coverage; keep tests from invoking financial writes more than once.
- [x] 9. Run focused tests and Dart analysis with the configured Dart Tooling MCP server, format changed Dart files, and inspect the diff.
- [x] 10. Complete the synchronization matrix and build/test report, mark plan/state progress, and append audit evidence.

## Plan Approval

The user explicitly instructed “Continue without limitations” and asked to install/use Flutter/Dart MCP tooling. The existing AI-DLC state also authorizes autonomous execution. This plan is therefore being executed without a new pause.
