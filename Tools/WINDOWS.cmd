@echo off
setlocal EnableDelayedExpansion
title Windows KMS Activation Tool - Markazi System
color 0A

echo ============================================================================
echo   Microsoft Windows KMS Automatic Activation Tool (WINDOWS)
echo ============================================================================
echo.

:: Accept input 1 from pipe or argument or default
set "CHOICE=1"
if not "%~1"=="" set "CHOICE=%~1"

:: Try standard activation first
echo [INFO] Attempting Windows Activation...
cscript //nologo %windir%\system32\slmgr.vbs /ato >nul 2>&1

:: Check if already licensed
for /f "tokens=*" %%A in ('cscript //nologo %windir%\system32\slmgr.vbs /dli') do (
    echo %%A | findstr /i "License Status: Licensed" >nul 2>&1
    if !errorlevel! equ 0 (
        echo [SUCCESS] Windows is already fully licensed and activated!
        goto :DONE
    )
)

:: If not activated, install appropriate KMS GVLK Key
echo [INFO] Installing Windows Volume KMS Client GVLK Key...
set "WIN_KEYS=NPPR9-FWDCX-D2C8J-H872K-2YT43 W269N-WFGWX-YVC9B-4J6C9-T83GX NW6C2-QMPVW-D7KKK-3GKT6-VCFB2 TX9XD-98N7V-6WMQ6-BX7FG-H8Q99"
for %%K in (!WIN_KEYS!) do (
    cscript //nologo %windir%\system32\slmgr.vbs /ipk %%K >nul 2>&1
)

:: Set KMS Servers
set "SERVERS=kms.03k.org kms.srv.crabdance.com kms8.msguides.com kms.digiboy.ir kms.cangshui.net 127.0.0.1"
for %%S in (!SERVERS!) do (
    echo [INFO] Trying KMS Server: %%S ...
    cscript //nologo %windir%\system32\slmgr.vbs /skms %%S >nul 2>&1
    cscript //nologo %windir%\system32\slmgr.vbs /ato >nul 2>&1
    
    for /f "tokens=*" %%A in ('cscript //nologo %windir%\system32\slmgr.vbs /dli') do (
        echo %%A | findstr /i "License Status: Licensed" >nul 2>&1
        if !errorlevel! equ 0 (
            echo [SUCCESS] Windows activated successfully with KMS Server %%S!
            goto :DONE
        )
    )
)

:DONE
echo.
echo ============================================================================
echo   Current Windows Licensing Status:
echo ============================================================================
cscript //nologo %windir%\system32\slmgr.vbs /dli
echo.

exit /b 0
