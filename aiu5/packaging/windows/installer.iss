; Installs the game and inference sidecars per user without altering player saves.
#ifndef PackageDir
  #error PackageDir must be supplied by build.ps1
#endif
#ifndef OutputDir
  #error OutputDir must be supplied by build.ps1
#endif
[Setup]
AppId={{80E89CB8-8E6B-46E1-8FD0-47690E0930C5}
AppName=沙盘上的生活
AppVersion=0.10.8
AppPublisher=AIU5
AppPublisherURL=https://github.com/syx536324-boop/aiu-interview
DefaultDirName={localappdata}\Programs\AIU5
DefaultGroupName=沙盘上的生活
UsePreviousGroup=no
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir={#OutputDir}
OutputBaseFilename=AIU5-Setup-0.10.8-win64
Compression=lzma2/normal
SolidCompression=yes
WizardStyle=modern
SetupIconFile={#SourcePath}\..\..\assets\branding\game-icon.ico
UninstallDisplayIcon={app}\game-icon.ico
CloseApplications=no
[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
[Files]
Source: "{#PackageDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
[Icons]
Name: "{group}\沙盘上的生活"; Filename: "{app}\AIU5.exe"; WorkingDir: "{app}"; IconFilename: "{app}\game-icon.ico"
Name: "{group}\卸载 沙盘上的生活"; Filename: "{uninstallexe}"
[InstallDelete]
Type: files; Name: "{userprograms}\AIU5 赤沙村\AIU5 赤沙村.lnk"
Type: files; Name: "{userprograms}\AIU5 赤沙村\卸载 AIU5.lnk"
Type: dirifempty; Name: "{userprograms}\AIU5 赤沙村"
[Run]
Filename: "{app}\AIU5.exe"; Description: "运行 沙盘上的生活"; Flags: nowait postinstall skipifsilent
