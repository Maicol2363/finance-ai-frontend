param([switch]$UnitOnly, [switch]$AudioTest, [string]$DeviceId = "", [string]$ApiBaseUrl = "")

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "FlutterWorkspace.ps1")
$frontendRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path

if (-not $UnitOnly) {
    if ([string]::IsNullOrWhiteSpace($DeviceId)) {
        throw "[ANDROID_VOICE_DEVICE_REQUIRED] Pass the authorized phone's ADB serial as DeviceId."
    }
    $fixtureRoot = Join-Path $frontendRoot "build\voice-verification\assets"
    New-Item -ItemType Directory -Path $fixtureRoot -Force | Out-Null
    $fixtures = @(
        @{ Name = "vosk-model-small-es-0.42.zip"; Url = "https://alphacephei.com/vosk/models/vosk-model-small-es-0.42.zip"; Hash = "09b239888f633ef2f0b4e09736e3d9936acfd810bc65d53fad45261762c6511f" },
        @{ Name = "vosk-model-small-en-us-0.15.zip"; Url = "https://alphacephei.com/vosk/models/vosk-model-small-en-us-0.15.zip"; Hash = "30f26242c4eb449f948e42cb302dd7a686cb29a3423a8367f99ff41780942498" },
        @{ Name = "test.wav"; Url = "https://raw.githubusercontent.com/alphacep/vosk-api/master/python/example/test.wav"; Hash = "dcfea5712c43a43ba7ae8083afb39d36993e5a69c46e88b68aaa72b65cb615bb" }
    )
    foreach ($fixture in $fixtures) {
        $fixturePath = Join-Path $fixtureRoot $fixture.Name
        if (-not (Test-Path -LiteralPath $fixturePath) -or
            (Get-FileHash -LiteralPath $fixturePath -Algorithm SHA256).Hash.ToLowerInvariant() -ne $fixture.Hash) {
            Invoke-WebRequest -Uri $fixture.Url -OutFile $fixturePath -TimeoutSec 180
        }
        if ((Get-FileHash -LiteralPath $fixturePath -Algorithm SHA256).Hash.ToLowerInvariant() -ne $fixture.Hash) {
            throw "[ANDROID_VOICE_FIXTURE_INTEGRITY] Public fixture checksum verification failed."
        }
    }
}

