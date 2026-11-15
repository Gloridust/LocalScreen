; Inno Setup script for the Windows installer.
;   iscc /DAppVersion=0.1.0 packaging\windows\installer.iss
; Expects the Flutter release build in build\windows\x64\runner\Release.

#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif
#define AppName "LocalScreen"
#define AppExe "localscreen.exe"
#define Root "..\.."

[Setup]
AppId={{6B0E7C0E-3C0B-4D0A-9B56-5E1B3A7C9F21}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppName}
AppPublisherURL=https://github.com/Gloridust/LocalScreen
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
; Installs per user by default, so no administrator prompt is needed.
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
SetupIconFile={#Root}\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#AppExe}
OutputDir={#Root}\build
OutputBaseFilename=LocalScreen-{#AppVersion}-windows-x64-setup
Compression=lzma2
SolidCompression=yes
WizardStyle=modern

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#Root}\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs ignoreversion

[Icons]
Name: "{autoprograms}\{#AppName}"; Filename: "{app}\{#AppExe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExe}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExe}"; Description: "{cm:LaunchProgram,{#AppName}}"; Flags: nowait postinstall skipifsilent
