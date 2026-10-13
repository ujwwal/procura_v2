@echo off
setlocal
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -NoExit -File "%~dp0launch-windows.ps1"
if errorlevel 1 (
  echo.
  echo Procura launcher exited with an error. Read the message above or refer to docs\setup-and-architecture.md.
  pause
  exit /b 1
)
