; Inno Setup 6 Script for Markazi System Checker
; Production Installer Generation for Windows 64-bit

#define MyAppName "Markazi System Checker"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "Markazi System"
#define MyAppExeName "MarkaziSystemChecker.exe"

[Setup]
AppId={{8B1D4F9A-4C2E-47E5-9D22-C8372651F109}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\MarkaziSystemChecker
DefaultGroupName={#MyAppName}
AllowNoIcons=yes
OutputDir=..\dist
OutputBaseFilename=MarkaziSystemChecker-Setup-{#MyAppVersion}
SetupIconFile=..\frontend\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#MyAppExeName}
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=admin
DisableProgramGroupPage=auto
CloseApplications=force
RestartApplications=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
; Main Flutter Windows Release Binaries
Source: "..\frontend\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

; Standalone Compiled Python Backend
Source: "..\build_backend_out\dist\backend_server.exe"; DestDir: "{app}\backend"; Flags: ignoreversion
Source: "..\build_backend_out\dist\backend_server.exe"; DestDir: "{app}"; Flags: ignoreversion

; Configuration and Corporate Presets
Source: "..\config\*"; DestDir: "{app}\config"; Flags: ignoreversion recursesubdirs createallsubdirs

; Tools and Activation Utilities
Source: "..\Tools\*"; DestDir: "{app}\Tools"; Flags: ignoreversion recursesubdirs createallsubdirs

; Software Package Installers Directory
Source: "..\Packages\*"; DestDir: "{app}\Packages"; Flags: ignoreversion recursesubdirs createallsubdirs

[Dirs]
Name: "{app}\logs"; Permissions: users-full
Name: "{app}\data"; Permissions: users-full
Name: "{app}\config"; Permissions: users-full
Name: "{app}\Tools"; Permissions: users-full
Name: "{app}\Packages"; Permissions: users-full

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[Code]
procedure InitializeWizard;
var
  ResultCode: Integer;
begin
  // Silently terminate any running instances of Markazi System Checker or backend before installation
  Exec('taskkill.exe', '/F /IM MarkaziSystemChecker.exe /IM backend_server.exe /T', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
end;

procedure CurStepChanged(CurStep: TSetupStep);
var
  ResultCode: Integer;
begin
  if CurStep = ssInstall then
  begin
    Exec('taskkill.exe', '/F /IM MarkaziSystemChecker.exe /IM backend_server.exe /T', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
    Sleep(250);
  end;
end;
