param([string]$InstallDirectory,[switch]$Unregister,[switch]$Development)
$ErrorActionPreference='Stop'
$packageName='UTerminal.ShellIntegration'
$classicTargets=@{
    # A final dot avoids a root directory's trailing backslash escaping the closing quote.
    'Directory'='%1\.'
    'Directory\Background'='%V\.'
    '*'='%1'
    'Drive'='%1\.'
}
function Remove-ClassicMenu {
    foreach($target in $classicTargets.Keys){
        $key="Software\Classes\$target\shell\UTerminal.OpenHere"
        [Microsoft.Win32.Registry]::CurrentUser.DeleteSubKeyTree($key,$false)
    }
}
if($Unregister){
    Remove-ClassicMenu
    Get-AppxPackage -Name $packageName | Remove-AppxPackage
    exit 0
}
if(!$InstallDirectory){throw 'InstallDirectory is required.'}
$InstallDirectory=[IO.Path]::GetFullPath($InstallDirectory)
$executable=Join-Path $InstallDirectory 'UTerminal.exe'
if(!(Test-Path -LiteralPath $executable -PathType Leaf)){throw 'UTerminal executable is missing.'}
try {
if(!(Test-Path -LiteralPath (Join-Path $InstallDirectory 'UTerminalShell.dll'))){throw 'UTerminal Shell DLL is missing.'}
$package=Join-Path $InstallDirectory 'resources/shell/UTerminalShell.msix'
$manifestPath=Join-Path $InstallDirectory 'resources/shell/AppxManifest.xml'
if($Development){
    $mode=Get-ItemProperty -LiteralPath 'HKLM:/SOFTWARE/Microsoft/Windows/CurrentVersion/AppModelUnlock' -ErrorAction SilentlyContinue
    if($mode.AllowDevelopmentWithoutDevLicense -ne 1){throw 'Development registration requires Developer Mode already enabled. Use a signed package for distribution.'}
    Add-AppxPackage -Register $manifestPath -ExternalLocation $InstallDirectory
}else{
    Add-AppxPackage -Path $package -ExternalLocation $InstallDirectory
}
} catch {
    Write-Warning "Modern Explorer menu registration failed; using the classic menu: $($_.Exception.Message)"
    # Use the registry API so the literal '*' target is never treated as a wildcard.
    foreach($target in $classicTargets.Keys){
        $key=[Microsoft.Win32.Registry]::CurrentUser.CreateSubKey("Software\Classes\$target\shell\UTerminal.OpenHere")
        try {
            # Unicode escapes keep this script compatible with Windows PowerShell's ANSI default.
            $label=([char]0x5728)+' UTerminal '+([char]0x4e2d)+([char]0x6253)+([char]0x5f00)
            $key.SetValue('',$label)
            $key.SetValue('Icon','"'+(Join-Path $InstallDirectory 'resources\icons\app-icon.ico')+'"')
            $key.SetValue('MultiSelectModel','Single')
            $command=$key.CreateSubKey('command')
            try {
                $command.SetValue('','"'+$executable+'" --open-terminal --directory "'+$classicTargets[$target]+'"')
            } finally {$command.Dispose()}
        } finally {$key.Dispose()}
    }
    Write-Output 'Registered UTerminal in the classic Explorer context menu.'
    exit 0
}
Remove-ClassicMenu
Write-Output 'Registered UTerminal in the modern Explorer context menu.'
