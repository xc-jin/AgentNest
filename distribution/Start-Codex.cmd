@echo off
setlocal
set "CODEX_START_PS=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
if exist "%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe" set "CODEX_START_PS=%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe"
"%CODEX_START_PS%" -NoProfile -ExecutionPolicy Bypass -File "%~dp0Start-Codex.ps1"
if errorlevel 1 pause
