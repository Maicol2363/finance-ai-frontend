$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "FlutterWorkspace.ps1")

$frontendRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$workspace = Enter-FlutterWorkspace -FrontendRoot $frontendRoot
$testExitCode = 0
$buildExitCode = 0

try {
    Push-Location $workspace.FrontendRoot
    try {
        # Windows CMake caches absolute source paths. Regenerate them after
        # entering the temporary no-space alias so native plugins use one path.
        & $workspace.Flutter clean
        if ($LASTEXITCODE -ne 0) {
            $testExitCode = $LASTEXITCODE
        }
        else {
            & $workspace.Flutter pub get --enforce-lockfile
            if ($LASTEXITCODE -ne 0) {
                $testExitCode = $LASTEXITCODE
            }
            else {
                & $workspace.Flutter test -d windows integration_test\windows_smoke_test.dart
                $testExitCode = $LASTEXITCODE
            }
        }
    }
    finally {
        Write-Host "Restoring the normal Finance AI Windows application bundle from a clean cache..."
        & $workspace.Flutter clean
        $buildExitCode = $LASTEXITCODE
        if ($buildExitCode -eq 0) {
            & $workspace.Flutter pub get --enforce-lockfile
            $buildExitCode = $LASTEXITCODE
        }
        if ($buildExitCode -eq 0) {
            & $workspace.Flutter build windows --debug
            $buildExitCode = $LASTEXITCODE
        }
        Pop-Location
    }
}
finally {
    Exit-FlutterWorkspace -Workspace $workspace
}

if ($buildExitCode -ne 0) {
    throw "[WINDOWS_APP_RESTORE_FAILED] The normal Windows application bundle could not be restored (exit $buildExitCode)."
}
if ($testExitCode -ne 0) {
    throw "[WINDOWS_SMOKE_FAILED] The Windows smoke test failed (exit $testExitCode); the normal application bundle was restored."
}

Write-Host "[WINDOWS_APP_READY] Windows smoke tests passed and the normal Finance AI application bundle is ready."
