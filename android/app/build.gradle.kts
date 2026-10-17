plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.nullcorvus.finance_ai"
    compileSdk {
        version = release(37) {
            minorApiLevel = 0
        }
    }
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.nullcorvus.finance_ai"
        val audioTest = project.findProperty("financeAiAudioTest") == "true"
        val voiceVerification = project.findProperty("financeAiVoiceVerification") == "true"
        if (voiceVerification) applicationId = "com.nullcorvus.finance_ai.voice_verification"
        else if (audioTest) applicationId = "com.nullcorvus.finance_ai.audio_test"
        manifestPlaceholders["financeAiAppLabel"] = if (voiceVerification) "Finance AI (voice verification)"
            else if (audioTest) "Finance AI (audio test)" else "Finance AI"
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Signs with debug key so release APK can be installed directly on devices without custom keystore
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

android.sourceSets.getByName("androidTest").assets.srcDir("../../build/voice-verification/assets")

dependencies {
    implementation("com.alphacephei:vosk-android:0.3.75@aar")
    implementation("net.java.dev.jna:jna:5.18.1@aar")
    testImplementation("junit:junit:4.13.2")
    // Keep Flutter integration_test's debug runtime consistent with this
    // instrumentation suite and Android's current permission requirements.
    debugImplementation("androidx.test:runner:1.7.0")
    androidTestImplementation("androidx.test:runner:1.7.0")
    androidTestImplementation("androidx.test.ext:junit:1.3.0")
}
