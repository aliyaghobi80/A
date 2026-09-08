import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:video_player_win/video_player_win.dart';

import '../../controllers/system_info_controller.dart';
import '../../main.dart';

class VideoSplashScreen extends StatefulWidget {
  const VideoSplashScreen({super.key});

  @override
  State<VideoSplashScreen> createState() => _VideoSplashScreenState();
}

class _VideoSplashScreenState extends State<VideoSplashScreen> {
  WinVideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  bool _videoFinished = false;
  bool _isNavigating = false;
  Timer? _safetyTimer;
  StreamSubscription? _systemInfoSubscription;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  void _log(String msg) {
    debugPrint('[VideoSplashScreen] $msg');
    try {
      final exeDir = File(Platform.resolvedExecutable).parent.path;
      final logDir = Directory('$exeDir\\logs');
      if (!logDir.existsSync()) {
        logDir.createSync(recursive: true);
      }
      final file = File('$exeDir\\logs\\splash.log');
      file.writeAsStringSync('[${DateTime.now().toIso8601String()}] $msg\r\n', mode: FileMode.append);
    } catch (_) {}
  }

  File? _findSplashVideo() {
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final candidates = [
      File('$exeDir\\data\\flutter_assets\\assets\\videos\\splash.mp4'),
      File('$exeDir\\assets\\videos\\splash.mp4'),
      File('${Directory.current.path}\\data\\flutter_assets\\assets\\videos\\splash.mp4'),
      File('${Directory.current.path}\\assets\\videos\\splash.mp4'),
      File('${Directory.current.path}\\frontend\\assets\\videos\\splash.mp4'),
      File('G:\\MarkaziSystem\\frontend\\assets\\videos\\splash.mp4'),
      File('G:\\MarkaziSystem\\dist\\splash.mp4'),
    ];

    for (final candidate in candidates) {
      if (candidate.existsSync()) {
        return candidate;
      }
    }
    return null;
  }

  Future<void> _initPlayer() async {
    _log('Initializing native Windows video player...');
    try {
      final videoFile = _findSplashVideo();
      if (videoFile == null) {
        _log('Splash video file not found in any candidate directory.');
        _onVideoFinished();
        return;
      }

      _log('Found splash video at: ${videoFile.path} (${videoFile.lengthSync()} bytes)');
      final ctrl = WinVideoPlayerController.file(videoFile);
      _controller = ctrl;

      await ctrl.initialize();
      _log('Video initialized successfully: size=${ctrl.value.size}, duration=${ctrl.value.duration}');

      if (!mounted) return;

      setState(() {
        _isInitialized = true;
      });

      ctrl.addListener(_videoListener);
      try {
        await ctrl.setPlaybackSpeed(2.0);
      } catch (_) {}
      await ctrl.play();
      try {
        await ctrl.setPlaybackSpeed(2.0);
        _log('Video playback speed set to 2.0x.');
      } catch (e) {
        _log('Warning: could not set playback speed to 2.0x: $e');
      }
      _log('Video playback started at 2.0x speed.');

      // Maximum fallback timeout in case video duration listener stalls (adjusted for 2.0x playback)
      final duration = ctrl.value.duration;
      final safetyMs = duration.inMilliseconds > 0
          ? (duration.inMilliseconds / 2.0).round() + 1500
          : 5000;
      _safetyTimer = Timer(Duration(milliseconds: safetyMs), () {
        _log('Safety timer fired after $safetyMs ms.');
        if (mounted && !_videoFinished) {
          _onVideoFinished();
        }
      });
    } catch (e, stack) {
      _log('Error initializing video: $e\n$stack');
      if (mounted) {
        setState(() {
          _hasError = true;
        });
        _onVideoFinished();
      }
    }
  }

  void _videoListener() {
    final ctrl = _controller;
    if (ctrl == null || !ctrl.value.isInitialized) return;
    final value = ctrl.value;

    if (value.isCompleted || (value.duration > Duration.zero && value.position >= value.duration)) {
      _log('Video reached end. Position: ${value.position}, Duration: ${value.duration}, isCompleted: ${value.isCompleted}');
      _onVideoFinished();
    }
  }

  void _onVideoFinished() {
    if (_videoFinished) return;
    _videoFinished = true;
    _safetyTimer?.cancel();

    final systemCtrl = Get.find<SystemInfoController>();
    if (systemCtrl.systemInfo.value != null || systemCtrl.errorMessage.value.isNotEmpty) {
      _navigateToDashboard();
    } else {
      // Re-render to show loading status if system is still warming up
      if (mounted) {
        setState(() {});
      }
      _listenForSystemReady(systemCtrl);
    }
  }

  void _listenForSystemReady(SystemInfoController systemCtrl) {
    // Poll or react to system info loading completion
    _systemInfoSubscription?.cancel();
    Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted || _isNavigating) {
        timer.cancel();
        return;
      }
      if (systemCtrl.systemInfo.value != null || systemCtrl.errorMessage.value.isNotEmpty) {
        timer.cancel();
        _navigateToDashboard();
      }
    });
  }

  void _skipVideo() {
    _log('User tapped Skip button.');
    _onVideoFinished();
    final systemCtrl = Get.find<SystemInfoController>();
    if (systemCtrl.systemInfo.value != null || systemCtrl.errorMessage.value.isNotEmpty) {
      _navigateToDashboard();
    }
  }

  void _navigateToDashboard() {
    if (_isNavigating || !mounted) return;
    _isNavigating = true;
    _log('Navigating to DashboardScreen.');

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 550),
        pageBuilder: (context, animation, secondaryAnimation) => const DashboardScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeInOut),
            child: child,
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _safetyTimer?.cancel();
    _systemInfoSubscription?.cancel();
    if (_controller != null) {
      _controller!.removeListener(_videoListener);
      _controller!.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final systemCtrl = Get.find<SystemInfoController>();
    final ctrl = _controller;

    return Scaffold(
      backgroundColor: const Color(0xFF070B14),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Responsive Fullscreen Cover Video Container
          if (_isInitialized && !_hasError && ctrl != null)
            Positioned.fill(
              child: FittedBox(
                fit: BoxFit.cover,
                clipBehavior: Clip.hardEdge,
                child: SizedBox(
                  width: ctrl.value.size.width > 0 ? ctrl.value.size.width : 1920,
                  height: ctrl.value.size.height > 0 ? ctrl.value.size.height : 1080,
                  child: WinVideoPlayer(ctrl),
                ),
              ),
            )
          else
            // Fallback Dark Branding while loading video or on error
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF131D33),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF22304E)),
                    ),
                    child: Image.asset(
                      'assets/logo/logo.png',
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => const Icon(Icons.speed_rounded, size: 56, color: Color(0xFF00E5FF)),
                    ),
                  ),
                ],
              ),
            ),

          // Responsive Loading Overlay (Appears only if video ended but system info is still scanning)
          if (_videoFinished)
            Obx(() {
              final info = systemCtrl.systemInfo.value;
              if (info != null) return const SizedBox.shrink();

              return Positioned(
                bottom: 48,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF131D33).withValues(alpha: 0.88),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.35)),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00E5FF)),
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Text(
                          'در حال آماده‌سازی و بارگذاری مشخصات سیستم...',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),

          // Subtle Responsive Skip Button (Top-Start)
          Positioned(
            top: 24,
            left: 24,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _skipVideo,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B).withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'رد کردن',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(Icons.skip_next_rounded, size: 16, color: Colors.white.withValues(alpha: 0.85)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
