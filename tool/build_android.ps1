param([string]$ApiBaseUrl = "", [switch]$AudioTest)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "FlutterWorkspace.ps1")

$frontendRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$workspace = Enter-FlutterWorkspace -FrontendRoot $frontendRoot

try {
    Push-Location $workspace.FrontendRoot
    try {
        & $workspace.Flutter pub get --enforce-lockfile
        if ($LASTEXITCODE -ne 0) {
            throw "[FLUTTER_DEPENDENCY_FAILURE] Locked Flutter dependencies could not be restored (exit $LASTEXITCODE)."
        }
        $phoneBuildArguments = @("build", "apk", "--debug",
            "--android-project-arg=financeAiAudioTest=$($AudioTest.IsPresent.ToString().ToLowerInvariant())",
            "--android-project-arg=financeAiVoiceVerification=false")
        if (-not [string]::IsNullOrWhiteSpace($ApiBaseUrl)) {
            $phoneBuildArguments += "--dart-define=FINANCE_AI_API_BASE_URL=$ApiBaseUrl"
        }
        & $workspace.Flutter @phoneBuildArguments
        if ($LASTEXITCODE -ne 0) {
            throw "[ANDROID_BUILD_FAILURE] The Finance AI debug APK could not be built (exit $LASTEXITCODE)."
        }
        $phoneMetadata = Get-Content -LiteralPath "build/app/outputs/apk/debug/output-metadata.json" -Raw | ConvertFrom-Json
        $expectedPhonePackage = if ($AudioTest) { "com.nullcorvus.finance_ai.audio_test" } else { "com.nullcorvus.finance_ai" }
        if ($phoneMetadata.applicationId -ne $expectedPhonePackage) {
            throw "[ANDROID_IDENTITY_FAILURE] The APK package does not match the requested build."
        }
        if ($AudioTest) {
            Copy-Item -LiteralPath "build/app/outputs/flutter-apk/app-debug.apk" -Destination "build/app/outputs/flutter-apk/finance-ai-audio-test.apk" -Force
        }
    }
    finally {
        Pop-Location
    }
}
finally {
    Exit-FlutterWorkspace -Workspace $workspace
}

Write-Host "[ANDROID_APP_READY] The shared Finance AI debug APK is ready."
