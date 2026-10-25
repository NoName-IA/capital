@echo off
rem Abre el proyecto en el editor de Godot para verlo o modificarlo.
start "" "%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64.exe" --editor --path "%~dp0."
