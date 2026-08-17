param(
    [switch]$SkipTests,
    [switch]$SkipInstaller
)

$ErrorActionPreference = "Stop"
$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$VenvPython = Join-Path $ProjectRoot ".venv\Scripts\python.exe"
$PythonVendorDir = Join-Path $ProjectRoot "src\poptools\resources\vendor\python"
$PythonManifestPath = Join-Path $PythonVendorDir "python-runtime.json"
$PythonManifest = Get-Content -LiteralPath $PythonManifestPath -Raw | ConvertFrom-Json
$PythonRuntimePackage = Join-Path $PythonVendorDir $PythonManifest.file

function Find-UvExecutable {
    $UvCommand = Get-Command "uv" -ErrorAction SilentlyContinue
    if ($UvCommand) { return $UvCommand.Source }

    $Candidates = @(
        (Join-Path $ProjectRoot ".venv\Scripts\uv.exe"),
        (Join-Path $ProjectRoot "tools\uv.exe"),
        (Join-Path $env:USERPROFILE ".local\bin\uv.exe"),
        (Join-Path $env:USERPROFILE "scoop\shims\uv.exe"),
        (Join-Path $env:USERPROFILE "scoop\apps\uv\current\uv.exe"),
        (Join-Path $env:USERPROFILE ".cargo\bin\uv.exe"),
        (Join-Path $env:LOCALAPPDATA "Programs\uv\uv.exe")
    )
    return $Candidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
}

if (-not (Test-Path -LiteralPath $PythonRuntimePackage)) {
    New-Item -ItemType Directory -Path $PythonVendorDir -Force | Out-Null
    Write-Host "Downloading the private Python runtime package..."
    Invoke-WebRequest -Uri $PythonManifest.url -OutFile $PythonRuntimePackage
}
$PythonRuntimePackageHash = (Get-FileHash -LiteralPath $PythonRuntimePackage -Algorithm SHA256).Hash.ToLowerInvariant()
if ($PythonRuntimePackageHash -ne $PythonManifest.sha256) {
    throw "Private Python runtime package checksum mismatch: $PythonRuntimePackage"
}

if (-not (Test-Path -LiteralPath $VenvPython)) {
    throw "Project venv is missing: $VenvPython"
}

$ActualPrefix = & $VenvPython -c "import pathlib,sys; print(pathlib.Path(sys.prefix).resolve())"
$ExpectedPrefix = (Resolve-Path (Join-Path $ProjectRoot ".venv")).Path
if ($ActualPrefix.Trim() -ne $ExpectedPrefix) {
    throw "Build must use the project .venv. Actual prefix: $ActualPrefix"
}

