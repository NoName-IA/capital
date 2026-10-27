; Instalador de Capital (Inno Setup 6). Primero exporta el juego a export/Capital.exe con el preset
; "Windows Desktop" y después compila este archivo: queda export/Capital-Setup.exe, que es lo que se comparte.
; Para armarlo todo de una (exportar, firmar y compilar): armar.ps1. Se instala solo para el usuario (sin pedir
; permisos de administrador) y crea accesos directos.

#define AppName "Capital"
#define AppVersion "1.0.0"

[Setup]
AppId={{6C2E8B1A-4F3D-4E7A-9C51-CA91A7A1D0B2}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher=NoName-IA
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
OutputDir=..\..\export
OutputBaseFilename=Capital-Setup
SetupIconFile=capital_setup.ico
SignTool=capital
SignedUninstaller=yes
UninstallDisplayIcon={app}\capital.ico
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

[Languages]
Name: "es"; MessagesFile: "compiler:Languages\Spanish.isl"
Name: "en"; MessagesFile: "compiler:Default.isl"
Name: "pt"; MessagesFile: "compiler:Languages\BrazilianPortuguese.isl"
Name: "ru"; MessagesFile: "compiler:Languages\Russian.isl"
Name: "de"; MessagesFile: "compiler:Languages\German.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "..\..\export\Capital.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\..\assets\icono\capital.ico"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\Capital.exe"; IconFilename: "{app}\capital.ico"
Name: "{group}\{cm:UninstallProgram,{#AppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\Capital.exe"; IconFilename: "{app}\capital.ico"; Tasks: desktopicon

[Run]
Filename: "{app}\Capital.exe"; Description: "{cm:LaunchProgram,{#AppName}}"; Flags: nowait postinstall skipifsilent
