@echo off
setlocal
cd /d "%~dp0"
if not defined RICHMAN_GODOT_BIN set "RICHMAN_GODOT_BIN=D:\software\Godot\4.6.2\Godot_v4.6.2-stable_win64.exe"
if not exist "%RICHMAN_GODOT_BIN%" (
  echo Set RICHMAN_GODOT_BIN to your Godot 4.6 executable, or open project.godot in Godot.
  pause
  exit /b 1
)
"%RICHMAN_GODOT_BIN%" --headless --path "%~dp0." --editor --import --quit
if errorlevel 1 exit /b 1
start "" "%RICHMAN_GODOT_BIN%" --path "%~dp0."
