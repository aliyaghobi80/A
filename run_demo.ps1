# Markazi System Checker - Silent Demo Launcher (PowerShell)
$portActive = (Get-NetTCPConnection -LocalPort 18088 -ErrorAction SilentlyContinue)
if (-not $portActive) {
    if (Get-Command pythonw -ErrorAction SilentlyContinue) {
        Start-Process pythonw -ArgumentList "backend\main.py --port 18088" -WindowStyle Hidden
    } else {
        Start-Process python -ArgumentList "backend\main.py --port 18088" -WindowStyle Hidden
    }
    Start-Sleep -Seconds 1
}

$releaseExe = Join-Path $PSScriptRoot "frontend\build\windows\x64\runner\Release\MarkaziSystemChecker.exe"
if (Test-Path $releaseExe) {
    Start-Process $releaseExe -WorkingDirectory (Split-Path $releaseExe -Parent)
} else {
    Write-Host "[ERROR] Release executable not found at: '$releaseExe'" -ForegroundColor Red
    Write-Host "Please build the application before launching (py build_production.py or flutter build windows --release)." -ForegroundColor Yellow
    exit 1
}
