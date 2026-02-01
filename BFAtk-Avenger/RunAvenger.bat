@echo off
:: Force the script to look at its own folder
cd /d "%~dp0"

:: =========================================================
:: CONFIGURATION FLAG
:: Set to 1: For Task Scheduler (Writes to log, NO PAUSE)
:: Set to 0: For Manual Run (Shows on screen, PAUSES at end)
:: =========================================================
set ENABLE_LOGGING=0

:: =========================================================
:: 1. ADMIN RIGHTS CHECK
:: =========================================================
net session >nul 2>&1
if %errorLevel% neq 0 (
    if "%ENABLE_LOGGING%"=="1" (
        echo [CRITICAL ERROR] %date% %time% - Script failed to start. >> debug_scheduler.log
        echo REASON: Administrator privileges are required. >> debug_scheduler.log
    ) else (
        echo [ERROR] Not running as Admin!
        echo Please Right-Click and 'Run as Administrator'.
        pause
    )
    exit /b
)

:: =========================================================
:: 2. SCRIPT LOGIC
:: =========================================================

if "%ENABLE_LOGGING%"=="1" (
    :: --- SCHEDULER MODE (Silent) ---
    echo Starting run at %date% %time% >> debug_scheduler.log
    
    :: Run PowerShell and capture output to file
    powershell.exe -ExecutionPolicy Bypass -File ".\BlockAttackers.ps1" >> debug_scheduler.log 2>&1
    
    echo Finished run at %date% %time% >> debug_scheduler.log
    echo ------------------------------------- >> debug_scheduler.log
    
    :: IMPORTANT: No 'pause' here! We want it to finish so Scheduler sees code 0x0.
    exit /b 0
) else (
    :: --- MANUAL MODE (Visual) ---
    echo Admin Rights Confirmed.
    echo Running "BlockAttackers.ps1" ...
    echo.
    
    powershell.exe -ExecutionPolicy Bypass -File ".\BlockAttackers.ps1"
    
    echo.
    echo ----------------------------------------------------
    echo Done. Press any key to close this window.
    pause >nul
)