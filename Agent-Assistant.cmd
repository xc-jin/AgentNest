@echo off
setlocal
title AgentNest
set "AGENT_SETUP_PS=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
if exist "%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe" set "AGENT_SETUP_PS=%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe"
"%AGENT_SETUP_PS%" -NoProfile -STA -ExecutionPolicy Bypass -File "%~dp0assistant\AgentSetup.ps1"
if errorlevel 1 pause
