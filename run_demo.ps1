# Central System Checker - Silent Demo Launcher (PowerShell)
$portActive = (Get-NetTCPConnection -LocalPort 18088 -ErrorAction SilentlyContinue)
if (-not $portActive) {
    if (Get-Command pythonw -ErrorAction SilentlyContinue) {
        Start-Process pythonw -ArgumentList "backend\main.py --port 18088" -WindowStyle Hidden
    } else {
        Start-Process python -ArgumentList "backend\main.py --port 18088" -WindowStyle Hidden
    }
    Start-Sleep -Seconds 1
}

$releaseExe = "frontend\build\windows\x64\runner\Release\CentralSystemChecker.exe"
if (Test-Path $releaseExe) {
    Start-Process $releaseExe -WorkingDirectory "frontend\build\windows\x64\runner\Release"
} else {
    Set-Location frontend
    flutter run -d windows
}
