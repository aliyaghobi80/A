// frontend/lib/widgets/hardware_tests/test_report_view.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../controllers/hardware_test_controller.dart';

class TestReportView extends StatelessWidget {
  const TestReportView({super.key});

  @override
  Widget build(BuildContext context) {
    final HardwareTestController ctrl = Get.find<HardwareTestController>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Bar
          _buildHeader(context, ctrl),
          const SizedBox(height: 20),

          // Summary Stats Cards
          Obx(() => _buildSummaryStats(ctrl)),
          const SizedBox(height: 24),

          // Actions Row (Copy, Export, Clear)
          _buildActionsRow(context, ctrl),
          const SizedBox(height: 24),

          // Results List or Empty State
          Obx(() {
            if (ctrl.testResults.isEmpty) {
              return _buildEmptyState();
            }
            return _buildResultsList(ctrl);
          }),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, HardwareTestController ctrl) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E222D),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2A2E3D)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => ctrl.selectSubTest('hub'),
            icon: const Icon(Icons.arrow_forward_rounded, color: Colors.white70),
            tooltip: 'بازگشت به منوی آزمون‌ها',
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF43A047).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF43A047).withValues(alpha: 0.3)),
            ),
            child: const Icon(Icons.assignment_turned_in_rounded, color: Color(0xFF66BB6A), size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'کارنامه و گزارش جامع سلامت سخت‌افزار',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                SizedBox(height: 4),
                Text(
                  'ثبت سوابق کیفی، کنترل سلامت ماژول‌ها و صدور گزارش QC تکنسین',
                  style: TextStyle(fontSize: 13, color: Colors.white54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryStats(HardwareTestController ctrl) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 650;
        final children = [
          Expanded(
            flex: isNarrow ? 0 : 1,
            child: _buildStatCard(
              title: 'مجموع آزمون‌های ثبت‌شده',
              value: '${ctrl.totalTestsCount}',
              icon: Icons.list_alt_rounded,
              color: const Color(0xFF42A5F5),
              bgColor: const Color(0xFF1976D2).withValues(alpha: 0.12),
            ),
          ),
          SizedBox(width: isNarrow ? 0 : 16, height: isNarrow ? 12 : 0),
          Expanded(
            flex: isNarrow ? 0 : 1,
            child: _buildStatCard(
              title: 'آزمون‌های تأییدشده (Pass)',
              value: '${ctrl.passedTestsCount}',
              icon: Icons.check_circle_outline_rounded,
              color: const Color(0xFF66BB6A),
              bgColor: const Color(0xFF388E3C).withValues(alpha: 0.12),
            ),
          ),
          SizedBox(width: isNarrow ? 0 : 16, height: isNarrow ? 12 : 0),
          Expanded(
            flex: isNarrow ? 0 : 1,
            child: _buildStatCard(
              title: 'نیازمند بررسی / ردشده',
              value: '${ctrl.failedTestsCount}',
              icon: Icons.error_outline_rounded,
              color: const Color(0xFFEF5350),
              bgColor: const Color(0xFFD32F2F).withValues(alpha: 0.12),
            ),
          ),
        ];

        if (isNarrow) {
          return Column(children: children);
        }
        return Row(children: children);
      },
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E222D),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 13, color: Colors.white70),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontFamily: 'Consolas',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionsRow(BuildContext context, HardwareTestController ctrl) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E222D),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2A2E3D)),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  final report = ctrl.getFormattedReport();
                  Clipboard.setData(ClipboardData(text: report));
                  Get.snackbar(
                    'کپی شد',
                    'متن گزارش با موفقیت در کلیپ‌بورد کپی شد',
                    snackPosition: SnackPosition.BOTTOM,
                    backgroundColor: const Color(0xFF2E7D32),
                    colorText: Colors.white,
                    duration: const Duration(seconds: 3),
                    margin: const EdgeInsets.all(16),
                    icon: const Icon(Icons.copy_rounded, color: Colors.white),
                  );
                },
                icon: const Icon(Icons.copy_rounded, size: 18),
                label: const Text('کپی متن گزارش (جهت گزارش QC و فاکتور)', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1976D2),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          OutlinedButton.icon(
            onPressed: () => _confirmClearResults(context, ctrl),
            icon: const Icon(Icons.delete_sweep_rounded, color: Color(0xFFEF5350), size: 18),
            label: const Text('پاک‌سازی سوابق آزمون', style: TextStyle(color: Color(0xFFEF5350))),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFEF5350)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmClearResults(BuildContext context, HardwareTestController ctrl) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E222D),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF2A2E3D)),
        ),
        title: const Text('پاک‌سازی سوابق آزمون‌ها', style: TextStyle(color: Colors.white)),
        content: const Text(
          'آیا از حذف تمام نتایج آزمون‌های ثبت‌شده در این نشست اطمینان دارید؟ این عمل غیرقابل بازگشت است.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('انصراف', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () {
              ctrl.clearResults();
              Navigator.of(ctx).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD32F2F),
              foregroundColor: Colors.white,
            ),
            child: const Text('حذف نتایج'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E222D),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2A2E3D)),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.assignment_late_outlined, size: 64, color: Colors.white.withValues(alpha: 0.2)),
            const SizedBox(height: 16),
            const Text(
              'هنوز تستی در این نشست کاری ثبت نشده است',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white70),
            ),
            const SizedBox(height: 8),
            const Text(
              'با اجرای هر یک از آزمون‌های مانیتور، صدا، میکروفون، کیبورد یا موس، نتیجه سلامت آن را ثبت کنید تا در اینجا و گزارش نهایی نمایش داده شود.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.white38),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsList(HardwareTestController ctrl) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E222D),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2A2E3D)),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: ctrl.testResults.length,
        separatorBuilder: (_, _) => const Divider(color: Color(0xFF2A2E3D), height: 1),
        itemBuilder: (context, index) {
          final result = ctrl.testResults[index];
          final isPassed = result.isPassed;
          final timeStr =
              '${result.timestamp.hour.toString().padLeft(2, '0')}:${result.timestamp.minute.toString().padLeft(2, '0')}:${result.timestamp.second.toString().padLeft(2, '0')}';

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              children: [
                // Index badge
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFF12141A),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF2A2E3D)),
                  ),
                  child: Text(
                    '${ctrl.testResults.length - index}',
                    style: const TextStyle(color: Colors.white54, fontSize: 13, fontFamily: 'Consolas'),
                  ),
                ),
                const SizedBox(width: 16),

                // Status Icon & Tag
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: (isPassed ? const Color(0xFF388E3C) : const Color(0xFFD32F2F)).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: (isPassed ? const Color(0xFF66BB6A) : const Color(0xFFEF5350)).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isPassed ? Icons.check_circle_rounded : Icons.cancel_rounded,
                        size: 16,
                        color: isPassed ? const Color(0xFF66BB6A) : const Color(0xFFEF5350),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        result.localizedStatus,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isPassed ? const Color(0xFF66BB6A) : const Color(0xFFEF5350),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),

                // Test Name & Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        result.testName,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        result.details,
                        style: const TextStyle(fontSize: 13, color: Colors.white70),
                      ),
                    ],
                  ),
                ),

                // Timestamp
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF12141A),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    timeStr,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white38,
                      fontFamily: 'Consolas',
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
