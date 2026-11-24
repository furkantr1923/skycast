; SKYCAST — Windows kurulum betiği (Inno Setup 6)
; CI tarafından derlenir: iscc /DAppVersion=1.0.0 /DSourceDir=... installer\skycast.iss

#ifndef AppVersion
  #define AppVersion "1.0.0"
#endif
#ifndef SourceDir
  #define SourceDir "..\build\windows\x64\runner\Release"
#endif

[Setup]
AppId={{6C1F3A52-8E7B-4D2A-9C5E-5B1A7F0D3E21}
AppName=SKYCAST
AppVersion={#AppVersion}
AppVerName=SKYCAST {#AppVersion}
AppPublisher=Furkan
AppPublisherURL=https://github.com/furkantr1923/skycast
AppSupportURL=https://github.com/furkantr1923/skycast/issues
DefaultDirName={autopf}\SKYCAST
DefaultGroupName=SKYCAST
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir=..\dist
OutputBaseFilename=SKYCAST-Setup-{#AppVersion}
SetupIconFile=..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\SKYCAST.exe
UninstallDisplayName=SKYCAST Hava Durumu
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
MinVersion=10.0

[Languages]
Name: "turkish"; MessagesFile: "compiler:Languages\Turkish.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\SKYCAST"; Filename: "{app}\SKYCAST.exe"
Name: "{group}\SKYCAST kaldır"; Filename: "{uninstallexe}"
Name: "{autodesktop}\SKYCAST"; Filename: "{app}\SKYCAST.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\SKYCAST.exe"; Description: "{cm:LaunchProgram,SKYCAST}"; Flags: nowait postinstall skipifsilent
