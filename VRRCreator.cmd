@echo off
REM ============================================================================
REM  VRR CREATOR — VR Realms Creator Kit manager
REM
REM  Double-click this file. A window opens listing every kit release, marks the
REM  one you have installed, and installs whichever you pick — about 1 MB
REM  instead of re-downloading the whole 1.2 GB kit, because the sample Content
REM  almost never changes.
REM
REM  It will NEVER touch your own maps or avatars. Everything it writes lives
REM  inside VRRealms\Plugins\VRRealmsCreatorKit\.
REM
REM  Close Unreal Editor first — the kit's plugin file is locked while it's open.
REM
REM  -console  runs the plain text version instead of the window.
REM ============================================================================
setlocal
cd /d "%~dp0"

if /I "%~1"=="-console" goto :console

REM -STA is required for WPF. Windows PowerShell 5.1 defaults to it, but saying
REM so explicitly means this still works if that ever changes or a different
REM host launches it.
powershell -NoProfile -STA -ExecutionPolicy Bypass -File "%~dp0Tools\VRRCreator-App.ps1"
if %ERRORLEVEL% EQU 0 goto :done

echo.
echo [VRR Creator] The window could not open. Falling back to text mode...
echo.

:console
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Tools\VRRCreator-Update.ps1"
echo.
echo Press any key to close.
pause >nul

:done
endlocal
