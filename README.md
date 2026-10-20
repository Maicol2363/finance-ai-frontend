# Finance AI Flutter Client

Shared Android and Windows Flutter client for the manual-first Finance AI application. The current slices support registration, Login, secure session restoration, protected Home, Logout, owned financial-account management, manual expense tracking, and personalized budgets with derived progress. Budgets may cover all expenses or one category, use an optional custom name, and run daily, weekly, fortnightly, monthly, quarterly, yearly, every custom number of days/weeks/months/years, or over a one-time date range. Users can create, list, inspect, edit, deactivate, reactivate, and permanently delete unused Cash, bank, digital-wallet, savings, credit-card, and other accounts with exact server-derived balances. Accounts with financial activity must be deactivated so history remains intact. Financial data stays in the backend; offline data storage and synchronization queues are not implemented. Both targets use the same Dart UI, state, validation, and API client.

## Gastos chat (HU-013)

The Gastos tab opens on a capture chat. The user writes what happened in their own words; the assistant proposes an expense, income or transfer in a compact review card, and the user confirms it in one tap, edits it in place or discards it. Only genuine ambiguity triggers one short question, answered by tapping an option or typing. Corrections keep the original text, failures use the shared copyable diagnostics with Retry, and the manual forms stay one tap away in the composer menu (`+`). Accept sends the final values to the same validated operation as the manual forms. The balance and the recent history now live in the Dashboard.

## Local voice input

Local Spanish/English dictation uses the existing Gastos composer microphone and
text-AI proposal flow. Android and Windows use the Anchored Composer: tap the mic,
see words in the existing message field, pause or edit, resume, and explicitly
send. Delete discards dictation immediately. Android retains working phone
recognizers and offers an integrated offline engine on the app's Android 7+
baseline when a phone service is unavailable or fails. Its language models are
explicit one-time downloads of about 40 MB each, with real progress and automatic
readiness checks. Audio stays in memory on the device. See
[voice behavior and device checks](docs/offline-voice-capture.md).

The installed Android build, local test setup, current verification results, and
UI behavior to preserve are recorded in the
[Android voice/UI checkpoint](docs/android-voice-ui-handoff.md).

## Local quality commands

Use Flutter 3.47.2 / Dart 3.13.2 from the repository root:

```powershell
.\tool\verify_shared.ps1
.\tool\build_android.ps1
.\tool\test_windows_and_restore.ps1
```

The helpers create and remove a temporary no-space drive alias when required by Flutter native hooks. They leave `android/local.properties` pointing to the real SDK path. Stable bracketed failure codes can be copied directly when a tooling step fails.

The debug outputs are generated at `build/app/outputs/flutter-apk/app-debug.apk` and `build/windows/x64/runner/Debug/finance_ai.exe`.

Build the separately named phone test app without changing the original app:

```powershell
.\tool\build_android.ps1 -AudioTest -ApiBaseUrl http://127.0.0.1:8000
```

It produces `build/app/outputs/flutter-apk/finance-ai-audio-test.apk`; connect the
phone API over USB with `adb reverse tcp:8000 tcp:8000`. Native voice unit tests use
`tool/verify_android_voice.ps1 -UnitOnly`. Passing `-DeviceId <ADB-serial>` also
runs the public audio/model compatibility fixtures in a separate verification
package, without opening a microphone or using the finance API.

Native Windows integration tests temporarily place their headless test harness in the shared debug output directory. Use `tool/test_windows_and_restore.ps1` instead of invoking the test alone: it verifies registration, Login/Home/Logout, a synthetic account-management flow, safe failure copying, and real Windows secure-storage replacement/deletion, then deletes the test build cache and rebuilds the normal application—even when a test fails. If an older build leaves `finance_ai.exe` running without a window, stop that process and run the helper before opening the executable again. The native runner now detects an incomplete bundle, reports a stable startup error if Flutter cannot render its first frame, and permits only one desktop instance; another launch focuses the existing window.

## API configuration

Registration, login, session restoration, and financial operations require a
reachable API. Offline voice recognition does not remove that requirement. The
phone test build can use USB forwarding or the computer's reachable Wi-Fi/hotspot
address. Keep Docker Desktop and the computer running. For a loopback build,
restore `adb reverse tcp:8000 tcp:8000` after reconnecting the phone. For cable-free
testing, build with `-ApiBaseUrl https://<trusted-api-host>` and use a certificate
trusted by the phone. Remote HTTP endpoints are rejected, including in debug
builds. Check `/health/ready` from the phone first; rebuild if the endpoint
changes. See the
[phone setup instructions](docs/android-voice-ui-handoff.md#cable-free-testing).
Full offline application operation is outside this checkpoint's scope.

Android emulators use `http://10.0.2.2:8000` by default; Windows uses `http://127.0.0.1:8000`. Override the endpoint at build or run time for a physical phone, another PC, or a future intermediary server:

```powershell
.\.tools\flutter\bin\flutter.bat run --dart-define=FINANCE_AI_API_BASE_URL=http://10.0.2.2:8000
.\.tools\flutter\bin\flutter.bat run -d windows --dart-define=FINANCE_AI_API_BASE_URL=https://api.example.com
```

The fully isolated Flutter/API/PostgreSQL test is orchestrated by the sibling `NullCorvus/finance-ai` project repository:

```powershell
Set-Location ..\finance-ai
docker compose --profile integration run --rm flutter-integration
```

The integration image verifies Register → Login → session restoration → Logout against a real internal-only API and the isolated `finance_ai_test` PostgreSQL database. It creates a disposable Linux runner internally, never writes synthetic users to the normal local database, and does not add Linux product support to the Android/Windows application.

## Copyable errors

Registration, Login, restoration, Logout, and financial-account failures display a stable error code and a `Copy error details` action. The copied report contains safe diagnostic context and deliberately excludes email, password, credential, account-name, and balance values. Future client features must use the shared components in `lib/core/diagnostics/`.

The access credential exists only in application memory. Only the rotating renewable credential is stored through `flutter_secure_storage`; Android backups are disabled and Windows uses the native credential store.

The API implementation lives in `Maicol2363/finance-ai-backend`; this client depends only on its versioned OpenAPI contract and configured base URL.
