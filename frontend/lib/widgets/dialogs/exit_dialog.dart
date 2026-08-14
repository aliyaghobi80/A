import 'dart:io';
import 'package:flutter/material.dart';
import '../../services/backend_process_manager.dart';

class ExitDialog {
  static Future<void> show(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    await showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF131D33) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.power_settings_new_rounded, color: Color(0xFFEF4444), size: 22),
            ),
            const SizedBox(width: 12),
            Text(
              'خروج از برنامه',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        content: Text(
          'آیا مایل به خروج کامل از نرم‌افزار (بستن پروسه بک‌اند و End Task) هستید یا مایلید در پس‌زمینه فعال بماند؟',
          style: TextStyle(
            fontSize: 14,
            height: 1.5,
            color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
          ),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('انصراف'),
          ),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.of(dialogCtx).pop();
            },
            icon: const Icon(Icons.minimize_rounded, size: 16),
            label: const Text('پس‌زمینه'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF3B82F6),
              side: const BorderSide(color: Color(0xFF3B82F6)),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.of(dialogCtx).pop();
              // Complete Exit (End Task)
              await BackendProcessManager.terminateAll();
              exit(0);
            },
            icon: const Icon(Icons.close_rounded, size: 16),
            label: const Text('خروج کامل (End Task)'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
