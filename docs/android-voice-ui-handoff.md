# Android voice and UI checkpoint

Checkpoint date: 2026-10-12. Frontend branch: `feat/offline-voice-capture`.
This checkpoint captures the voice reliability work and navigation fixes before
the next UI change. Detailed engine behavior, model provenance and safe diagnostics
are in [Local voice input](offline-voice-capture.md).

UI follow-up: the current app uses the agreed Anchored Composer. One tap starts
dictation in the existing message field; Pause/Continue and immediate Delete sit
above it. Focusing the field stops capture for editing, and Send explicitly
creates a proposal. The hold/drag steps below describe the earlier reliability
checkpoint, rather than the current interaction. The shared speech controller,
native engines, model setup, safe diagnostics and financial flow are unchanged.

## Installed build

| Item | Checkpoint value |
| --- | --- |
| App label | Finance AI (audio test) |
| Package | `com.nullcorvus.finance_ai.audio_test` |
| App version | `0.1.0+1` |
| Phone | Samsung A55, SM-A556E, Android 16 |
| Artifact | `build/app/outputs/flutter-apk/finance-ai-audio-test.apk` |
| APK SHA-256 | `BD73066EE539F7273065CDF23544702889CC71C24276E26DC8673B2D370B2213` |
| API configured in this APK | `http://127.0.0.1:8000`, forwarded over USB |

The verified APK was installed with `adb install -r` and opened successfully on
the connected phone. Existing audio-test app data was preserved. The original
`com.nullcorvus.finance_ai` app remains a separate installation: its signing key
differs from the current development key. Continue using the audio-test package
for updates to this test installation.

APKs, model archives, public audio fixtures, coverage output and device-test logs
are generated artifacts under ignored directories. Source, tests, notices and
this handoff belong in Git; the APK is reproducible with the build helper.

## Scope and implemented behavior

- Keep a working Android on-device recognizer on API 31+; support enumeration is
  advisory and has a 1.5-second limit. A stalled opening has a six-second limit
  before attempting the integrated offline recognizer.
- Offer app-managed Vosk models on the app's Android API 24+ baseline when the
  phone service or language cannot work. Spanish and English each need an explicit
  one-time download of about 40 MB. Verified models stay in private no-backup
  storage; downloads report actual progress and can be cancelled.
- Treat empty/unrecognized utterances as retryable. Preserve visible words for
  editing, and avoid declaring Spanish unsupported after a temporary failure.
- Link microphone permission failures to this app's permissions. Assistant and
  keyboard settings are not recovery steps for the integrated recognizer.
- Reserve the system bottom inset for Android buttons and gestures. Use one
  composer microphone; the `+` menu contains photo, text and manual capture.
- Clear the microphone gesture/edit target after failures. Bound and scroll voice
  setup/error panels on smaller screens and with an open keyboard or larger text.

Offline applies to transcription after model setup. Registration, login, session
restoration and financial reads/writes still use the API. The user explicitly
declined implementing full offline app operation in this session. Server AI
proposal configuration was also excluded from this work. Neither the backend
contract nor its business rules were changed.

## Testing the current phone build

1. Keep the computer and Docker Desktop running. The existing local services at
   this checkpoint are `finance-ai-database-1` and `finance-ai-api-1`, in Compose
   project `finance-ai`, using the existing database volume. Docker Desktop
   restarting brought both services back; readiness returned HTTP 200.
2. Keep the phone connected with USB debugging authorized. The current test
   serial is `RZCX81YTSJE`. Restore forwarding after a reconnect:

   ```powershell
   adb -s RZCX81YTSJE reverse tcp:8000 tcp:8000
   adb -s RZCX81YTSJE reverse --list
   Invoke-RestMethod http://127.0.0.1:8000/health/ready
   ```

3. Open **Finance AI (audio test)**, register or log in, and open **Gastos**.
   Hold the composer microphone, wait for **Escuchando**, then speak. Drag upward
   into the edit target to review the transcript without calling AI. Releasing
   normally accepts the transcript through the existing text proposal flow.

The phone's USB API path was also checked with a temporary ADB forward into the
phone's reversed port: HTTP 200 with `status: ready`. That temporary probe was
removed; normal USB reverse remains configured.

The reported `network_unavailable` / `register_account` / `connection_failure`
occurred while Docker and the local API were stopped. Restarting those existing
services restored readiness. If registration fails again, first check Docker,
`/health/ready`, the USB device and reverse mapping; retain the safe copied error
report if those checks pass. Avoid replacing the existing database with a fresh
Compose project when restoring this test environment.

This APK's loopback URL needs USB forwarding to reach the computer. Testing over
Wi-Fi or a hosted API requires building with that server's reachable URL.

## Cable-free testing

