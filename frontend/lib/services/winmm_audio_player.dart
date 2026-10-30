// frontend/lib/services/winmm_audio_player.dart
import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

typedef _PlaySoundWNative = Int32 Function(
  Pointer<Utf16> pszSound,
  IntPtr hmod,
  Uint32 fdwSound,
);
typedef _PlaySoundWDart = int Function(
  Pointer<Utf16> pszSound,
  int hmod,
  int fdwSound,
);

/// Native Windows Multimedia (winmm.dll) Audio Player for Markazi System Checker.
/// Provides zero-dependency, ultra-reliable PCM WAV playback with:
/// - In-memory software volume scaling (1% - 60%, safe default 20%)
/// - Dynamic channel isolation (Left ear, Right ear, Both channels)
/// - Reactive playback state (`isPlaying`, `currentTrack`, `errorMessage`)
/// - Immediate DAC termination via `sndPurge`
class WinmmAudioPlayer extends GetxService {
  static const int sndSync = 0x0000;
  static const int sndAsync = 0x0001;
  static const int sndNodefault = 0x0002;
  static const int sndMemory = 0x0004;
  static const int sndLoop = 0x0008;
  static const int sndNostop = 0x0010;
  static const int sndPurge = 0x0040;
  static const int sndFilename = 0x00020000;

  final RxBool isPlaying = false.obs;
  final RxString currentTrack = ''.obs;
  final RxString errorMessage = ''.obs;

  _PlaySoundWDart? _playSoundNative;
  int Function(String path, int flags)? testPlaybackHandler;
  Timer? _stopTimer;
  int _tempCounter = 0;

  WinmmAudioPlayer({this.testPlaybackHandler}) {
    _initNative();
  }

  void _initNative() {
    if (testPlaybackHandler != null) return;
    if (Platform.isWindows) {
      try {
        final lib = DynamicLibrary.open('winmm.dll');
        _playSoundNative = lib.lookupFunction<_PlaySoundWNative, _PlaySoundWDart>('PlaySoundW');
      } catch (e) {
        debugPrint('[WinmmAudioPlayer] Error loading winmm.dll: $e');
        errorMessage.value = 'خطا در بارگذاری کتابخانه صوتی ویندوز: $e';
      }
    }
  }

  /// Validates standard RIFF WAVE PCM header format.
  static bool isValidWav(Uint8List bytes) {
    if (bytes.length < 44) return false;
    final header = String.fromCharCodes(bytes.sublist(0, 4));
    final format = String.fromCharCodes(bytes.sublist(8, 12));
    return header == 'RIFF' && format == 'WAVE';
  }

  /// Locates the 'data' chunk offset and payload length in a RIFF WAVE file.
  static ({int offset, int length})? findDataChunk(Uint8List bytes) {
    if (!isValidWav(bytes)) return null;
    int offset = 12;
    while (offset + 8 <= bytes.length) {
      final chunkId = String.fromCharCodes(bytes.sublist(offset, offset + 4));
      final chunkLength = ByteData.sublistView(bytes).getUint32(offset + 4, Endian.little);
      if (chunkId == 'data') {
        return (offset: offset + 8, length: chunkLength);
      }
      offset += 8 + chunkLength;
      // Chunks are padded to 2-byte word boundaries
      if (chunkLength % 2 != 0) offset += 1;
    }
    return null;
  }

