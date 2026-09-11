import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/device_settings_controller.dart';
import '../../controllers/theme_language_controller.dart';
import '../../theme/app_theme.dart';

class DeviceSettingsPage extends StatelessWidget {
  const DeviceSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<DeviceSettingsController>();
    final themeController = Get.find<ThemeLanguageController>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = themeController.currentAccentColor;

    return Obx(
      () => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'تنظیمات مهم دستگاه',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: isDark
                    ? AppTheme.darkTextPrimary
                    : AppTheme.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'تنظیمات سریع و ایمن برای تحویل دستگاه مشتری • ${controller.windowsLabel.value}',
              style: TextStyle(
                fontSize: 13,
                color: isDark
                    ? AppTheme.darkTextSecondary
                    : AppTheme.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 16),
            _ActionCard(
              icon: Icons.shield_rounded,
              iconColor: const Color(0xFF0284C7),
              title: 'Windows Security (Defender)',
              description: controller.pinNeedsConfirmation.value
                  ? 'میانبر ساخته می‌شود؛ ویندوز ۱۱ ممکن است تأیید نهایی Pin را از خود کاربر بخواهد.'
                  : 'دسترسی سریع به وضعیت امنیت و آنتی‌ویروس ویندوز از Taskbar.',
              isDark: isDark,
              trailing: FilledButton.icon(
                onPressed: controller.isPinningSecurity.value
                    ? null
                    : () => controller.pinSecurity(context),
                icon: controller.isPinningSecurity.value
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.push_pin_rounded, size: 18),
                label: const Text('پین به تسک‌بار'),
                style: FilledButton.styleFrom(
                  backgroundColor: accent,
                  minimumSize: const Size(150, 46),
                ),
              ),
            ),
            const SizedBox(height: 14),
            _ActionCard(
              icon: Icons.bedtime_rounded,
              iconColor: const Color(0xFF8B5CF6),
              title: 'Screen، Sleep و Hibernate',
              description: controller.hasBattery.value
                  ? 'هر سه زمان برای حالت اتصال لپ‌تاپ به برق و استفاده از باتری روی Never قرار می‌گیرند.'
                  : 'هر سه زمان مصرف انرژی کامپیوتر روی Never قرار می‌گیرند؛ مقادیر حالت باتری نیز برای دستگاه‌های پشتیبانی‌شده ذخیره می‌شوند.',
              isDark: isDark,
              trailing: OutlinedButton.icon(
                onPressed: !controller.isSettingSleep.value
                    ? () => controller.setSleepNever(context)
                    : null,
                icon: controller.isSettingSleep.value
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.all_inclusive_rounded, size: 19),
                label: const Text('همه روی Never'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(150, 46),
                ),
              ),
            ),
            const SizedBox(height: 14),
            _ActionCard(
              icon: Icons.rocket_launch_rounded,
              iconColor: const Color(0xFFF59E0B),
              title: 'Startup Apps',
              description:
                  'همهٔ برنامه‌های بخش Startup خاموش می‌شوند تا ورود به ویندوز سریع‌تر شود؛ سپس صفحهٔ Startup برای بررسی نتیجه باز می‌شود.',
              isDark: isDark,
              trailing: FilledButton.icon(
                onPressed: controller.isDisablingStartup.value
                    ? null
                    : () => controller.disableStartupApps(context),
                icon: controller.isDisablingStartup.value
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.power_off_rounded, size: 18),
                label: Text(
                  controller.isDisablingStartup.value
                      ? 'در حال خاموش‌کردن...'
                      : 'خاموش‌کردن همه',
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFD97706),
                  minimumSize: const Size(170, 46),
                ),
              ),
            ),
            const SizedBox(height: 14),
            _ActionCard(
              icon: Icons.layers_clear_rounded,
              iconColor: controller.isWindows10.value
                  ? const Color(0xFF0EA5E9)
                  : const Color(0xFF64748B),
              title: 'Background Apps ویندوز ۱۰',
              description: controller.isWindows10.value
                  ? 'اجرای پس‌زمینهٔ برنامه‌های Microsoft Store خاموش می‌شود تا مصرف RAM، باتری و اینترنت کمتر شود؛ سپس صفحهٔ Background Apps باز می‌شود.'
                  : 'این قابلیت مخصوص Windows 10 و برای بالابردن سرعت دستگاه است؛ تنظیم سراسری Background Apps در Windows 11 وجود ندارد.',
              isDark: isDark,
              trailing: OutlinedButton.icon(
                onPressed:
                    !controller.isWindows10.value ||
                        controller.isDisablingBackgroundApps.value
                    ? null
                    : () => controller.disableBackgroundApps(context),
                icon: controller.isDisablingBackgroundApps.value
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        controller.isWindows10.value
                            ? Icons.block_rounded
                            : Icons.lock_outline_rounded,
                        size: 18,
                      ),
                label: Text(
                  controller.isDisablingBackgroundApps.value
                      ? 'در حال اعمال...'
                      : (controller.isWindows10.value
                            ? 'خاموش‌کردن Background Apps'
                            : 'فقط Windows 10'),
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(210, 46),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(
                  0xFFF59E0B,
                ).withValues(alpha: isDark ? .12 : .08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFF59E0B).withValues(alpha: .35),
                ),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: Color(0xFFF59E0B)),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'هیچ‌کدام از این ابزارها سیستم را ری‌استارت نمی‌کنند. پس از پایان نصب همهٔ نرم‌افزارها و درایورها، ری‌استارت را خودتان انجام دهید.',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.6,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;
  final bool isDark;
  final Widget trailing;

  const _ActionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
    required this.isDark,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 640;
          final information = Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: isDark ? .18 : .1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      description,
                      style: const TextStyle(fontSize: 13, height: 1.55),
                    ),
                  ],
                ),
              ),
            ],
          );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                information,
                const SizedBox(height: 14),
                Align(alignment: Alignment.centerLeft, child: trailing),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: information),
              const SizedBox(width: 20),
              trailing,
            ],
          );
        },
      ),
    );
  }
}
