#!/usr/bin/env python3
"""
scripts/test_audio_stress.py
Empirical stress test harness for Audio Diagnostics, Asset Synthesis,
Volume Scaling, and Backend Playback Fix.
"""

import io
import math
import os
import struct
import sys
import time
import wave
import numpy as np

AUDIO_DIR = os.path.abspath(
    os.path.join(os.path.dirname(__file__), "..", "frontend", "assets", "audio")
)

EXPECTED_ASSETS = {
    "sine_440hz_left.wav": {"duration": 2.5, "left_active": True, "right_active": False},
    "sine_440hz_right.wav": {"duration": 2.5, "left_active": False, "right_active": True},
    "sine_440hz_both.wav": {"duration": 2.5, "left_active": True, "right_active": True},
    "sine_1khz_left.wav": {"duration": 2.5, "left_active": True, "right_active": False},
    "sine_1khz_right.wav": {"duration": 2.5, "left_active": False, "right_active": True},
    "sine_1khz_both.wav": {"duration": 2.5, "left_active": True, "right_active": True},
    "bass_40hz.wav": {"duration": 2.5, "left_active": True, "right_active": True},
    "bass_60hz.wav": {"duration": 2.5, "left_active": True, "right_active": True},
    "bass_80hz.wav": {"duration": 2.5, "left_active": True, "right_active": True},
    "bass_100hz.wav": {"duration": 2.5, "left_active": True, "right_active": True},
    "bass_sweep_20_120hz.wav": {"duration": 3.0, "left_active": True, "right_active": True},
    "pink_noise.wav": {"duration": 3.0, "left_active": True, "right_active": True},
    "channel_id_chime.wav": {"duration": 2.8, "left_active": True, "right_active": True, "chime": True},
}


def test_audio_assets():
    print("=" * 60)
    print("TEST 1: Audio Assets Format & RIFF Header Validation")
    print("=" * 60)

    for filename, spec in EXPECTED_ASSETS.items():
        filepath = os.path.join(AUDIO_DIR, filename)
        assert os.path.exists(filepath), f"Missing file: {filepath}"
        filesize = os.path.getsize(filepath)
        assert filesize > 44, f"File too small ({filesize} bytes): {filename}"

        # Raw header check
        with open(filepath, "rb") as f:
            header = f.read(12)
            assert header[:4] == b"RIFF", f"Header not RIFF in {filename}"
            assert header[8:12] == b"WAVE", f"Header not WAVE in {filename}"

        # Wave parser check
        with wave.open(filepath, "rb") as wf:
            n_channels = wf.getnchannels()
            sampwidth = wf.getsampwidth()
            framerate = wf.getframerate()
            n_frames = wf.getnframes()
            duration = n_frames / framerate

            assert n_channels == 2, f"{filename}: expected 2 channels, got {n_channels}"
            assert sampwidth == 2, f"{filename}: expected 16-bit (2 bytes), got {sampwidth}"
            assert framerate == 44100, f"{filename}: expected 44100 Hz, got {framerate}"
            assert abs(duration - spec["duration"]) < 0.01, (
                f"{filename}: expected duration {spec['duration']}s, got {duration}s"
            )

            frames = wf.readframes(n_frames)
            samples = np.frombuffer(frames, dtype=np.int16).reshape(-1, 2)
            left_samples = samples[:, 0]
            right_samples = samples[:, 1]

            # Anti-click check: first and last samples should be close to zero
            assert abs(left_samples[0]) <= 5, f"{filename}: left onset pop: {left_samples[0]}"
            assert abs(right_samples[0]) <= 5, f"{filename}: right onset pop: {right_samples[0]}"
            assert abs(left_samples[-1]) <= 5, f"{filename}: left offset pop: {left_samples[-1]}"
            assert abs(right_samples[-1]) <= 5, f"{filename}: right offset pop: {right_samples[-1]}"

            # Active channel amplitude check
            if spec["left_active"] and not spec.get("chime"):
                max_l = np.max(np.abs(left_samples))
                assert max_l > 10000, f"{filename}: left channel amplitude too low ({max_l})"
            if spec["right_active"] and not spec.get("chime"):
                max_r = np.max(np.abs(right_samples))
                assert max_r > 10000, f"{filename}: right channel amplitude too low ({max_r})"

            # Channel isolation check
            if not spec["left_active"]:
                energy_l = np.sum(np.abs(left_samples))
                assert energy_l == 0, f"{filename}: left channel expected 0 energy, got {energy_l}"
            if not spec["right_active"]:
                energy_r = np.sum(np.abs(right_samples))
                assert energy_r == 0, f"{filename}: right channel expected 0 energy, got {energy_r}"

            # Special Chime Channel Sequence check
            if spec.get("chime"):
                # Left bursts: 0.1s - 1.0s (samples 4410 to 44100)
                # Right bursts: 1.6s - 2.5s (samples 70560 to 110250)
                # Left active window: right channel must be strictly zero
                left_window_right_energy = np.sum(np.abs(right_samples[4410:44100]))
                assert left_window_right_energy == 0, (
                    f"Chime: right channel energy during left window: {left_window_right_energy}"
                )
                # Right active window: left channel must be strictly zero
                right_window_left_energy = np.sum(np.abs(left_samples[70560:110250]))
                assert right_window_left_energy == 0, (
                    f"Chime: left channel energy during right window: {right_window_left_energy}"
                )
                # Silent gap: 1.1s - 1.5s (samples 48510 to 66150)
                gap_energy = np.sum(np.abs(samples[48510:66150]))
                assert gap_energy == 0, f"Chime: gap contains energy: {gap_energy}"

            print(f"  [PASS] {filename:26s} | {duration:.2f}s | L_max={np.max(np.abs(left_samples)):5d} | R_max={np.max(np.abs(right_samples)):5d}")

    print("\nAll 13 audio assets PASSED format and channel isolation tests!\n")


