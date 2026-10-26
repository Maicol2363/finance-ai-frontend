# Android build reproduction

Prerequisites: Flutter 3.47.5 / Dart 3.13.4, Android SDK 37, Gradle 9.3.1, Java 21. Shell Java 26 failed the androidJdkImage transform; use Java 21 for direct Gradle commands. Restore locked packages with `flutter pub get --enforce-lockfile`.

Main package retains its original Cloud Run endpoint:

```bash
flutter build apk --debug --split-per-abi --target-platform android-arm64 --android-project-arg=financeAiAudioTest=false --android-project-arg=financeAiVoiceVerification=false --dart-define=FINANCE_AI_API_BASE_URL=https://finance-api-7caahuohmq-rj.a.run.app
```

Before installation, inspect package/version with aapt and compare the APK and installed certificate with apksigner. The main package certificate matches the Linux development key; audio_test does not. Do not uninstall or replace an incompatible package.

Use the independent verification package for local synthetic accounts:

```bash
flutter build apk --debug --target-platform android-arm64 --android-project-arg=financeAiAudioTest=false --android-project-arg=financeAiVoiceVerification=true --dart-define=FINANCE_AI_API_BASE_URL=http://127.0.0.1:8000
adb -s 6d3dd54 reverse tcp:8000 tcp:8000
```

Never change a saved installation's API endpoint while assuming its credentials remain valid. The initial main-package USB build did this and caused session invalidation. The final main APK restores Cloud Run; manual sign-in is required. Financial records were not modified by this error.
