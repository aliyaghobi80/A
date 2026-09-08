import 'package:flutter/material.dart';
import '../../models/system_info.dart';
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
        color: color.withValues(alpha: isDark ? 0.22 : 0.09),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.60 : 0.30),
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

/// A dedicated, premium brand badge for motherboard manufacturers
/// Displaying English canonical name, Persian localized brand, brand-specific icon,
/// and distinctive signature color glow.
class MotherboardBrandBadge extends StatelessWidget {
  final MotherboardInfo motherboard;
  final bool compact;
  final bool showChipset;

  const MotherboardBrandBadge({
    super.key,
    required this.motherboard,
    this.compact = false,
    this.showChipset = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final brandColor = motherboard.brandColor;
    final brandEn = motherboard.effectiveBrand;
    final brandFa = motherboard.effectiveBrandFa;
    final chipset = motherboard.effectiveChipset;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: compact ? 3.5 : 5.5,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            brandColor.withValues(alpha: isDark ? 0.24 : 0.14),
            brandColor.withValues(alpha: isDark ? 0.08 : 0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: brandColor.withValues(alpha: isDark ? 0.5 : 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: brandColor.withValues(alpha: isDark ? 0.22 : 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: brandColor.withValues(alpha: isDark ? 0.3 : 0.16),
              shape: BoxShape.circle,
            ),
            child: Icon(
              motherboard.brandIcon,
              size: compact ? 12 : 14,
              color: brandColor,
            ),
          ),
          const SizedBox(width: 6),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Text(
              brandEn,
              style: TextStyle(
                fontSize: compact ? 11.5 : 12.5,
                fontWeight: FontWeight.w800,
                color: brandColor,
                letterSpacing: 0.4,
              ),
            ),
          ),
          if (brandFa.isNotEmpty) ...[
            Container(
              height: compact ? 10 : 12,
              width: 1,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              color: brandColor.withValues(alpha: 0.35),
            ),
            Text(
              brandFa,
              style: TextStyle(
                fontSize: compact ? 11 : 12,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white.withValues(alpha: 0.95) : const Color(0xFF1E293B),
              ),
            ),
          ],
          if (showChipset && chipset.isNotEmpty) ...[
            Container(
              height: compact ? 10 : 12,
              width: 1,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              color: brandColor.withValues(alpha: 0.35),
            ),
            Directionality(
              textDirection: TextDirection.ltr,
              child: Text(
                chipset,
                style: TextStyle(
                  fontSize: compact ? 10.5 : 11.5,
                  fontWeight: FontWeight.w700,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A premium, high-end badge for Genuine Original licenses (Windows / Office)
/// Featuring an emerald gradient with glowing borders, verified shield icon,
/// and Persian/English typography.
class GenuineOriginalBadge extends StatelessWidget {
  final String label;
  final String? subLabel;
  final bool compact;
  final bool isOffice;

  const GenuineOriginalBadge({
    super.key,
    this.label = 'اورجینال (Original)',
    this.subLabel,
    this.compact = false,
    this.isOffice = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const accentGold = Color(0xFF10B981);
    final primaryColor = isOffice ? const Color(0xFF10B981) : const Color(0xFF059669);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: compact ? 3.5 : 5.5,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accentGold.withValues(alpha: isDark ? 0.28 : 0.16),
            primaryColor.withValues(alpha: isDark ? 0.12 : 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: accentGold.withValues(alpha: isDark ? 0.6 : 0.4),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: accentGold.withValues(alpha: isDark ? 0.25 : 0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: accentGold.withValues(alpha: isDark ? 0.35 : 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.verified_rounded,
              size: compact ? 13 : 15,
              color: accentGold,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: compact ? 11.5 : 12.5,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF064E3B),
              letterSpacing: 0.2,
            ),
          ),
          if (subLabel != null && subLabel!.isNotEmpty) ...[
            Container(
              height: compact ? 10 : 12,
              width: 1,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              color: accentGold.withValues(alpha: 0.4),
            ),
            Directionality(
              textDirection: TextDirection.ltr,
              child: Text(
                subLabel!,
                style: TextStyle(
                  fontSize: compact ? 10.5 : 11.5,
                  fontWeight: FontWeight.w700,
                  color: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF047857),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
