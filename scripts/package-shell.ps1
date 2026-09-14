param([string]$Destination,[string]$SigningCertificateThumbprint,[string]$Publisher='CN=UTerminal',[Parameter(Mandatory=$true)][string]$Version)
$ErrorActionPreference='Stop'
$project=Split-Path -Parent $PSScriptRoot
if(!$Destination){$Destination=Join-Path $project 'build/shell-package'}
New-Item -ItemType Directory -Path $Destination -Force | Out-Null
$manifestDirectory=Join-Path $Destination 'identity'
New-Item -ItemType Directory -Path $manifestDirectory -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $project 'resources/shell/AppxManifest.xml') -Destination $manifestDirectory
$manifestPath=Join-Path $manifestDirectory 'AppxManifest.xml'
$manifest=[xml](Get-Content -LiteralPath $manifestPath -Raw)
$manifest.Package.Identity.Publisher=$Publisher
$manifest.Package.Identity.Version="$Version.0"
$manifest.Save($manifestPath)
$sdk=Get-ChildItem 'C:/Program Files (x86)/Windows Kits/10/bin' -Directory | Where-Object Name -Match '^10\.0\.' | Sort-Object { [version]$_.Name } -Descending | Select-Object -First 1
$makeappx=Join-Path $sdk.FullName 'x64/makeappx.exe'
& $makeappx pack /d $manifestDirectory /p (Join-Path $Destination 'UTerminalShell.msix') /nv /o
if($LASTEXITCODE){throw "Shell identity package failed: $LASTEXITCODE"}
if($SigningCertificateThumbprint){
    $signtool=Join-Path $sdk.FullName 'x64/signtool.exe'
    & $signtool sign /fd SHA256 /sha1 $SigningCertificateThumbprint (Join-Path $Destination 'UTerminalShell.msix')
    if($LASTEXITCODE){throw "Shell identity signing failed: $LASTEXITCODE"}
    & $signtool verify /pa (Join-Path $Destination 'UTerminalShell.msix')
    if($LASTEXITCODE){throw "Shell identity signature verification failed: $LASTEXITCODE"}
}else{Write-Warning 'Unsigned development package: Explorer registration on end-user machines requires a trusted signature.'}
