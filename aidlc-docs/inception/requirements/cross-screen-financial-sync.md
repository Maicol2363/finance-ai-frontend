# Cross-Screen Financial Data Synchronization

## Intent

Keep already-open or retained financial screens synchronized after a successful financial mutation. The client must refresh dependent server-backed data without replaying the mutation or changing backend, cloud, or installed-app state.

## Confirmed Baseline

- The dashboard's income totals watch `incomesListProvider`, which watches `incomeRevisionProvider`.
- Manual income create, update, and delete increment the income revision, but did not invalidate the cached account list or history.
- The account controller is a persistent `NotifierProvider`; account and dashboard screens only load accounts while the provider is in its initial state.
- The router retains tab branches in an indexed stack, so returning to a screen does not guarantee its `initState` runs again.
- Income repository writes call the backend's income endpoints. Backend source writes a confirmed financial transaction and its account movement in one database transaction; account projections sum opening balance and confirmed movements.
- No production API response for the reported device session was captured. The backend conclusion is source/contract evidence, not a live response observation.

## Requirements

1. After a successful income create, update, or delete, refresh account balances and loaded history as well as income totals.
2. After a successful expense create, update, or delete, refresh loaded accounts and history; preserve the existing expense list and budget refresh behavior.
3. After a successful transfer, refresh loaded accounts and history from the mutation boundary so callers do not have to remember separate refresh calls.
4. After a confirmed AI expense, refresh accounts, history, the expense feed, and budgets. After a text-captured income or transfer, refresh the dependent movement data and only invalidate the income feed for an income.
5. A refresh requested while a list is already loading must not be lost. Coalesce overlapping requests and make one follow-up request after the in-flight request completes.
6. Failed or unconfirmed mutations must not publish a success event. Uncertain outcomes may refresh data for resolution but must not replay a financial write.
7. Preserve API contracts, error diagnostics, selected filters, navigation, and existing user data. No backend or deployed environment change is in scope.

## Acceptance Criteria

- An already-rendered Accounts screen shows the server's updated balance after an income mutation signal, without a manual pull-to-refresh or route reconstruction.
- Loaded History and Dashboard totals converge after successful mutations across income, expense, transfer, and AI capture paths.
- Refresh requests that arrive during a load are coalesced and drained afterward.
- Tests verify visible balance change, account/history refresh behavior, and no repeated mutation call.
- Categories, income sources, and budgets are reviewed for cached cross-screen reads; any additional confirmed defect is fixed and covered.
- The report separates verified source behavior from unverified Android/API behavior.

## Scope and Constraints

- Frontend Dart/Flutter only, in the isolated worktree based on frontend commit `ae1065d3585197a9df071d38b419bd49366c64de`.
- Backend checkout at `37de6dc61a7e4c5215febe7ed3ecca1a3b97e098` is read-only.
- Do not push, merge, deploy, modify Cloud Run, mutate production data, or replace the installed APK.
- Existing security extension configuration is enabled; resiliency is disabled; property-based testing is partial.
