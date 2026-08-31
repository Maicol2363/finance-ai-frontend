# Finance AI Flutter Client

Shared Android and Windows Flutter client for the manual-first Finance AI application. The current identity slice supports registration, Login, secure session restoration, protected Home, and Logout. Budgeting, synchronization, and AI remain later stories. Both targets use the same Dart UI, state, validation, and API client.

## Local quality commands

Use Flutter 3.47.2 / Dart 3.13.2 from the repository root:

```powershell
Set-Location frontend
.\tool\verify_shared.ps1
.\tool\build_android.ps1
.\tool\test_windows_and_restore.ps1
```

The helpers create and remove a temporary no-space drive alias when required by Flutter native hooks. They leave `android/local.properties` pointing to the real SDK path. Stable bracketed failure codes can be copied directly when a tooling step fails.

The debug outputs are generated at `build/app/outputs/flutter-apk/app-debug.apk` and `build/windows/x64/runner/Debug/finance_ai.exe`.

Native Windows integration tests temporarily place their headless test harness in the shared debug output directory. Use `tool/test_windows_and_restore.ps1` instead of invoking the test alone: it verifies registration, Login/Home/Logout, and real Windows secure-storage replacement/deletion, then deletes the test build cache and rebuilds the normal application—even when a test fails. If an older build leaves `finance_ai.exe` running without a window, stop that process and run the helper before opening the executable again. The native runner now detects an incomplete bundle, reports a stable startup error if Flutter cannot render its first frame, and permits only one desktop instance; another launch focuses the existing window.

## API configuration

Android emulators use `http://10.0.2.2:8000` by default; Windows uses `http://127.0.0.1:8000`. Override the endpoint at build or run time for a physical phone, another PC, or a future intermediary server:

```powershell
..\.tools\flutter\bin\flutter.bat run --dart-define=FINANCE_AI_API_BASE_URL=http://10.0.2.2:8000
..\.tools\flutter\bin\flutter.bat run -d windows --dart-define=FINANCE_AI_API_BASE_URL=https://api.example.com
```

From the repository root, the fully isolated Flutter/API/PostgreSQL test is:

```powershell
docker compose --profile integration run --rm flutter-integration
```

The integration image verifies Register → Login → session restoration → Logout against a real internal-only API and the isolated `finance_ai_test` PostgreSQL database. It creates a disposable Linux runner internally, never writes synthetic users to the normal local database, and does not add Linux product support to the Android/Windows application.

## Copyable errors

Registration, Login, restoration, and Logout failures display a stable error code and a `Copy error details` action. The copied report contains safe diagnostic context and deliberately excludes email, password, and credential values. Future client features must use the shared components in `lib/core/diagnostics/`.

The access credential exists only in application memory. Only the rotating renewable credential is stored through `flutter_secure_storage`; Android backups are disabled and Windows uses the native credential store.
