param(
    [string]$Configuration = "Release"
)

$ErrorActionPreference = "Stop"
$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$BuildDirectory = Join-Path $ProjectRoot "build\native"
$InstallDirectory = Join-Path $ProjectRoot "src\poptools\native"

$CMakeCommand = Get-Command cmake -ErrorAction SilentlyContinue
$CMake = if ($CMakeCommand) { $CMakeCommand.Source } else {
    Join-Path $ProjectRoot ".venv\Scripts\cmake.exe"
}
if (-not (Test-Path -LiteralPath $CMake -PathType Leaf)) {
    throw "CMake was not found. Install CMake and a Qt 6.10+ C++ SDK compatible with PySide6."
}

$QtPrefix = $env:QT_ROOT_DIR
if (-not $QtPrefix) {
    $QMake = (Get-Command qmake6 -ErrorAction SilentlyContinue).Source
    if (-not $QMake) { $QMake = (Get-Command qmake -ErrorAction SilentlyContinue).Source }
    if ($QMake) { $QtPrefix = (& $QMake -query QT_INSTALL_PREFIX).Trim() }
}
if (-not $QtPrefix) {
    throw "Qt 6 C++ SDK was not found. Set QT_ROOT_DIR or add qmake to PATH."
}

New-Item -ItemType Directory -Path $BuildDirectory -Force | Out-Null
New-Item -ItemType Directory -Path $InstallDirectory -Force | Out-Null

& $CMake -S (Join-Path $ProjectRoot "native") -B $BuildDirectory `
    "-DCMAKE_BUILD_TYPE=$Configuration" `
    "-DCMAKE_PREFIX_PATH=$QtPrefix"
if ($LASTEXITCODE -ne 0) { throw "Native terminal configure failed" }

& $CMake --build $BuildDirectory --config $Configuration --parallel
if ($LASTEXITCODE -ne 0) { throw "Native terminal build failed" }

$CTest = Join-Path (Split-Path -Parent $CMake) "ctest.exe"
if (-not (Test-Path -LiteralPath $CTest -PathType Leaf)) {
    $CTestCommand = Get-Command ctest -ErrorAction SilentlyContinue
    $CTest = if ($CTestCommand) { $CTestCommand.Source } else { "" }
}
if (-not $CTest) { throw "CTest was not found beside CMake" }
& $CTest --test-dir $BuildDirectory --build-config $Configuration --output-on-failure
if ($LASTEXITCODE -ne 0) { throw "Native terminal tests failed" }

& $CMake --install $BuildDirectory --config $Configuration --prefix $InstallDirectory
if ($LASTEXITCODE -ne 0) { throw "Native terminal install failed" }

Write-Host "Native terminal installed at $InstallDirectory"
