// frontend/lib/models/qc_report.dart
import 'package:flutter/material.dart';

enum QcState {
  pass,
  warning,
  fail,
  unknown,
  notPresent;

  static QcState fromString(String? val) {
    switch ((val ?? '').toUpperCase().trim()) {
      case 'PASS':
      case 'OK':
      case 'SUCCESS':
        return QcState.pass;
      case 'WARNING':
      case 'WARN':
        return QcState.warning;
      case 'FAIL':
      case 'ERROR':
        return QcState.fail;
      case 'NOT_PRESENT':
      case 'NOT PRESENT':
        return QcState.notPresent;
      case 'UNKNOWN':
      default:
        return QcState.unknown;
    }
  }

  Color getColor(bool isDark) {
    switch (this) {
      case QcState.pass:
        return const Color(0xFF10B981); // Emerald Green
      case QcState.warning:
        return const Color(0xFFF59E0B); // Amber Warning
      case QcState.fail:
        return const Color(0xFFEF4444); // Rose Red
      case QcState.notPresent:
        return isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8); // Slate
      case QcState.unknown:
        return isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    }
  }

  IconData get icon {
    switch (this) {
      case QcState.pass:
        return Icons.check_circle_rounded;
      case QcState.warning:
        return Icons.warning_amber_rounded;
      case QcState.fail:
        return Icons.cancel_rounded;
      case QcState.notPresent:
        return Icons.remove_circle_outline_rounded;
      case QcState.unknown:
        return Icons.help_outline_rounded;
    }
  }
}

class QcReport {
  final String timestamp;
  final String overallStatus; // 'READY' or 'NEEDS_ATTENTION'
  final bool isReady;
  final bool hasProblems;
  final int problemsCount;
  final int requiredProblemsCount;
  final int passedCategoriesCount;
  final int totalCategoriesCount;
  final List<QcCategory> categories;
  final List<QcIssue> problems;

  const QcReport({
    required this.timestamp,
    required this.overallStatus,
    required this.isReady,
    required this.hasProblems,
    required this.problemsCount,
    required this.requiredProblemsCount,
    required this.passedCategoriesCount,
    required this.totalCategoriesCount,
    required this.categories,
    required this.problems,
  });

  factory QcReport.fromJson(Map<String, dynamic> json) {
    final catsRaw = json['categories'] as List? ?? [];
    final probsRaw = json['problems'] as List? ?? [];

    return QcReport(
      timestamp: json['timestamp'] as String? ?? DateTime.now().toIso8601String(),
      overallStatus: json['overall_status'] as String? ?? 'NEEDS_ATTENTION',
      isReady: json['is_ready'] as bool? ?? false,
      hasProblems: json['has_problems'] as bool? ?? false,
      problemsCount: json['problems_count'] as int? ?? probsRaw.length,
      requiredProblemsCount: json['required_problems_count'] as int? ?? 0,
      passedCategoriesCount: json['passed_categories_count'] as int? ?? 0,
      totalCategoriesCount: json['total_categories_count'] as int? ?? catsRaw.length,
      categories: catsRaw.map((e) => QcCategory.fromJson(e as Map<String, dynamic>)).toList(),
      problems: probsRaw.map((e) => QcIssue.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }

  static QcReport empty() {
    return QcReport(
      timestamp: DateTime.now().toIso8601String(),
      overallStatus: 'NEEDS_ATTENTION',
      isReady: false,
      hasProblems: false,
      problemsCount: 0,
      requiredProblemsCount: 0,
      passedCategoriesCount: 0,
      totalCategoriesCount: 0,
      categories: [],
      problems: [],
    );
  }
}

class QcCategory {
  final String id;
  final String name;
  final String displayName;
  final QcState state;
  final int passedCount;
  final int totalCount;
  final List<QcItem> items;

  const QcCategory({
    required this.id,
    required this.name,
    required this.displayName,
    required this.state,
    required this.passedCount,
    required this.totalCount,
    required this.items,
  });

  factory QcCategory.fromJson(Map<String, dynamic> json) {
    final itemsRaw = json['items'] as List? ?? [];
    return QcCategory(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      displayName: json['displayName'] as String? ?? json['name'] as String? ?? '',
      state: QcState.fromString(json['state'] as String?),
      passedCount: json['passed_count'] as int? ?? 0,
      totalCount: json['total_count'] as int? ?? itemsRaw.length,
      items: itemsRaw.map((e) => QcItem.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}

class QcItem {
  final String id;
  final String name;
  final String detail;
  final QcState state;
  final bool isRequired;
  final String? packageId;
  final String? packageFilename;

  const QcItem({
    required this.id,
    required this.name,
    required this.detail,
    required this.state,
    required this.isRequired,
    this.packageId,
    this.packageFilename,
  });

  factory QcItem.fromJson(Map<String, dynamic> json) {
    return QcItem(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      detail: json['detail'] as String? ?? '',
      state: QcState.fromString(json['state'] as String?),
      isRequired: json['is_required'] as bool? ?? true,
      packageId: json['package_id'] as String?,
      packageFilename: json['package_filename'] as String?,
    );
  }
}

class QcIssue {
  final String id;
  final String category;
  final String categoryName;
  final String name;
  final QcState status;
  final QcState severity;
  final String description;
  final bool isRequired;
  final String actionType; // 'install_software', 'activate_windows', 'activate_office', 'open_folder', 'view_details', 'none'
  final String actionLabel;
  final String actionTarget;
  final String? packageFilename;
  final bool canAutoPrepare;

  const QcIssue({
    required this.id,
    required this.category,
    required this.categoryName,
    required this.name,
    required this.status,
    required this.severity,
    required this.description,
    required this.isRequired,
    required this.actionType,
    required this.actionLabel,
    required this.actionTarget,
    this.packageFilename,
    this.canAutoPrepare = false,
  });

  factory QcIssue.fromJson(Map<String, dynamic> json) {
    return QcIssue(
      id: json['id'] as String? ?? '',
      category: json['category'] as String? ?? '',
      categoryName: json['category_name'] as String? ?? '',
      name: json['name'] as String? ?? '',
      status: QcState.fromString(json['status'] as String?),
      severity: QcState.fromString(json['severity'] as String?),
      description: json['description'] as String? ?? '',
      isRequired: json['is_required'] as bool? ?? true,
      actionType: json['action_type'] as String? ?? 'none',
      actionLabel: json['action_label'] as String? ?? '',
      actionTarget: json['action_target'] as String? ?? '',
      packageFilename: json['package_filename'] as String?,
      canAutoPrepare: json['can_auto_prepare'] as bool? ?? false,
    );
  }
}
