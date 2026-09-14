#ifndef SourceDir
  #error SourceDir must point to the expanded deployment directory
#endif
#ifndef OutputDir
  #define OutputDir "..\build\installer"
#endif
#ifndef AppVersion
  #error AppVersion must come from the CMake build metadata
#endif
[Setup]
AppId={{A588C320-66F2-428D-8572-C9927CB1C46A}
AppName=UTerminal
AppVersion={#AppVersion}
AppPublisher=UTerminal
DefaultDirName={localappdata}\Programs\UTerminal
DefaultGroupName=UTerminal
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0.22000
OutputDir={#OutputDir}
OutputBaseFilename=UTerminal-{#AppVersion}-win-x64-setup
SetupIconFile={#SourceDir}\resources\icons\app-icon.ico
UninstallDisplayIcon={app}\UTerminal.exe
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
CloseApplications=yes
RestartApplications=no
ChangesAssociations=yes
SetupLogging=yes
[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; Flags: unchecked
[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
[Registry]
; Register classic verbs directly: no PowerShell, MSIX identity or signing required.
Root: HKCU; Subkey: "Software\Classes\Directory\shell\UTerminal.OpenHere"; ValueType: string; ValueName: ""; ValueData: "在 UTerminal 中打开"; Flags: uninsdeletekey
Root: HKCU; Subkey: "Software\Classes\Directory\shell\UTerminal.OpenHere"; ValueType: string; ValueName: "Icon"; ValueData: """{app}\resources\icons\app-icon.ico"""
Root: HKCU; Subkey: "Software\Classes\Directory\shell\UTerminal.OpenHere"; ValueType: string; ValueName: "MultiSelectModel"; ValueData: "Single"
Root: HKCU; Subkey: "Software\Classes\Directory\shell\UTerminal.OpenHere\command"; ValueType: string; ValueName: ""; ValueData: """{app}\UTerminal.exe"" --open-terminal --directory ""%1\."""
Root: HKCU; Subkey: "Software\Classes\Directory\Background\shell\UTerminal.OpenHere"; ValueType: string; ValueName: ""; ValueData: "在 UTerminal 中打开"; Flags: uninsdeletekey
Root: HKCU; Subkey: "Software\Classes\Directory\Background\shell\UTerminal.OpenHere"; ValueType: string; ValueName: "Icon"; ValueData: """{app}\resources\icons\app-icon.ico"""
; A background menu has no selected item. Also remove the value left by older installers.
Root: HKCU; Subkey: "Software\Classes\Directory\Background\shell\UTerminal.OpenHere"; ValueType: none; ValueName: "MultiSelectModel"; Flags: deletevalue
Root: HKCU; Subkey: "Software\Classes\Directory\Background\shell\UTerminal.OpenHere\command"; ValueType: string; ValueName: ""; ValueData: """{app}\UTerminal.exe"" --open-terminal --directory ""%V\."""
Root: HKCU; Subkey: "Software\Classes\*\shell\UTerminal.OpenHere"; ValueType: string; ValueName: ""; ValueData: "在 UTerminal 中打开"; Flags: uninsdeletekey
Root: HKCU; Subkey: "Software\Classes\*\shell\UTerminal.OpenHere"; ValueType: string; ValueName: "Icon"; ValueData: """{app}\resources\icons\app-icon.ico"""
Root: HKCU; Subkey: "Software\Classes\*\shell\UTerminal.OpenHere"; ValueType: string; ValueName: "MultiSelectModel"; ValueData: "Single"
Root: HKCU; Subkey: "Software\Classes\*\shell\UTerminal.OpenHere\command"; ValueType: string; ValueName: ""; ValueData: """{app}\UTerminal.exe"" --open-terminal --directory ""%1"""
Root: HKCU; Subkey: "Software\Classes\Drive\shell\UTerminal.OpenHere"; ValueType: string; ValueName: ""; ValueData: "在 UTerminal 中打开"; Flags: uninsdeletekey
Root: HKCU; Subkey: "Software\Classes\Drive\shell\UTerminal.OpenHere"; ValueType: string; ValueName: "Icon"; ValueData: """{app}\resources\icons\app-icon.ico"""
Root: HKCU; Subkey: "Software\Classes\Drive\shell\UTerminal.OpenHere"; ValueType: string; ValueName: "MultiSelectModel"; ValueData: "Single"
Root: HKCU; Subkey: "Software\Classes\Drive\shell\UTerminal.OpenHere\command"; ValueType: string; ValueName: ""; ValueData: """{app}\UTerminal.exe"" --open-terminal --directory ""%1\."""
[Icons]
Name: "{group}\UTerminal"; Filename: "{app}\UTerminal.exe"
Name: "{autodesktop}\UTerminal"; Filename: "{app}\UTerminal.exe"; Tasks: desktopicon
[Run]
Filename: "{app}\UTerminal.exe"; Description: "Launch UTerminal"; Flags: nowait postinstall skipifsilent
[UninstallRun]
Filename: "{sys}\WindowsPowerShell\v1.0\powershell.exe"; Parameters: "-NoLogo -NoProfile -ExecutionPolicy Bypass -File ""{app}\resources\shell\register.ps1"" -Unregister"; Flags: runhidden waituntilterminated
