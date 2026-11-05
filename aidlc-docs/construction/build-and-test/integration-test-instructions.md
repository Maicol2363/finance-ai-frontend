# Device and integration verification

Device: Redmi 23021RAAEG, Android 13/API 33, serial 6d3dd54, America/Bogota. Separate package: com.nullcorvus.finance_ai.voice_verification. Existing audio_test signing key is different; that installation was not changed.

Native compatibility assets are public Vosk fixtures only, under ignored build/voice-verification/assets. Download official pinned Spanish/English model archives and Vosk test.wav. Verify the hashes recorded in docs/offline-voice-capture.md before use; assets belong in the instrumentation APK only.

```bash
cd android
JAVA_HOME=/home/d3ad/.sdkman/candidates/java/21.0.6-tem ./gradlew :app:assembleDebugAndroidTest -PfinanceAiVoiceVerification=true
adb -s 6d3dd54 install -r ../build/app/outputs/apk/androidTest/debug/app-debug-androidTest.apk
adb -s 6d3dd54 shell am instrument -w com.nullcorvus.finance_ai.voice_verification.test/androidx.test.runner.AndroidJUnitRunner
```

Five assertions passed on the phone, including prepare-before-subscription replay. These tests load pinned models/decode a public WAV and do not prove microphone recognition. Independent microphone evidence was obtained on the phone; the user explicitly confirmed "ya funciona pasa atexto ya probe". Visible words, pause/edit/continue and a real API proposal requiring explicit confirmation were inspected. No Confirmar y guardar action was executed by Sol.

Android Back: seven focused widget cases passed, covering four secondary roots and three direct form deep links. The latter three initially failed; listening to routerDelegate fixes the stale canPop after the child route is popped. Physical Ajustes -> Cuentas -> detail -> Back -> list -> Back -> Ajustes -> Back -> Inicio succeeded.

Use tool/sol_device_probe.py for locating current controls; it does not print editor values. UI dumps/screenshots remain local in ignored build/sol-evidence. Reopening camera help twice succeeded; camera preview, gallery/flash/shutter positioning remained visible. A photographed real receipt was not submitted to the API.

# Release-only Flutter UI journeys

The Android UI journeys run from `.github/workflows/release-android-integration.yml` for a same-repository PR from `develop` to `main`. A manual run accepts a backend branch/tag/commit input (default `main`). The workflow logs the resolved backend commit, starts the disposable backend/PostgreSQL Compose stack, and tears down the database volume afterward. Provider API keys are blank.

With an Android emulator and the matching backend Compose stack already ready, run from the Flutter project root:

```bash
flutter test integration_test/register_flow_test.dart \
  --dart-define=RUN_REAL_AUTH_FLOW_TEST=true \
  --dart-define=FINANCE_AI_API_BASE_URL=http://10.0.2.2:8000
flutter test integration_test/release_financial_journeys_test.dart \
  --dart-define=RUN_REAL_FINANCIAL_JOURNEYS=true \
  --dart-define=FINANCE_AI_API_BASE_URL=http://10.0.2.2:8000
```

The Android emulator reaches the host's local API through `10.0.2.2`. These are real UI/API integration tests, not part of the everyday PR unit/widget test and coverage command. Test A covers registration, login, process restart/session restore, logout and protected-route denial. Test B creates a 100,000 COP account, records a 20,000 COP manual expense, checks transaction history and confirms 80,000 COP on dashboard/accounts. Test C transfers 30,000 COP between accounts initialized at 100,000 and 10,000 COP, confirms 70,000 and 40,000 COP, checks the history entry once and verifies balances after tab navigation. API replay/idempotency is covered by the backend integration suite.
