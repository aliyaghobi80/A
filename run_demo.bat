@echo off
title Central System Checker - Demo Launcher
echo =======================================================
echo     Central System Checker / مرکزی سیستم چکر - Demo
echo =======================================================
echo.

:: Check if Python is installed
python --version >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Python is not found in PATH. Please install Python 3.9+.
    pause
    exit /b 1
)

:: Check if backend is already listening on port 18080
netstat -ano | findstr :18080 >nul 2>&1
if %errorlevel% neq 0 (
    echo [1/2] Starting Python system inspection backend (port 18080)...
    start /min "Central System Checker Backend" cmd /c "python backend\main.py --port 18080"
    timeout /t 2 /nobreak >nul
) else (
    echo [1/2] Python backend already active on port 18080.
)

:: Launch Flutter application
echo [2/2] Launching Central System Checker Desktop App...
if exist "frontend\build\windows\x64\runner\Release\CentralSystemChecker.exe" (
    start "" "frontend\build\windows\x64\runner\Release\CentralSystemChecker.exe"
) else if exist "frontend\build\windows\x64\runner\Release\central_system_checker.exe" (
    start "" "frontend\build\windows\x64\runner\Release\central_system_checker.exe"
) else if exist "frontend\build\windows\x64\runner\Release\pc_system_inspector.exe" (
    start "" "frontend\build\windows\x64\runner\Release\pc_system_inspector.exe"
) else if exist "frontend\build\windows\x64\runner\Debug\central_system_checker.exe" (
    start "" "frontend\build\windows\x64\runner\Debug\central_system_checker.exe"
) else if exist "frontend\build\windows\x64\runner\Debug\pc_system_inspector.exe" (
    start "" "frontend\build\windows\x64\runner\Debug\pc_system_inspector.exe"
) else (
    echo Running via Flutter CLI...
    cd frontend
    flutter run -d windows
)

echo.
echo Application started!
