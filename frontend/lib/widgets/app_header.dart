import 'package:flutter/material.dart';

class AppHeader extends StatelessWidget {
  final bool isRefreshing;
  final VoidCallback onRefresh;
  final bool isDarkMode;
  final VoidCallback onToggleTheme;
  final String? lastUpdated;

  const AppHeader({
    super.key,
    required this.isRefreshing,
    required this.onRefresh,
    required this.isDarkMode,
    required this.onToggleTheme,
    this.lastUpdated,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // App Logo Icon
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2563EB), Color(0xFF06B6D4)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2563EB).withValues(alpha: 0.35),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.computer_rounded,
            size: 24,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 14),
        // Title & Subtitle
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(
                  'PC System Inspector',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                    color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: (isDark ? const Color(0xFF10B981) : const Color(0xFF059669)).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(
                      color: (isDark ? const Color(0xFF10B981) : const Color(0xFF059669)).withValues(alpha: 0.3),
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
                        'Live Inspector',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF047857),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              'Hardware & Windows Information',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
        const Spacer(),

        // Theme Toggle Button
        Tooltip(
          message: isDarkMode ? 'Switch to Light Mode' : 'Switch to Dark Mode',
          child: InkWell(
            borderRadius: BorderRadius.circular(9),
            onTap: onToggleTheme,
            child: Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF192238) : Colors.white,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(
                  color: isDark ? const Color(0xFF263554) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Icon(
                isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                size: 18,
                color: isDark ? const Color(0xFFFCD34D) : const Color(0xFF475569),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),

        // Refresh Button
        ElevatedButton(
          onPressed: isRefreshing ? null : onRefresh,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2563EB),
            foregroundColor: Colors.white,
            disabledBackgroundColor: const Color(0xFF2563EB).withValues(alpha: 0.6),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                const SizedBox(width: 8),
                const Text(
                  'Refreshing...',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ] else ...[
                const Icon(Icons.refresh_rounded, size: 16),
                const SizedBox(width: 6),
                const Text(
                  'Refresh',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
