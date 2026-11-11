@echo off
setlocal
set "PS7=pwsh.exe"
if exist "%LOCALAPPDATA%\Microsoft\WindowsApps\pwsh.exe" set "PS7=%LOCALAPPDATA%\Microsoft\WindowsApps\pwsh.exe"
if exist "%ProgramFiles%\PowerShell\7\pwsh.exe" set "PS7=%ProgramFiles%\PowerShell\7\pwsh.exe"
"%PS7%" -NoLogo -NoProfile -ExecutionPolicy RemoteSigned -File "%~dp0Build-APK.ps1" %*
set "BUILD_EXIT=%ERRORLEVEL%"
if not "%BUILD_EXIT%"=="0" echo APK build failed. Exit code: %BUILD_EXIT%
if "%~1"=="" pause
exit /b %BUILD_EXIT%
