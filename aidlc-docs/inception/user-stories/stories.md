# User Stories

## FSYNC-01 — Keep Financial Screens in Sync

**As a** signed-in person managing my finances,

**I want** the dashboard, account balances, and history to refresh after I confirm an income, expense, transfer, or AI-captured operation,

**so that** every screen shows the same current financial state without me repeating the operation or manually refreshing each screen.

### Acceptance Criteria

1. After an income create, update, or delete succeeds, the income totals, account balance, and loaded history reflect the saved result.
2. After an expense create, update, or delete succeeds, loaded account balances and history reflect the saved result; expense totals and budgets continue to refresh.
3. After a transfer succeeds, loaded source/destination balances and history reflect the transfer without changing income totals.
4. After an AI expense is confirmed, account balances, history, expense feed, and budgets refresh; after a text-captured income, only income-dependent data is invalidated in addition to shared movement data.
5. A refresh requested while a provider is loading is performed after the in-flight request; the financial write is not repeated.
6. A rejected or unconfirmed operation does not publish a confirmed-mutation signal.

### Traceability

- Requirements: R1–R7 in `requirements/cross-screen-financial-sync.md`.
- Verification: account screen widget regression; controller refresh/coalescing tests; focused Dart/Flutter MCP analysis and tests.
