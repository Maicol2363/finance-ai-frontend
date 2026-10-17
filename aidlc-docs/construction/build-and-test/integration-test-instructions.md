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
