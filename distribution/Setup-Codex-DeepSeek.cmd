@echo off
setlocal
title Codex + DeepSeek Setup
set "CODEX_SETUP_PS=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
if exist "%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe" set "CODEX_SETUP_PS=%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe"
"%CODEX_SETUP_PS%" -NoProfile -ExecutionPolicy Bypass -File "%~dp0Setup-Codex-DeepSeek.ps1"
set "CODEX_SETUP_EXIT=%ERRORLEVEL%"
echo.
if not "%CODEX_SETUP_EXIT%"=="0" echo Setup stopped. Read the error above. Installation log: "%LOCALAPPDATA%\CodexDeepSeekSetup\codex-install.log"
pause
exit /b %CODEX_SETUP_EXIT%
