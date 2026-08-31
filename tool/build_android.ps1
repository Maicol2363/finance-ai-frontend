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
        & $workspace.Flutter build apk --debug
        if ($LASTEXITCODE -ne 0) {
            throw "[ANDROID_BUILD_FAILURE] The Finance AI debug APK could not be built (exit $LASTEXITCODE)."
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
