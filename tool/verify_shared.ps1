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
        & $workspace.Dart format --output=none --set-exit-if-changed lib test integration_test
        if ($LASTEXITCODE -ne 0) {
            throw "[FLUTTER_FORMAT_FAILURE] Dart formatting is not current (exit $LASTEXITCODE)."
        }
        & $workspace.Flutter analyze
        if ($LASTEXITCODE -ne 0) {
            throw "[FLUTTER_ANALYZE_FAILURE] Flutter analysis failed (exit $LASTEXITCODE)."
        }
        & $workspace.Flutter test --coverage
        if ($LASTEXITCODE -ne 0) {
            throw "[FLUTTER_TEST_FAILURE] Shared Flutter tests failed (exit $LASTEXITCODE)."
        }

        $found = 0
        $hit = 0
        foreach ($line in Get-Content -LiteralPath ".\coverage\lcov.info") {
            if ($line.StartsWith("LF:")) {
                $found += [int]$line.Substring(3)
            }
            elseif ($line.StartsWith("LH:")) {
                $hit += [int]$line.Substring(3)
            }
        }
        $coverage = if ($found -eq 0) { 0 } else { 100 * $hit / $found }
        Write-Host ("Flutter line coverage: {0:N2}%" -f $coverage)
        if ($coverage -lt 80) {
            throw "[FLUTTER_COVERAGE_FAILURE] Flutter line coverage is below 80%."
        }
    }
    finally {
        Pop-Location
    }
}
finally {
    Exit-FlutterWorkspace -Workspace $workspace
}

Write-Host "[FLUTTER_SHARED_OK] Formatting, analysis, tests, and coverage passed."
