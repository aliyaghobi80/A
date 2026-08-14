# Central System Checker - Demo Launcher (PowerShell)
Write-Host "=======================================================" -ForegroundColor Cyan
Write-Host "    Central System Checker / مرکزی سیستم چکر - Demo    " -ForegroundColor Cyan
Write-Host "=======================================================" -ForegroundColor Cyan

# Verify Python
try {
    $pyVer = python --version 2>&1
    Write-Host "[OK] Detected $pyVer" -ForegroundColor Green
} catch {
    Write-Error "[ERROR] Python not found in PATH."
    exit 1
}

# Check Backend
$portActive = (Get-NetTCPConnection -LocalPort 18080 -ErrorAction SilentlyContinue)
if (-not $portActive) {
    Write-Host "[1/2] Starting Python backend service (port 18080)..." -ForegroundColor Yellow
    Start-Process python -ArgumentList "backend\main.py --port 18080" -WindowStyle Hidden
    Start-Sleep -Seconds 2
} else {
    Write-Host "[1/2] Python backend already active on port 18080." -ForegroundColor Green
}

$releaseExeMain = "frontend\build\windows\x64\runner\Release\CentralSystemChecker.exe"
$releaseExeNew = "frontend\build\windows\x64\runner\Release\central_system_checker.exe"
$releaseExeOld = "frontend\build\windows\x64\runner\Release\pc_system_inspector.exe"
$debugExeNew = "frontend\build\windows\x64\runner\Debug\central_system_checker.exe"
$debugExeOld = "frontend\build\windows\x64\runner\Debug\pc_system_inspector.exe"

if (Test-Path $releaseExeMain) {
    Write-Host "[2/2] Launching Windows Desktop Application (Release)..." -ForegroundColor Green
    Start-Process $releaseExeMain
} elseif (Test-Path $releaseExeNew) {
    Write-Host "[2/2] Launching Windows Desktop Application (Release)..." -ForegroundColor Green
    Start-Process $releaseExeNew
} elseif (Test-Path $releaseExeOld) {
    Write-Host "[2/2] Launching Windows Desktop Application (Release)..." -ForegroundColor Green
    Start-Process $releaseExeOld
} elseif (Test-Path $debugExeNew) {
    Write-Host "[2/2] Launching Windows Desktop Application (Debug)..." -ForegroundColor Green
    Start-Process $debugExeNew
} elseif (Test-Path $debugExeOld) {
    Write-Host "[2/2] Launching Windows Desktop Application (Debug)..." -ForegroundColor Green
    Start-Process $debugExeOld
} else {
    Write-Host "[2/2] Running via Flutter CLI..." -ForegroundColor Yellow
    Set-Location frontend
    flutter run -d windows
}

Write-Host "`nCentral System Checker launched successfully!" -ForegroundColor Cyan
