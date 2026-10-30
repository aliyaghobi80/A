#!/usr/bin/env python3
"""
scripts/generate_audio_assets.py
Generates pure CC0 (Creative Commons Zero 1.0 Universal / Public Domain)
diagnostic WAV audio assets for Markazi System Checker.

Audio files generated in frontend/assets/audio/:
  1. sine_440hz_left.wav       - 440 Hz Sine, Left Ear Only (2.5s)
  2. sine_440hz_right.wav      - 440 Hz Sine, Right Ear Only (2.5s)
  3. sine_440hz_both.wav       - 440 Hz Sine, Both Channels (2.5s)
  4. sine_1khz_left.wav        - 1000 Hz Sine, Left Ear Only (2.5s)
  5. sine_1khz_right.wav       - 1000 Hz Sine, Right Ear Only (2.5s)
  6. sine_1khz_both.wav        - 1000 Hz Sine, Both Channels (2.5s)
  7. bass_40hz.wav             - 40 Hz Sub-bass Sine, Stereo (2.5s)
  8. bass_60hz.wav             - 60 Hz Bass Sine, Stereo (2.5s)
  9. bass_80hz.wav             - 80 Hz Upper-bass Sine, Stereo (2.5s)
 10. bass_100hz.wav            - 100 Hz Mid-bass Sine, Stereo (2.5s)
 11. bass_sweep_20_120hz.wav   - Logarithmic Bass Sweep 20Hz -> 120Hz (3.0s)
 12. pink_noise.wav            - 1/f Pink Noise Filtered (3.0s)
 13. channel_id_chime.wav      - Sequenced Stereo Chime (Left -> Pause -> Right, 2.8s)

Specifications:
- Sample Rate: 44,100 Hz (44.1 kHz)
- Bit Depth: 16-bit Linear PCM (Signed Little-Endian, interleaved stereo)
- Envelope: 25ms anti-click raised-cosine ramp at onset and offset
- Peak Level: -1.4 dBFS (0.85 normalized)
"""

import os
import sys
import wave
import numpy as np

SAMPLE_RATE = 44100
OUT_DIR = os.path.abspath(
    os.path.join(os.path.dirname(__file__), "..", "frontend", "assets", "audio")
)


def apply_envelope(signal: np.ndarray, ramp_ms: float = 25.0) -> np.ndarray:
    """Applies a smooth raised-cosine (Hann) fade-in and fade-out to prevent pops."""
    ramp_samples = int(SAMPLE_RATE * (ramp_ms / 1000.0))
    if len(signal) <= 2 * ramp_samples or ramp_samples <= 0:
        return signal
    env = np.ones(len(signal), dtype=np.float64)
    # Raised cosine onset: 0.5 * (1 - cos(pi * t / ramp)) = sin^2(pi * t / (2 * ramp))
    t = np.linspace(0.0, np.pi, ramp_samples, endpoint=False)
    onset = 0.5 * (1.0 - np.cos(t))
    env[:ramp_samples] = onset
    env[-ramp_samples:] = onset[::-1]
    return signal * env


def save_wav(filename: str, left: np.ndarray, right: np.ndarray) -> str:
    """Saves 16-bit interleaved stereo PCM WAV to OUT_DIR."""
    os.makedirs(OUT_DIR, exist_ok=True)
    filepath = os.path.join(OUT_DIR, filename)

    left_env = apply_envelope(left)
    right_env = apply_envelope(right)

    left_i16 = (np.clip(left_env, -1.0, 1.0) * 32767.0).astype(np.int16)
    right_i16 = (np.clip(right_env, -1.0, 1.0) * 32767.0).astype(np.int16)

    interleaved = np.empty((len(left_i16) * 2,), dtype=np.int16)
    interleaved[0::2] = left_i16
    interleaved[1::2] = right_i16

    with wave.open(filepath, "wb") as wf:
        wf.setnchannels(2)
        wf.setsampwidth(2)
        wf.setframerate(SAMPLE_RATE)
        wf.writeframes(interleaved.tobytes())

    size = os.path.getsize(filepath)
    print(f"Generated: {filename:24s} | {len(left_i16):6d} samples ({len(left_i16)/SAMPLE_RATE:.1f}s) | {size:,} bytes")
    return filepath


