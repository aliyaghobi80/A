import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

enum BadgeStatus {
  success,
  warning,
  danger,
  neutral,
  info,
}

class StatusDot extends StatelessWidget {
  final String label;
  final BadgeStatus status;
  final double fontSize;

  const StatusDot({
    super.key,
    required this.label,
    this.status = BadgeStatus.success,
    this.fontSize = 12.5,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Color color;

    switch (status) {
      case BadgeStatus.success:
        color = AppTheme.statusSuccess;
        break;
      case BadgeStatus.warning:
        color = AppTheme.statusWarning;
        break;
      case BadgeStatus.danger:
        color = AppTheme.statusDanger;
        break;
      case BadgeStatus.info:
        color = const Color(0xFF0284C7);
        break;
      case BadgeStatus.neutral:
        color = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;
        break;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}

class StatusBadge extends StatelessWidget {
  final String label;
  final BadgeStatus status;
  final IconData? icon;
  final bool showIcon;
  final double fontSize;

  const StatusBadge({
    super.key,
    required this.label,
    this.status = BadgeStatus.success,
    this.icon,
    this.showIcon = true,
    this.fontSize = 12,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Color color;

    switch (status) {
      case BadgeStatus.success:
        color = AppTheme.statusSuccess;
        break;
      case BadgeStatus.warning:
        color = AppTheme.statusWarning;
        break;
      case BadgeStatus.danger:
        color = AppTheme.statusDanger;
        break;
      case BadgeStatus.info:
        color = const Color(0xFF0284C7);
        break;
      case BadgeStatus.neutral:
        color = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.18 : 0.09),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.4 : 0.25),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showIcon) ...[
            Icon(
              icon ?? _getDefaultIcon(status),
              size: fontSize + 1,
              color: color,
            ),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getDefaultIcon(BadgeStatus st) {
    switch (st) {
      case BadgeStatus.success:
        return Icons.check_circle_rounded;
      case BadgeStatus.warning:
        return Icons.warning_amber_rounded;
      case BadgeStatus.danger:
        return Icons.error_outline_rounded;
      case BadgeStatus.info:
        return Icons.info_outline_rounded;
      case BadgeStatus.neutral:
        return Icons.remove_circle_outline_rounded;
    }
  }
}

class MetaTag extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;
  final bool isLtrValue;

  const MetaTag({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.isLtrValue = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted),
            const SizedBox(width: 5),
          ],
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted,
            ),
          ),
          Directionality(
            textDirection: isLtrValue ? TextDirection.ltr : TextDirection.rtl,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class EmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;

  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 56, color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted),
            const SizedBox(height: 14),
            Text(
              title,
              style: TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.w800,
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 13.5,
                color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted,
              ),
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[
              const SizedBox(height: 18),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
