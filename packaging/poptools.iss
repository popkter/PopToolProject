#define MyAppName "泡泡工具箱"
#ifndef MyAppVersion
#define MyAppVersion "0.0.0"
#endif
#ifndef MyAppVersionInfoVersion
#define MyAppVersionInfoVersion "0.0.0.0"
#endif
#define MyAppPublisher "PopTools"
#define MyAppExeName "泡泡工具箱.exe"
#define MyAppUserModelId "PopTools.ZhangPaopaoToolbox"

[Setup]
AppId={{2D39A497-EC7D-4A4E-A09F-5CC3768725B4}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={localappdata}\Programs\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
OutputDir=..\dist
OutputBaseFilename={#MyAppName}-Setup
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
SetupIconFile=..\src\poptools\resources\icons\app-icon.ico
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
UninstallDisplayIcon={app}\{#MyAppExeName}
; Older PopTools builds treated Restart Manager's close request as a request
; to minimize to the tray. Try a graceful close first, then terminate those
; legacy builds after the user has confirmed that Setup may close the app.
CloseApplications=force
RestartApplications=no
SetupLogging=yes
UsePreviousAppDir=yes
ChangesEnvironment=no
VersionInfoVersion={#MyAppVersionInfoVersion}
VersionInfoCompany={#MyAppPublisher}
VersionInfoDescription={#MyAppName} 安装程序
VersionInfoProductName={#MyAppName}

[Tasks]
Name: "desktopicon"; Description: "创建桌面快捷方式"; GroupDescription: "附加任务："; Flags: unchecked

[Files]
Source: "..\dist\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; AppUserModelID: "{#MyAppUserModelId}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; AppUserModelID: "{#MyAppUserModelId}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "启动 {#MyAppName}"; Flags: nowait postinstall skipifsilent

[Code]
function GetWindowThreadProcessId(Wnd: HWND; var ProcessId: DWORD): DWORD;
  external 'GetWindowThreadProcessId@user32.dll stdcall';

function CloseRunningApplication(): Boolean;
var
  AppWindow: HWND;
  ProcessId: DWORD;
  ResultCode: Integer;
begin
  Result := True;
  AppWindow := FindWindowByWindowName('{#MyAppName}');
  if AppWindow = 0 then
    Exit;

  if (not WizardSilent) and
     (MsgBox(
       '{#MyAppName} 正在运行。继续安装将关闭当前应用，是否继续？',
       mbConfirmation, MB_YESNO or MB_DEFBUTTON2) <> idYes) then
  begin
    Result := False;
    Exit;
  end;

  ProcessId := 0;
  GetWindowThreadProcessId(AppWindow, ProcessId);
  if ProcessId <> 0 then
  begin
    Log(Format('Closing running {#MyAppName} process %d before installation.', [ProcessId]));
    Exec(
      ExpandConstant('{cmd}'),
      Format('/D /Q /C taskkill /PID %d /T /F', [ProcessId]),
      '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
    Sleep(500);
  end;
end;

function NextButtonClick(CurPageID: Integer): Boolean;
begin
  Result := True;
  if CurPageID = wpReady then
    Result := CloseRunningApplication();
end;
