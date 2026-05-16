@echo off
chcp 65001 > nul
setlocal EnableExtensions

cd /d "%~dp0"

set "SCRIPT_DIR=%~dp0"
for %%I in ("%SCRIPT_DIR%..") do set "ROOT_DIR=%%~fI"

set "PS_DIR=%SCRIPT_DIR%powershell"

rem GitHub raw path for the PowerShell folder.
rem Local expected path is: script\powershell
rem GitHub expected path is: powershell
set "GITHUB_PS_BASE=https://raw.githubusercontent.com/SomostVE/KyuHachiGe/main/powershell"

set "PLAYNITE_URL=https://playnite.link"
set "RETROARCH_URL=https://www.retroarch.com/index.php?page=platforms"

call :BOOTSTRAP

:MENU
cls
call :BANNER

echo [1] Check environment
echo [2] Download patched library
echo [3] Check patched games library update
echo [4] Download Playnite (to list your games)
echo [5] Download RetroArch portable 64bit (for emulation)
echo.
echo [O] Download original games
echo [Q] Quit
echo.

set "CHOICE="
set /p "CHOICE=Select an option: "

if /I "%CHOICE%"=="1" call :RUN_PS "00_check_environment.ps1"
if /I "%CHOICE%"=="2" call :RUN_PS "01_download_patched_library.ps1"
if /I "%CHOICE%"=="3" call :RUN_PS "02_check_patched_games_update.ps1"
if /I "%CHOICE%"=="4" call :OPEN_URL "%PLAYNITE_URL%" "Playnite"
if /I "%CHOICE%"=="5" call :OPEN_URL "%RETROARCH_URL%" "RetroArch platforms page - choose Download (64bit)"
if /I "%CHOICE%"=="O" call :RUN_PS "90_download_original_games.ps1"
if /I "%CHOICE%"=="Q" goto END

goto MENU

:BOOTSTRAP
if not exist "%ROOT_DIR%\emulator" mkdir "%ROOT_DIR%\emulator" > nul 2> nul
if not exist "%ROOT_DIR%\frontend" mkdir "%ROOT_DIR%\frontend" > nul 2> nul
if not exist "%PS_DIR%" mkdir "%PS_DIR%" > nul 2> nul

call :ENSURE_PS "00_check_environment.ps1"
call :ENSURE_PS "01_download_patched_library.ps1"
call :ENSURE_PS "02_check_patched_games_update.ps1"
call :ENSURE_PS "90_download_original_games.ps1"

exit /b 0

:ENSURE_PS
set "PS_FILE=%~1"

if exist "%PS_DIR%\%PS_FILE%" exit /b 0

echo Missing %PS_FILE%
echo Downloading from GitHub...

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ErrorActionPreference='Stop'; [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -UseBasicParsing -Uri '%GITHUB_PS_BASE%/%PS_FILE%' -OutFile '%PS_DIR%\%PS_FILE%'"

if errorlevel 1 (
    echo [WARN] Could not download %PS_FILE%
    echo        Check GITHUB_PS_BASE in KyuHachiGe.bat after publishing the GitHub repository.
    echo.
) else (
    echo [OK] Downloaded %PS_FILE%
)

exit /b 0

:BANNER
echo ============================================================
echo   ____   ____        ___   ___
echo  ^|  _ \ / ___^|      / _ \ ( _ )
echo  ^| ^|_) ^| ^|   _____ ^| (_) ^|/ _ \
echo  ^|  __/^| ^|__^|_____  \__, ^| (_) ^|
echo  ^|_^|    \____^|       /_/  \___/
echo.
echo                    KyuHachiGe
echo      NEC PC-98 ENGLISH GAME LIBRARY BUILDER
echo ============================================================
echo.
exit /b 0

:OPEN_URL
cls
call :BANNER
echo Opening:
echo %~2
echo.
echo %~1
echo.
start "" "%~1"
pause
goto MENU

:RUN_PS
set "PS_FILE=%~1"

if not exist "%PS_DIR%" (
    cls
    call :BANNER
    echo ERROR: PowerShell folder not found:
    echo "%PS_DIR%"
    echo.
    pause
    goto MENU
)

if not exist "%PS_DIR%\%PS_FILE%" (
    cls
    call :BANNER
    echo ERROR: PowerShell script not found:
    echo "%PS_DIR%\%PS_FILE%"
    echo.
    echo Restart KyuHachiGe.bat or check your GitHub raw path:
    echo %GITHUB_PS_BASE%
    echo.
    pause
    goto MENU
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PS_DIR%\%PS_FILE%"

echo.
pause
goto MENU

:END
endlocal
exit /b 0
