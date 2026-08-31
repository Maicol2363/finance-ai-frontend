$ErrorActionPreference = "Stop"

function Enter-FlutterWorkspace {
    param([Parameter(Mandatory = $true)][string]$FrontendRoot)

    $resolvedFrontend = (Resolve-Path -LiteralPath $FrontendRoot).Path
    $repositoryRoot = (Resolve-Path -LiteralPath (Join-Path $resolvedFrontend "..")).Path
    $flutterRelativePath = ".tools\flutter\bin\flutter.bat"
    $dartRelativePath = ".tools\flutter\bin\dart.bat"
    $localPropertiesPath = Join-Path $resolvedFrontend "android\local.properties"
    $hadLocalProperties = Test-Path -LiteralPath $localPropertiesPath
    $originalLocalProperties = if ($hadLocalProperties) {
        [System.IO.File]::ReadAllText($localPropertiesPath)
    }
    else {
        $null
    }

    if ($repositoryRoot -notmatch "\s") {
        return [pscustomobject]@{
            FrontendRoot = $resolvedFrontend
            Flutter = (Resolve-Path -LiteralPath (Join-Path $repositoryRoot $flutterRelativePath)).Path
            Dart = (Resolve-Path -LiteralPath (Join-Path $repositoryRoot $dartRelativePath)).Path
            AliasDrive = $null
            LocalPropertiesPath = $localPropertiesPath
            HadLocalProperties = $hadLocalProperties
            OriginalLocalProperties = $originalLocalProperties
        }
    }

    $usedDrives = @(Get-PSDrive -PSProvider FileSystem | ForEach-Object { $_.Name.ToUpperInvariant() })
    $cachedDriveLetter = $null
    $cmakeCachePath = Join-Path $resolvedFrontend "build\windows\x64\CMakeCache.txt"
    if (Test-Path -LiteralPath $cmakeCachePath) {
        $cachedHomeLine = Get-Content -LiteralPath $cmakeCachePath |
            Where-Object { $_ -match '^CMAKE_HOME_DIRECTORY:INTERNAL=([Q-Z]):/frontend/windows$' } |
            Select-Object -First 1
        if ($null -ne $cachedHomeLine -and
            $cachedHomeLine -match '^CMAKE_HOME_DIRECTORY:INTERNAL=([Q-Z]):/frontend/windows$') {
            $cachedDriveLetter = $Matches[1].ToUpperInvariant()
        }
    }

    $candidateDrives = @()
    if ($null -ne $cachedDriveLetter -and $cachedDriveLetter -notin $usedDrives) {
        $candidateDrives += $cachedDriveLetter
    }
    $candidateDrives += @("Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z") |
        Where-Object { $_ -ne $cachedDriveLetter }

    $driveLetter = $candidateDrives |
        Where-Object { $_ -notin $usedDrives } |
        Select-Object -First 1
    if ($null -eq $driveLetter) {
        throw "[FLUTTER_PATH_ALIAS_UNAVAILABLE] No temporary drive letter is available for the space-safe Flutter workspace alias."
    }

    & subst.exe "${driveLetter}:" $repositoryRoot
    if ($LASTEXITCODE -ne 0) {
        throw "[FLUTTER_PATH_ALIAS_FAILED] The temporary Flutter workspace alias could not be created."
    }

    return [pscustomobject]@{
        FrontendRoot = "${driveLetter}:\frontend"
        Flutter = "${driveLetter}:\$flutterRelativePath"
        Dart = "${driveLetter}:\$dartRelativePath"
        AliasDrive = $driveLetter
        LocalPropertiesPath = $localPropertiesPath
        HadLocalProperties = $hadLocalProperties
        OriginalLocalProperties = $originalLocalProperties
    }
}

function Exit-FlutterWorkspace {
    param([Parameter(Mandatory = $true)]$Workspace)

    if ($null -ne $Workspace.AliasDrive) {
        $aliasName = "$($Workspace.AliasDrive):"
        & subst.exe $aliasName /D
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "[FLUTTER_PATH_ALIAS_CLEANUP_FAILED] The temporary drive alias could not be removed."
        }
    }

    if ($Workspace.HadLocalProperties) {
        [System.IO.File]::WriteAllText(
            $Workspace.LocalPropertiesPath,
            $Workspace.OriginalLocalProperties,
            [System.Text.UTF8Encoding]::new($false)
        )
    }
    elseif (Test-Path -LiteralPath $Workspace.LocalPropertiesPath) {
        Remove-Item -LiteralPath $Workspace.LocalPropertiesPath -Force
    }
}
