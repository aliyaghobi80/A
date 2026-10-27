// frontend/lib/widgets/hardware_tests/webcam_test_view.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/hardware_test_controller.dart';
import '../../theme/app_theme.dart';

class WebcamTestView extends StatelessWidget {
  const WebcamTestView({super.key});

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

          // Camera Launch Card
          Container(
            padding: const EdgeInsets.all(22),
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
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.videocam_rounded, color: Colors.white, size: 36),
                ),
                const SizedBox(height: 16),
                const Text(
                  'آزمون تصویر و درایور وب‌کم',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  'برای بررسی تصویر زنده، فوکوس، تغییر رزولوشن و ثبت عکس آزمایشی، ابزار دوربین ویندوز را باز کنید.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () => ctrl.launchCameraApp(),
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: const Text('باز کردن برنامه دوربین ویندوز (Camera App)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF59E0B),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                  ),
                ),
                Obx(() {
                  final msg = ctrl.cameraStatusMessage.value;
                  if (msg.isEmpty) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      msg,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF10B981), fontWeight: FontWeight.w600),
                    ),
                  );
                }),
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

          const SizedBox(height: 16),

          // Evaluation Row
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ثبت نتیجه تست وب‌کم',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'آیا وضوح تصویر، عملکرد فوکوس و نرخ فریم دوربین مورد تأیید است؟',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    ctrl.recordResult(
                      testName: 'تست وب‌کم و تصویر',
                      status: 'passed',
                      details: 'تصویر زنده دوربین بررسی شد؛ وضوح، فوکوس و سلامت سنسور تأیید گردید.',
                    );
                    Get.snackbar(
                      'ثبت شد',
                      'سلامت وب‌کم در کارنامه ثبت شد.',
                      snackPosition: SnackPosition.BOTTOM,
                      backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.9),
                      colorText: Colors.white,
                      duration: const Duration(seconds: 2),
                    );
                  },
                  icon: const Icon(Icons.check_rounded, size: 16),
                  label: const Text('تصویر دوربین شفاف است (موفق)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: () {
                    ctrl.recordResult(
                      testName: 'تست وب‌کم و تصویر',
                      status: 'failed',
                      details: 'تصویر سیاه، عدم شناسایی وب‌کم، فوکوس خراب یا قطع‌ووصلی گزارش شد.',
                    );
                    Get.snackbar(
                      'ثبت شد',
                      'ایراد وب‌کم در کارنامه ثبت شد.',
                      snackPosition: SnackPosition.BOTTOM,
                      backgroundColor: const Color(0xFFEF4444).withValues(alpha: 0.9),
                      colorText: Colors.white,
                      duration: const Duration(seconds: 2),
                    );
                  },
                  icon: const Icon(Icons.error_outline_rounded, size: 16),
                  label: const Text('ایراد در تصویر دوربین'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFEF4444),
                    side: const BorderSide(color: Color(0xFFEF4444)),
                  ),
                ),
              ],
            ),
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
