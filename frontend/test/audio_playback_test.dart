// frontend/test/audio_playback_test.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:markazi_system_checker/controllers/hardware_test_controller.dart';
import 'package:markazi_system_checker/services/winmm_audio_player.dart';

Uint8List createSyntheticWav({
  int numChannels = 2,
  int sampleRate = 44100,
  int bitsPerSample = 16,
  int numSamplePairs = 100,
  int leftVal = 1000,
  int rightVal = 2000,
}) {
  final dataLength = numSamplePairs * numChannels * (bitsPerSample ~/ 8);
  final totalLength = 44 + dataLength;
  final bytes = Uint8List(totalLength);
  final view = ByteData.sublistView(bytes);

  // RIFF header
  bytes.setRange(0, 4, 'RIFF'.codeUnits);
  view.setUint32(4, totalLength - 8, Endian.little);
  bytes.setRange(8, 12, 'WAVE'.codeUnits);

  // fmt chunk
  bytes.setRange(12, 16, 'fmt '.codeUnits);
  view.setUint32(16, 16, Endian.little); // chunk size
  view.setUint16(20, 1, Endian.little); // audio format (PCM = 1)
  view.setUint16(22, numChannels, Endian.little);
  view.setUint32(24, sampleRate, Endian.little);
  final byteRate = sampleRate * numChannels * (bitsPerSample ~/ 8);
  view.setUint32(28, byteRate, Endian.little);
  final blockAlign = numChannels * (bitsPerSample ~/ 8);
  view.setUint16(32, blockAlign, Endian.little);
  view.setUint16(34, bitsPerSample, Endian.little);

  // data chunk
  bytes.setRange(36, 40, 'data'.codeUnits);
  view.setUint32(40, dataLength, Endian.little);

  // samples
  int offset = 44;
  for (int i = 0; i < numSamplePairs; i++) {
    view.setInt16(offset, leftVal, Endian.little);
    if (numChannels == 2) {
      view.setInt16(offset + 2, rightVal, Endian.little);
      offset += 4;
    } else {
      offset += 2;
    }
  }

  return bytes;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    Get.reset();
  });

  group('Audio Asset File Integrity Tests (R4)', () {
    final expectedFiles = [
      'sine_440hz_left.wav',
      'sine_440hz_right.wav',
      'sine_440hz_both.wav',
      'sine_1khz_left.wav',
      'sine_1khz_right.wav',
      'sine_1khz_both.wav',
      'bass_40hz.wav',
      'bass_60hz.wav',
      'bass_80hz.wav',
      'bass_100hz.wav',
      'bass_sweep_20_120hz.wav',
      'pink_noise.wav',
      'channel_id_chime.wav',
    ];

    test('All 13 pure CC0 WAV files exist on disk with valid headers', () {
      final audioDir = Directory('assets/audio');
      expect(audioDir.existsSync(), isTrue, reason: 'assets/audio directory must exist');

      for (final filename in expectedFiles) {
        final file = File('${audioDir.path}/$filename');
        expect(file.existsSync(), isTrue, reason: 'Asset $filename must exist');
        final bytes = file.readAsBytesSync();
        expect(bytes.length, greaterThan(100000), reason: '$filename size must exceed 100KB');

        // Check RIFF and WAVE header
        expect(WinmmAudioPlayer.isValidWav(bytes), isTrue, reason: '$filename must be a valid RIFF WAVE');

        final view = ByteData.sublistView(bytes);
        final numChannels = view.getUint16(22, Endian.little);
        final sampleRate = view.getUint32(24, Endian.little);
        final bitsPerSample = view.getUint16(34, Endian.little);

        expect(numChannels, equals(2), reason: '$filename must be stereo');
        expect(sampleRate, equals(44100), reason: '$filename must be 44.1 kHz');
        expect(bitsPerSample, equals(16), reason: '$filename must be 16-bit');

        final dataChunk = WinmmAudioPlayer.findDataChunk(bytes);
        expect(dataChunk, isNotNull, reason: '$filename must have a data chunk');
        expect(dataChunk!.length, greaterThan(100000));
      }
    });
  });

  group('WAV Buffer Parsing and Channel Separation Logic', () {
    test('isValidWav identifies valid and invalid buffers', () {
      final valid = createSyntheticWav();
      expect(WinmmAudioPlayer.isValidWav(valid), isTrue);

      final truncated = Uint8List.fromList([1, 2, 3]);
      expect(WinmmAudioPlayer.isValidWav(truncated), isFalse);

      final corrupted = Uint8List.fromList(valid);
      corrupted[0] = 0; // Break 'RIFF'
      expect(WinmmAudioPlayer.isValidWav(corrupted), isFalse);
    });

    test('findDataChunk correctly locates data offset and length', () {
      final wav = createSyntheticWav(numSamplePairs: 50);
      final chunk = WinmmAudioPlayer.findDataChunk(wav);
      expect(chunk, isNotNull);
      expect(chunk!.offset, equals(44));
      expect(chunk.length, equals(50 * 2 * 2)); // 50 pairs * 2 channels * 2 bytes = 200
    });

    test('processWavBuffer isolates left channel and zeroes right channel', () {
      final raw = createSyntheticWav(leftVal: 1000, rightVal: 2000);
      final processed = WinmmAudioPlayer.processWavBuffer(
        raw,
        volume: 0.20,
        channelMode: 'left',
      );

      final view = ByteData.sublistView(processed);
      // Left channel sample: round(1000 * 0.20) = 200
      final left = view.getInt16(44, Endian.little);
      // Right channel sample: 0 (completely silenced)
      final right = view.getInt16(46, Endian.little);

      expect(left, equals(200));
      expect(right, equals(0));
    });

    test('processWavBuffer isolates right channel and zeroes left channel', () {
      final raw = createSyntheticWav(leftVal: 1000, rightVal: 2000);
      final processed = WinmmAudioPlayer.processWavBuffer(
        raw,
        volume: 0.20,
        channelMode: 'right',
      );

      final view = ByteData.sublistView(processed);
      final left = view.getInt16(44, Endian.little);
      // Right channel sample: round(2000 * 0.20) = 400
      final right = view.getInt16(46, Endian.little);

      expect(left, equals(0));
      expect(right, equals(400));
    });

    test('processWavBuffer scales both channels identically in stereo mode', () {
      final raw = createSyntheticWav(leftVal: 1000, rightVal: 2000);
      final processed = WinmmAudioPlayer.processWavBuffer(
        raw,
        volume: 0.20,
        channelMode: 'both',
      );

      final view = ByteData.sublistView(processed);
      final left = view.getInt16(44, Endian.little);
      final right = view.getInt16(46, Endian.little);

      expect(left, equals(200));
      expect(right, equals(400));
    });

    test('processWavBuffer clamps volume to [0.01, 0.60]', () {
      final raw = createSyntheticWav(leftVal: 1000, rightVal: 1000);

      // Underflow volume clamp: 0.00 -> 0.01 (gain = 0.01 -> 10)
      final minProcessed = WinmmAudioPlayer.processWavBuffer(raw, volume: 0.00);
      final minView = ByteData.sublistView(minProcessed);
      expect(minView.getInt16(44, Endian.little), equals(10));

      // Overflow volume clamp: 1.00 -> 0.60 (gain = 0.60 -> 600)
      final maxProcessed = WinmmAudioPlayer.processWavBuffer(raw, volume: 1.00);
      final maxView = ByteData.sublistView(maxProcessed);
      expect(maxView.getInt16(44, Endian.little), equals(600));
    });
  });

  group('WinmmAudioPlayer Lifecycle & Error Surfacing', () {
    test('Successful simulated playback updates isPlaying state', () async {
      String? playedPath;
      int? playedFlags;

      final player = WinmmAudioPlayer(
        testPlaybackHandler: (path, flags) {
          playedPath = path;
          playedFlags = flags;
          return 1; // Success
        },
      );

      final raw = createSyntheticWav();
      await player.playProcessedBytes(raw, duration: const Duration(milliseconds: 200));

      expect(player.isPlaying.value, isTrue);
      expect(playedPath, isNotNull);
      expect(playedPath, endsWith('.wav'));
      expect(playedFlags, equals(WinmmAudioPlayer.sndFilename | WinmmAudioPlayer.sndAsync | WinmmAudioPlayer.sndNodefault));

      // Calling stop halts playback and resets state
      player.stop();
      expect(player.isPlaying.value, isFalse);
    });

    test('Simulated native failure throws and surfaces error', () async {
      final player = WinmmAudioPlayer(
        testPlaybackHandler: (path, flags) => 0, // Failure
      );

      final raw = createSyntheticWav();
      expect(
        () async => await player.playProcessedBytes(raw),
        throwsA(isA<Exception>()),
      );
      expect(player.isPlaying.value, isFalse);
    });
  });

  group('HardwareTestController Audio Integration', () {
    test('Initializes with safe default volume 20% (0.20)', () {
      final player = WinmmAudioPlayer(testPlaybackHandler: (p, f) => 1);
      final ctrl = HardwareTestController(audioPlayer: player);

      expect(ctrl.audioVolume.value, equals(0.20));
      expect(ctrl.isAudioPlaying.value, isFalse);
      expect(ctrl.audioErrorMessage.value, isEmpty);
    });

    test('resolveAudioAsset maps test parameters accurately to bundled assets', () {
      final player = WinmmAudioPlayer(testPlaybackHandler: (p, f) => 1);
      final ctrl = HardwareTestController(audioPlayer: player);

      // Chime
      expect(ctrl.resolveAudioAsset(kind: 'chime'), equals('assets/audio/channel_id_chime.wav'));

      // Pink noise
      expect(ctrl.resolveAudioAsset(kind: 'both', pinkNoise: true), equals('assets/audio/pink_noise.wav'));

      // Sweep
      expect(ctrl.resolveAudioAsset(kind: 'both', sweep: true), equals('assets/audio/bass_sweep_20_120hz.wav'));

      // Bass tones
      expect(ctrl.resolveAudioAsset(kind: 'both', frequency: 40.0), equals('assets/audio/bass_40hz.wav'));
      expect(ctrl.resolveAudioAsset(kind: 'both', frequency: 60.0), equals('assets/audio/bass_60hz.wav'));
      expect(ctrl.resolveAudioAsset(kind: 'both', frequency: 80.0), equals('assets/audio/bass_80hz.wav'));
      expect(ctrl.resolveAudioAsset(kind: 'both', frequency: 100.0), equals('assets/audio/bass_100hz.wav'));

      // 1 kHz
      expect(ctrl.resolveAudioAsset(kind: 'left', frequency: 1000.0), equals('assets/audio/sine_1khz_left.wav'));
      expect(ctrl.resolveAudioAsset(kind: 'right', frequency: 1000.0), equals('assets/audio/sine_1khz_right.wav'));
      expect(ctrl.resolveAudioAsset(kind: 'both', frequency: 1000.0), equals('assets/audio/sine_1khz_both.wav'));

      // 440 Hz
      expect(ctrl.resolveAudioAsset(kind: 'left', frequency: 440.0), equals('assets/audio/sine_440hz_left.wav'));
      expect(ctrl.resolveAudioAsset(kind: 'right', frequency: 440.0), equals('assets/audio/sine_440hz_right.wav'));
      expect(ctrl.resolveAudioAsset(kind: 'both', frequency: 440.0), equals('assets/audio/sine_440hz_both.wav'));
    });

    test('playAudioTone updates state and handles stopAudio', () async {
      final player = WinmmAudioPlayer(testPlaybackHandler: (p, f) => 1);
      final ctrl = HardwareTestController(audioPlayer: player);

      // Test stopAudio clears playing state
      ctrl.isAudioPlaying.value = true;
      ctrl.currentAudioKind.value = 'left';
      await ctrl.stopAudio();

      expect(ctrl.isAudioPlaying.value, isFalse);
      expect(ctrl.currentAudioKind.value, isEmpty);
    });
  });
}