Push-Location $ProjectRoot
$TestWorkspace = Join-Path $ProjectRoot ("build\pytest-" + [guid]::NewGuid().ToString("N"))
try {
    # A venv created by uv records the uv version in pyvenv.cfg, but it does not
    # contain uv.exe. Only require a package installer when dependencies are missing.
    $PrevEAP = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        # Ensure dev dependencies (pytest, pyinstaller, etc.) are installed.
        & $VenvPython -c "import pytest, PyInstaller" 2>$null
        $DevMissing = ($LASTEXITCODE -ne 0)
        & $VenvPython -c "import pkg_resources" 2>$null
        $PkgResourcesMissing = ($LASTEXITCODE -ne 0)

        if ($DevMissing -or $PkgResourcesMissing) {
            $UvExe = Find-UvExecutable
            if (-not $UvExe) {
                Write-Host "uv executable not found; using pip inside the project venv." -ForegroundColor Yellow
                & $VenvPython -c "import pip" 2>$null
                if ($LASTEXITCODE -ne 0) {
                    & $VenvPython -m ensurepip --upgrade 2>&1 | ForEach-Object { Write-Host "  $_" }
                    if ($LASTEXITCODE -ne 0) { throw "Failed to bootstrap pip in the project venv" }
                }
            }
        }

        if ($DevMissing) {
            Write-Host "Dev dependencies not found, installing..." -ForegroundColor Yellow
            if ($UvExe) {
                & $UvExe pip install --python $VenvPython -e ".[dev]" 2>&1 | ForEach-Object { Write-Host "  $_" }
            }
            else {
                & $VenvPython -m pip install -e ".[dev]" 2>&1 | ForEach-Object { Write-Host "  $_" }
            }
            if ($LASTEXITCODE -ne 0) { throw "Failed to install dev dependencies" }
            Write-Host "Dev dependencies installed." -ForegroundColor Green
        }

        # setuptools >= 70 removed pkg_resources, but wexpect still imports it unconditionally.
        # Ensure it's available at both build time (PyInstaller analysis) and runtime.
        if ($PkgResourcesMissing) {
            Write-Host "pkg_resources not found, installing setuptools<70..." -ForegroundColor Yellow
            if ($UvExe) {
                & $UvExe pip install --python $VenvPython "setuptools<70" 2>&1 | ForEach-Object { Write-Host "  $_" }
            }
            else {
                & $VenvPython -m pip install "setuptools<70" 2>&1 | ForEach-Object { Write-Host "  $_" }
            }
            if ($LASTEXITCODE -ne 0) { throw "Failed to install setuptools<70" }
            Write-Host "setuptools downgraded (pkg_resources now available)." -ForegroundColor Green
        }
    }
    finally {
        $ErrorActionPreference = $PrevEAP
    }

    $LegacyOutput = Join-Path $ProjectRoot "dist\泡泡工具箱"
    $SingleFileOutput = Join-Path $ProjectRoot "dist\泡泡工具箱.exe"
    if (Test-Path -LiteralPath $LegacyOutput) {
        Remove-Item -LiteralPath $LegacyOutput -Recurse -Force
    }
    if (Test-Path -LiteralPath $SingleFileOutput) {
        Remove-Item -LiteralPath $SingleFileOutput -Force
    }

    if (-not $SkipTests) {
        $PytestBaseTemp = Join-Path $TestWorkspace "tmp"
        $PytestCacheDir = Join-Path $TestWorkspace "cache"
        New-Item -ItemType Directory -Path $TestWorkspace -Force | Out-Null
        & $VenvPython -m pytest "--basetemp=$PytestBaseTemp" -o "cache_dir=$PytestCacheDir"
        if ($LASTEXITCODE -ne 0) { throw "Tests failed" }
    }

    $PyprojectPath = Join-Path $ProjectRoot "pyproject.toml"
    $PyprojectContent = Get-Content -LiteralPath $PyprojectPath -Raw
    if ($PyprojectContent -notmatch '(?m)^version\s*=\s*"([^"\r\n]+)"\s*$') {
        throw "Could not find the project version in pyproject.toml"
    }
    $BaseVersion = $Matches[1]
    $BuildDate = Get-Date -Format "yyyy-MM-dd"
    $BuildVersion = "${BuildDate}_$BaseVersion"

    # Inno Setup requires VersionInfoVersion to contain four numeric parts.
    # Keep the user-facing build version above, including date and prerelease
    # suffix, for AppVersion and the application runtime.
    $VersionCore = ($BaseVersion -split "-", 2)[0]
    $VersionParts = @($VersionCore -split "\.")
    $InvalidVersionPart = $VersionParts | Where-Object { $_ -notmatch '^\d+$' }
    if ($VersionParts.Count -gt 4 -or $InvalidVersionPart) {
        throw "Project version must start with a numeric version such as 0.2.0 or 0.2.0-alpha"
    }
    while ($VersionParts.Count -lt 4) { $VersionParts += "0" }
    $VersionInfoVersion = $VersionParts -join "."
    $VersionFile = Join-Path $ProjectRoot "src\poptools\_build_version.py"
    $VersionContent = "# Auto-generated by build.ps1 — do not commit.`n__build_version__ = '$BuildVersion'"
    [System.IO.File]::WriteAllText(
        $VersionFile,
        $VersionContent,
        [System.Text.UTF8Encoding]::new($false)
    )
    Write-Host "Build version: $BuildVersion"

    & $VenvPython -m PyInstaller --noconfirm --clean "packaging\poptools.spec"
    if ($LASTEXITCODE -ne 0) { throw "PyInstaller build failed" }

    $BuiltExe = Join-Path $ProjectRoot "dist\泡泡工具箱.exe"
    $BuiltExeHash = (Get-FileHash -LiteralPath $BuiltExe -Algorithm SHA256).Hash.ToLowerInvariant()
    $ChecksumFile = Join-Path $ProjectRoot "dist\泡泡工具箱.exe.sha256"
    [System.IO.File]::WriteAllText(
        $ChecksumFile,
        "$BuiltExeHash  泡泡工具箱.exe`n",
        [System.Text.UTF8Encoding]::new($false)
    )
    Write-Host "Self-contained single-file application created at dist\泡泡工具箱.exe"
    Write-Host "OTA checksum created at dist\泡泡工具箱.exe.sha256"

    if (-not $SkipInstaller) {
        $InnoCompiler = (Get-Command "ISCC.exe" -ErrorAction SilentlyContinue).Source
        if (-not $InnoCompiler) {
            $InnoCompiler = @(
                (Join-Path $env:LOCALAPPDATA "Programs\Inno Setup 6\ISCC.exe"),
                (Join-Path ([Environment]::GetFolderPath("ProgramFilesX86")) "Inno Setup 6\ISCC.exe"),
                (Join-Path ([Environment]::GetFolderPath("ProgramFiles")) "Inno Setup 6\ISCC.exe")
            ) | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
        }
        if (-not $InnoCompiler) {
            throw "Inno Setup 6 is required to build the installer. Install it or use -SkipInstaller."
        }
        & $InnoCompiler "/DMyAppVersion=$BuildVersion" "/DMyAppVersionInfoVersion=$VersionInfoVersion" "packaging\poptools.iss"
        if ($LASTEXITCODE -ne 0) { throw "Inno Setup build failed" }
        Write-Host "Per-user installer created at dist\泡泡工具箱-Setup.exe"
    }
}
finally {
    if (Test-Path -LiteralPath $TestWorkspace) {
        Remove-Item -LiteralPath $TestWorkspace -Recurse -Force -ErrorAction SilentlyContinue
    }
    Pop-Location
}

