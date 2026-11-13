# Financial State Flow Reverse Engineering

## Scope

Focused brownfield analysis of the frontend state and mutation flows named in the synchronization request. It does not claim to be a complete inventory of unrelated authentication, cloud, or presentation code.

## UI and Provider Lifecycle

- The app router uses `StatefulShellRoute.indexedStack` for retained navigation branches.
- `accountsControllerProvider` is a non-auto-disposed `NotifierProvider` with an initially empty state.
- Home, Dashboard, and Accounts screens load accounts only when `listStatus` is `initial`. A cached `ready` state therefore survives route/tab changes.
- `HistoryController` and `ExpensesController` also expose shared state. History already queues a reload requested during page loading; Accounts and Expenses previously returned early and dropped such a reload.
- `monthlyTotalsProvider` watches the expense-list result and awaits `incomesListProvider`. `incomesListProvider` watches `incomeRevisionProvider`, explaining why income totals updated while the account balance did not.

## Transaction Mutation Paths

| Flow | Mutation boundary | Existing synchronization before this change | Confirmed gap |
|---|---|---|---|
| Manual income create/update/delete | Income form/detail screen calls `IncomesRepository` | Incremented income revision | Account controller and loaded history stayed cached |
| Manual expense create/update/delete | `ExpensesController` | Canonical expense list and budget progress refreshed; create screen also reloaded history | Account balances could stay cached; history refresh was caller-specific |
| Transfer | `TransferController` / transfer form | Form manually reloaded history and accounts after create | Synchronization depended on the form caller; uncertain-outcome refresh was not shared |
| Text capture | `TextCaptureController.confirm` | Called account, history, expense, budget, and income refreshes directly | Refreshed income data for every intent; a stale in-flight load could absorb refresh requests |
| Receipt capture | `ReceiptCaptureNotifier.confirmExpense` | Refreshed expense feed, history, and budgets | Did not refresh accounts |
| Account management | `AccountsController` | Canonical list refreshed after account mutations | No cross-screen catalog issue found in the inspected flow |
| Categories and income sources | Shared catalog controllers/providers | Mutations refresh their canonical shared lists; expense forms watch shared category state | No confirmed stale-state defect found in inspected flows |
| Budgets | `BudgetsController` | Expense mutations reload budget progress; budget writes refresh the shared controller state | No confirmed stale-state defect found in inspected flows |

## Root Cause

Income dashboard totals and account balances read different state owners. Income mutations bumped the income revision, invalidating the income list and causing dependent monthly totals to recalculate. The accounts screen and dashboard balance instead read `AccountsController.result`, which remained cached in a persistent provider. The retained screen lifecycle did not call `initState` again, so navigating back did not reload the account endpoint. A manual refresh fetched the updated server projection, matching the observed recovery path.

The same missing dependency affected any successful transaction that changed account movements unless its UI caller explicitly reloaded accounts. History had the same caller-specific problem. Receipt AI confirmation is a confirmed example: it refreshed expenses/history/budgets but omitted accounts.

## Backend Evidence and Limits

The inspected backend source creates or updates the confirmed income transaction and account movement in a single database transaction. `SQLAlchemyAccountRepository` calculates balance as opening balance plus the sum of confirmed account movements, and the account service returns that projection from list/detail endpoints. This is consistent with the report that an account reload restored the expected balance. The original Android session's actual response was not captured, and no deployed API was called as part of this task; runtime correctness remains unverified.

## State Ownership Decision

Use a small shared financial-movement revision as an invalidation signal. Loaded Accounts and History controllers subscribe and reload from their existing repositories. A separate expense-feed revision handles AI-confirmed expenses that are created outside `ExpensesController`. The existing income revision remains specific to income totals. Mutations stay at their current repository/controller boundaries and are never replayed by a refresh.