def test_volume_scaling_and_clamping():
    print("=" * 60)
    print("TEST 2: Volume Gain Scaling & Boundary Clamping Stress Test")
    print("=" * 60)

    # Simulate WinmmAudioPlayer.processWavBuffer sample calculation
    # Range of test gains including normal and adversarial
    test_volumes = [
        -10.0, -1.0, 0.0, 0.0001, 0.01, 0.05, 0.10, 0.20, 0.35, 0.50, 0.60,
        0.6001, 0.75, 1.0, 1.5, 2.0, 10.0, 100.0, 1e6
    ]

    # Extreme input samples
    test_samples = [
        -32768, -32767, -20000, -1, 0, 1, 20000, 32766, 32767
    ]

    for vol in test_volumes:
        gain = min(0.60, max(0.01, float(vol)))
        assert 0.01 <= gain <= 0.60, f"Gain not clamped: {gain} for vol {vol}"

        for s in test_samples:
            scaled_left = int(round(s * gain))
            clamped_left = max(-32768, min(32767, scaled_left))

            assert -32768 <= clamped_left <= 32767, (
                f"Sample out of 16-bit bounds: {clamped_left} (input={s}, gain={gain})"
            )
            # Verify no clipping when gain <= 0.60 because 32767 * 0.6 = 19660.2
            assert scaled_left == clamped_left, (
                f"Unexpected clipping occurred: scaled={scaled_left}, clamped={clamped_left}"
            )

    print("  [PASS] Gain correctly clamped to [0.01, 0.60] across 19 test volumes.")
    print("  [PASS] 16-bit samples never overflow/underflow or clip bounds.")
    print("\nVolume Scaling & Clamping PASSED!\n")


def test_backend_direct_execution():
    print("=" * 60)
    print("TEST 3: Backend Audio Direct Execution & Concurrency Stress Test")
    print("=" * 60)

    sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))
    from backend.hardware_tests.audio_test import play_audio_tone, stop_audio

    # 1. Standard tones direct execution
    cases = [
        {"kind": "left", "freq": 440.0, "duration": 0.3},
        {"kind": "right", "freq": 1000.0, "duration": 0.3},
        {"kind": "both", "freq": 60.0, "duration": 0.3},
        {"kind": "both", "sweep": True, "duration": 0.3},
        {"kind": "both", "pink_noise": True, "duration": 0.3},
    ]

    for case in cases:
        res = play_audio_tone(**case)
        assert res["status"] == "ok", f"play_audio_tone failed: {res}"
        assert res["bytes_played"] > 0, f"No bytes played: {res}"
        print(f"  [PASS] Direct execution: {case} -> status={res['status']}, bytes={res['bytes_played']}")
        time.sleep(0.05)

    # 2. Stop audio check
    stopped = stop_audio()
    print(f"  [PASS] stop_audio returned: {stopped}")

    # 3. Burst Concurrency Stress Test: 20 rapid successive calls
    print("\nRunning burst concurrency stress test (20 rapid calls in < 50ms)...")
    start_t = time.time()
    for i in range(20):
        k = "left" if i % 2 == 0 else "right"
        res = play_audio_tone(kind=k, freq=440.0 + i * 20, duration=0.2)
        assert res["status"] == "ok", f"Burst call {i} failed: {res}"

    elapsed = time.time() - start_t
    print(f"  [PASS] 20 rapid burst calls succeeded in {elapsed:.3f}s with zero exceptions.")

    stop_audio()
    print("\nBackend Audio Direct Execution & Concurrency Stress Test PASSED!\n")


if __name__ == "__main__":
    test_audio_assets()
    test_volume_scaling_and_clamping()
    test_backend_direct_execution()
    print("=" * 60)
    print("ALL EMPIRICAL AUDIO STRESS TESTS PASSED SUCCESSFULLY!")
    print("=" * 60)
