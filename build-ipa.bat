@echo off
chcp 65001 >nul 2>nul
title DocScan Cloud IPA Builder
cd /d "%~dp0"

echo.
echo   DocScan - Cloud IPA Builder (Windows)
echo   Building on GitHub macOS runner, no Mac needed.
echo.

where python >nul 2>nul
if %errorlevel%==0 (
    python "%~dp0tools\build_remote.py"
) else (
    py -3 "%~dp0tools\build_remote.py"
)

echo.
echo ----------------------------------------------------------
echo  Finished. Press any key to close this window.
pause >nul
