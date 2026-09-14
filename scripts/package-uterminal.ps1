param([string]$QtRoot=$env:QT_ROOT,[string]$InnoCompiler,[switch]$SkipBuild,[string]$SigningCertificateThumbprint,[string]$Publisher='CN=UTerminal',[string]$BuildDirectory)
$ErrorActionPreference='Stop'
$projectRoot=Split-Path -Parent $PSScriptRoot
if(!$QtRoot){$QtRoot=Join-Path $projectRoot 'build/qt-sdk/6.10.3/msvc2022_64'}
if(!$InnoCompiler){$InnoCompiler=Join-Path $env:LOCALAPPDATA 'Programs/Inno Setup 6/ISCC.exe'}
if(!(Test-Path -LiteralPath $InnoCompiler)){throw 'Inno Setup 6 compiler not found. Pass -InnoCompiler.'}
$build=if($BuildDirectory){[IO.Path]::GetFullPath($BuildDirectory)}else{Join-Path $projectRoot 'build/uterminal-vs'}
if(!$SkipBuild){& "$PSScriptRoot/build-uterminal.ps1" -Configuration Release -QtRoot $QtRoot -BuildDirectory $build -Test}
$version=(Get-Content -LiteralPath "$build/version.json" -Raw | ConvertFrom-Json).version
if($version -notmatch '^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$'){throw 'Invalid CMake application version.'}
foreach($component in $version.Split('.')){if([int64]$component -gt 65535){throw 'Application version exceeds Windows version component limit.'}}
foreach($binary in 'UTerminal.exe','UTerminalUpdateRunner.exe','UTerminalShell.dll'){
    if((Get-Item -LiteralPath "$build/Release/$binary").VersionInfo.ProductVersion -ne $version){throw "Build version mismatch: $binary"}
}
$stage=[IO.Path]::GetFullPath((Join-Path $projectRoot 'build/uterminal-package'))
$allowed=[IO.Path]::GetFullPath((Join-Path $projectRoot 'build'))+[IO.Path]::DirectorySeparatorChar
if(!$stage.StartsWith($allowed,[StringComparison]::OrdinalIgnoreCase)){throw 'Package staging directory escapes build workspace.'}
if(Test-Path -LiteralPath $stage){Remove-Item -LiteralPath $stage -Recurse -Force}
New-Item -ItemType Directory -Path $stage | Out-Null
Copy-Item -LiteralPath "$build/Release/UTerminal.exe" -Destination $stage
Copy-Item -LiteralPath "$build/Release/UTerminalUpdateRunner.exe" -Destination $stage
Copy-Item -LiteralPath "$build/Release/UTerminalShell.dll" -Destination $stage
Copy-Item -LiteralPath "$projectRoot/resources" -Destination $stage -Recurse
$bootstrapCache=[IO.Path]::GetFullPath((Join-Path $stage 'resources/plugin-bootstrap/__pycache__'))
if(!$bootstrapCache.StartsWith($stage+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw 'Bootstrap cache escapes package staging directory.'}
if(Test-Path -LiteralPath $bootstrapCache){Remove-Item -LiteralPath $bootstrapCache -Recurse -Force}
& "$PSScriptRoot/package-shell.ps1" -Destination "$projectRoot/build/shell-package" -SigningCertificateThumbprint $SigningCertificateThumbprint -Publisher $Publisher -Version $version
Copy-Item -LiteralPath "$projectRoot/build/shell-package/UTerminalShell.msix" -Destination "$stage/resources/shell"
Copy-Item -LiteralPath "$projectRoot/build/shell-package/identity/AppxManifest.xml" -Destination "$stage/resources/shell"
$utDeployPath=$env:PATH
Remove-Item Env:PATH -ErrorAction SilentlyContinue
$env:Path="$QtRoot/bin;$utDeployPath"
& "$QtRoot/bin/windeployqt.exe" --release --compiler-runtime --qmldir "$projectRoot/resources/qml" "$stage/UTerminal.exe"
if($LASTEXITCODE){throw "Qt deployment failed: $LASTEXITCODE"}
$vswhere=Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'
$vsRoot=& $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
$redistRoot=Join-Path $vsRoot 'VC/Redist/MSVC'
$crt=Get-ChildItem -LiteralPath $redistRoot -Directory | Where-Object Name -Match '^\d+\.' | Sort-Object { [version]$_.Name } -Descending | ForEach-Object { Get-ChildItem -LiteralPath (Join-Path $_.FullName 'x64') -Directory -Filter '*.CRT' } | Select-Object -First 1
if(!$crt){throw 'MSVC redistributable DLL directory was not found.'}
Copy-Item -Path (Join-Path $crt.FullName '*.dll') -Destination $stage
if(!(Test-Path -LiteralPath "$stage/vcruntime140.dll")){throw 'MSVC runtime missing from package.'}
& "$PSScriptRoot/package-notices.ps1" -Stage $stage -QtRoot $QtRoot
# Qt libraries, QML imports and resources are regular files here. Inno expands
# them at installation; the executable has no startup unpacking step.
& $InnoCompiler /Qp "/DSourceDir=$stage" "/DOutputDir=$projectRoot/build/installer" "/DAppVersion=$version" "$projectRoot/installer/UTerminal.iss"
if($LASTEXITCODE){throw "Installer compilation failed: $LASTEXITCODE"}
$installer=Join-Path $projectRoot "build/installer/UTerminal-$version-win-x64-setup.exe"
$hash=(Get-FileHash -LiteralPath $installer -Algorithm SHA256).Hash.ToLowerInvariant()
"$hash  $([IO.Path]::GetFileName($installer))" | Set-Content -LiteralPath (Join-Path $projectRoot 'build/installer/SHA256SUMS.txt') -Encoding ascii
