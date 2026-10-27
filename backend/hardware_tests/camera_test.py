# backend/hardware_tests/camera_test.py
"""
Camera & Webcam Diagnostics for Markazi System Checker.
Detects installed imaging devices/webcams and allows technicians to launch
the native Windows Camera diagnostic tool to verify autofocus, resolution, and picture quality.
"""

import json
import subprocess


def get_camera_devices() -> list:
    """Detects connected camera and webcam devices on Windows."""
    devices = []
    try:
        cmd = [
            "powershell.exe",
            "-NoProfile",
            "-NonInteractive",
            "-Command",
            "@([System.Array](Get-PnpDevice -Class Camera, Image -ErrorAction SilentlyContinue | Select-Object FriendlyName, Status, InstanceId)) | ConvertTo-Json -Compress",
        ]
        res = subprocess.run(cmd, capture_output=True, text=True, timeout=5)
        if res.returncode == 0 and res.stdout.strip():
            raw = json.loads(res.stdout)
            if isinstance(raw, dict):
                raw = [raw]
            for item in raw:
                name = item.get("FriendlyName")
                if name:
                    devices.append({
                        "name": name,
                        "status": item.get("Status") or "OK",
                        "instance_id": item.get("InstanceId") or "",
                    })
    except Exception:
        pass

    return devices


def launch_camera_app() -> dict:
    """Launches the Windows native Camera application for technician inspection."""
    try:
        subprocess.Popen(
            ["explorer.exe", "microsoft.windows.camera:"],
            shell=False,
        )
        return {
            "status": "ok",
            "message": "برنامه دوربین ویندوز برای بررسی تصویر، وضوح و فوکوس اجرا شد.",
        }
    except Exception as e:
        return {
            "status": "error",
            "message": f"خطا در باز کردن برنامه دوربین: {e}",
        }
