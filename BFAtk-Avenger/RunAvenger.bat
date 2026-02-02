@echo off
:: =========================================================
:: CONFIGURATION FLAG
:: Set to 1: DEBUG MODE (Output to Screen AND Log File)
:: Set to 0: SILENT MODE (No Output, No Log File)
:: =========================================================
set ENABLE_LOGGING=0

:: =========================================================
:: 1. SETUP & ADMIN CHECK
:: =========================================================
pushd "%~dp0"

net session >nul 2>&1
if %errorLevel% neq 0 goto :AdminFailed

if "%ENABLE_LOGGING%"=="1" goto :RunDebug
goto :RunSilent

:: =========================================================
:: ERROR HANDLER
:: =========================================================
:AdminFailed
if "%ENABLE_LOGGING%"=="1" (
    echo [CRITICAL ERROR] %date% %time% - Script failed to start. >> debug_scheduler.log
    echo REASON: Administrator privileges are required. >> debug_scheduler.log
)
echo.
echo [CRITICAL ERROR] Administrator privileges are required.
echo Please Right-Click this file and select 'Run as Administrator'.
echo.
pause
goto :End

:: =========================================================
:: MODE 1: DEBUG (Visible + Log File)
:: =========================================================
:RunDebug
echo Starting run at %date% %time% >> debug_scheduler.log

:: FIX: Replaced Tee-Object with a loop to support ASCII Encoding on all Windows versions
powershell.exe -ExecutionPolicy Bypass -Command "& { . '.\BlockAttackers.ps1' } *>&1 | ForEach-Object { Write-Host $_; $_ | Out-File 'debug_scheduler.log' -Append -Encoding ASCII }"

echo Finished run at %date% %time% >> debug_scheduler.log
echo ------------------------------------- >> debug_scheduler.log
goto :End

:: =========================================================
:: MODE 0: SILENT (Task Scheduler Default)
:: =========================================================
:RunSilent
powershell.exe -ExecutionPolicy Bypass -File ".\BlockAttackers.ps1" >nul 2>&1
goto :End

:: =========================================================
:: CLEANUP
:: =========================================================
:End
popd
exit /b 0