def generate_all_assets() -> list[str]:
    """Generates all 13 pure CC0 diagnostic WAV files."""
    generated = []

    # 1. Sine tones: 440 Hz (Concert Pitch A4) and 1000 Hz (1 kHz Reference)
    for freq, prefix in [(440.0, "sine_440hz"), (1000.0, "sine_1khz")]:
        duration = 2.5
        n = int(SAMPLE_RATE * duration)
        t = np.linspace(0.0, duration, n, endpoint=False)
        sig = np.sin(2.0 * np.pi * freq * t) * 0.85
        zero = np.zeros_like(sig)

        generated.append(save_wav(f"{prefix}_left.wav", sig, zero))
        generated.append(save_wav(f"{prefix}_right.wav", zero, sig))
        generated.append(save_wav(f"{prefix}_both.wav", sig, sig))

    # 2. Bass tones: 40 Hz, 60 Hz, 80 Hz, 100 Hz
    for freq in [40.0, 60.0, 80.0, 100.0]:
        duration = 2.5
        n = int(SAMPLE_RATE * duration)
        t = np.linspace(0.0, duration, n, endpoint=False)
        sig = np.sin(2.0 * np.pi * freq * t) * 0.85
        generated.append(save_wav(f"bass_{int(freq)}hz.wav", sig, sig))

    # 3. Logarithmic bass frequency sweep: 20 Hz to 120 Hz over 3.0s
    d_sweep = 3.0
    n_sweep = int(SAMPLE_RATE * d_sweep)
    t_sweep = np.linspace(0.0, d_sweep, n_sweep, endpoint=False)
    f0, f1 = 20.0, 120.0
    k = np.log(f1 / f0) / d_sweep
    phase = 2.0 * np.pi * f0 * (np.exp(k * t_sweep) - 1.0) / k
    sweep = np.sin(phase) * 0.85
    generated.append(save_wav("bass_sweep_20_120hz.wav", sweep, sweep))

    # 4. Pink noise (1/f spectral density) via FFT/IRFFT filter
    d_pink = 3.0
    n_pink = int(SAMPLE_RATE * d_pink)
    # Use deterministic seed for reproducible bit-exact output
    rng = np.random.default_rng(seed=42)
    white = rng.standard_normal(n_pink)
    X = np.fft.rfft(white)
    freqs = np.fft.rfftfreq(n_pink, d=1.0 / SAMPLE_RATE)
    pink_filter = np.zeros_like(freqs)
    pink_filter[1:] = 1.0 / np.sqrt(freqs[1:])
    pink = np.fft.irfft(X * pink_filter, n=n_pink)
    max_val = np.max(np.abs(pink))
    if max_val > 0:
        pink = (pink / max_val) * 0.85
    generated.append(save_wav("pink_noise.wav", pink, pink))

    # 5. Distinct channel test sound (Sequenced Stereo Chime)
    # Timeline:
    # 0.1s - 0.5s: Left ear tone burst (523.25 Hz C5, Hann windowed), Right silent
    # 0.6s - 1.0s: Left ear tone burst (659.25 Hz E5, Hann windowed), Right silent
    # 1.1s - 1.6s: Silence (500ms)
    # 1.6s - 2.0s: Right ear tone burst (659.25 Hz E5, Hann windowed), Left silent
    # 2.1s - 2.5s: Right ear tone burst (783.99 Hz G5, Hann windowed), Left silent
    d_chime = 2.8
    n_chime = int(SAMPLE_RATE * d_chime)
    l_chime = np.zeros(n_chime, dtype=np.float64)
    r_chime = np.zeros(n_chime, dtype=np.float64)

    def tone_burst(freq: float, duration: float = 0.4) -> np.ndarray:
        n_b = int(SAMPLE_RATE * duration)
        t_b = np.linspace(0.0, duration, n_b, endpoint=False)
        burst = np.sin(2.0 * np.pi * freq * t_b) * np.hanning(n_b) * 0.85
        return burst

    b_c5 = tone_burst(523.25, 0.4)
    b_e5 = tone_burst(659.25, 0.4)
    b_g5 = tone_burst(783.99, 0.4)

    def insert_burst(channel: np.ndarray, start_sec: float, burst: np.ndarray):
        s_idx = int(start_sec * SAMPLE_RATE)
        e_idx = s_idx + len(burst)
        if e_idx <= len(channel):
            channel[s_idx:e_idx] = burst

    # Left bursts
    insert_burst(l_chime, 0.1, b_c5)
    insert_burst(l_chime, 0.6, b_e5)
    # Right bursts
    insert_burst(r_chime, 1.6, b_e5)
    insert_burst(r_chime, 2.1, b_g5)

    generated.append(save_wav("channel_id_chime.wav", l_chime, r_chime))

    return generated


if __name__ == "__main__":
    print(f"Generating CC0 audio assets in: {OUT_DIR}")
    results = generate_all_assets()
    print(f"\nSuccessfully generated {len(results)} audio assets.")
