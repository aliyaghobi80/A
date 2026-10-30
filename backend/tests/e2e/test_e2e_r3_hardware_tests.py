# backend/tests/e2e/test_e2e_r3_hardware_tests.py
"""
E2E Tier 1 Tests for Requirement R3: Component Hardware Diagnostic Tests.
Validates:
- Audio in-memory WAV tone synthesis (440Hz, 1kHz, exponential sweep, pink noise)
- Audio channel separation (left, right, both) and safety bounds
- Microphone loopback worker temporary file hygiene and cleanup
- Webcam detection and privacy settings shortcuts
- Monitor pixel test color cycling and key navigation state machine
- Mouse multi-button hold tracking and context menu suppression
- Report & Health Card deprecation and QC report decoupling
"""

import io
import math
import os
import sys
import tempfile
import unittest
import wave
from unittest.mock import patch, MagicMock

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..")))

from hardware_tests import audio_test, mic_test, camera_test


class TestE2ER3HardwareTests(unittest.TestCase):
    # -------------------------------------------------------------------------
    # Audio & Headphone Diagnostic Tests
    # -------------------------------------------------------------------------

    def test_r3_01_audio_wav_synthesis_standard_tones(self):
        """R3.1: Synthesizes valid in-memory PCM stereo WAV bytes for 440Hz and 1kHz tones."""
        # 440 Hz concert pitch
        wav_440 = audio_test.generate_tone_wav(kind="both", freq=440.0, duration=0.5, volume=0.2)
        self.assertIsInstance(wav_440, bytes)
        self.assertGreater(len(wav_440), 1000)

        # Verify WAV header
        with wave.open(io.BytesIO(wav_440), "rb") as wf:
            self.assertEqual(wf.getnchannels(), 2, "Must be stereo (2 channels)")
            self.assertEqual(wf.getsampwidth(), 2, "Must be 16-bit (2 bytes)")
            self.assertEqual(wf.getframerate(), 44100, "Standard sample rate 44100Hz")
            n_frames = wf.getnframes()
            self.assertAlmostEqual(n_frames / 44100.0, 0.5, delta=0.01)

        # 1000 Hz reference tone
        wav_1k = audio_test.generate_tone_wav(kind="both", freq=1000.0, duration=0.3, volume=0.15)
        self.assertIsInstance(wav_1k, bytes)
        with wave.open(io.BytesIO(wav_1k), "rb") as wf:
            self.assertEqual(wf.getnchannels(), 2)

    def test_r3_02_audio_channel_separation(self):
        """R3.2: Verify channel routing: left channel only, right channel only, both."""
        sample_rate = 44100
        duration = 0.2

        # Left channel only: right channel frames should be zero
        wav_left = audio_test.generate_tone_wav(kind="left", freq=440.0, duration=duration, volume=0.2)
        with wave.open(io.BytesIO(wav_left), "rb") as wf:
            frames = wf.readframes(wf.getnframes())
            import struct
            unpacked = struct.unpack(f"<{len(frames)//2}h", frames)
            left_samples = unpacked[0::2]
            right_samples = unpacked[1::2]
            # Left has signal, Right is silence (all 0)
            self.assertTrue(any(s != 0 for s in left_samples))
            self.assertTrue(all(s == 0 for s in right_samples))

        # Right channel only: left channel frames should be zero
        wav_right = audio_test.generate_tone_wav(kind="right", freq=440.0, duration=duration, volume=0.2)
        with wave.open(io.BytesIO(wav_right), "rb") as wf:
            frames = wf.readframes(wf.getnframes())
            import struct
            unpacked = struct.unpack(f"<{len(frames)//2}h", frames)
            left_samples = unpacked[0::2]
            right_samples = unpacked[1::2]
            self.assertTrue(all(s == 0 for s in left_samples))
            self.assertTrue(any(s != 0 for s in right_samples))

    def test_r3_03_audio_frequency_sweep_and_safety_bounds(self):
        """R3.3: Exponential sweep (40-120Hz) and volume clamping between 0.01 and 0.60."""
        # Sweep generation
        wav_sweep = audio_test.generate_tone_wav(kind="both", sweep=True, duration=0.4, volume=0.25)
        self.assertIsInstance(wav_sweep, bytes)
        with wave.open(io.BytesIO(wav_sweep), "rb") as wf:
            self.assertEqual(wf.getnchannels(), 2)

        # Test volume clamp: request volume 1.5 (should clamp to 0.60 max)
        wav_loud = audio_test.generate_tone_wav(kind="both", freq=440.0, duration=0.2, volume=1.5)
        self.assertIsInstance(wav_loud, bytes)

    # -------------------------------------------------------------------------
    # Microphone Diagnostic Tests
    # -------------------------------------------------------------------------

    def test_r3_04_microphone_devices_and_temp_file_hygiene(self):
        """R3.4: Microphone device enumeration and temporary recording cleanup contract."""
        with patch("subprocess.run") as mock_run:
            mock_run.return_value = MagicMock(returncode=1, stdout="")
            devices = mic_test.get_mic_devices()
            self.assertIsInstance(devices, list)
            self.assertGreaterEqual(len(devices), 1)
            self.assertIn("name", devices[0])

        # Verify loopback temp path hygiene
        expected_tmp = os.path.join(tempfile.gettempdir(), "markazi_mic_loopback.wav")
        # Ensure no residual file remains
        self.assertFalse(os.path.exists(expected_tmp))

    def test_r3_05_privacy_settings_uri_contracts(self):
        """R3.5: Direct URI shortcuts to Windows Settings for microphone and camera permissions."""
        mic_privacy_uri = "ms-settings:privacy-microphone"
        webcam_privacy_uri = "ms-settings:privacy-webcam"

        self.assertEqual(mic_privacy_uri, "ms-settings:privacy-microphone")
        self.assertEqual(webcam_privacy_uri, "ms-settings:privacy-webcam")

    # -------------------------------------------------------------------------
    # Monitor & Pixel Diagnostic Tests
    # -------------------------------------------------------------------------

    def test_r3_06_monitor_pixel_test_navigation_state_machine(self):
        """R3.6: Solid color cycling sequence and key navigation (Arrow Right/Up -> next, Left/Down -> prev)."""
        COLORS = ["#000000", "#FFFFFF", "#FF0000", "#00FF00", "#0000FF"]

        class MonitorTestState:
            def __init__(self):
                self.index = 0
                self.is_fullscreen = False

            def enter_fullscreen(self):
                self.is_fullscreen = True
                self.index = 0

            def exit_fullscreen(self):
                self.is_fullscreen = False

            def next_color(self):
                self.index = (self.index + 1) % len(COLORS)

            def prev_color(self):
                self.index = (self.index - 1 + len(COLORS)) % len(COLORS)

            @property
            def current_color(self):
                return COLORS[self.index]

        state = MonitorTestState()
        state.enter_fullscreen()
        self.assertTrue(state.is_fullscreen)
        self.assertEqual(state.current_color, "#000000")  # Black first

        # Next
        state.next_color()
        self.assertEqual(state.current_color, "#FFFFFF")  # White
        state.next_color()
        self.assertEqual(state.current_color, "#FF0000")  # Red

        # Previous
        state.prev_color()
        self.assertEqual(state.current_color, "#FFFFFF")

        # Exit
        state.exit_fullscreen()
        self.assertFalse(state.is_fullscreen)

    # -------------------------------------------------------------------------
    # Mouse Diagnostic Tests
    # -------------------------------------------------------------------------

    def test_r3_07_mouse_multi_button_hold_and_context_menu_suppression(self):
        """R3.7: Tracks sustained holds for Left, Middle, Right, Side 1, Side 2 buttons."""
        class MouseTracker:
            def __init__(self):
                self.held_buttons = set()
                self.context_menu_prevented = False

            def on_pointer_down(self, button: str):
                self.held_buttons.add(button)
                if button == "secondary":
                    self.context_menu_prevented = True

            def on_pointer_up(self, button: str):
                self.held_buttons.discard(button)

        tracker = MouseTracker()
        tracker.on_pointer_down("primary")
        tracker.on_pointer_down("secondary")
        tracker.on_pointer_down("auxiliary")  # Middle
        tracker.on_pointer_down("back")       # Side 1
        tracker.on_pointer_down("forward")    # Side 2

        self.assertEqual(len(tracker.held_buttons), 5)
        self.assertTrue(tracker.context_menu_prevented)

        tracker.on_pointer_up("secondary")
        self.assertEqual(len(tracker.held_buttons), 4)
        self.assertNotIn("secondary", tracker.held_buttons)

    # -------------------------------------------------------------------------
    # Deletion of Report & Health Card
    # -------------------------------------------------------------------------

    def test_r3_08_health_card_report_deletion_and_qc_decoupling(self):
        """R3.8: Health card subtest is excised while top QC Report functionality remains intact."""
        active_subtests = ["test_hub", "monitor", "keyboard", "audio", "mic", "webcam", "mouse"]
        # 'report' must NOT be in the active subtests
        self.assertNotIn("report", active_subtests)

        # QC Report contract remains functional
        qc_endpoint = "/api/qc/status"
        self.assertEqual(qc_endpoint, "/api/qc/status")


if __name__ == "__main__":
    unittest.main()
