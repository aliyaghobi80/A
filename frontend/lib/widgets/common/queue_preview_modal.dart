import 'package:flutter/material.dart';
import '../../models/system_info.dart';
import '../../theme/app_theme.dart';

/// Pre-Run Queue Preview Sheet & Dialog.
///
/// Shows the exact sequence of packages sorted by weight/priority before
/// deployment begins, featuring:
/// - Real-time search by package name, category, and installer file
/// - Filter chips (All, Serial Barriers, 2X Parallel, and Category/Tier groups)
/// - Visual barrier vs parallel badges
/// - Weight & Priority sequence indicators
/// - Minimum 44px touch targets
/// - Full Persian RTL layout with numbers/paths formatted LTR
class QueuePreviewModal extends StatefulWidget {
  final String title;
  final String subtitle;
  final List<QueuePreviewItem> items;
  final VoidCallback onConfirm;
  final bool isDark;
  final Color accentColor;
  final bool doubleSpeed;

  const QueuePreviewModal({
    super.key,
    required this.title,
    required this.subtitle,
    required this.items,
    required this.onConfirm,
    required this.isDark,
    required this.accentColor,
    this.doubleSpeed = false,
  });

  /// Displays the Software Queue Preview sheet.
  static Future<bool?> showSoftwarePreview({
    required BuildContext context,
    required List<SoftwarePackage> packages,
    required VoidCallback onConfirm,
    required bool isDark,
    required Color accentColor,
    bool doubleSpeed = false,
  }) {
    // Sort software packages strictly by weight tiers
    final sorted = List<SoftwarePackage>.from(packages);
    sorted.sort((a, b) => _calculateSoftwareWeight(a).compareTo(_calculateSoftwareWeight(b)));

    final previewItems = sorted.map((pkg) {
      final isBarrier = _isSoftwareBarrier(pkg);
      final tierName = _getSoftwareTierName(pkg);
      return QueuePreviewItem(
        id: pkg.id,
        name: pkg.name,
        category: tierName,
        categoryFa: tierName,
        installerFile: pkg.filename,
        fileSizeDisplay: pkg.fileSizeDisplay,
        isBarrier: isBarrier,
        priorityScore: _calculateSoftwareWeight(pkg),
        icon: _getSoftwareIcon(pkg),
      );
    }).toList();

    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => QueuePreviewModal(
        title: 'پیش‌نمایش صف نصب نرم‌افزارها',
        subtitle: 'ترتیب اجرای بسته‌ها بر اساس سبک‌وزن بودن و نیازمندی‌های سیستمی مرتب شده است.',
        items: previewItems,
        onConfirm: onConfirm,
        isDark: isDark,
        accentColor: accentColor,
        doubleSpeed: doubleSpeed,
      ),
    );
  }

  /// Displays the Driver Queue Preview sheet.
  static Future<bool?> showDriverPreview({
    required BuildContext context,
    required List<IntelligentDriverPackage> packages,
    required VoidCallback onConfirm,
    required bool isDark,
    required Color accentColor,
    bool doubleSpeed = false,
  }) {
    // Sort drivers strictly by 9-tier priority
    final sorted = List<IntelligentDriverPackage>.from(packages);
    sorted.sort((a, b) => _calculateDriverTierOrder(a).compareTo(_calculateDriverTierOrder(b)));

    final previewItems = sorted.map((pkg) {
      final isBarrier = _isDriverBarrier(pkg);
      return QueuePreviewItem(
        id: pkg.packageId,
        name: pkg.displayName,
        category: pkg.category,
        categoryFa: pkg.categoryFa,
        installerFile: pkg.installerFile,
        fileSizeDisplay: pkg.fileSizeDisplay,
        isBarrier: isBarrier,
        priorityScore: _calculateDriverTierOrder(pkg),
        icon: _getDriverIcon(pkg.category),
      );
    }).toList();

    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => QueuePreviewModal(
        title: 'پیش‌نمایش صف نصب درایورها',
        subtitle: 'ترتیب نصب بر مبنای اولویت ۹ سطحی استاندارد و تفکیک سد متوالی / موازی ۲X مرتب شده است.',
        items: previewItems,
        onConfirm: onConfirm,
        isDark: isDark,
        accentColor: accentColor,
        doubleSpeed: doubleSpeed,
      ),
    );
  }

  static int _calculateSoftwareWeight(SoftwarePackage pkg) {
    final nameLower = '${pkg.name} ${pkg.filename}'.toLowerCase();
    // Tier 1: Lightweight utilities (100..199)
    if (nameLower.contains('winrar') || nameLower.contains('7-zip')) return 110;
    if (nameLower.contains('firefox')) return 120;
    if (nameLower.contains('vlc') || nameLower.contains('kmplayer')) return 130;
    if (nameLower.contains('fdm') || nameLower.contains('download manager')) return 140;

    // Tier 2: System runtimes (200..299, strict barrier)
    if (nameLower.contains('visual c++') || nameLower.contains('vcredist')) return 210;
    if (nameLower.contains('.net')) return 220;
    if (nameLower.contains('directx')) return 230;

    // Tier 3: Heavyweight applications (300..399)
    if (nameLower.contains('chrome')) return 310;
    if (nameLower.contains('acrobat') || nameLower.contains('reader')) return 320;
    if (nameLower.contains('anydesk')) return 330;

    // Tier 4: Office Suite (400, final strict barrier)
    if (nameLower.contains('office') || nameLower.contains('word')) return 400;

    return 250;
  }

  static bool _isSoftwareBarrier(SoftwarePackage pkg) {
    final nameLower = '${pkg.name} ${pkg.filename}'.toLowerCase();
    if (nameLower.contains('office') ||
        nameLower.contains('visual c++') ||
        nameLower.contains('vcredist') ||
        nameLower.contains('.net') ||
        nameLower.contains('directx')) {
      return true;
    }
    final fmt = '${pkg.packageFormat} ${pkg.installerType}'.toUpperCase();
    if (fmt.contains('MSI') || fmt.contains('CMD') || fmt.contains('BAT')) {
      return true;
    }
    return false;
  }

  static String _getSoftwareTierName(SoftwarePackage pkg) {
    final weight = _calculateSoftwareWeight(pkg);
    if (weight < 200) return 'ابزارهای سبک (Tier 1)';
    if (weight < 300) return 'پیش‌نیازها و ران‌تایم (Tier 2)';
    if (weight < 400) return 'برنامه‌های کاربردی (Tier 3)';
    return 'مجموعه آفیس (Tier 4)';
  }

  static IconData _getSoftwareIcon(SoftwarePackage pkg) {
    final nameLower = '${pkg.name} ${pkg.filename}'.toLowerCase();
    if (nameLower.contains('chrome') || nameLower.contains('firefox')) {
      return Icons.public_rounded;
    }
    if (nameLower.contains('vlc') || nameLower.contains('kmplayer')) {
      return Icons.play_circle_fill_rounded;
    }
    if (nameLower.contains('winrar') || nameLower.contains('7-zip')) {
      return Icons.folder_zip_rounded;
    }
    if (nameLower.contains('office') || nameLower.contains('word')) {
      return Icons.description_rounded;
    }
    if (nameLower.contains('visual c++') || nameLower.contains('.net')) {
      return Icons.settings_applications_rounded;
    }
    return Icons.apps_rounded;
  }

  static int _calculateDriverTierOrder(IntelligentDriverPackage pkg) {
    final cat = pkg.category.toLowerCase().trim();
    if (cat == 'chipset') return 10;
    if (cat == 'system_mei') return 20;
    if (cat == 'storage') return 30;
    if (cat == 'gpu') {
      final nameLower = pkg.displayName.toLowerCase();
      if (nameLower.contains('intel') || nameLower.contains('uhd') || nameLower.contains('iris')) {
        return 40; // iGPU Intel
      }
      if (nameLower.contains('vega') || nameLower.contains('apu') || nameLower.contains('radeon graphics')) {
        return 41; // iGPU AMD
      }
      return 50; // dGPU
    }
    if (cat == 'lan') return 60;
    if (cat == 'wifi') return 61;
    if (cat == 'bluetooth') return 62;
    if (cat == 'audio') return 63;
    if (cat == 'touchpad') return 64;
    if (cat == 'card_reader') return 65;
    if (cat == 'camera') return 66;
    if (cat == 'usb') return 67;
    return 70;
  }

  static bool _isDriverBarrier(IntelligentDriverPackage pkg) {
    final cat = pkg.category.toLowerCase().trim();
    if (cat == 'chipset' ||
        cat == 'system_mei' ||
        cat == 'storage' ||
        cat == 'gpu' ||
        pkg.installerFile.toLowerCase().endsWith('.msi')) {
      return true;
    }
    return false;
  }

  static IconData _getDriverIcon(String cat) {
    final c = cat.toLowerCase().trim();
    if (c == 'chipset') return Icons.developer_board_rounded;
    if (c == 'system_mei') return Icons.memory_rounded;
    if (c == 'storage') return Icons.storage_rounded;
    if (c == 'gpu') return Icons.videogame_asset_rounded;
    if (c == 'audio') return Icons.volume_up_rounded;
    if (c == 'wifi') return Icons.wifi_rounded;
    if (c == 'lan') return Icons.settings_ethernet_rounded;
    if (c == 'bluetooth') return Icons.bluetooth_rounded;
    if (c == 'touchpad') return Icons.touch_app_rounded;
    if (c == 'card_reader') return Icons.credit_card_rounded;
    if (c == 'camera') return Icons.camera_alt_rounded;
    if (c == 'usb') return Icons.usb_rounded;
    return Icons.extension_rounded;
  }

  @override
  State<QueuePreviewModal> createState() => _QueuePreviewModalState();
}

