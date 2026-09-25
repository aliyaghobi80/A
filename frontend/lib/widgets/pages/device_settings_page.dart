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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF0F2B48), const Color(0xFF1E3A5F)]
                      : [const Color(0xFFEFF6FF), const Color(0xFFDBEAFE)],
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.35),
                ),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 640;
                  final info = Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF3B82F6,
                          ).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.auto_awesome_rounded,
                          color: Color(0xFF2563EB),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'اعمال یکپارچهٔ تمامی تنظیمات مهم',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF1E293B),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'تنظیم خودکار آیکون‌های دسکتاپ، ساعت تهران، حالت Never اسلیپ، باتری و بهینه‌سازی استارتاپ به صورت یکجا',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? const Color(0xFF94A3B8)
                                    : const Color(0xFF475569),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );

                  final buttons = Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: controller.isLoading.value
                            ? null
                            : controller.refreshStatus,
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: Text(
                          controller.isLoading.value
                              ? 'بررسی...'
                              : 'بررسی مجدد',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: controller.isApplyingAll.value
                            ? null
                            : () => controller.applyAllSettings(context),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: controller.isApplyingAll.value
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.flash_on_rounded, size: 18),
                        label: Text(
                          controller.isApplyingAll.value
                              ? 'در حال اعمال همه تنظیمات...'
                              : 'اعمال خودکار همه تنظیمات',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  );

                  if (compact) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        info,
                        const SizedBox(height: 12),
                        Align(alignment: Alignment.centerLeft, child: buttons),
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(child: info),
                      const SizedBox(width: 16),
                      buttons,
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            _ActionCard(
              icon: Icons.shield_rounded,
              iconColor: const Color(0xFF0284C7),
              title: 'آیکن‌های اصلی دسکتاپ',
              description:
                  'نمایش This PC، Control Panel و Recycle Bin؛ بدون تغییر سایر آیکن‌ها.',
              completed: controller.desktopIconsReady.value,
              isDark: isDark,
              trailing: FilledButton.icon(
                onPressed:
                    !controller.windowsActivated.value ||
                        controller.isSettingDesktopTime.value
                    ? null
                    : () =>
                          controller.configureDesktopTime(context, icons: true),
                icon: const Icon(Icons.desktop_windows_rounded, size: 18),
                label: Text(
                  !controller.windowsActivated.value
                      ? 'ابتدا ویندوز را فعال کنید'
                      : controller.desktopIconsReady.value
                      ? 'سه آیکن فعال هستند'
                      : 'نمایش سه آیکن',
                ),
              ),
            ),
            const SizedBox(height: 14),
            _ActionCard(
              icon: Icons.schedule_rounded,
              iconColor: const Color(0xFF0284C7),
              title: 'منطقهٔ زمانی تهران (UTC+03:30)',
              description:
                  '${controller.timezoneDescription.value}\nابتدا تهران تنظیم می‌شود؛ تشخیص خودکار ممکن است بعداً منطقه را بر اساس موقعیت تغییر دهد. ساعت خودکار گزینه‌ای جداست.',
              completed: controller.timezoneReady.value,
              isDark: isDark,
              trailing: FilledButton.icon(
                onPressed: controller.isSettingDesktopTime.value
                    ? null
                    : () => controller.configureDesktopTime(
                        context,
                        icons: false,
                      ),
                icon: const Icon(Icons.public_rounded, size: 18),
                label: Text(
                  controller.isSettingDesktopTime.value
                      ? 'در حال تنظیم...'
                      : 'تهران + منطقهٔ زمانی خودکار',
                ),
              ),
            ),
            const SizedBox(height: 14),
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
              description: controller.timeoutDescription.value,
              completed: controller.sleepReady.value == true,
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
                label: Text(
                  controller.sleepReady.value == true
                      ? 'الان همه روی Never هستند'
                      : 'همه روی Never',
                ),
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
              description: controller.startupDescription.value,
              completed: controller.startupReady.value == true,
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
                      : (controller.startupReady.value == true
                            ? 'همهٔ Startup Apps خاموش هستند'
                            : 'خاموش‌کردن همه'),
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
              completed: controller.backgroundReady.value == true,
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
                            ? (controller.backgroundReady.value == true
                                  ? 'Background Apps خاموش است'
                                  : 'خاموش‌کردن Background Apps')
                            : 'فقط Windows 10'),
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(210, 46),
                ),
              ),
            ),
            const SizedBox(height: 14),
            if (controller.hasBattery.value) ...[
              _ActionCard(
                icon: Icons.battery_charging_full_rounded,
                iconColor: accent,
                title: 'Power mode لپ‌تاپ',
                isDark: isDark,
                completed: controller.powerReady.value == true,
                description: controller.powerSupported.value
                    ? controller.powerDescription.value
                    : 'تنظیم جداگانهٔ Power mode در این نسخهٔ ویندوز پشتیبانی نمی‌شود؛ تنظیمات Power & battery ویندوز را بررسی کنید.',
                trailing: FilledButton.icon(
                  onPressed:
                      controller.isSettingPower.value ||
                          !controller.powerSupported.value
                      ? null
                      : () => controller.setPowerModes(context),
                  icon: const Icon(Icons.bolt_rounded),
                  label: Text(
                    controller.isSettingPower.value
                        ? 'در حال اعمال...'
                        : controller.powerReady.value == true
                        ? 'برق Performance / باتری Balanced'
                        : 'تنظیم برق و باتری',
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],
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
  final bool completed;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;
  final bool isDark;
  final Widget trailing;

  const _ActionCard({
    this.completed = false,
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
        color: completed
            ? const Color(0xFF10B981).withValues(alpha: isDark ? .12 : .08)
            : isDark
            ? AppTheme.darkCard
            : AppTheme.lightCard,
        boxShadow: completed
            ? [
                BoxShadow(
                  color: const Color(0xFF10B981).withValues(alpha: .12),
                  blurRadius: 12,
                ),
              ]
            : null,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: completed
              ? const Color(0xFF10B981)
              : isDark
              ? AppTheme.darkBorder
              : AppTheme.lightBorder,
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
                child: Icon(
                  completed ? Icons.check_circle_rounded : icon,
                  color: completed ? const Color(0xFF059669) : iconColor,
                  size: 28,
                ),
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
