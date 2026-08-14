@echo off
rem ============================================================================
rem Markazi System Checker - Microsoft Office Activation Script
rem Organization / Corporate Volume & KMS Activation Entry Point
rem ============================================================================

echo [INFO] Starting Microsoft Office activation process...

set OSPP_FOUND=0

rem Check Click-to-Run and standard ospp.vbs locations
if exist "%ProgramFiles%\Microsoft Office\root\Office16\ospp.vbs" (
    echo [INFO] Found Office Click-to-Run ospp.vbs in Program Files
    cscript //nologo "%ProgramFiles%\Microsoft Office\root\Office16\ospp.vbs" /act
    set OSPP_FOUND=1
) else if exist "%ProgramFiles(x86)%\Microsoft Office\root\Office16\ospp.vbs" (
    echo [INFO] Found Office Click-to-Run ospp.vbs in Program Files (x86)
    cscript //nologo "%ProgramFiles(x86)%\Microsoft Office\root\Office16\ospp.vbs" /act
    set OSPP_FOUND=1
) else if exist "%ProgramFiles%\Microsoft Office\Office16\ospp.vbs" (
    echo [INFO] Found Office 16/2019/2021/2024 ospp.vbs in Program Files
    cscript //nologo "%ProgramFiles%\Microsoft Office\Office16\ospp.vbs" /act
    set OSPP_FOUND=1
) else if exist "%ProgramFiles(x86)%\Microsoft Office\Office16\ospp.vbs" (
    echo [INFO] Found Office 16/2019/2021/2024 ospp.vbs in Program Files (x86)
    cscript //nologo "%ProgramFiles(x86)%\Microsoft Office\Office16\ospp.vbs" /act
    set OSPP_FOUND=1
) else if exist "%ProgramFiles%\Microsoft Office\Office15\ospp.vbs" (
    echo [INFO] Found Office 15/2013 ospp.vbs in Program Files
    cscript //nologo "%ProgramFiles%\Microsoft Office\Office15\ospp.vbs" /act
    set OSPP_FOUND=1
) else if exist "%ProgramFiles(x86)%\Microsoft Office\Office15\ospp.vbs" (
    echo [INFO] Found Office 15/2013 ospp.vbs in Program Files (x86)
    cscript //nologo "%ProgramFiles(x86)%\Microsoft Office\Office15\ospp.vbs" /act
    set OSPP_FOUND=1
)

if %OSPP_FOUND% equ 0 (
    echo [WARNING] ospp.vbs not found in default paths.
)

set EXIT_CODE=%ERRORLEVEL%
if %EXIT_CODE% equ 0 (
    echo [SUCCESS] Office activation command completed successfully.
) else (
    echo [WARNING] Office activation returned status code %EXIT_CODE%.
)

exit /b %EXIT_CODE%
