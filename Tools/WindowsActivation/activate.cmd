@echo off
rem ============================================================================
rem Markazi System Checker - Windows Activation Script
rem Organization / Corporate Volume & KMS Activation Entry Point
rem ============================================================================

echo [INFO] Starting Windows activation process...
echo [INFO] Contacting configured licensing service / KMS...

rem Standard Windows activation trigger
cscript //nologo %windir%\system32\slmgr.vbs /ato

set EXIT_CODE=%ERRORLEVEL%
if %EXIT_CODE% equ 0 (
    echo [SUCCESS] Windows activation command completed successfully.
) else (
    echo [WARNING] Windows activation returned status code %EXIT_CODE%.
)

exit /b %EXIT_CODE%
