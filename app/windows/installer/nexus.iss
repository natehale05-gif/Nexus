; Inno Setup script for the NEXUS Windows installer.
;
; Produces a real setup.exe - Start Menu entry, optional desktop shortcut, and
; an uninstaller registered in Add/Remove Programs - rather than a zip the user
; has to unpack and keep track of.
;
; Built by .github/workflows/release.yml:
;   iscc /DAppVersion=1.2.3 /DBuildDir=..\..\build\windows\x64\runner\Release \
;        /DOutputDir=..\..\..\dist app\windows\installer\nexus.iss
;
; PrivilegesRequired=lowest is deliberate: the app is unsigned, and asking for
; a UAC elevation prompt on an unsigned installer is exactly the sequence that
; makes people (rightly) bail out. Installing per-user into
; %LOCALAPPDATA%\Programs needs no elevation and no admin account.

#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif
#ifndef BuildDir
  #define BuildDir "..\..\build\windows\x64\runner\Release"
#endif
#ifndef OutputDir
  #define OutputDir "..\..\..\dist"
#endif

#define AppName "NEXUS"
#define AppExeName "nexus_app.exe"

[Setup]
AppId={{8E4C1A62-3F17-4B2E-9D5A-7C0B6E1F2A84}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher=NEXUS
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
; Nothing to configure, so don't make the user click through a wizard.
DisableDirPage=auto
; No Architectures* directives on purpose: they'd pin us to Inno Setup 6.3+,
; and they buy nothing here. With PrivilegesRequired=lowest, {autopf} resolves
; to {localappdata}\Programs regardless of the installer's own bitness.
PrivilegesRequired=lowest
OutputDir={#OutputDir}
OutputBaseFilename=NEXUS-windows-x64-setup
SetupIconFile=..\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#AppExeName}
UninstallDisplayName={#AppName}
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
; Refuse to run the 32-bit-only path; the Flutter build is x64.
MinVersion=10.0

[Tasks]
Name: "desktopicon"; Description: "Create a &desktop shortcut"; GroupDescription: "Additional shortcuts:"

[Files]
; The whole Release folder: the exe needs flutter_windows.dll, the plugin DLLs
; and data/ (icudtl.dat + the AOT app snapshot) beside it.
Source: "{#BuildDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExeName}"
Name: "{group}\Uninstall {#AppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExeName}"; Description: "Launch {#AppName}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
; Flutter writes its shader/engine cache next to the install; leave the user's
; paired-server credentials and downloaded media alone (those live in
; %APPDATA%, deliberately, so a reinstall doesn't re-pair every device).
Type: filesandordirs; Name: "{app}\data\flutter_assets"
