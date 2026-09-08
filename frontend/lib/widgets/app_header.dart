import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/qc_controller.dart';
import '../controllers/theme_language_controller.dart';
import '../l10n/app_localizations.dart';
import '../services/settings_service.dart';
import 'dialogs/exit_dialog.dart';

class AppHeader extends StatelessWidget {
  final bool isRefreshing;
  final VoidCallback onRefresh;
  final bool isDarkMode;
  final VoidCallback onToggleTheme;
  final DisplayMode displayMode;
  final ValueChanged<DisplayMode> onModeChanged;
  final String currentLanguage;
  final ValueChanged<String> onLanguageChanged;
  final String? lastUpdated;

  const AppHeader({
    super.key,
    required this.isRefreshing,
    required this.onRefresh,
    required this.isDarkMode,
    required this.onToggleTheme,
    required this.displayMode,
    required this.onModeChanged,
    required this.currentLanguage,
    required this.onLanguageChanged,
    this.lastUpdated,
  });

  Widget _buildSegmentedButton<T>({
    required BuildContext context,
    required T selectedValue,
    required List<({T value, String label, String? tooltip, IconData? icon})>
    options,
    required ValueChanged<T> onSelected,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    // Resolve accent color — falls back to colorScheme.primary if controller not yet registered
    final accentColor = Get.isRegistered<ThemeLanguageController>()
        ? Get.find<ThemeLanguageController>().currentAccentColor
        : theme.colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? const Color(0xFF263554) : const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: options.map((opt) {
          final isSelected = selectedValue == opt.value;

          Widget btn = Semantics(
            button: true,
            selected: isSelected,
            label: opt.tooltip ?? opt.label,
            child: InkWell(
              borderRadius: BorderRadius.circular(7),
              onTap: () => onSelected(opt.value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                constraints: const BoxConstraints(minHeight: 44),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isDark ? accentColor : Colors.white)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(7),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(
                              alpha: isDark ? 0.3 : 0.08,
                            ),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (opt.icon != null) ...[
                      Icon(
                        opt.icon,
                        size: 14,
                        color: isSelected
                            ? Colors.white
                            : (isDark
                                  ? const Color(0xFFCBD5E1)
                                  : const Color(0xFF64748B)),
                      ),
                      const SizedBox(width: 5),
                    ],
                    Text(
                      opt.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w600,
                        color: isSelected
                            ? Colors.white
                            : (isDark
                                  ? const Color(0xFFCBD5E1)
                                  : const Color(0xFF64748B)),

                      ),
                    ),
                  ],
                ),
              ),
            ),
          );

          if (opt.tooltip != null) {
            btn = Tooltip(message: opt.tooltip!, child: btn);
          }

          return btn;
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 800;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // App Brand Logo
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(
                      0xFF2563EB,
                    ).withValues(alpha: isDark ? 0.3 : 0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  'assets/logo/camputermarkazi.png',
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2563EB), Color(0xFF06B6D4)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.computer_rounded,
                      size: 24,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            // Title & Subtitle
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.appName,
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: isDark
                            ? const Color(0xFFF8FAFC)
                            : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color:
                            (isDark
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFF059669))
                                .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                          color:
                              (isDark
                                      ? const Color(0xFF10B981)
                                      : const Color(0xFF059669))
                                  .withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFF10B981),
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            l10n.liveInspector,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? const Color(0xFF6EE7B7)
                                  : const Color(0xFF047857),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.appSubtitle,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
            const Spacer(),

            // Mode Switcher [ Simple | Advanced ]
            _buildSegmentedButton<DisplayMode>(
              context: context,
              selectedValue: displayMode,
              onSelected: onModeChanged,
              options: [
                (
                  value: DisplayMode.simple,
                  label: l10n.simpleMode,
                  tooltip: l10n.simpleModeTooltip,
                  icon: Icons.receipt_long_rounded,
                ),
                (
                  value: DisplayMode.advanced,
                  label: l10n.advancedMode,
                  tooltip: l10n.advancedModeTooltip,
                  icon: Icons.dashboard_customize_rounded,
                ),
              ],
            ),
            const SizedBox(width: 10),

            // Language Switcher [ EN | FA ]
            _buildSegmentedButton<String>(
              context: context,
              selectedValue: currentLanguage,
              onSelected: onLanguageChanged,
              options: [
                (value: 'en', label: 'EN', tooltip: 'English', icon: null),
                (value: 'fa', label: 'FA', tooltip: 'فارسی', icon: null),
              ],
            ),
            const SizedBox(width: 10),

            // Theme Toggle Button
            Tooltip(
              message: isDarkMode
                  ? l10n.switchToLightMode
                  : l10n.switchToDarkMode,
              child: InkWell(
                borderRadius: BorderRadius.circular(9),
                onTap: onToggleTheme,
                child: Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF192238) : Colors.white,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF263554)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Icon(
                    isDarkMode
                        ? Icons.light_mode_rounded
                        : Icons.dark_mode_rounded,
                    size: 18,
                    color: isDark
                        ? const Color(0xFFFCD34D)
                        : const Color(0xFF475569),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),

            // Prominent Full System Check (QC) Button
            Builder(
              builder: (ctx) {
                if (Get.isRegistered<QcController>()) {
                  final qcCtrl = Get.find<QcController>();
                  return Obx(() {
                    final isChecking = qcCtrl.isChecking.value;
                    return ElevatedButton(
                      onPressed: isChecking
                          ? null
                          : () => qcCtrl.runFullCheck(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(
                          0xFF059669,
                        ), // Emerald Accent
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: const Color(
                          0xFF059669,
                        ).withValues(alpha: 0.6),
                        padding: EdgeInsets.symmetric(
                          horizontal: isCompact ? 12 : 16,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(9),
                        ),
                        elevation: 0,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isChecking) ...[
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            ),
                            if (!isCompact) ...[
                              const SizedBox(width: 8),
                              Text(
                                l10n.checking,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ] else ...[
                            const Icon(
                              Icons.health_and_safety_rounded,
                              size: 16,
                            ),
                            if (!isCompact) ...[
                              const SizedBox(width: 6),
                              Text(
                                l10n.runFullCheck,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ],
                        ],
                      ),
                    );
                  });
                }
                return const SizedBox.shrink();
              },
            ),
            const SizedBox(width: 10),

            // Refresh Button
            ElevatedButton(
              onPressed: isRefreshing ? null : onRefresh,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(
                  0xFF2563EB,
                ).withValues(alpha: 0.6),
                padding: EdgeInsets.symmetric(
                  horizontal: isCompact ? 12 : 16,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9),
                ),
                elevation: 0,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isRefreshing) ...[
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    if (!isCompact) ...[
                      const SizedBox(width: 8),
                      Text(
                        l10n.refreshing,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ] else ...[
                    const Icon(Icons.refresh_rounded, size: 16),
                    if (!isCompact) ...[
                      const SizedBox(width: 6),
                      Text(
                        l10n.refresh,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),

            // Exit Application Button
            Tooltip(
              message: 'خروج از برنامه',
              child: InkWell(
                borderRadius: BorderRadius.circular(9),
                onTap: () => ExitDialog.show(context),
                child: Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color:
                        (isDark
                                ? const Color(0xFFEF4444)
                                : const Color(0xFFFEE2E2))
                            .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Icon(
                    Icons.power_settings_new_rounded,
                    size: 18,
                    color: Color(0xFFEF4444),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
