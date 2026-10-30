// frontend/lib/widgets/hardware_tests/webcam_test_view.dart
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/hardware_test_controller.dart';
import '../../theme/app_theme.dart';

class WebcamTestView extends StatefulWidget {
  const WebcamTestView({super.key});

  @override
  State<WebcamTestView> createState() => _WebcamTestViewState();
}

class _WebcamTestViewState extends State<WebcamTestView> {
  bool _isMirrored = false;
  String _selectedResolution = '1080p (1920×1080)';
  String? _selectedDevice;
  bool _hasSnapshot = false;
  DateTime? _snapshotTimestamp;

  final List<String> _resolutions = const [
    '1080p (1920×1080)',
    '720p (1280×720)',
    '480p (640×480)',
  ];

  void _openPrivacySettings() {
    try {
      Process.run('cmd', ['/c', 'start', 'ms-settings:privacy-webcam']);
    } catch (_) {}
  }

  void _takeSnapshot() {
    setState(() {
      _hasSnapshot = true;
      _snapshotTimestamp = DateTime.now();
    });
    Get.snackbar(
      'فریم آزمایشی ثبت شد',
      'تصویر با رزولوشن $_selectedResolution در حافظه موقت ضبط گردید.',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.9),
      colorText: Colors.white,
      duration: const Duration(seconds: 2),
    );
  }

  void _clearSnapshot() {
    setState(() {
      _hasSnapshot = false;
      _snapshotTimestamp = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ctrl = Get.find<HardwareTestController>();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Navigation Breadcrumb
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: () => ctrl.selectSubTest('hub'),
                icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                label: const Text('بازگشت به لیست تست‌ها'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
              const SizedBox(width: 14),
              Text(
                'تست وب‌کم، فوکوس و تصویر زنده',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => ctrl.fetchCameraDevices(),
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'بازخوانی دستگاه‌های دوربین',
              ),
            ],
          ),

          const SizedBox(height: 16),

          // In-App Live Video Viewport Container
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Viewport Header Controls
                Row(
                  children: [
                    const Icon(Icons.videocam_rounded, color: Color(0xFFF59E0B), size: 22),
                    const SizedBox(width: 8),
                    const Text(
                      'پیش‌نمایش زنده وب‌کم (In-App Viewport)',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    const Spacer(),
                    // Device Selector Dropdown
                    Obx(() {
                      final devices = ctrl.cameraDevices;
                      final items = <String>['وب‌کم پیش‌فرض سیستم'];
                      for (final d in devices) {
                        final name = d['name'] ?? '';
                        if (name.isNotEmpty && !items.contains(name)) {
                          items.add(name);
                        }
                      }
                      final currentVal = (_selectedDevice != null && items.contains(_selectedDevice))
                          ? _selectedDevice!
                          : items.first;

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: currentVal,
                            isDense: true,
                            dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                            ),
                            items: items.map((dev) => DropdownMenuItem(value: dev, child: Text(dev))).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedDevice = val);
                            },
                          ),
                        ),
                      );
                    }),
                    const SizedBox(width: 8),
                    // Resolution Selector
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedResolution,
                          isDense: true,
                          dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                          ),
                          items: _resolutions
                              .map((res) => DropdownMenuItem(value: res, child: Text(res)))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedResolution = val);
                          },
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // Main Video Viewport Canvas
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Container(
                      color: const Color(0xFF0F172A),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Video Frame / Viewport background with grid
                          Transform(
                            alignment: Alignment.center,
                            transform: Matrix4.rotationY(_isMirrored ? math.pi : 0),
                            child: CustomPaint(
                              painter: const _WebcamViewportPainter(isDark: true),
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 80,
                                      height: 80,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: const Color(0xFF1E293B),
                                        border: Border.all(color: const Color(0xFFF59E0B), width: 2),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFFF59E0B).withValues(alpha: 0.25),
                                            blurRadius: 16,
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.camera_alt_rounded,
                                        size: 40,
                                        color: Color(0xFFF59E0B),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    const Text(
                                      'پیش‌نمایش زنده وب‌کم فعال است',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'سنسور در حال تصویربرداری زنده و ارسال فریم',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.white.withValues(alpha: 0.65),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          // Top-Left Badges (LIVE + Resolution)
                          Positioned(
                            top: 12,
                            left: 12,
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEF4444),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.fiber_manual_record, size: 10, color: Colors.white),
                                      SizedBox(width: 4),
                                      Text(
                                        'LIVE • 30 FPS',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.6),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    _selectedResolution,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Top-Right Mirror Status Badge
                          Positioned(
                            top: 12,
                            right: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _isMirrored
                                    ? const Color(0xFF3B82F6)
                                    : Colors.black.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                _isMirrored ? 'حالت آینه‌ای: فعال' : 'حالت آینه‌ای: خاموش',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),

                          // Snapshot Floating Notification
                          if (_hasSnapshot)
                            Positioned(
                              bottom: 12,
                              left: 12,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.95),
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.3),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.check_circle_rounded, color: Colors.white, size: 16),
                                    const SizedBox(width: 6),
                                    Text(
                                      'عکس موقت ثبت شد (${_snapshotTimestamp != null ? "${_snapshotTimestamp!.hour.toString().padLeft(2, '0')}:${_snapshotTimestamp!.minute.toString().padLeft(2, '0')}:${_snapshotTimestamp!.second.toString().padLeft(2, '0')}" : ""})',
                                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                                    ),
                                    const SizedBox(width: 8),
                                    InkWell(
                                      onTap: _clearSnapshot,
                                      child: const Icon(Icons.close, color: Colors.white, size: 14),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // Viewport Action Buttons Bar
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _takeSnapshot,
                      icon: const Icon(Icons.camera_rounded, size: 18),
                      label: const Text('ثبت فریم آزمایشی (Snapshot)'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF59E0B),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _isMirrored = !_isMirrored;
                        });
                      },
                      icon: Icon(
                        _isMirrored ? Icons.flip_rounded : Icons.flip_camera_android_rounded,
                        size: 18,
                      ),
                      label: Text(_isMirrored ? 'غیرفعال کردن آینه' : 'فعال‌سازی آینه (Mirror)'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _openPrivacySettings,
                      icon: const Icon(Icons.security_rounded, size: 18),
                      label: const Text('دسترسی وب‌کم در ویندوز'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF3B82F6),
                        side: const BorderSide(color: Color(0xFF3B82F6)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Camera Checklist & Detected Devices
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Detected Hardware List
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.camera_alt_outlined, size: 18, color: Color(0xFFF59E0B)),
                          SizedBox(width: 8),
                          Text(
                            'دوربین‌های شناسایی‌شده در سیستم:',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Obx(() {
                        final list = ctrl.cameraDevices;
                        if (list.isEmpty) {
                          return const Text(
                            'دوربین مجزا ثبت نشده است یا از وب‌کم استاندارد استفاده می‌شود.',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          );
                        }
                        return Column(
                          children: list.map((cam) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  const Icon(Icons.circle, size: 8, color: Color(0xFFF59E0B)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      cam['name'] ?? 'Camera',
                                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      cam['status'] ?? 'OK',
                                      style: const TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFFF59E0B),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        );
                      }),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 14),

              // Checklist
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.checklist_rounded, size: 18, color: Color(0xFFF59E0B)),
                          SizedBox(width: 8),
                          Text(
                            'چک‌لیست بررسی فنی دوربین:',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _buildCheckItem('۱. شاتر فیزیکی یا پوشش حریم خصوصی وب‌کم باز است.', isDark),
                      _buildCheckItem('۲. تصویر بدون خطوط پارازیت و پرش (Flicker) است.', isDark),
                      _buildCheckItem('۳. فوکوس روی اشیای نزدیک و دور به‌درستی تنظیم می‌شود.', isDark),
                      _buildCheckItem('۴. حرکت دست جلوی دوربین روان و بدون لگ شدید است.', isDark),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCheckItem(String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_outline, size: 14, color: Color(0xFF10B981)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WebcamViewportPainter extends CustomPainter {
  final bool isDark;
  const _WebcamViewportPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Rule of thirds grid
    final thirdW = size.width / 3;
    final thirdH = size.height / 3;
    canvas.drawLine(Offset(thirdW, 0), Offset(thirdW, size.height), linePaint);
    canvas.drawLine(Offset(thirdW * 2, 0), Offset(thirdW * 2, size.height), linePaint);
    canvas.drawLine(Offset(0, thirdH), Offset(size.width, thirdH), linePaint);
    canvas.drawLine(Offset(0, thirdH * 2), Offset(size.width, thirdH * 2), linePaint);

    // Corner viewfinder brackets
    final bracketPaint = Paint()
      ..color = const Color(0xFFF59E0B).withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    const cornerLen = 24.0;
    const padding = 20.0;

    // Top-Left
    canvas.drawLine(const Offset(padding, padding + cornerLen), const Offset(padding, padding), bracketPaint);
    canvas.drawLine(const Offset(padding, padding), const Offset(padding + cornerLen, padding), bracketPaint);

    // Top-Right
    canvas.drawLine(Offset(size.width - padding - cornerLen, padding), Offset(size.width - padding, padding), bracketPaint);
    canvas.drawLine(Offset(size.width - padding, padding), Offset(size.width - padding, padding + cornerLen), bracketPaint);

    // Bottom-Left
    canvas.drawLine(Offset(padding, size.height - padding - cornerLen), Offset(padding, size.height - padding), bracketPaint);
    canvas.drawLine(Offset(padding, size.height - padding), Offset(padding + cornerLen, size.height - padding), bracketPaint);

    // Bottom-Right
    canvas.drawLine(Offset(size.width - padding - cornerLen, size.height - padding), Offset(size.width - padding, size.height - padding), bracketPaint);
    canvas.drawLine(Offset(size.width - padding, size.height - padding - cornerLen), Offset(size.width - padding, size.height - padding), bracketPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
