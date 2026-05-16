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

if /I "%CHOICE%"=="1" goto CONFIRM_CHECK_ENVIRONMENT
if /I "%CHOICE%"=="2" goto CONFIRM_DOWNLOAD_PATCHED_LIBRARY
if /I "%CHOICE%"=="3" goto CONFIRM_CHECK_PATCHED_UPDATE
if /I "%CHOICE%"=="4" goto CONFIRM_PLAYNITE
if /I "%CHOICE%"=="5" goto CONFIRM_RETROARCH
if /I "%CHOICE%"=="O" goto CONFIRM_ORIGINAL_GAMES
if /I "%CHOICE%"=="Q" goto END

goto MENU

:BOOTSTRAP
if not exist "%ROOT_DIR%\emulator" mkdir "%ROOT_DIR%\emulator" > nul 2> nul
if not exist "%ROOT_DIR%\frontend" mkdir "%ROOT_DIR%\frontend" > nul 2> nul
if not exist "%PS_DIR%" mkdir "%PS_DIR%" > nul 2> nul

if exist "%PS_DIR%\00_check_environment.ps1" if exist "%PS_DIR%\01_download_patched_library.ps1" if exist "%PS_DIR%\02_check_patched_games_update.ps1" if exist "%PS_DIR%\90_download_original_games.ps1" exit /b 0

cls
call :BANNER

echo PowerShell scripts setup notice
echo.
echo Some required PowerShell scripts are missing.
echo.
echo KyuHachiGe uses a local PowerShell folder here:
echo "%PS_DIR%"
echo.
echo Missing scripts will be downloaded from GitHub:
echo %GITHUB_PS_BASE%
echo.
echo Required scripts:
echo - 00_check_environment.ps1
echo - 01_download_patched_library.ps1
echo - 02_check_patched_games_update.ps1
echo - 90_download_original_games.ps1
echo.
echo Existing scripts will be kept.
echo Only missing scripts will be downloaded.
echo.
echo These files are required by the menu options.
echo.

call :ASK_YN "Proceed with downloading missing PowerShell scripts?"
if errorlevel 1 goto END

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
echo     https://github.com/SomostVE/KyuHachiGe
echo      NEC PC-98 ENGLISH GAME LIBRARY BUILDER
echo ============================================================
echo.
exit /b 0

:ASK_YN
set "ANSWER="
set /p "ANSWER=%~1 [Y/N]: "

if /I "%ANSWER%"=="Y" exit /b 0
if /I "%ANSWER%"=="YES" exit /b 0
if /I "%ANSWER%"=="N" exit /b 1
if /I "%ANSWER%"=="NO" exit /b 1

echo Please type Y or N, then press Enter.
goto ASK_YN

:CONFIRM_CHECK_ENVIRONMENT
cls
call :BANNER
echo Option [1] Check environment
echo.
echo This option will run:
echo 00_check_environment.ps1
echo.
echo It will check if the expected local folders and required files exist.
echo It can verify folders such as emulator, frontend, script, and powershell.
echo.
echo It will not download the game library.
echo It will not download original games.
echo It will not modify your PC-98 games.
echo.
call :ASK_YN "Run this option?"
if errorlevel 1 goto MENU
call :RUN_PS "00_check_environment.ps1"
goto MENU

:CONFIRM_DOWNLOAD_PATCHED_LIBRARY
cls
call :BANNER
echo Option [2] Download patched library
echo.
echo This option will run:
echo 01_download_patched_library.ps1
echo.
echo It will download or update the ready-to-use English patched PC-98 library.
echo The downloaded files will be stored inside the portable KyuHachiGe folder structure.
echo.
echo Depending on the library size and your connection, this can take time.
echo Make sure you have enough disk space before continuing.
echo.
echo It will not download the original unpatched game archive.
echo.
call :ASK_YN "Run this option?"
if errorlevel 1 goto MENU
call :RUN_PS "01_download_patched_library.ps1"
goto MENU

:CONFIRM_CHECK_PATCHED_UPDATE
cls
call :BANNER
echo Option [3] Check patched games library update
echo.
echo This option will run:
echo 02_check_patched_games_update.ps1
echo.
echo It will check whether the patched PC-98 game library has updates available.
echo It is meant to compare the local patched library with the available remote version.
echo.
echo It should not download the original game archive.
echo It should not modify your original PC-98 files.
echo.
call :ASK_YN "Run this option?"
if errorlevel 1 goto MENU
call :RUN_PS "02_check_patched_games_update.ps1"
goto MENU

:CONFIRM_PLAYNITE
cls
call :BANNER
echo Option [4] Download Playnite
echo.
echo This option will open the Playnite website in your browser:
echo %PLAYNITE_URL%
echo.
echo Playnite is used to display your games as a local library,
echo similar to Steam or GOG.
echo.
echo This launcher will only open the website.
echo You will download and install or extract Playnite manually.
echo.
call :ASK_YN "Open Playnite website?"
if errorlevel 1 goto MENU
call :OPEN_URL "%PLAYNITE_URL%" "Playnite"
goto MENU

:CONFIRM_RETROARCH
cls
call :BANNER
echo Option [5] Download RetroArch portable 64bit
echo.
echo This option will open the RetroArch platforms page in your browser:
echo %RETROARCH_URL%
echo.
echo RetroArch is used for emulation.
echo For PC-98, you will use the Neko Project II Kai core.
echo.
echo This launcher will only open the website.
echo Choose the Windows 64bit download manually.
echo.
call :ASK_YN "Open RetroArch website?"
if errorlevel 1 goto MENU
call :OPEN_URL "%RETROARCH_URL%" "RetroArch platforms page - choose Download (64bit)"
goto MENU

:CONFIRM_ORIGINAL_GAMES
cls
call :BANNER
echo Option [O] Download original games
echo.
echo This option will run:
echo 90_download_original_games.ps1
echo.
echo It will download the original PC-98 game archive.
echo It is large ^(80 GB^).
echo.
echo Use this option only if you want the original unpatched game files.
echo This can take a long time and requires a lot of disk space.
echo.
call :ASK_YN "Run this option?"
if errorlevel 1 goto MENU
call :RUN_PS "90_download_original_games.ps1"
goto MENU

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
