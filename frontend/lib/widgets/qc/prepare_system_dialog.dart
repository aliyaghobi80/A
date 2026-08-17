// frontend/lib/widgets/qc/prepare_system_dialog.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/qc_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../models/qc_report.dart';

class PrepareSystemDialog extends StatefulWidget {
  final List<QcIssue> issues;

  const PrepareSystemDialog({
    super.key,
    required this.issues,
  });

  static Future<void> show(BuildContext context, List<QcIssue> issues) async {
    final preparable = issues.where((i) => i.canAutoPrepare).toList();
    if (preparable.isEmpty) return;

    await showDialog(
      context: context,
      builder: (ctx) => PrepareSystemDialog(issues: preparable),
    );
  }

  @override
  State<PrepareSystemDialog> createState() => _PrepareSystemDialogState();
}

class _PrepareSystemDialogState extends State<PrepareSystemDialog> {
  late final Set<String> _selectedIds;

  @override
  void initState() {
    super.initState();
    // Default select all preparable issues
    _selectedIds = widget.issues.map((i) => i.id).toSet();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);
    final qcCtrl = Get.find<QcController>();

    final selectedIssues = widget.issues.where((i) => _selectedIds.contains(i.id)).toList();

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 520,
        constraints: const BoxConstraints(maxHeight: 620),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.auto_fix_high_rounded, color: Color(0xFF2563EB), size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.prepareSystem,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.prepareSystemDescription,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(
                    Icons.close_rounded,
                    color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Checklist of Actions
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: widget.issues.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final issue = widget.issues[index];
                  final isSelected = _selectedIds.contains(issue.id);

                  IconData typeIcon;
                  Color typeColor;

                  if (issue.actionType == 'install_software') {
                    typeIcon = Icons.download_rounded;
                    typeColor = const Color(0xFF2563EB);
                  } else if (issue.actionType.startsWith('activate')) {
                    typeIcon = Icons.verified_user_rounded;
                    typeColor = const Color(0xFFD97706);
                  } else {
                    typeIcon = Icons.settings_suggest_rounded;
                    typeColor = const Color(0xFF10B981);
                  }

                  return InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _selectedIds.remove(issue.id);
                        } else {
                          _selectedIds.add(issue.id);
                        }
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9))
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? (isDark ? const Color(0xFF38BDF8).withValues(alpha: 0.5) : const Color(0xFF2563EB))
                              : (isDark ? const Color(0xFF1E2C4A) : const Color(0xFFE2E8F0)),
                          width: isSelected ? 1.4 : 1.0,
                        ),
                      ),
                      child: Row(
                        children: [
                          Checkbox(
                            value: isSelected,
                            activeColor: const Color(0xFF2563EB),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                            onChanged: (val) {
                              setState(() {
                                if (val == true) {
                                  _selectedIds.add(issue.id);
                                } else {
                                  _selectedIds.remove(issue.id);
                                }
                              });
                            },
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: typeColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(typeIcon, color: typeColor, size: 18),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  issue.name,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  issue.actionLabel,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              issue.isRequired ? (l10n.isPersian ? 'ضروری' : 'Required') : (l10n.isPersian ? 'اختیاری' : 'Optional'),
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFEF4444),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),

            // Footer Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.cancel),
                ),
                ElevatedButton.icon(
                  onPressed: selectedIssues.isEmpty
                      ? null
                      : () {
                          Navigator.of(context).pop();
                          qcCtrl.executeBatchPreparation(context, selectedIssues);
                        },
                  icon: const Icon(Icons.play_arrow_rounded, size: 18),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  label: Text(
                    '${l10n.executeSelectedActions} (${selectedIssues.length})',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
