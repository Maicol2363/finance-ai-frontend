# Verifiable delivery summary

Base: origin/develop ed51988. Branch: fix/android-voice-nav-home-polish. All work is in a separate worktree; dirty source checkouts were neither stashed nor reset. Sol coordinated actual Luna UI, camera, metrics and read-only audit agents. Their reports were inspected and integrated. Project TOML is compatible with the current Codex schema and CLI; existing globals were not overwritten.

## Root causes and corrections

- Installed main APK still exposed the older hold interface, not PR 33 Anchored Composer. The installed signing identities and actual artifact were checked; final update uses the compatible main certificate.
- A native preparation callback could precede the event sink; one pending event is replayed on subscription. Device readiness alone did not guarantee useful recognition callbacks. Missing callbacks/empty results now have bounded recovery, and partial/committed words survive review.
- Transparent status bars inherited light icons over a light header. App-wide overlay styling now follows theme; the existing bottom SafeArea remains the single inset owner. Actual three-button icons stay below app labels.
- go() from management submenus could destroy origin history. push() preserves it, root back returns to Inicio, and routerDelegate changes refresh canPop after child removal.
- Home is option 2: compact light greeting/selector, stock balance, monthly flow, honest weekly insight, compact projection, compact Presupuestos link and separate /analysis. Detailed charts/periods/categories remain available. Palette restores olive/lime with readable foregrounds.
- Previous spending was only first-page data; both comparison windows now paginate, preserve coverage/completeness and decline extrapolation when truncated. Metrics use currency-filtered real expenses, comparable full weeks, local dates and explicit coverage gates; no LLM or new endpoint was added. Midnight/resume and mutation changes invalidate relevant data.
- Camera help reopens the existing dialog without resetting first-use persistence.
- Shared diagnostic labels, title headings and 48 dp selectors were repaired for Spanish/accessibility.

## Requirement matrix