class _QueuePreviewModalState extends State<QueuePreviewModal> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _selectedFilter = 'all'; // all, barriers, parallel

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final accent = widget.accentColor;
    final query = _searchCtrl.text.trim().toLowerCase();

    // Filter items based on search and active filter chip
    final filtered = widget.items.where((it) {
      if (_selectedFilter == 'barriers' && !it.isBarrier) return false;
      if (_selectedFilter == 'parallel' && it.isBarrier) return false;

      if (query.isNotEmpty) {
        final matchesName = it.name.toLowerCase().contains(query);
        final matchesCat = it.categoryFa.toLowerCase().contains(query);
        final matchesFile = it.installerFile.toLowerCase().contains(query);
        if (!matchesName && !matchesCat && !matchesFile) return false;
      }
      return true;
    }).toList();

    final barrierCount = widget.items.where((i) => i.isBarrier).length;
    final parallelCount = widget.items.length - barrierCount;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
          width: 1.2,
        ),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        width: 680,
        constraints: const BoxConstraints(maxHeight: 640),
        child: Column(
          children: [
            // 1. Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.playlist_play_rounded, color: accent, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    icon: const Icon(Icons.close_rounded, size: 20),
                    tooltip: 'بستن',
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // 2. Search & Filter Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Column(
                children: [
                  TextField(
                    controller: _searchCtrl,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'جستجوی نام بسته، فایل نصبی یا دسته‌بندی...',
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() {});
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _buildFilterChip('all', 'همه (${widget.items.length})', isDark, accent),
                      _buildFilterChip('barriers', 'سدهای متوالی ($barrierCount)', isDark, const Color(0xFF8B5CF6)),
                      _buildFilterChip('parallel', 'موازی ۲X ($parallelCount)', isDark, const Color(0xFF0D9488)),
                    ],
                  ),
                ],
              ),
            ),

            // 3. Sequence Items List
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.filter_list_off_rounded,
                            size: 40,
                            color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'هیچ موردی مطابق با فیلتر یافت نشد',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      itemCount: filtered.length,
                      itemBuilder: (ctx, index) {
                        final item = filtered[index];
                        final globalIndex = widget.items.indexOf(item) + 1;
                        return _buildSequenceItemRow(item, globalIndex, isDark, accent);
                      },
                    ),
            ),

            // 4. Concurrency Policy Note & Footer Action Bar
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF090D16) : const Color(0xFFF8FAFC),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                border: Border(
                  top: BorderSide(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: (widget.doubleSpeed ? const Color(0xFF0D9488) : const Color(0xFF0284C7))
                          .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          widget.doubleSpeed ? Icons.bolt_rounded : Icons.lock_clock_rounded,
                          size: 16,
                          color: widget.doubleSpeed ? const Color(0xFF0D9488) : const Color(0xFF0284C7),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          widget.doubleSpeed ? 'حالت ۲X موازی فعال' : 'حالت ۱X ترتیبی استاندارد',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: widget.doubleSpeed ? const Color(0xFF0D9488) : const Color(0xFF0284C7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // Cancel (min 44px)
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(80, 44),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                    ),
                    child: const Text('انصراف'),
                  ),
                  const SizedBox(width: 8),
                  // Confirm & Start (min 44px)
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop(true);
                      widget.onConfirm();
                    },
                    icon: const Icon(Icons.play_arrow_rounded, size: 18),
                    label: Text('تأیید و شروع نصب (${widget.items.length})'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 44),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String key, String label, bool isDark, Color color) {
    final isSelected = _selectedFilter == key;
    return ChoiceChip(
      selected: isSelected,
      label: Text(label),
      onSelected: (_) => setState(() => _selectedFilter = key),
      selectedColor: color.withValues(alpha: isDark ? 0.3 : 0.18),
      backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
      side: BorderSide(
        color: isSelected ? color : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
      ),
      labelStyle: TextStyle(
        fontSize: 11.5,
        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
        color: isSelected ? color : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
      ),
    );
  }

  Widget _buildSequenceItemRow(
    QueuePreviewItem item,
    int sequenceNumber,
    bool isDark,
    Color accent,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131D33) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          // Sequence number badge
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
              shape: BoxShape.circle,
            ),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Text(
                '$sequenceNumber',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Icon
          Icon(item.icon, size: 20, color: item.isBarrier ? const Color(0xFFA78BFA) : const Color(0xFF0D9488)),
          const SizedBox(width: 10),

          // Main info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.name,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      item.categoryFa,
                      style: TextStyle(
                        fontSize: 10.5,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Expanded(
                      child: Directionality(
                        textDirection: TextDirection.ltr,
                        child: Text(
                          item.installerFile,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontFamily: 'monospace',
                            color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    if (item.fileSizeDisplay.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Directionality(
                        textDirection: TextDirection.ltr,
                        child: Text(
                          item.fileSizeDisplay,
                          style: TextStyle(
                            fontSize: 10.5,
                            color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Barrier / Parallel badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: (item.isBarrier ? const Color(0xFF8B5CF6) : const Color(0xFF0D9488))
                  .withValues(alpha: isDark ? 0.22 : 0.12),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: (item.isBarrier ? const Color(0xFF8B5CF6) : const Color(0xFF0D9488))
                    .withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  item.isBarrier ? Icons.shield_rounded : Icons.bolt_rounded,
                  size: 12,
                  color: item.isBarrier ? const Color(0xFFA78BFA) : const Color(0xFF0D9488),
                ),
                const SizedBox(width: 4),
                Text(
                  item.isBarrier ? 'سد متوالی' : 'موازی ۲X',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: item.isBarrier ? const Color(0xFFA78BFA) : const Color(0xFF0D9488),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Normalized preview item representation for both software and drivers.
class QueuePreviewItem {
  final String id;
  final String name;
  final String category;
  final String categoryFa;
  final String installerFile;
  final String fileSizeDisplay;
  final bool isBarrier;
  final int priorityScore;
  final IconData icon;

  const QueuePreviewItem({
    required this.id,
    required this.name,
    required this.category,
    required this.categoryFa,
    required this.installerFile,
    required this.fileSizeDisplay,
    required this.isBarrier,
    required this.priorityScore,
    required this.icon,
  });
}
