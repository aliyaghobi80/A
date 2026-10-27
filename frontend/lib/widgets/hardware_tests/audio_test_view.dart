// frontend/lib/widgets/hardware_tests/audio_test_view.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/hardware_test_controller.dart';
import '../../theme/app_theme.dart';

class AudioTestView extends StatelessWidget {
  const AudioTestView({super.key});

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
                'تست صدا، تفکیک هدفون و فرکانس بیس',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Volume & Stop Control Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.volume_up_rounded, size: 20, color: Color(0xFF8B5CF6)),
                const SizedBox(width: 10),
                const Text(
                  'سطح ولوم آزمایشی:',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Obx(() {
                    return Slider(
                      value: ctrl.audioVolume.value,
                      min: 0.05,
                      max: 0.40,
                      divisions: 7,
                      label: '${(ctrl.audioVolume.value * 100).toInt()}%',
                      activeColor: const Color(0xFF8B5CF6),
                      onChanged: (val) => ctrl.audioVolume.value = val,
                    );
                  }),
                ),
                Obx(() {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${(ctrl.audioVolume.value * 100).toInt()}%',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontFamily: 'monospace'),
                    ),
                  );
                }),
                const SizedBox(width: 14),
                ElevatedButton.icon(
                  onPressed: () => ctrl.stopAudio(),
                  icon: const Icon(Icons.stop_rounded, size: 16),
                  label: const Text('توقف صدا ■'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 3 Channel Cards (Left, Right, Both)
          Row(
            children: [
              // Left Ear Card
              Expanded(
                child: _buildChannelCard(
                  title: 'کانال چپ (Left)',
                  description: 'فقط باید از گوشی یا بلندگوی سمت چپ صدا پخش شود.',
                  earLabel: 'L',
                  kind: 'left',
                  isDark: isDark,
                  ctrl: ctrl,
                  accentColor: const Color(0xFF3B82F6),
                  onPlay: () => ctrl.playAudioTone(kind: 'left', frequency: 440.0),
                ),
              ),
              const SizedBox(width: 14),
              // Right Ear Card
              Expanded(
                child: _buildChannelCard(
                  title: 'کانال راست (Right)',
                  description: 'فقط باید از گوشی یا بلندگوی سمت راست صدا پخش شود.',
                  earLabel: 'R',
                  kind: 'right',
                  isDark: isDark,
                  ctrl: ctrl,
                  accentColor: const Color(0xFF10B981),
                  onPlay: () => ctrl.playAudioTone(kind: 'right', frequency: 440.0),
                ),
              ),
              const SizedBox(width: 14),
              // Both Stereo Card
              Expanded(
                child: _buildChannelCard(
                  title: 'هر دو کانال (Stereo)',
                  description: 'صدا باید متوازن و همزمان از هر دو سمت شنیده شود.',
                  earLabel: 'L+R',
                  kind: 'both',
                  isDark: isDark,
                  ctrl: ctrl,
                  accentColor: const Color(0xFF8B5CF6),
                  onPlay: () => ctrl.playAudioTone(kind: 'both', frequency: 440.0),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Bass Frequency Test Card
          Container(
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
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.graphic_eq_rounded, color: Color(0xFFF59E0B), size: 20),
                    ),
                    const SizedBox(width: 10),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'تست فرکانس بم و بیس (Low Frequency)',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'صدای فرکانس پایین را با ولوم ملایم پخش کنید؛ دیافراگم نباید صدای خش‌خش یا تق‌تق داشته باشد.',
                          style: TextStyle(fontSize: 11.5, color: Colors.grey),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => ctrl.playAudioTone(kind: 'both', frequency: 60.0),
                      icon: const Icon(Icons.play_arrow_rounded, size: 16),
                      label: const Text('بیس ۶۰ هرتز (60 Hz)'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => ctrl.playAudioTone(kind: 'both', frequency: 80.0),
                      icon: const Icon(Icons.play_arrow_rounded, size: 16),
                      label: const Text('بیس ۸۰ هرتز (80 Hz)'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => ctrl.playAudioTone(kind: 'both', frequency: 100.0),
                      icon: const Icon(Icons.play_arrow_rounded, size: 16),
                      label: const Text('بیس ۱۰۰ هرتز (100 Hz)'),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => ctrl.playAudioTone(kind: 'both', frequency: 40.0, sweep: true),
                      icon: const Icon(Icons.waves_rounded, size: 16),
                      label: const Text('پویش پیوسته بیس (۴۰ تا ۱۲۰ هرتز Sweep)'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF59E0B),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Result Recording Bar
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
                        'ثبت نتیجه تست صدا و هدفون',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'آیا صدای کانال چپ و راست به‌درستی تفکیک شدند و صدای بیس بدون لرزش غیرعادی بود؟',
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
                      testName: 'تست صدا و تفکیک هدفون',
                      status: 'passed',
                      details: 'کانال چپ، راست، استریو و فرکانس بیس بدون نویز و با تفکیک صحیح شنیده شدند.',
                    );
                    Get.snackbar(
                      'ثبت شد',
                      'سلامت خروجی صدا در کارنامه ثبت شد.',
                      snackPosition: SnackPosition.BOTTOM,
                      backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.9),
                      colorText: Colors.white,
                      duration: const Duration(seconds: 2),
                    );
                  },
                  icon: const Icon(Icons.check_rounded, size: 16),
                  label: const Text('خروجی صدا سالم است (موفق)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: () {
                    ctrl.recordResult(
                      testName: 'تست صدا و تفکیک هدفون',
                      status: 'failed',
                      details: 'عدم پخش صدا از یکی از کانال‌ها، جابه‌جایی چپ/راست یا نویز غیرعادی گزارش شد.',
                    );
                    Get.snackbar(
                      'ثبت شد',
                      'ایراد خروجی صدا در کارنامه ثبت شد.',
                      snackPosition: SnackPosition.BOTTOM,
                      backgroundColor: const Color(0xFFEF4444).withValues(alpha: 0.9),
                      colorText: Colors.white,
                      duration: const Duration(seconds: 2),
                    );
                  },
                  icon: const Icon(Icons.error_outline_rounded, size: 16),
                  label: const Text('ایراد در خروجی صدا'),
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

  Widget _buildChannelCard({
    required String title,
    required String description,
    required String earLabel,
    required String kind,
    required bool isDark,
    required HardwareTestController ctrl,
    required Color accentColor,
    required VoidCallback onPlay,
  }) {
    return Obx(() {
      final isPlayingThis = ctrl.isAudioPlaying.value && ctrl.currentAudioKind.value == kind;

      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isPlayingThis ? accentColor : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            width: isPlayingThis ? 2.2 : 1.2,
          ),
          boxShadow: isPlayingThis
              ? [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.25),
                    blurRadius: 10,
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: isDark ? 0.2 : 0.1),
                shape: BoxShape.circle,
                border: Border.all(color: accentColor, width: 1.5),
              ),
              child: Center(
                child: Text(
                  earLabel,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: accentColor,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              description,
              style: TextStyle(
                fontSize: 11.5,
                color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onPlay,
                icon: Icon(
                  isPlayingThis ? Icons.waves_rounded : Icons.play_arrow_rounded,
                  size: 16,
                ),
                label: Text(isPlayingThis ? 'در حال پخش...' : 'پخش صدا'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}
