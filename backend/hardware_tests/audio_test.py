# backend/hardware_tests/audio_test.py
"""
Audio & Headphone Diagnostic Tone Generator for Markazi System Checker.
Generates pure sine-wave PCM stereo audio in-memory for testing:
- Left ear channel separation
- Right ear channel separation
- Stereo balance
- Low-frequency bass tones (60Hz, 80Hz, 100Hz) and bass sweeps (40-120Hz).
Uses only standard library (math, struct, wave, io, winsound) with no external binaries.
"""

import io
import math
import random
import struct
import threading
import wave

try:
    import winsound
except ImportError:
    winsound = None

_playback_lock = threading.Lock()
_active_playback_thread = None


def generate_tone_wav(
    kind: str = "both",
    freq: float = 440.0,
    duration: float = 2.2,
    volume: float = 0.2,
    sweep: bool = False,
    pink_noise: bool = False,
    sample_rate: int = 44100,
) -> bytes:
    """Generates standard 16-bit stereo PCM WAV bytes in memory."""
    duration = max(0.2, min(8.0, float(duration)))
    volume = max(0.01, min(0.60, float(volume)))
    freq = max(20.0, min(8000.0, float(freq)))
    n_samples = int(sample_rate * duration)
    ramp_samples = min(2200, n_samples // 4)

    buf = io.BytesIO()
    with wave.open(buf, "wb") as wf:
        wf.setnchannels(2)
        wf.setsampwidth(2)
        wf.setframerate(sample_rate)

        frames = bytearray()
        # Kellet filter states for pink noise approximation
        b0, b1, b2, b3, b4, b5, b6 = 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0
        for i in range(n_samples):
            t = i / sample_rate
            if pink_noise:
                white = random.uniform(-1.0, 1.0)
                b0 = 0.99886 * b0 + white * 0.0555179
                b1 = 0.99332 * b1 + white * 0.0750759
                b2 = 0.96900 * b2 + white * 0.1538520
                b3 = 0.86650 * b3 + white * 0.3104856
                b4 = 0.55000 * b4 + white * 0.5329522
                b5 = -0.7616 * b5 - white * 0.0168980
                raw_wave = (b0 + b1 + b2 + b3 + b4 + b5 + b6 + white * 0.5362) * 0.11
                b6 = white * 0.115926
            elif sweep:
                # 40Hz to 120Hz exponential sweep
                current_freq = 40.0 * math.pow(120.0 / 40.0, t / duration)
                phase = 2.0 * math.pi * current_freq * t
                raw_wave = math.sin(phase)
            else:
                phase = 2.0 * math.pi * freq * t
                raw_wave = math.sin(phase)

            # Smooth fade-in and fade-out envelope to avoid audible speaker pops
            if i < ramp_samples:
                env = i / ramp_samples
            elif i > n_samples - ramp_samples:
                env = (n_samples - i) / ramp_samples
            else:
                env = 1.0

            val = int(volume * 32767.0 * raw_wave * env)
            val = max(-32767, min(32767, val))

            if kind == "left":
                frames.extend(struct.pack("<hh", val, 0))
            elif kind == "right":
                frames.extend(struct.pack("<hh", 0, val))
            else:
                frames.extend(struct.pack("<hh", val, val))

        wf.writeframes(frames)

    return buf.getvalue()


def stop_audio() -> bool:
    """Stops any currently playing audio tone immediately."""
    global winsound
    if winsound:
        try:
            winsound.PlaySound(None, winsound.SND_PURGE)
            return True
        except Exception:
            pass
    return False


def play_audio_tone(
    kind: str = "both",
    freq: float = 440.0,
    duration: float = 2.2,
    volume: float = 0.2,
    sweep: bool = False,
    pink_noise: bool = False,
) -> dict:
    """Synthesizes and plays the diagnostic tone asynchronously."""
    global winsound
    stop_audio()

    wav_bytes = generate_tone_wav(
        kind=kind,
        freq=freq,
        duration=duration,
        volume=volume,
        sweep=sweep,
        pink_noise=pink_noise,
    )

    played = False
    if winsound:
        try:
            snd_sync = getattr(winsound, "SND_SYNC", 0)
            snd_memory = getattr(winsound, "SND_MEMORY", 4)
            snd_nodefault = getattr(winsound, "SND_NODEFAULT", 2)
            flags = snd_memory | snd_sync | snd_nodefault

            def _worker():
                try:
                    winsound.PlaySound(wav_bytes, flags)
                except Exception:
                    pass

            with _playback_lock:
                _active_playback_thread = threading.Thread(target=_worker, daemon=True)
                _active_playback_thread.start()
            played = True
        except Exception as e:
            return {
                "status": "error",
                "message": f"Playback failed: {e}",
                "kind": kind,
                "bytes": len(wav_bytes),
            }

    return {
        "status": "ok",
        "kind": kind,
        "frequency": freq,
        "duration": duration,
        "volume": volume,
        "sweep": sweep,
        "pink_noise": pink_noise,
        "bytes_played": len(wav_bytes),
        "native_played": played,
    }
