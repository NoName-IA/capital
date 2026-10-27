# Arma el instalador para compartir: exporta el juego, lo firma y compila export\Capital-Setup.exe (también firmado).
# Uso (desde cualquier carpeta): powershell -ExecutionPolicy Bypass -File tools\instalador\armar.ps1
$ErrorActionPreference = "Stop"
$proyecto = (Resolve-Path "$PSScriptRoot\..\..").Path
$godot = "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe"
$iscc = "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe"
$firmar = "$PSScriptRoot\firmar.ps1"

New-Item -ItemType Directory -Force "$proyecto\export" | Out-Null
Remove-Item "$proyecto\export\*" -Force -ErrorAction SilentlyContinue

# 1) El juego: solo lo de res:// (las partidas y ajustes viven en la carpeta del usuario, nunca van en el .exe)
& $godot --headless --path $proyecto --export-release "Windows Desktop" "$proyecto\export\Capital.exe" | Out-Null
if (-not (Test-Path "$proyecto\export\Capital.exe")) { throw "No se pudo exportar el juego." }

# 2) Firmarlo
& powershell -NoProfile -ExecutionPolicy Bypass -File $firmar "$proyecto\export\Capital.exe"
if ($LASTEXITCODE -ne 0) { throw "No se pudo firmar Capital.exe." }

# 3) El instalador (Inno Setup firma el instalador y el desinstalador con el mismo script)
& $iscc /Q "/Scapital=powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$firmar`" `$f" "$PSScriptRoot\capital.iss"
if ($LASTEXITCODE -ne 0) { throw "No se pudo compilar el instalador." }
Write-Output "Listo: $proyecto\export\Capital-Setup.exe"
