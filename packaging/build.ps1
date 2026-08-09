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

    & $VenvPython -m PyInstaller --noconfirm --clean "packaging\poptools.spec"
    if ($LASTEXITCODE -ne 0) { throw "PyInstaller build failed" }

    Write-Host "Self-contained single-file application created at dist\泡泡工具箱.exe"

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
        & $InnoCompiler "packaging\poptools.iss"
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

