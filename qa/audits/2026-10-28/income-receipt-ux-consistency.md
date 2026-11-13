# UX Consistency Audit — Income, Expense, Receipt, and Transfer Flows

**Scope:** Source review of detail/edit routes, actions, accessibility labels, and loading/saving states. Only the requested income-detail and receipt-edit changes were implemented. Other observations are follow-up work.

## Findings

### Resolved in this change

- **Income detail actions were below the data as large buttons**, while expense and receipt details use paired 48 × 48 header icon buttons. Income now uses the same header pattern, theme error color for Delete, matching tooltips and semantic labels, and preserves edit navigation, delete confirmation, progress/error handling, and disabled states.
- **Receipt editing showed both “Nota o comentarios” (`note`) and “Nota del recibo” (`receipt_note`) as editable fields.** The receipt-note input and its edit-form state were removed. The update command now omits `receipt_note`, so the API leaves the stored value unchanged. `note` and “Quitar la nota” keep their existing behavior.

### Follow-up; no screen changes made

- **Transfer history entries have no detail/edit destination.** The history card exposes income and expense entries as tappable buttons with a chevron, but transfer entries are not tappable and have no chevron. The router has a transfer creation form but no transfer detail or edit route. Consider a future transfer-detail flow and a consistent explanation/action for transfer history entries.
- **Income and expense edit forms differ by domain, but share clear save-state behavior.** Both expose loading/errors and disable submission while saving; expense edit additionally blocks mutations when the result is uncertain. No inconsistency requiring a change was found for this request.
- **Receipt details already share the expense header action pattern.** No change was needed there.

## Files reviewed

- `lib/features/incomes/presentation/income_detail_screen.dart`
- `lib/features/incomes/presentation/income_form_screen.dart`
- `lib/features/expenses/presentation/expense_detail_screen.dart`
- `lib/features/expenses/presentation/expense_form_screen.dart`
- `lib/features/transfers/presentation/transfer_form_screen.dart`
- `lib/features/expenses/presentation/history_screen.dart`
- `lib/core/router/app_router.dart`

## Verification boundary

These findings are based on source and widget-test inspection. Android screen behavior and screenshots are recorded separately after Maestro verification.