$workspace = Enter-FlutterWorkspace -FrontendRoot $frontendRoot
$previousJavaHome = $env:JAVA_HOME
$previousDeviceId = $env:ANDROID_SERIAL
try {
    $flutterConfiguration = & $workspace.Flutter config --list
    $configuredJava = $flutterConfiguration | Where-Object { $_ -match '^\s*jdk-dir:\s+(.+)$' } | Select-Object -First 1
    if ($configuredJava -match '^\s*jdk-dir:\s+(.+)$') { $env:JAVA_HOME = $Matches[1].Trim() }
    if ([string]::IsNullOrWhiteSpace($env:JAVA_HOME) -or
        -not (Test-Path -LiteralPath (Join-Path $env:JAVA_HOME "bin\java.exe"))) {
        throw "[ANDROID_VOICE_JDK_UNAVAILABLE] Configure Flutter's JDK or JAVA_HOME first."
    }
    if (-not $UnitOnly) { $env:ANDROID_SERIAL = $DeviceId }
    Push-Location (Join-Path $workspace.FrontendRoot "android")
    try {
        $voiceGradleArguments = @("--console=plain", ":app:testDebugUnitTest",
            "-PfinanceAiAudioTest=$($AudioTest.IsPresent.ToString().ToLowerInvariant())",
            "-PfinanceAiVoiceVerification=$((-not $UnitOnly.IsPresent).ToString().ToLowerInvariant())")
        if (-not $UnitOnly) { $voiceGradleArguments += @(":app:assembleDebug", ":app:assembleDebugAndroidTest") }
        if (-not [string]::IsNullOrWhiteSpace($ApiBaseUrl)) {
            $encodedApiDefine = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("FINANCE_AI_API_BASE_URL=$ApiBaseUrl"))
            $voiceGradleArguments += "-Pdart-defines=$encodedApiDefine"
        }
        & .\gradlew.bat @voiceGradleArguments
        if ($LASTEXITCODE -ne 0) { throw "[ANDROID_VOICE_VERIFICATION_FAILURE] Native Android voice checks failed." }
        if (-not $UnitOnly) {
            $sdkLine = $flutterConfiguration | Where-Object { $_ -match '^\s*android-sdk:\s+(.+)$' } | Select-Object -First 1
            if (-not ($sdkLine -match '^\s*android-sdk:\s+(.+)$')) { throw "[ANDROID_VOICE_ADB_UNAVAILABLE] Configure Flutter's Android SDK first." }
            $voiceAdb = Join-Path $Matches[1].Trim() "platform-tools\adb.exe"
            $voiceTargetApk = Join-Path $frontendRoot "build\app\outputs\apk\debug\app-debug.apk"
            $voiceInstrumentationApk = Join-Path $frontendRoot "build\app\outputs\apk\androidTest\debug\app-debug-androidTest.apk"
            $voiceTargetMetadata = Get-Content -LiteralPath (Join-Path (Split-Path -Parent $voiceTargetApk) "output-metadata.json") -Raw | ConvertFrom-Json
            $voiceTestMetadata = Get-Content -LiteralPath (Join-Path (Split-Path -Parent $voiceInstrumentationApk) "output-metadata.json") -Raw | ConvertFrom-Json
            if ($voiceTargetMetadata.applicationId -ne "com.nullcorvus.finance_ai.voice_verification" -or
                $voiceTestMetadata.applicationId -ne "com.nullcorvus.finance_ai.voice_verification.test") {
                throw "[ANDROID_VOICE_IDENTITY_FAILURE] Verification must use the isolated fixture packages."
            }
            try {
                & $voiceAdb -s $DeviceId install -r $voiceTargetApk
                if ($LASTEXITCODE -ne 0) { throw "[ANDROID_VOICE_TARGET_INSTALL_FAILURE] Could not install the isolated verification target." }
                & $voiceAdb -s $DeviceId install -r $voiceInstrumentationApk
                if ($LASTEXITCODE -ne 0) { throw "[ANDROID_VOICE_TEST_INSTALL_FAILURE] Could not install the native test fixture." }
                $instrumentationOutput = & $voiceAdb -s $DeviceId shell am instrument -w -r "com.nullcorvus.finance_ai.voice_verification.test/androidx.test.runner.AndroidJUnitRunner"
                $instrumentationExit = $LASTEXITCODE
                $instrumentationOutput | Set-Content -LiteralPath (Join-Path $frontendRoot "build\voice-verification\device-results.txt") -Encoding UTF8
                $instrumentationOutput | Write-Output
                if ($instrumentationExit -ne 0 -or ($instrumentationOutput -join "`n") -notmatch 'OK \([0-9]+ tests?\)') {
                    throw "[ANDROID_VOICE_DEVICE_FAILURE] Native phone assertions failed."
                }
            } finally {
                # These namespaces are reserved for this disposable test fixture.
                foreach ($voiceTestPackage in @("com.nullcorvus.finance_ai.voice_verification.test", "com.nullcorvus.finance_ai.voice_verification")) {
                    $installedFixture = & $voiceAdb -s $DeviceId shell pm path $voiceTestPackage
                    if ($installedFixture -match '^package:') { & $voiceAdb -s $DeviceId uninstall $voiceTestPackage }
                }
            }
        }
    } finally { Pop-Location }
} finally {
    $env:JAVA_HOME = $previousJavaHome
    $env:ANDROID_SERIAL = $previousDeviceId
    Exit-FlutterWorkspace -Workspace $workspace
}
Write-Host "[ANDROID_VOICE_OK] Native model and compatibility verification passed."
