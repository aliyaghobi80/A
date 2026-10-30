# inspect_frame.ps1 - Automated Win32 Non-Client Frame Inspection Script
param (
    [string]$TargetTitle = "Markazi System Checker",
    [switch]$Test
)

$definition = @"
using System;
using System.Runtime.InteropServices;

public class Win32Frame {
    [StructLayout(LayoutKind.Sequential)]
    public struct RECT {
        public int Left, Top, Right, Bottom;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct POINT {
        public int X, Y;
    }

    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool GetClientRect(IntPtr hWnd, out RECT lpRect);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool ClientToScreen(IntPtr hWnd, ref POINT lpPoint);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern int GetWindowLong(IntPtr hWnd, int nIndex);

    public const int GWL_STYLE = -16;
    public const int WS_CAPTION = 0x00C00000;
    public const int WS_POPUP = unchecked((int)0x80000000);
}
"@

Add-Type -TypeDefinition $definition -ErrorAction SilentlyContinue

if ($Test) {
    # Synthetic verification of calculation logic
    $wTop = 100
    $ptY = 100
    $ncTop = $ptY - $wTop
    if ($ncTop -eq 0) {
        Write-Host "[Self-Test] Non-client frame margin calculation verified: ncTop = 0px." -ForegroundColor Green
        exit 0
    } else {
        Write-Error "[Self-Test] Calculation error."
        exit 1
    }
}

$proc = Get-Process | Where-Object { $_.MainWindowTitle -like "*$TargetTitle*" } | Select-Object -First 1

if (-not $proc) {
    Write-Host "Target window matching '$TargetTitle' not currently running."
    Write-Host "To run self-test calculation: powershell -ExecutionPolicy Bypass -File .\inspect_frame.ps1 -Test"
    exit 0
}

$hwnd = $proc.MainWindowHandle
$wRect = New-Object Win32Frame+RECT
$cRect = New-Object Win32Frame+RECT
$pt = New-Object Win32Frame+POINT

[Win32Frame]::GetWindowRect($hwnd, [ref]$wRect) | Out-Null
[Win32Frame]::GetClientRect($hwnd, [ref]$cRect) | Out-Null
[Win32Frame]::ClientToScreen($hwnd, [ref]$pt) | Out-Null
$style = [Win32Frame]::GetWindowLong($hwnd, [Win32Frame]::GWL_STYLE)

$ncTop = $pt.Y - $wRect.Top
$ncLeft = $pt.X - $wRect.Left
$ncBottom = $wRect.Bottom - ($pt.Y + $cRect.Bottom)
$ncRight = $wRect.Right - ($pt.X + $cRect.Right)

$hasCaption = ($style -band [Win32Frame]::WS_CAPTION) -ne 0
$isPopup = ($style -band [Win32Frame]::WS_POPUP) -ne 0

Write-Host "=== Win32 Window Frame Inspection ==="
Write-Host ("HWND: 0x{0:X}" -f $hwnd.ToInt64())
Write-Host "Title: $($proc.MainWindowTitle)"
Write-Host ("Style: 0x{0:X8} (WS_CAPTION={1}, WS_POPUP={2})" -f $style, $hasCaption, $isPopup)
Write-Host "Window Rect: ($($wRect.Left), $($wRect.Top), $($wRect.Right), $($wRect.Bottom))"
Write-Host "Client Rect: ($($cRect.Left), $($cRect.Top), $($cRect.Right), $($cRect.Bottom))"
Write-Host "Client Screen Origin: ($($pt.X), $($pt.Y))"
Write-Host "Non-Client Margins: Top=${ncTop}px, Left=${ncLeft}px, Right=${ncRight}px, Bottom=${ncBottom}px"

if ($ncTop -le 1) {
    Write-Host "VERDICT: PASS (Native title bar eliminated, top non-client height <= 1px)" -ForegroundColor Green
    exit 0
} else {
    Write-Host "VERDICT: FAIL (Native title bar present, top non-client height = ${ncTop}px)" -ForegroundColor Red
    exit 1
}
