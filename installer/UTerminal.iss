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
[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; Flags: unchecked
[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
[Icons]
Name: "{group}\UTerminal"; Filename: "{app}\UTerminal.exe"
Name: "{autodesktop}\UTerminal"; Filename: "{app}\UTerminal.exe"; Tasks: desktopicon
[Run]
Filename: "{app}\UTerminal.exe"; Description: "Launch UTerminal"; Flags: nowait postinstall skipifsilent
[UninstallRun]
Filename: "{sys}\WindowsPowerShell\v1.0\powershell.exe"; Parameters: "-NoLogo -NoProfile -ExecutionPolicy Bypass -File ""{app}\resources\shell\register.ps1"" -Unregister"; Flags: runhidden waituntilterminated

[Code]
procedure CurStepChanged(CurStep: TSetupStep);
var
  ResultCode: Integer;
  Registered: Boolean;
begin
  if CurStep = ssPostInstall then
  begin
    Registered := Exec(ExpandConstant('{sys}\WindowsPowerShell\v1.0\powershell.exe'),
      ExpandConstant('-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "{app}\resources\shell\register.ps1" -InstallDirectory "{app}"'),
      '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
    if (not Registered) or (ResultCode <> 0) then
    begin
      Log(Format('UTerminal Explorer registration failed: %d', [ResultCode]));
      SuppressibleMsgBox('UTerminal was installed, but neither the modern nor the classic Explorer context menu could be registered. See resources\shell\README.md in the installation folder.', mbError, MB_OK, IDOK);
    end;
  end;
end;
