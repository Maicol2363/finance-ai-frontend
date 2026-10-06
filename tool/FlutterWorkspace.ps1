$ErrorActionPreference = "Stop"

function Get-WorkspaceRelativePath {
    param(
        [Parameter(Mandatory = $true)][string]$BasePath,
        [Parameter(Mandatory = $true)][string]$TargetPath
    )

    $normalizedBase = [System.IO.Path]::GetFullPath($BasePath).TrimEnd("\", "/")
    $normalizedTarget = [System.IO.Path]::GetFullPath($TargetPath)
    $basePrefix = $normalizedBase + [System.IO.Path]::DirectorySeparatorChar

    if ($normalizedTarget.Equals($normalizedBase, [System.StringComparison]::OrdinalIgnoreCase)) {
        return "."
    }
    if (-not $normalizedTarget.StartsWith($basePrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "[FLUTTER_PATH_ALIAS_TARGET_OUTSIDE_ROOT] '$normalizedTarget' is not below '$normalizedBase'."
    }

    return $normalizedTarget.Substring($basePrefix.Length)
}

function Enter-FlutterWorkspace {
    param([Parameter(Mandatory = $true)][string]$FrontendRoot)

    $resolvedFrontend = (Resolve-Path -LiteralPath $FrontendRoot).Path
    $repositoryRoot = $resolvedFrontend
    $flutterRelativePath = ".tools\flutter\bin\flutter.bat"
    $dartRelativePath = ".tools\flutter\bin\dart.bat"
    $localFlutterPath = Join-Path $repositoryRoot $flutterRelativePath
    $localDartPath = Join-Path $repositoryRoot $dartRelativePath
    $usesLocalToolchain = Test-Path -LiteralPath $localFlutterPath
    if ($usesLocalToolchain) {
        $flutterExecutable = (Resolve-Path -LiteralPath $localFlutterPath).Path
        $dartExecutable = (Resolve-Path -LiteralPath $localDartPath).Path
    }
    else {
        $configuredRoot = $env:FINANCE_AI_FLUTTER_ROOT
        $workspaceRoot = Split-Path -Parent $repositoryRoot
        $siblingRoot = Join-Path $workspaceRoot "finance-ai\.tools\flutter"
        $candidateRoot = if (-not [string]::IsNullOrWhiteSpace($configuredRoot)) {
            $configuredRoot
        }
        elseif (Test-Path -LiteralPath (Join-Path $siblingRoot "bin\flutter.bat")) {
            $siblingRoot
        }
        else {
            $null
        }
        if ($null -ne $candidateRoot) {
            $flutterExecutable = (Resolve-Path -LiteralPath (Join-Path $candidateRoot "bin\flutter.bat")).Path
            $dartExecutable = (Resolve-Path -LiteralPath (Join-Path $candidateRoot "bin\dart.bat")).Path
        }
        else {
            $flutterCommand = Get-Command flutter.bat -ErrorAction SilentlyContinue
            $dartCommand = Get-Command dart.bat -ErrorAction SilentlyContinue
            if ($null -eq $flutterCommand -or $null -eq $dartCommand) {
                throw "[FLUTTER_TOOLCHAIN_UNAVAILABLE] Install Flutter 3.47.2, set FINANCE_AI_FLUTTER_ROOT, add Flutter to PATH, or place it under .tools\flutter."
            }
            $flutterExecutable = $flutterCommand.Source
            $dartExecutable = $dartCommand.Source
        }
    }
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
            Flutter = $flutterExecutable
            Dart = $dartExecutable
            AliasDrive = $null
            LocalPropertiesPath = $localPropertiesPath
            HadLocalProperties = $hadLocalProperties
            OriginalLocalProperties = $originalLocalProperties
        }
    }

    $aliasRoot = $repositoryRoot
    if (-not $usesLocalToolchain -and $flutterExecutable -match "\s") {
        $repositoryParent = Split-Path -Parent $repositoryRoot
        $flutterBin = Split-Path -Parent $flutterExecutable
        $flutterSdkRoot = (Resolve-Path -LiteralPath (Join-Path $flutterBin "..")).Path
        $parentPrefix = $repositoryParent.TrimEnd("\") + "\"
        if (-not $flutterSdkRoot.StartsWith($parentPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "[FLUTTER_TOOLCHAIN_PATH_UNSAFE] Install Flutter in a path without spaces or below the repository's parent directory."
        }
        $aliasRoot = $repositoryParent
    }

    $usedDrives = @(Get-PSDrive -PSProvider FileSystem | ForEach-Object { $_.Name.ToUpperInvariant() })
    $cachedDriveLetter = $null
    $cmakeCachePath = Join-Path $resolvedFrontend "build\windows\x64\CMakeCache.txt"
    if (Test-Path -LiteralPath $cmakeCachePath) {
        $cachedHomeLine = Get-Content -LiteralPath $cmakeCachePath |
            Where-Object { $_ -match '^CMAKE_HOME_DIRECTORY:INTERNAL=([Q-Z]):/.*/?windows$' } |
            Select-Object -First 1
        if ($null -ne $cachedHomeLine -and
            $cachedHomeLine -match '^CMAKE_HOME_DIRECTORY:INTERNAL=([Q-Z]):/.*/?windows$') {
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

    & subst.exe "${driveLetter}:" $aliasRoot
    if ($LASTEXITCODE -ne 0) {
        throw "[FLUTTER_PATH_ALIAS_FAILED] The temporary Flutter workspace alias could not be created."
    }

    try {
        $aliasDriveRoot = "${driveLetter}:\"
        $frontendRelativeToAlias = Get-WorkspaceRelativePath -BasePath $aliasRoot -TargetPath $resolvedFrontend
        $aliasedFrontend = (Join-Path $aliasDriveRoot $frontendRelativeToAlias)
        $aliasedFlutter = if ($usesLocalToolchain -or $flutterExecutable -match "\s") {
            Join-Path $aliasDriveRoot (Get-WorkspaceRelativePath -BasePath $aliasRoot -TargetPath $flutterExecutable)
        } else { $flutterExecutable }
        $aliasedDart = if ($usesLocalToolchain -or $dartExecutable -match "\s") {
            Join-Path $aliasDriveRoot (Get-WorkspaceRelativePath -BasePath $aliasRoot -TargetPath $dartExecutable)
        } else { $dartExecutable }

        return [pscustomobject]@{
            FrontendRoot = $aliasedFrontend
            Flutter = $aliasedFlutter
            Dart = $aliasedDart
            AliasDrive = $driveLetter
            LocalPropertiesPath = $localPropertiesPath
            HadLocalProperties = $hadLocalProperties
            OriginalLocalProperties = $originalLocalProperties
        }
    }
    catch {
        & subst.exe "${driveLetter}:" /D
        throw
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
