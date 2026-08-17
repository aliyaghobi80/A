@echo off
setlocal

:: Find pythonw for completely windowless backend execution
set "PYTHONW_BIN="
where pythonw >nul 2>&1 && set "PYTHONW_BIN=pythonw"
if not defined PYTHONW_BIN if exist "G:\python\pythonw.exe" set "PYTHONW_BIN=G:\python\pythonw.exe"
if not defined PYTHONW_BIN if exist "C:\Python314\pythonw.exe" set "PYTHONW_BIN=C:\Python314\pythonw.exe"
if not defined PYTHONW_BIN if exist "C:\Python312\pythonw.exe" set "PYTHONW_BIN=C:\Python312\pythonw.exe"
if not defined PYTHONW_BIN if exist "C:\Python311\pythonw.exe" set "PYTHONW_BIN=C:\Python311\pythonw.exe"
if not defined PYTHONW_BIN if exist "C:\Program Files\Python312\pythonw.exe" set "PYTHONW_BIN=C:\Program Files\Python312\pythonw.exe"
if not defined PYTHONW_BIN set "PYTHONW_BIN=pythonw"

:: Check if backend service is already active on port 18088
netstat -ano | findstr :18088 >nul 2>&1
if %errorlevel% neq 0 (
    start "" "%PYTHONW_BIN%" "%~dp0backend\main.py" --port 18088
    timeout /t 1 /nobreak >nul
)

:: Launch Flutter Desktop Application
if exist "%~dp0frontend\build\windows\x64\runner\Release\CentralSystemChecker.exe" (
    start "" /D "%~dp0frontend\build\windows\x64\runner\Release" "CentralSystemChecker.exe"
    exit 0
)

if exist "%~dp0frontend\build\windows\x64\runner\Release\central_system_checker.exe" (
    start "" /D "%~dp0frontend\build\windows\x64\runner\Release" "central_system_checker.exe"
    exit 0
)

cd /d "%~dp0frontend"
flutter run -d windows
exit 0
