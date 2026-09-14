param([Parameter(Mandatory=$true)][string]$Stage,[Parameter(Mandatory=$true)][string]$QtRoot)
$ErrorActionPreference='Stop'
$projectRoot=Split-Path -Parent $PSScriptRoot
$stagePath=[IO.Path]::GetFullPath($Stage)
if(!(Test-Path -LiteralPath (Join-Path $stagePath 'UTerminal.exe'))){throw 'Not a UTerminal deployment directory.'}
$notices=Join-Path $stagePath 'resources/licenses'
New-Item -ItemType Directory -Force -Path $notices | Out-Null
Copy-Item -LiteralPath (Join-Path $projectRoot 'native/third_party/libvterm/UTERMINAL-PATCHES.md') -Destination $notices
$qtNotices=Join-Path $notices 'qt-sbom'
New-Item -ItemType Directory -Force -Path $qtNotices | Out-Null
$repositories=@{}
$modules=@(Get-ChildItem -LiteralPath $stagePath -Filter 'Qt6*.dll' -File | Sort-Object Name | ForEach-Object {
    $module=$_.BaseName.Substring(3)
    $metadata=Join-Path $QtRoot "modules/$module.json"
    if(!(Test-Path -LiteralPath $metadata)){$metadata=Join-Path $QtRoot "modules/${module}Private.json"}
    if(!(Test-Path -LiteralPath $metadata)){throw "Qt module metadata missing: $module"}
    $info=Get-Content -LiteralPath $metadata -Raw | ConvertFrom-Json
    if(!$info.repository -or !$info.version){throw "Incomplete Qt metadata: $metadata"}
    $stem="$($info.repository)-$($info.version)"
    $repositories[$stem]=$true
    [ordered]@{file=$_.Name;module=$info.name;repository=$info.repository;version=$info.version}
})
if(!$modules.Count){throw 'No deployed Qt libraries found.'}
foreach($stem in ($repositories.Keys | Sort-Object)){
    $sbom=Join-Path $QtRoot "sbom/$stem.spdx.json"
    if(!(Test-Path -LiteralPath $sbom)){throw "Qt SDK SBOM missing: $sbom"}
    Copy-Item -LiteralPath $sbom -Destination $qtNotices
}
$files=@(Get-ChildItem -LiteralPath $stagePath -File -Recurse | Where-Object { $_.Extension -in '.dll','.exe','.otf','.ttf' } | Sort-Object FullName | ForEach-Object {
    [ordered]@{path=$_.FullName.Substring($stagePath.Length+1).Replace('\','/');bytes=$_.Length;sha256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()}
})
[ordered]@{schemaVersion=1;qtModules=$modules;files=$files} | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $notices 'deployed-components.json') -Encoding UTF8
Write-Output "Dependency inventory: $($files.Count) binaries/fonts; $($repositories.Count) Qt repository SBOMs."
