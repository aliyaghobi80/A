# backend/hardware_tests/mic_test.py
"""
Microphone Diagnostics & Audio Loopback for Markazi System Checker.
Detects audio input devices and provides an interactive loopback voice test
so technicians can speak into the microphone and immediately listen back.
"""

import ctypes
import os
import subprocess
import tempfile
import threading
import time

try:
    import winsound
except ImportError:
    winsound = None

_loopback_lock = threading.Lock()
_loopback_state = {
    "is_busy": False,
    "phase": "idle",  # idle, recording, playing, completed, error
    "message": "",
    "device_name": "",
}


def get_mic_devices() -> list:
    """Returns detected audio recording devices from Windows."""
    devices = []
    # 1. Query Win32_SoundDevice
    try:
        cmd = [
            "powershell.exe",
            "-NoProfile",
            "-NonInteractive",
            "-Command",
            "@([System.Array](Get-CimInstance Win32_SoundDevice | Select-Object Name,Status,Manufacturer)) | ConvertTo-Json -Compress",
        ]
        res = subprocess.run(cmd, capture_output=True, text=True, timeout=5)
        if res.returncode == 0 and res.stdout.strip():
            import json

            data = json.loads(res.stdout)
            if isinstance(data, dict):
                data = [data]
            for d in data:
                name = d.get("Name") or "Audio Device"
                devices.append({
                    "name": name,
                    "status": d.get("Status") or "OK",
                    "manufacturer": d.get("Manufacturer") or "Standard",
                })
    except Exception:
        pass

    if not devices:
        devices.append({
            "name": "ورودی صوتی پیش‌فرض ویندوز (Default Microphone)",
            "status": "OK",
            "manufacturer": "Microsoft",
        })

    return devices


def _run_loopback_worker(duration_seconds: float = 3.0):
    global _loopback_state, winsound
    tmp_wav = os.path.join(tempfile.gettempdir(), "markazi_mic_loopback.wav")
    try:
        with _loopback_lock:
            _loopback_state["is_busy"] = True
            _loopback_state["phase"] = "recording"
            _loopback_state["message"] = f"در حال ضبط صدا ({int(duration_seconds)} ثانیه)... صحبت کنید"

        if os.path.isfile(tmp_wav):
            try:
                os.remove(tmp_wav)
            except Exception:
                pass

        # Use Windows MCI (Media Control Interface) via winmm.dll
        winmm = ctypes.windll.winmm
        winmm.mciSendStringW("close markazimic", None, 0, None)

        open_res = winmm.mciSendStringW("open new type waveaudio alias markazimic", None, 0, None)
        if open_res != 0:
            raise RuntimeError(f"ویندوز نتوانست کانال ضبط صدا را باز کند (کد خطا: {open_res})")

        winmm.mciSendStringW(
            "set markazimic time format ms bitspersample 16 channels 2 samplespersec 44100",
            None,
            0,
            None,
        )

        rec_res = winmm.mciSendStringW("record markazimic", None, 0, None)
        if rec_res != 0:
            raise RuntimeError(f"خطا در آغاز ضبط میکروفون (کد خطا: {rec_res})")

        time.sleep(duration_seconds)

        winmm.mciSendStringW("stop markazimic", None, 0, None)
        winmm.mciSendStringW(f'save markazimic "{tmp_wav}"', None, 0, None)
        winmm.mciSendStringW("close markazimic", None, 0, None)

        if not os.path.isfile(tmp_wav) or os.path.getsize(tmp_wav) < 100:
            raise RuntimeError("فایل ضبط‌شده نامعتبر است یا صدایی دریافت نشد.")

        # Phase 2: Playing back
        with _loopback_lock:
            _loopback_state["phase"] = "playing"
            _loopback_state["message"] = "در حال بازپخش صدای ضبط‌شده شما در هدفون/بلندگو..."

        if winsound:
            winsound.PlaySound(tmp_wav, winsound.SND_FILENAME | winsound.SND_SYNC)

        with _loopback_lock:
            _loopback_state["phase"] = "completed"
            _loopback_state["message"] = "بازپخش به اتمام رسید. آیا صدای خود را شفاف شنیدید؟"

    except Exception as e:
        with _loopback_lock:
            _loopback_state["phase"] = "error"
            _loopback_state["message"] = f"خطا در آزمون میکروفون: {e}"
    finally:
        with _loopback_lock:
            _loopback_state["is_busy"] = False
        if os.path.isfile(tmp_wav):
            try:
                os.remove(tmp_wav)
            except Exception:
                pass


def start_loopback_test(duration_seconds: float = 3.0) -> dict:
    """Initiates an asynchronous mic loopback recording and playback."""
    with _loopback_lock:
        if _loopback_state["is_busy"]:
            return {
                "status": "busy",
                "message": "یک آزمون ضبط در حال اجرا است.",
                **_loopback_state,
            }

    t = threading.Thread(target=_run_loopback_worker, args=(duration_seconds,), daemon=True)
    t.start()

    return {
        "status": "started",
        "phase": "recording",
        "message": f"ضبط آغاز شد ({int(duration_seconds)} ثانیه)...",
    }


def get_loopback_status() -> dict:
    """Returns the current progress of the microphone loopback test."""
    with _loopback_lock:
        return dict(_loopback_state)
