// frontend/lib/widgets/hardware_tests/test_hub_view.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/hardware_test_controller.dart';
import '../../theme/app_theme.dart';

class TestHubView extends StatelessWidget {
  const TestHubView({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ctrl = Get.find<HardwareTestController>();

    final testItems = [
      _TestCardItem(
        id: 'monitor',
        title: 'تست مانیتور و پیکسل',
        subtitle: 'بررسی ۹ الگوی رنگی تمام‌صفحه RGB برای تشخیص پیکسل‌های سوخته، گیرکرده و یکنواختی پنل',
        icon: Icons.monitor_rounded,
        gradientColors: const [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
        badgeText: '۹ رنگ استاندارد',
      ),
      _TestCardItem(
        id: 'audio',
        title: 'تست صدا و هدفون',
        subtitle: 'تفکیک دقیق کانال چپ، کانال راست، صدای استریو و آزمون فرکانس‌های بم و بیس (Bass Sweep)',
        icon: Icons.headphones_rounded,
        gradientColors: const [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
        badgeText: 'تولید فرکانس درجا',
      ),
      _TestCardItem(
        id: 'mic',
        title: 'تست میکروفون و هدست',
        subtitle: 'سنجش ورودی صدا، وضعیت درایور و آزمون لوپ‌بک (ضبط فوری صدا و شنیدن در خروجی)',
        icon: Icons.mic_rounded,
        gradientColors: const [Color(0xFF10B981), Color(0xFF047857)],
        badgeText: 'بررسی زنده وضوح',
      ),
      _TestCardItem(
        id: 'webcam',
        title: 'تست وب‌کم و تصویر',
        subtitle: 'بررسی شناسایی وب‌کم‌های سیستم، فوکوس، وضوح تصویر و اجرای ابزار تست تصویر ویندوز',
        icon: Icons.videocam_rounded,
        gradientColors: const [Color(0xFFF59E0B), Color(0xFFD97706)],
        badgeText: 'بررسی فوکوس و FPS',
      ),
      _TestCardItem(
        id: 'keyboard',
        title: 'تست کیبورد (۱۰۵ کلید)',
        subtitle: 'شبیه‌ساز بصری و تعاملی کیبورد استاندارد همراه با کلیدهای میانبر، جهت‌نما و بخش ماشین‌حساب (Numpad)',
        icon: Icons.keyboard_rounded,
        gradientColors: const [Color(0xFF0EA5E9), Color(0xFF0284C7)],
        badgeText: '۱۰۵ کلید فیزیکی',
      ),
      _TestCardItem(
        id: 'mouse',
        title: 'تست موس و اسکرول',
        subtitle: 'سنجش کلیک چپ، راست، کلیک وسط چرخ و بررسی روان بودن حرکت اسکرول روی متن نمونه مرکزی',
        icon: Icons.mouse_rounded,
        gradientColors: const [Color(0xFFEC4899), Color(0xFFBE185D)],
        badgeText: 'کلیک و اسکرول',
      ),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Hub Header Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                    : [const Color(0xFFF8FAFC), const Color(0xFFEEF2F6)],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF3B82F6).withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.speed_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'مرکز تست و عیب‌یابی قطعات',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: isDark
                                  ? AppTheme.darkTextPrimary
                                  : AppTheme.lightTextPrimary,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: const Color(0xFF10B981).withValues(alpha: 0.4),
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_circle_outline, size: 13, color: Color(0xFF10B981)),
                                SizedBox(width: 4),
                                Text(
                                  'کاملاً آفلاین',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF10B981),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'محیط مستقل تست مانیتور، هدفون، میکروفون، وب‌کم، کیبورد و موس برای سیستم‌های اسمبل‌شده و لپ‌تاپ‌های آماده تحویل.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // 2. Grid of Interactive Test Containers
          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth > 950 ? 3 : (constraints.maxWidth > 640 ? 2 : 1);
              final itemWidth = (constraints.maxWidth - (crossAxisCount - 1) * 16) / crossAxisCount;

              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: testItems.map((item) {
                  return SizedBox(
                    width: itemWidth,
                    child: _buildTestCard(context, item, isDark, ctrl),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTestCard(
    BuildContext context,
    _TestCardItem item,
    bool isDark,
    HardwareTestController ctrl,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => ctrl.selectSubTest(item.id),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Icon & Tag
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: item.gradientColors,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(item.icon, color: Colors.white, size: 24),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: item.gradientColors.first.withValues(alpha: isDark ? 0.18 : 0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: item.gradientColors.first.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      item.badgeText,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: item.gradientColors.first,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Title
              Text(
                item.title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                ),
              ),
              const SizedBox(height: 6),
              // Description
              Text(
                item.subtitle,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.45,
                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 14),
              // Action Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'ورود به تست',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: item.gradientColors.first,
                    ),
                  ),
                  Icon(
                    Icons.arrow_back_rounded,
                    size: 16,
                    color: item.gradientColors.first,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TestCardItem {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> gradientColors;
  final String badgeText;

  const _TestCardItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradientColors,
    required this.badgeText,
  });
}