  /// Scales PCM samples and routes channels in memory without disk recreation.
  /// - [volume]: Software gain multiplier clamped to [0.01, 0.60].
  /// - [channelMode]: 'left' (zeroes right), 'right' (zeroes left), 'both' (scales both).
  static Uint8List processWavBuffer(
    Uint8List sourceBytes, {
    required double volume,
    String channelMode = 'both',
  }) {
    if (!isValidWav(sourceBytes)) return sourceBytes;

    final gain = volume.clamp(0.01, 0.60);
    final dataChunk = findDataChunk(sourceBytes);
    if (dataChunk == null) return sourceBytes;

    // Clone buffer for non-destructive modification
    final outBytes = Uint8List.fromList(sourceBytes);
    final view = ByteData.sublistView(outBytes);

    // Read format chunk to verify channels & bits per sample
    int numChannels = 2;
    int bitsPerSample = 16;
    if (sourceBytes.length >= 36) {
      numChannels = view.getUint16(22, Endian.little);
      bitsPerSample = view.getUint16(34, Endian.little);
    }

    if (bitsPerSample != 16) {
      return outBytes;
    }

    final dataStart = dataChunk.offset;
    final dataEnd = (dataStart + dataChunk.length).clamp(dataStart, outBytes.length);

    if (numChannels == 2) {
      // 16-bit interleaved stereo: Left = offset, Right = offset + 2
      for (int i = dataStart; i + 4 <= dataEnd; i += 4) {
        int left = view.getInt16(i, Endian.little);
        int right = view.getInt16(i + 2, Endian.little);

        if (channelMode == 'left') {
          left = (left * gain).round().clamp(-32768, 32767);
          right = 0;
        } else if (channelMode == 'right') {
          left = 0;
          right = (right * gain).round().clamp(-32768, 32767);
        } else {
          left = (left * gain).round().clamp(-32768, 32767);
          right = (right * gain).round().clamp(-32768, 32767);
        }

        view.setInt16(i, left, Endian.little);
        view.setInt16(i + 2, right, Endian.little);
      }
    } else if (numChannels == 1) {
      // Mono
      for (int i = dataStart; i + 2 <= dataEnd; i += 2) {
        int sample = view.getInt16(i, Endian.little);
        sample = (sample * gain).round().clamp(-32768, 32767);
        view.setInt16(i, sample, Endian.little);
      }
    }

    return outBytes;
  }

  /// Plays a bundled asset WAV file with real-time software gain and channel routing.
  Future<void> playAsset(
    String assetPath, {
    double volume = 0.20,
    String channel = 'both',
    Duration duration = const Duration(milliseconds: 2500),
  }) async {
    try {
      errorMessage.value = '';
      currentTrack.value = assetPath;

      final ByteData data = await rootBundle.load(assetPath);
      final Uint8List rawBytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);

      final processedBytes = processWavBuffer(
        rawBytes,
        volume: volume,
        channelMode: channel,
      );

      await playProcessedBytes(processedBytes, duration: duration);
    } catch (e) {
      debugPrint('[WinmmAudioPlayer] Playback error: $e');
      errorMessage.value = 'خطا در پخش فایل صوتی: $e';
      isPlaying.value = false;
      currentTrack.value = '';
      rethrow;
    }
  }

  /// Writes the adjusted buffer to a temporary file and triggers WinMM asynchronous playback.
  Future<void> playProcessedBytes(
    Uint8List wavBytes, {
    Duration duration = const Duration(milliseconds: 2500),
  }) async {
    stop();

    final tempDir = Directory.systemTemp;
    _tempCounter = (_tempCounter + 1) % 10;
    final tempFile = File('${tempDir.path}\\markazi_tone_$_tempCounter.wav');

    await tempFile.writeAsBytes(wavBytes, flush: true);

    if (testPlaybackHandler != null) {
      final res = testPlaybackHandler!(tempFile.path, sndFilename | sndAsync | sndNodefault);
      if (res == 0) {
        throw Exception('Native PlaySound returned 0 (Playback initialization failed)');
      }
    } else if (Platform.isWindows && _playSoundNative != null) {
      final pPath = tempFile.path.toNativeUtf16();
      try {
        final res = _playSoundNative!(pPath, 0, sndFilename | sndAsync | sndNodefault);
        if (res == 0) {
          throw Exception('WinMM PlaySoundW returned 0 (Device busy or unavailable)');
        }
      } finally {
        calloc.free(pPath);
      }
    } else if (!Platform.isWindows) {
      debugPrint('[WinmmAudioPlayer] Non-Windows OS detected; simulated playback');
    }

    isPlaying.value = true;
    _stopTimer?.cancel();
    _stopTimer = Timer(duration, () {
      isPlaying.value = false;
      currentTrack.value = '';
    });
  }

  /// Halts playback immediately on the hardware DAC via `sndPurge`.
  void stop() {
    _stopTimer?.cancel();
    isPlaying.value = false;
    currentTrack.value = '';

    if (testPlaybackHandler != null) {
      testPlaybackHandler!('', sndPurge);
    } else if (Platform.isWindows && _playSoundNative != null) {
      _playSoundNative!(nullptr, 0, sndPurge);
    }
  }

  @override
  void onClose() {
    stop();
    super.onClose();
  }
}
