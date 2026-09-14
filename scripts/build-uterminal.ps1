param(
    [ValidateSet('Debug','Release')][string]$Configuration='Debug',
    [string]$QtRoot=$env:QT_ROOT,
    [string]$BuildDirectory,
    [switch]$Test
)
$ErrorActionPreference='Stop'
$projectRoot=Split-Path -Parent $PSScriptRoot
if(!$QtRoot){$QtRoot=Join-Path $projectRoot 'build/qt-sdk/6.10.3/msvc2022_64'}
if(!(Test-Path -LiteralPath "$QtRoot/bin/Qt6Core.dll")){throw 'Qt C++ SDK not found. Set QT_ROOT or pass -QtRoot.'}
$vswhere=Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'
if(!(Test-Path -LiteralPath $vswhere)){throw 'Install Visual Studio with Desktop development with C++.'}
$vs=(& $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -format json | ConvertFrom-Json)[0]
if(!$vs){throw 'Visual Studio C++ toolchain was not found.'}
$cmake=Join-Path $vs.installationPath 'Common7/IDE/CommonExtensions/Microsoft/CMake/CMake/bin/cmake.exe'
$ctest=Join-Path (Split-Path $cmake) 'ctest.exe'
$major=[int]($vs.installationVersion.Split('.')[0])
$generator=if($major -ge 18){'Visual Studio 18 2026'}else{'Visual Studio 17 2022'}
$build=if($BuildDirectory){[IO.Path]::GetFullPath($BuildDirectory)}else{Join-Path $projectRoot 'build/uterminal-vs'}
# Avoid duplicate PATH/Path entries inherited from certain Windows hosts.
$utBuildPath=$env:PATH
Remove-Item Env:PATH -ErrorAction SilentlyContinue
$env:Path="$QtRoot/bin;$utBuildPath"
& $cmake -S $projectRoot -B $build -G $generator -A x64 "-DCMAKE_PREFIX_PATH=$QtRoot" -DBUILD_TESTING=ON
if($LASTEXITCODE){throw "CMake configure failed: $LASTEXITCODE"}
& $cmake --build $build --config $Configuration --parallel
if($LASTEXITCODE){throw "C++ build failed: $LASTEXITCODE"}
if($Test){
    & $ctest --test-dir $build -C $Configuration --output-on-failure
    if($LASTEXITCODE){throw "Tests failed: $LASTEXITCODE"}
}
Write-Output "Executable: $build/$Configuration/UTerminal.exe"
Write-Output "Visual Studio solution: $build/UTerminal.slnx"
