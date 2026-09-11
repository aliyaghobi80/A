import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../l10n/app_localizations.dart';

class InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;
  final bool isMonospace;
  final bool isPrimary;
  final bool copyable;
  final Widget? trailingBadge;
  final bool forceLtrValue;

  const InfoRow({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.isMonospace = false,
    this.isPrimary = false,
    this.copyable = false,
    this.trailingBadge,
    this.forceLtrValue = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);

    final isUnavailable =
        value.trim().toLowerCase() == 'not available' ||
        value.trim() == 'موجود نیست' ||
        value.trim().toLowerCase() == 'unknown' ||
        value.trim().toLowerCase() == 'n/a';

    Color valueColor;
    if (isUnavailable) {
      valueColor = isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8);
    } else if (isPrimary) {
      valueColor = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    } else {
      valueColor = isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155);
    }

    final displayValue = isUnavailable ? l10n.notAvailable : value;

    Widget valueWidget = Text(
      displayValue,
      style: TextStyle(
        fontSize: 13,
        fontWeight: isPrimary ? FontWeight.w600 : FontWeight.w500,
        fontFamily: isMonospace ? 'monospace' : null,
        fontStyle: isUnavailable ? FontStyle.italic : FontStyle.normal,
        color: valueColor,
      ),
      overflow: TextOverflow.ellipsis,
      maxLines: 2,
    );

    if (forceLtrValue || isMonospace) {
      valueWidget = Directionality(
        textDirection: TextDirection.ltr,
        child: valueWidget,
      );
    }

    final rowContent = Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 15,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
            const SizedBox(width: 8),
          ],
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isDark
                    ? const Color(0xFF94A3B8)
                    : const Color(0xFF64748B),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: valueWidget),
          ?trailingBadge,
          if (copyable && !isUnavailable) ...[
            const SizedBox(width: 6),
            Tooltip(
              message: l10n.copy,
              child: InkWell(
                borderRadius: BorderRadius.circular(4),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: value));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${l10n.copiedToClipboard}: $value'),
                      duration: const Duration(seconds: 1),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: Icon(
                    Icons.copy_rounded,
                    size: 13,
                    color: isDark
                        ? const Color(0xFF64748B)
                        : const Color(0xFF94A3B8),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );

    return rowContent;
  }
}
