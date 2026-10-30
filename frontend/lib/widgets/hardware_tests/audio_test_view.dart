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
                  'سطح ولوم آزمایشی (پیش‌فرض ۲۰٪):',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Obx(() {
                    return Slider(
                      value: ctrl.audioVolume.value.clamp(0.01, 0.60),
                      min: 0.01,
                      max: 0.60,
                      divisions: 59,
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

          const SizedBox(height: 12),

          // Mute Warning Banner & Safety Guidance
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.12 : 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.volume_off_rounded, size: 16, color: Color(0xFFF59E0B)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'هشدار ایمنی: در صورت عدم شنیدن صدا، کلید سخت‌افزاری Mute کیبورد، جک هدفون یا اسلایدر ولوم ویندوز را بررسی فرمایید.',
                    style: TextStyle(fontSize: 11.5, color: Color(0xFFD97706), fontWeight: FontWeight.w600),
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
                          'تست فرکانس بم، زیر و نویز مرجع',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'صدای فرکانس پایین و تن‌های مرجع را با ولوم ملایم پخش کنید.',
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
                      onPressed: () => ctrl.playAudioTone(kind: 'both', frequency: 440.0),
                      icon: const Icon(Icons.music_note_rounded, size: 16),
                      label: const Text('تن استاندارد ۴۴۰ هرتز (Concert Pitch A4)'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => ctrl.playAudioTone(kind: 'both', frequency: 1000.0),
                      icon: const Icon(Icons.tune_rounded, size: 16),
                      label: const Text('تن مرجع ۱۰۰۰ هرتز (1 kHz Reference)'),
                    ),
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
                    ElevatedButton.icon(
                      onPressed: () => ctrl.playAudioTone(kind: 'both', frequency: 500.0),
                      icon: const Icon(Icons.graphic_eq_rounded, size: 16),
                      label: const Text('نویز صورتی (Pink Noise 1/f)'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEC4899),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
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
