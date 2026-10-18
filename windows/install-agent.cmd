@echo off
rem Starts install-agent.ps1 with the execution policy bypassed for this one process.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install-agent.ps1" %*
set "code=%errorlevel%"
rem The script waits for Enter itself when it stops (exit 2); pause on any other failure, so its words stay.
if not "%code%"=="0" if not "%code%"=="2" pause
exit /b %code%
