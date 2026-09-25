; Inno Setup 6 Script for Markazi System Checker
; Production Installer Generation for Windows 64-bit

#define MyAppName "Markazi System Checker"
#define MyAppVersion "1.1.29"
#define MyAppPublisher "Markazi System"
#define MyAppExeName "MarkaziSystemChecker.exe"

[Setup]
AppId={{8B1D4F9A-4C2E-47E5-9D22-C8372651F109}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\MarkaziSystemChecker
DisableDirPage=no
UsePreviousAppDir=no
AlwaysShowDirOnReadyPage=yes
DefaultGroupName={#MyAppName}
AllowNoIcons=yes
OutputDir=..\dist
OutputBaseFilename=MarkaziSystemChecker-Setup
SetupIconFile=app_icon.ico
WizardSmallImageFile=wizard_small.bmp
WizardImageFile=wizard_large.bmp
UninstallDisplayIcon={app}\{#MyAppExeName}
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0
PrivilegesRequired=admin
DisableProgramGroupPage=no
CloseApplications=no
RestartApplications=no
RestartIfNeededByRun=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
; Main Flutter Windows Release Binaries
Source: "..\frontend\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

; Configuration and Corporate Presets
Source: "..\config\*"; DestDir: "{app}\config"; Flags: ignoreversion recursesubdirs createallsubdirs

[InstallDelete]
; Remove the obsolete one-file backend and any stale native runtime from 1.1.0.
Type: files; Name: "{app}\backend_server.exe"
Type: files; Name: "{app}\ucrtbase.dll"
Type: files; Name: "{app}\d3dcompiler_47.dll"
Type: filesandordirs; Name: "{app}\backend"

[Dirs]
Name: "{app}\logs"; Permissions: users-full
Name: "{app}\data"; Permissions: users-full
Name: "{app}\config"; Permissions: users-full
Name: "{app}\Packages"; Permissions: users-full

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\{#MyAppExeName}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon; IconFilename: "{app}\{#MyAppExeName}"

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent runascurrentuser

[Code]
function KillAppProcesses(): Boolean;
var
  ResultCode: Integer;
begin
  // Force terminate any running instances of Markazi System Checker or backend silently
  Exec('taskkill.exe', '/F /IM MarkaziSystemChecker.exe /IM backend_server.exe /T', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  Sleep(200);
  Result := True;
end;

function InitializeSetup(): Boolean;
begin
  KillAppProcesses();
  Result := True;
end;

procedure InitializeWizard();
begin
  KillAppProcesses();
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssInstall then
  begin
    KillAppProcesses();
    Sleep(250);
  end;
end;
