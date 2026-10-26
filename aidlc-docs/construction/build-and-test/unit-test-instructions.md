# Shared and native unit verification

```bash
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze
flutter test --coverage --reporter expanded
```

Final result: 539 shared tests passed; line coverage 11493/13549 = 84.83%. Baseline on origin/develop and its CI: 501 passed/11 failed. Nine Spanish diagnostic expectations, semantic heading and undersized/duplicated selector semantics were repaired in production. Assertions that formerly expected English labels were updated to the specified Spanish UI; diagnostic report wire fields remain unchanged.

JVM checks:

```bash
cd android
JAVA_HOME=/home/d3ad/.sdkman/candidates/java/21.0.6-tem ./gradlew :app:testDebugUnitTest
```

Five model-store JVM tests passed. Native Windows builds/tests require Windows and were not executed on this Linux host; no Windows-native implementation changed.
