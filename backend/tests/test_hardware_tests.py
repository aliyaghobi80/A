# backend/tests/test_hardware_tests.py
import unittest
from unittest.mock import patch, MagicMock
from hardware_tests.audio_test import generate_tone_wav, play_audio_tone, stop_audio
from hardware_tests.mic_test import get_mic_devices, get_loopback_status
from hardware_tests.camera_test import get_camera_devices, launch_camera_app


class TestHardwareTests(unittest.TestCase):
    def test_generate_tone_wav_left(self):
        wav_bytes = generate_tone_wav(kind="left", freq=440.0, duration=0.2, volume=0.2)
        self.assertGreater(len(wav_bytes), 1000)
        self.assertTrue(wav_bytes.startswith(b"RIFF"))

    def test_generate_tone_wav_right(self):
        wav_bytes = generate_tone_wav(kind="right", freq=440.0, duration=0.2, volume=0.2)
        self.assertGreater(len(wav_bytes), 1000)
        self.assertTrue(wav_bytes.startswith(b"RIFF"))

    def test_generate_tone_wav_bass_sweep(self):
        wav_bytes = generate_tone_wav(kind="bass", freq=60.0, duration=0.2, volume=0.2, sweep=True)
        self.assertGreater(len(wav_bytes), 1000)
        self.assertTrue(wav_bytes.startswith(b"RIFF"))

    @patch("hardware_tests.audio_test.winsound")
    def test_play_audio_tone(self, mock_winsound):
        mock_winsound.PlaySound = MagicMock()
        mock_winsound.SND_MEMORY = 4
        mock_winsound.SND_SYNC = 0
        mock_winsound.SND_ASYNC = 1
        mock_winsound.SND_NODEFAULT = 2
        mock_winsound.SND_PURGE = 64

        res = play_audio_tone(kind="left", freq=440.0, duration=0.1, volume=0.1)
        self.assertEqual(res["status"], "ok")
        self.assertEqual(res["kind"], "left")

        stopped = stop_audio()
        self.assertTrue(stopped)

    def test_play_audio_tone_real_execution(self):
        """Verifies unmocked real execution does not raise RuntimeError: Cannot play asynchronously from memory."""
        res = play_audio_tone(kind="both", freq=440.0, duration=0.05, volume=0.1)
        self.assertEqual(res["status"], "ok")
        self.assertGreater(res["bytes_played"], 1000)
        self.assertIn("native_played", res)

        stopped = stop_audio()
        self.assertIsInstance(stopped, bool)

    def test_play_audio_tone_real_execution_left_and_right(self):
        """Verifies left and right channel isolation play without error."""
        res_left = play_audio_tone(kind="left", freq=1000.0, duration=0.05, volume=0.1)
        self.assertEqual(res_left["status"], "ok")
        self.assertEqual(res_left["kind"], "left")

        res_right = play_audio_tone(kind="right", freq=1000.0, duration=0.05, volume=0.1)
        self.assertEqual(res_right["status"], "ok")
        self.assertEqual(res_right["kind"], "right")

        stopped = stop_audio()
        self.assertIsInstance(stopped, bool)

    def test_play_audio_tone_real_execution_pink_noise_and_sweep(self):
        """Verifies real execution of pink noise and bass sweep."""
        res_pink = play_audio_tone(kind="both", pink_noise=True, duration=0.05, volume=0.1)
        self.assertEqual(res_pink["status"], "ok")
        self.assertTrue(res_pink["pink_noise"])

        res_sweep = play_audio_tone(kind="both", sweep=True, duration=0.05, volume=0.1)
        self.assertEqual(res_sweep["status"], "ok")
        self.assertTrue(res_sweep["sweep"])

        stop_audio()

    def test_generate_tone_wav_discrete_frequencies(self):
        """Verifies WAV generation across 40Hz, 60Hz, 80Hz, 100Hz, 440Hz, 1000Hz."""
        for freq in [40.0, 60.0, 80.0, 100.0, 440.0, 1000.0]:
            wav = generate_tone_wav(kind="both", freq=freq, duration=0.05, volume=0.2)
            self.assertTrue(wav.startswith(b"RIFF"))
            self.assertGreater(len(wav), 1000)

    def test_generate_tone_wav_pink_noise(self):
        wav_bytes = generate_tone_wav(pink_noise=True, duration=0.1, volume=0.2)
        self.assertGreater(len(wav_bytes), 1000)
        self.assertTrue(wav_bytes.startswith(b"RIFF"))

    def test_get_mic_devices(self):
        devices = get_mic_devices()
        self.assertIsInstance(devices, list)
        self.assertGreater(len(devices), 0)
        self.assertIn("name", devices[0])

    def test_get_loopback_status(self):
        status = get_loopback_status()
        self.assertIn("phase", status)
        self.assertIn("is_busy", status)

    def test_get_camera_devices(self):
        cams = get_camera_devices()
        self.assertIsInstance(cams, list)

    @patch("subprocess.Popen")
    def test_launch_camera_app(self, mock_popen):
        res = launch_camera_app()
        self.assertEqual(res["status"], "ok")
        mock_popen.assert_called_once()


if __name__ == "__main__":
    unittest.main()
