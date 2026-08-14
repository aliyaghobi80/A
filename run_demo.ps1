# PC System Inspector - Demo Launcher (PowerShell)
Write-Host "=======================================================" -ForegroundColor Cyan
Write-Host "         PC System Inspector - Phase 1 Demo            " -ForegroundColor Cyan
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

# Check Frontend executable
$releaseExe = "frontend\build\windows\x64\runner\Release\pc_system_inspector.exe"
$debugExe = "frontend\build\windows\x64\runner\Debug\pc_system_inspector.exe"

if (Test-Path $releaseExe) {
    Write-Host "[2/2] Launching Windows Desktop Application (Release)..." -ForegroundColor Green
    Start-Process $releaseExe
} elseif (Test-Path $debugExe) {
    Write-Host "[2/2] Launching Windows Desktop Application (Debug)..." -ForegroundColor Green
    Start-Process $debugExe
} else {
    Write-Host "[2/2] Running via Flutter CLI..." -ForegroundColor Yellow
    Set-Location frontend
    flutter run -d windows
}

Write-Host "`nPC System Inspector launched successfully!" -ForegroundColor Cyan