On 2026-10-13, the Anchored Composer audio-test APK was rebuilt with the
computer's current Wi-Fi API address. The existing Docker services were restarted,
and readiness was verified from both the computer and the phone over Wi-Fi.
This changes the build configuration; authentication and capture logic are unchanged.

Keep the computer awake, Docker running, and both devices on the same Wi-Fi.
Use the computer's Wi-Fi IPv4 address from `ipconfig` when building:

```powershell
$wifiApiBaseUrl = 'http://<computer-wifi-ip>:8000'
.\tool\build_android.ps1 -AudioTest -ApiBaseUrl $wifiApiBaseUrl
```

Check `http://<computer-wifi-ip>:8000/health/ready` in the phone's browser before
installing the update. The expected response is `{"status":"ready"}`. Update the
existing **Finance AI (audio test)** installation to preserve its app data.
USB forwarding is unnecessary for this build. If the computer's address changes,
rebuild with the new address.

Login, session restoration and financial operations still require the API.
Transcription can work offline after model setup. If session restoration reports
a connection failure, restore connectivity and use **Retry restoration**; that
failure preserves the saved renewable credential. The current router sends users
to the recovery screen when renewal fails, which can feel like a logout.
The authentication flow was inspected but not modified as part of this UI work.

## Reproducing verification and the APK

Run the helpers from the frontend repository:

```powershell
.\tool\verify_shared.ps1
.\tool\verify_android_voice.ps1 -UnitOnly
.\tool\verify_android_voice.ps1 -DeviceId RZCX81YTSJE
.\tool\build_android.ps1 -AudioTest -ApiBaseUrl http://127.0.0.1:8000
adb -s RZCX81YTSJE install -r build/app/outputs/flutter-apk/finance-ai-audio-test.apk
adb -s RZCX81YTSJE reverse tcp:8000 tcp:8000
```

Device verification uses disposable `.voice_verification` and
`.voice_verification.test` packages. It removes only those test fixtures, leaves
the audio-test app and its data intact, never opens a microphone, and never calls
the finance API. Its public fixture assets are packaged only in the test APK.
Build the audio-test APK after device verification, since both commands use the
shared debug output directory. The helpers pass package properties explicitly
and check output package identities to avoid accidentally installing the main
app or a verification fixture as the audio-test update.

| Verification at this checkpoint | Result |
| --- | --- |
| Shared Flutter tests | 460 passed |
| Flutter line coverage | 83.77%, above the required 80% |
| Dart formatting and static analysis | Passed |
| Native model-store JVM tests | 5 passed; integrity, containment, cancellation and installation |
| Native compatibility on the A55 | 4 passed; both models load, public English WAV decodes, missing-service setup/ready paths, early release without mic activation |
| Android debug build and signature | Passed; audio-test identity verified |
| Native 64-bit ELF and APK ZIP alignment | Passed for 16 KB pages |
| Public model/audio test fixtures in product APK | None |
| Phone installation and launch | Succeeded |
| Phone USB API readiness | HTTP 200, ready |

The shared Flutter and native Android checks cover the current changes. Native
Windows recognition was unchanged in this checkpoint; its previously recorded
smoke results remain in the voice document. This checkpoint does not establish
live speech accuracy or latency. The older phone and Xiaomi need real utterance
tests, including Colombian amounts, merchant names, permissions, missing models,
pauses and rapid stop/restart.

## Contracts to preserve during UI changes

| Area | Behavior and regression coverage |
| --- | --- |
| Bottom navigation | Keep `SafeArea` system-inset spacing in portrait/landscape and for buttons/gestures; `test/core/widgets/app_bottom_nav_test.dart` |
| Capture menu | Keep one voice entry point in the composer; photo/text/manual remain accessible; `test/features/text_capture/presentation/text_capture_chat_test.dart` |
| Composer interaction and layout | One persistent message field, tap capture, anchored pause/resume, immediate discard, explicit send, keyboard access, recovery and small displays with larger text; `test/features/voice_capture/voice_chat_test.dart` |
| Capture state | One accepted submission per session, draft prefix, replacement hypotheses, late-event rejection, retry, timeouts, download cancellation/completion and resume without auto-start; `test/features/voice_capture/voice_capture_controller_test.dart` |
| Native events and diagnostics | Allowlisted codes/reasons/engine/API metadata and bounded progress; never copy transcripts, entered values, credentials or raw native errors; `test/features/voice_capture/native_speech_service_test.dart` |

Keep the shared Dart voice controller as the owner of recognition state and
submission. Android and Windows tap/pause/edit/resume use that same feature
code. Download completion and returning from settings must not start a mic or
submit a draft. Typing stays available during model setup; financial operations
continue through the existing validated repositories and confirmation flow.
