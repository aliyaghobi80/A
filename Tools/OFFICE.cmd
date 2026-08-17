@echo off
setlocal EnableDelayedExpansion
title Office KMS Activation Tool - Markazi System
color 0B

echo ============================================================================
echo   Microsoft Office KMS Automatic Activation Tool (OFFICE)
echo ============================================================================
echo.

:: Accept input 1 from pipe or argument or default
set "CHOICE=1"
if not "%~1"=="" set "CHOICE=%~1"

:: Find OSPP.VBS in all known locations
set "OSPP="
if exist "%ProgramFiles%\Microsoft Office\root\Office16\OSPP.VBS" set "OSPP=%ProgramFiles%\Microsoft Office\root\Office16\OSPP.VBS"
if not defined OSPP if exist "%ProgramFiles(x86)%\Microsoft Office\root\Office16\OSPP.VBS" set "OSPP=%ProgramFiles(x86)%\Microsoft Office\root\Office16\OSPP.VBS"
if not defined OSPP if exist "%ProgramFiles%\Microsoft Office\Office16\OSPP.VBS" set "OSPP=%ProgramFiles%\Microsoft Office\Office16\OSPP.VBS"
if not defined OSPP if exist "%ProgramFiles(x86)%\Microsoft Office\Office16\OSPP.VBS" set "OSPP=%ProgramFiles(x86)%\Microsoft Office\Office16\OSPP.VBS"
if not defined OSPP if exist "%ProgramFiles%\Microsoft Office\Office15\OSPP.VBS" set "OSPP=%ProgramFiles%\Microsoft Office\Office15\OSPP.VBS"
if not defined OSPP if exist "%ProgramFiles(x86)%\Microsoft Office\Office15\OSPP.VBS" set "OSPP=%ProgramFiles(x86)%\Microsoft Office\Office15\OSPP.VBS"
if not defined OSPP if exist "%ProgramFiles%\Microsoft Office\Office14\OSPP.VBS" set "OSPP=%ProgramFiles%\Microsoft Office\Office14\OSPP.VBS"
if not defined OSPP if exist "%ProgramFiles(x86)%\Microsoft Office\Office14\OSPP.VBS" set "OSPP=%ProgramFiles(x86)%\Microsoft Office\Office14\OSPP.VBS"

if not defined OSPP (
    echo [ERROR] OSPP.VBS script could not be located. Microsoft Office might not be installed.
    exit /b 1
)

echo [INFO] Found Office Licensing Tool: "!OSPP!"

:: Find Licenses directory
set "LIC_DIR="
for %%D in ("%ProgramFiles%\Microsoft Office\root\Licenses16" "%ProgramFiles(x86)%\Microsoft Office\root\Licenses16" "%ProgramFiles%\Microsoft Office\root\Licenses15" "%ProgramFiles(x86)%\Microsoft Office\root\Licenses15") do (
    if exist "%%~D" if not defined LIC_DIR set "LIC_DIR=%%~D"
)

if defined LIC_DIR (
    echo [INFO] Installing core volume licenses from "!LIC_DIR!"...
    for %%F in ("client-issuance-root.xrm-ms" "client-issuance-root-16.xrm-ms" "client-issuance-ul.xrm-ms" "client-issuance-ul-oob.xrm-ms" "client-issuance-ppd.xrm-ms" "pkeyconfig-office.xrm-ms") do (
        if exist "!LIC_DIR!\%%~F" (
            cscript //nologo "!OSPP!" /inslic:"!LIC_DIR!\%%~F" >nul 2>&1
        )
    )
    for %%F in ("!LIC_DIR!\*ProPlus*VL_KMS*.xrm-ms" "!LIC_DIR!\*Standard*VL_KMS*.xrm-ms" "!LIC_DIR!\*ProPlus2024VL*.xrm-ms" "!LIC_DIR!\*ProPlus2021VL*.xrm-ms" "!LIC_DIR!\*ProPlus2019VL*.xrm-ms") do (
        if exist "%%~F" (
            cscript //nologo "!OSPP!" /inslic:"%%~F" >nul 2>&1
        )
    )
)

:: Install appropriate GVLK keys
echo [INFO] Applying Microsoft Volume KMS GVLK Client Keys...
set "KEYS=FXYTK-NJJ8C-GB6DW-3DYQT-6F7TH NMMKJ-6RK4F-KMJVX-8D9MJ-6MWKP XQNVK-8JYDB-WJ9W3-YJ8YR-WFG99 YC7DK-G2NP8-2QQC3-J6H88-GVGXT"
for %%K in (!KEYS!) do (
    cscript //nologo "!OSPP!" /inpkey:%%K >nul 2>&1
)

:: Try KMS Servers
echo [INFO] Connecting to KMS Activation Servers...
set "SERVERS=kms.03k.org kms.srv.crabdance.com kms8.msguides.com kms.digiboy.ir kms.cangshui.net 127.0.0.1"
set "ACTIVATED=0"

for %%S in (!SERVERS!) do (
    echo [INFO] Trying KMS Server: %%S ...
    cscript //nologo "!OSPP!" /sethst:%%S >nul 2>&1
    cscript //nologo "!OSPP!" /setprt:1688 >nul 2>&1
    
    for /f "delims=" %%R in ('cscript //nologo "!OSPP!" /act') do (
        echo %%R
        echo %%R | findstr /i "successful ---LICENSED---" >nul 2>&1
        if !errorlevel! equ 0 set "ACTIVATED=1"
    )
    
    if !ACTIVATED! equ 1 (
        echo [SUCCESS] Office activated successfully with KMS Server %%S!
        goto :DONE
    )
)

:DONE
echo.
echo ============================================================================
echo   Current Office Licensing Status:
echo ============================================================================
cscript //nologo "!OSPP!" /dstatus
echo.

exit /b 0