| Requirement | Status | Evidence |
|---|---|---|
| Spanish microphone -> visible editable text | verified on phone | Direct user confirmation and private screenshots; acoustic capture also observed |
| Explicit Send -> real API proposal -> review | verified on phone | Proposal visible with Confirmar y guardar; no save by Sol; isolated synthetic account |
| Missing model/install/retry | verified on phone | Explicit Spanish download, ready state, live offline engine |
| Pause/edit/continue/discard/late-event guards | verified automatically; pause observed on phone | Shared voice/controller/native privacy tests plus local paused screenshot |
| Insets, gestures and three-button navigation | verified on phone | Home screenshots/XML, themes, system button separation; mode restored |
| Back from secondary roots/deep forms | verified automatically and on phone | Seven focused tests plus account detail physical path |
| Option 2, olive palette, separate analysis/budgets | verified on phone and automatically | Home/analysis screenshots and golden; no duplicated recent movements/capture actions |
| Weekly calculations/projection/currency/incomplete data | verified automatically | Eleven pure calculation tests, paginated totals cases, currency selector checks, empty-state phone |
| Reopen camera guide | verified on phone and automatically | Two help reopenings; 23 guide/capture focal tests; physical camera preview |
| Real photographed receipt capture | pending | No suitable physical receipt was positioned; no room image was uploaded |
| Recognition accuracy across merchant names/devices and timing | pending | User passed actual speech; no quantitative cross-device benchmark |
| Preserve existing financial data / audio_test | verified by bounded operations | Only the new local synthetic profile was changed. Later explicit user authorization added demo movements to this profile only; no existing user data, clear, uninstall or backend change |
| Preserve main login credential | not preserved; manual action required | Initial main build incorrectly changed server to localhost; restore rejected and cleared credential. Final main build restores original Cloud Run URL. User must sign in again. |
| Full verification | verified automatically | 539/0, 84.83% coverage, analyze/format/diff clean; 5 JVM and 5 device native checks |
| Draft PR, no merge | verified remotely | [#34](https://github.com/Maicol2363/finance-ai-frontend/pull/34), draft against develop |

## Local evidence and limitations

Ignored build/sol-evidence contains baseline/final logs, native XML/JUnit results, screenshots, private recording and both final APKs. Never attach raw transcripts, credentials, user-camera preview, UI dumps or audio to a public PR. Reproduction commands and summarized outcomes are safe to publish. Android tests with mocked speech/public PCM are distinguished from actual mic evidence.

Main final API: original Cloud Run endpoint (readiness HTTP 200). Synthetic verification API: localhost:8000 over adb reverse (HTTP 200). The initial API mismatch was a coordinator error and was disclosed; it cannot be repaired without the user's main-app sign-in. No existing financial data was erased and no database/volume was restarted.

## Extension compliance

Security enabled: applicable diagnostic/privacy, bounded input/model integrity, credential protection in source and account separation checks complied with in source and final artifact. Credential-preservation incident above is a disclosed operational non-compliance, not hidden as a pass. Infrastructure/web/backend deployment rules are N/A because no resources/endpoints changed. Resiliency extension remains disabled and was skipped; PBT partial applies to pure metrics, covered by deterministic generated boundary loops. This is not a new production security certification.

## Populated synthetic profile (user-authorized extension)

The user asked for several months of synthetic data and USD selection. Seed scope is the guarded local SOL fixture account, not the main Cloud Run account. Dataset runs May–October 2026 through October 13: 115 expenses, 18 incomes, 11 transfers (including explicitly declared cross-currency amounts), four budgets, two additional accounts, six categories and two income sources. All entries are labelled demo/synthetic; existing records were not deleted. Repeating the script uses a private checkpoint to skip completed creations.

`tool/seed_sol_demo.py --credentials /private/path/to/fixture.json` requires the SOL example.com identity and uses localhost only. It never prints or checkpoints credentials/tokens. USD is available from the server currency catalog even with no USD movements; Inicio and Análisis share the view currency, without automatic currency conversion. Previous summary values are withheld during a currency reload.

Populated profile verified physically: COP Home balance 20,017,400 and monthly income/expense 4,130,000/679,300; USD stock 1,480.25 and flow 475/63.50. These are synthetic ledger results, never exchange-converted. USD analysis preserves scope. Camera guide reopened twice; permission revocation/recovery was checked in verification package and permission restored. Final Android settings match initial values.

Official configuration source: [Codex subagents](https://learn.chatgpt.com/docs/agent-configuration/subagents). Native API source: [Android SpeechRecognizer](https://developer.android.com/reference/android/speech/SpeechRecognizer).

## Final device-driven regressions

The populated USD screen exposed a disagreement: Home showed 151.42 while Análisis displayed 147.84 despite explaining the 63.50 / 13 × 31 formula. Current-month Análisis now reuses HomeFinancialMetrics and its completeness/coverage/minimum-days gates instead of a differently defined backend estimate. Elapsed days and cutoff labels use the selected local calendar window. A widget regression supplies conflicting backend days/projection and verifies the local result.

Audit found voided entries counted in existing totals/series/category breakdown even though Home metrics excluded them. Both paginated comparison windows now exclude them before aggregation, and each chart granularity and category breakdown has matching guards. Provider, pure-series and widget tests cover confirmed plus voided movements. Category aggregation also excludes non-negative movements.

Riverpod retains previous values while loading a new period. Totals are now accepted only when their calendar window matches the selected range; same-range refresh can retain valid data. A deferred-Future regression confirms that September values disappear during a pending annual reload. Home checks its current month similarly, and unavailable local totals cannot be displayed as zero merely because the summary endpoint completed.

Synthetic seed rerun produced an identical checkpoint (no duplicate entries). Final selector is independently discoverable by Android accessibility as Seleccionar moneda; USD persists into Análisis. Screenshots and APK checksum proofs remain in ignored build/sol-evidence. CI results are available on PR #34; per-run links/results are updated in its description after the final source push.

Final source correction: dcab32043a499d81e0f7e18c56b5fd7c22157139. Both installed APKs were pulled back and their SHA-256 matched the delivery artifacts:

- 6309d24e2df84a448054f5cc8d75400fde3f44327c26711a4da20890772ea63e — main-delivery.apk
- 41e5787e6c26d8283c99893dc94b829dc3e2571cc5cba9241c144a9ff996407a — verification-delivery.apk

Physical USD Análisis now displays 151.42, agreeing with Inicio and its visible 63.50 / 13 × 31 formula. Earlier probe assertions were taken before the navigation frame settled; a fresh UI dump and inspected screenshot verified the final screen.
