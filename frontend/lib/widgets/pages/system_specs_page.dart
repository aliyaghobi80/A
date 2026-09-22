import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/system_info_controller.dart';
import '../../controllers/theme_language_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../models/system_info.dart';
import '../../theme/app_theme.dart';
import '../common/design_components.dart';

class SystemSpecsPage extends StatefulWidget {
  final SystemInfo info;

  const SystemSpecsPage({super.key, required this.info});

  @override
  State<SystemSpecsPage> createState() => _SystemSpecsPageState();
}

class _SystemSpecsPageState extends State<SystemSpecsPage> {
  int? focusedRamIndex;

  static String normalizeCpuName(String raw) {
    final name = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    final intelModel = RegExp(
      r'(i[3579]-[\w\d]+|Core\s+Ultra\s+\d+\s+[\w\d]+|Xeon\s+[\w\d\-]+(?:\s+v\d+)?|Pentium\s+[\w\d]+|Celeron\s+[\w\d]+)',
      caseSensitive: false,
    ).firstMatch(name);
    final amdModel = RegExp(
      r'(Ryzen\s+[3579]\s+[\w\d]+|Threadripper\s+[\w\d]+|Athlon\s+[\w\d]+|EPYC\s+[\w\d]+)',
      caseSensitive: false,
    ).firstMatch(name);
    final genMatch = RegExp(
      r'(\d+)(?:th|rd|nd|st)\s+Gen',
      caseSensitive: false,
    ).firstMatch(name);
    final genStr = genMatch != null ? '${genMatch.group(1)}th Gen' : '';
    final vendor = name.toLowerCase().contains('intel')
        ? 'Intel(R)'
        : (name.toLowerCase().contains('amd') ? 'AMD(R)' : '');

    String modelStr = '';
    String familyStr = '';

    if (intelModel != null) {
      modelStr = intelModel.group(1)!.trim();
      familyStr = name.contains('Core') || modelStr.startsWith('i')
          ? 'Core(TM)'
          : '';
    } else if (amdModel != null) {
      modelStr = amdModel.group(1)!.trim();
      familyStr = 'Ryzen(TM)';
    }

    if (modelStr.isNotEmpty) {
      final parts = <String>[];
      parts.add(modelStr);
      if (familyStr.isNotEmpty &&
          !modelStr.toLowerCase().contains(familyStr.toLowerCase())) {
        parts.add(familyStr);
      }
      if (genStr.isNotEmpty) {
        parts.add(genStr);
      }
      if (vendor.isNotEmpty) {
        parts.add(vendor);
      }
      return parts.join(' ');
    }
    return name;
  }

  static String formatGpuTitle(String name, String vramDisplay) {
    final raw = name.trim();
    if (raw.toUpperCase().contains('12G') ||
        raw.toUpperCase().contains('GB') ||
        raw.toUpperCase().contains('VRAM')) {
      return raw;
    }
    if (vramDisplay.isNotEmpty && vramDisplay != 'Shared') {
      final vClean = vramDisplay
          .replaceAll(' ', '')
          .toUpperCase()
          .replaceAll('B', '');
      return '$raw $vClean';
    }
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final systemCtrl = Get.find<SystemInfoController>();
    final themeCtrl = Get.find<ThemeLanguageController>();
    final l10n = AppLocalizations.of(context);
    final accent = themeCtrl.currentAccentColor;
    final info = widget.info;

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final isWidePc = totalWidth >= 1100;
        final isCompact = totalWidth < 700;

        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isCompact ? 12 : 20,
            vertical: 16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // -------------------------------------------------------------
              // Layer 1: Hardware Summary Cards (Strict Order: 1.MB, 2.CPU, 3.RAM, 4.GPU, 5.Power)
              // -------------------------------------------------------------
              if (info.system.sku != 'Not available' ||
                  info.system.chassisType == 'Laptop') ...[
                Text(
                  l10n.isPersian ? 'مدل دقیق دستگاه' : 'Device model',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                SelectableText(
                  '${info.system.manufacturer} ${info.system.model}',
                  textDirection: TextDirection.ltr,
                ),
                SelectableText(
                  'System SKU: ${info.system.sku}',
                  textDirection: TextDirection.ltr,
                ),
                const SizedBox(height: 12),
              ],
              _buildHardwareSummaryRow(info, isDark, accent, l10n),

              const SizedBox(height: 18),

              // -------------------------------------------------------------
              // Layer 2: Main Hardware Detailed Cards
              // -------------------------------------------------------------
              if (isWidePc)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Right Column in RTL: 1. Motherboard, 2. CPU, 3. RAM DIMM Visual Rack
                    Expanded(
                      flex: 5,
                      child: Column(
                        children: [
                          _buildMotherboardCard(
                            info.motherboard,
                            info.bios,
                            isDark,
                            accent,
                            systemCtrl,
                            isCompact,
                          ),
                          const SizedBox(height: 18),
                          _buildCpuCard(
                            info.cpu,
                            isDark,
                            accent,
                            systemCtrl,
                            isCompact,
                          ),
                          const SizedBox(height: 18),
                          _buildRamVisualRackCard(
                            info.ram,
                            isDark,
                            accent,
                            systemCtrl,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 18),
                    // Left Column in RTL: 4. GPU, 5. Power/Battery, 6. Storage Devices
                    Expanded(
                      flex: 5,
                      child: Column(
                        children: [
                          _buildGpuCard(
                            info.gpu,
                            isDark,
                            accent,
                            systemCtrl,
                            isCompact,
                          ),
                          const SizedBox(height: 18),
                          _buildPowerOrBatteryCard(
                            info.battery,
                            isDark,
                            accent,
                          ),
                          const SizedBox(height: 18),
                          _buildStorageDevicesCard(
                            info.storage,
                            isDark,
                            accent,
                            systemCtrl,
                            context,
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              else
                // Tablet & Compact Single-Column Mode (Strict Priority Sequence)
                Column(
                  children: [
                    _buildMotherboardCard(
                      info.motherboard,
                      info.bios,
                      isDark,
                      accent,
                      systemCtrl,
                      isCompact,
                    ),
                    const SizedBox(height: 16),
                    _buildCpuCard(
                      info.cpu,
                      isDark,
                      accent,
                      systemCtrl,
                      isCompact,
                    ),
                    const SizedBox(height: 16),
                    _buildRamVisualRackCard(
                      info.ram,
                      isDark,
                      accent,
                      systemCtrl,
                    ),
                    const SizedBox(height: 16),
                    _buildGpuCard(
                      info.gpu,
                      isDark,
                      accent,
                      systemCtrl,
                      isCompact,
                    ),
                    const SizedBox(height: 16),
                    _buildPowerOrBatteryCard(info.battery, isDark, accent),
                    const SizedBox(height: 16),
                    _buildStorageDevicesCard(
                      info.storage,
                      isDark,
                      accent,
                      systemCtrl,
                      context,
                    ),
                  ],
                ),

              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  // -------------------------------------------------------------
  // 1. Layer 1: Hardware Summary Cards (Strict Order: 1.MB, 2.CPU, 3.RAM, 4.GPU, 5.Power)
  // -------------------------------------------------------------
  Widget _buildHardwareSummaryRow(
    SystemInfo info,
    bool isDark,
    Color accent,
    AppLocalizations l10n,
  ) {
    // 1. Motherboard
    final mb = info.motherboard;
    final mbName = mb.fullDisplayName.isNotEmpty
        ? mb.fullDisplayName
        : 'Motherboard';
    final mbSubList = <String>[];
    if (mb.effectiveChipset.isNotEmpty) {
      mbSubList.add(mb.effectiveChipset);
    }
    if (info.bios.version.isNotEmpty && info.bios.version != 'Not available') {
      mbSubList.add('BIOS: ${info.bios.version}');
    } else if (mb.effectiveFormFactor.isNotEmpty) {
      mbSubList.add(mb.effectiveFormFactor);
    }
    final mbSub = mbSubList.isNotEmpty ? mbSubList.join(' • ') : 'استاندارد';
    final mbCategory = mb.effectiveBrandFa.isNotEmpty
        ? 'مادربرد (${mb.effectiveBrandFa})'
        : 'مادربرد (Motherboard)';

    // 2. CPU
    final cpuName = normalizeCpuName(
      info.cpu.name.isNotEmpty ? info.cpu.name : info.cpu.manufacturer,
    );
    final cpuSub =
        '${info.cpu.cores} هسته فیزیکی / ${info.cpu.threads} رشته${info.cpu.maxClockDisplay.isNotEmpty && info.cpu.maxClockDisplay != "Not available" ? " • ${info.cpu.maxClockDisplay}" : ""}';

    // 3. RAM
    final totalRam = info.ram.totalDisplay.isNotEmpty
        ? info.ram.totalDisplay
        : '${info.ram.totalGb} GB';
    final ramSpeed =
        info.ram.speedDisplay.isNotEmpty &&
            info.ram.speedDisplay != 'Not available'
        ? info.ram.speedDisplay
        : '';
    final ramSub = ramSpeed.isNotEmpty
        ? '$ramSpeed (${info.ram.modules.length} اسلات فعال)'
        : '${info.ram.modules.length} اسلات فعال';

    // 4. GPU (Support dual GPUs: Discrete + Integrated)
    String gpuName;
    String gpuSub;
    if (info.gpu.isEmpty) {
      gpuName = 'پردازنده گرافیکی یافت نشد';
      gpuSub = 'نیاز به بررسی درایور';
    } else if (info.gpu.length == 1) {
      final g = info.gpu.first;
      gpuName = formatGpuTitle(g.name, g.vramDisplay);
      gpuSub = g.isMicrosoftBasicDisplayAdapter
          ? 'نیاز به نصب درایور'
          : (g.vramDisplay != 'Not available' && g.vramDisplay != 'Shared'
              ? 'حافظه اختصاصی ${g.vramDisplay} (${g.typeLabelFa})'
              : g.typeLabelFa);
    } else {
      final discrete = info.gpu.firstWhere(
        (g) => g.isDiscrete,
        orElse: () => info.gpu.first,
      );
      final integrated = info.gpu.firstWhere(
        (g) => g.isIntegrated && g != discrete,
        orElse: () => info.gpu.last,
      );
      final dTitle = formatGpuTitle(discrete.name, discrete.vramDisplay);
      final iTitle = integrated != discrete
          ? formatGpuTitle(integrated.name, integrated.vramDisplay)
          : '';
      gpuName = iTitle.isNotEmpty ? '$dTitle + $iTitle' : dTitle;
      final iSub = integrated != discrete ? ' و ${integrated.typeLabelFa}' : '';
      gpuSub = 'گرافیک دوگانه: ${discrete.typeLabelFa}$iSub';
    }

    // 5. Power / Battery
    String powerCategory;
    String powerMain;
    String powerSub;
    IconData powerIcon;
    Color powerColor;

    if (!info.battery.hasBattery) {
      powerCategory = 'منبع تغذیه (Power)';
      powerMain = 'برق شهری (AC Power)';
      powerSub = info.battery.psuDisplay;
      powerIcon = Icons.power_rounded;
      powerColor = const Color(0xFF0284C7);
    } else {
      powerCategory = 'باتری دستگاه (Battery)';
      final hp = info.battery.healthPercent;
      powerMain = hp != null
          ? 'سلامت باتری: ${hp.toStringAsFixed(0)}%'
          : 'باتری لپ‌تاپ';
      powerSub =
          '${info.battery.powerSourceFa} • ${info.battery.fullChargeCapacityMwh} mWh';
      powerIcon = Icons.battery_charging_full_rounded;
      powerColor = const Color(0xFF10B981);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;

        if (availableWidth >= 1100) {
          // 5 cards in 1 row (Desktop)
          final cardWidth = (availableWidth - 4 * 12) / 5.0;
          return Row(
            children: [
              _buildSummaryCard(
                mbCategory,
                mbName,
                mbSub,
                mb.brandIcon,
                mb.brandColor,
                cardWidth,
                isDark,
              ),
              const SizedBox(width: 12),
              _buildSummaryCard(
                'پردازنده (CPU)',
                cpuName,
                cpuSub,
                Icons.memory_rounded,
                const Color(0xFF2563EB),
                cardWidth,
                isDark,
              ),
              const SizedBox(width: 12),
              _buildSummaryCard(
                'حافظه رم (RAM)',
                totalRam,
                ramSub,
                Icons.dns_rounded,
                const Color(0xFFF59E0B),
                cardWidth,
                isDark,
              ),
              const SizedBox(width: 12),
              _buildSummaryCard(
                'کارت گرافیک (GPU)',
                gpuName,
                gpuSub,
                Icons.videogame_asset_rounded,
                const Color(0xFF10B981),
                cardWidth,
                isDark,
              ),
              const SizedBox(width: 12),
              _buildSummaryCard(
                powerCategory,
                powerMain,
                powerSub,
                powerIcon,
                powerColor,
                cardWidth,
                isDark,
              ),
            ],
          );
        } else if (availableWidth >= 650) {
          // 2 columns (Tablet mode) - NO empty spaces! Card 5 spans 100% full width on row 3!
          final cardWidth = (availableWidth - 12) / 2.0;
          return Column(
            children: [
              Row(
                children: [
                  _buildSummaryCard(
                    mbCategory,
                    mbName,
                    mbSub,
                    mb.brandIcon,
                    mb.brandColor,
                    cardWidth,
                    isDark,
                  ),
                  const SizedBox(width: 12),
                  _buildSummaryCard(
                    'پردازنده (CPU)',
                    cpuName,
                    cpuSub,
                    Icons.memory_rounded,
                    const Color(0xFF2563EB),
                    cardWidth,
                    isDark,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildSummaryCard(
                    'حافظه رم (RAM)',
                    totalRam,
                    ramSub,
                    Icons.dns_rounded,
                    const Color(0xFFF59E0B),
                    cardWidth,
                    isDark,
                  ),
                  const SizedBox(width: 12),
                  _buildSummaryCard(
                    'کارت گرافیک (GPU)',
                    gpuName,
                    gpuSub,
                    Icons.videogame_asset_rounded,
                    const Color(0xFF10B981),
                    cardWidth,
                    isDark,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildSummaryCard(
                powerCategory,
                powerMain,
                powerSub,
                powerIcon,
                powerColor,
                availableWidth,
                isDark,
              ),
            ],
          );
        } else {
          // 1 column (Compact / Mobile) - 100% full width per card
          return Column(
            children: [
              _buildSummaryCard(
                mbCategory,
                mbName,
                mbSub,
                mb.brandIcon,
                mb.brandColor,
                availableWidth,
                isDark,
              ),
              const SizedBox(height: 10),
              _buildSummaryCard(
                'پردازنده (CPU)',
                cpuName,
                cpuSub,
                Icons.memory_rounded,
                const Color(0xFF2563EB),
                availableWidth,
                isDark,
              ),
              const SizedBox(height: 10),
              _buildSummaryCard(
                'حافظه رم (RAM)',
                totalRam,
                ramSub,
                Icons.dns_rounded,
                const Color(0xFFF59E0B),
                availableWidth,
                isDark,
              ),
              const SizedBox(height: 10),
              _buildSummaryCard(
                'کارت گرافیک (GPU)',
                gpuName,
                gpuSub,
                Icons.videogame_asset_rounded,
                const Color(0xFF10B981),
                availableWidth,
                isDark,
              ),
              const SizedBox(height: 10),
              _buildSummaryCard(
                powerCategory,
                powerMain,
                powerSub,
                powerIcon,
                powerColor,
                availableWidth,
                isDark,
              ),
            ],
          );
        }
      },
    );
  }

  Widget _buildSummaryCard(
    String category,
    String mainValue,
    String subValue,
    IconData icon,
    Color iconColor,
    double width,
    bool isDark,
  ) {
    return Container(
      width: width,
      constraints: const BoxConstraints(minHeight: 88),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: isDark ? 0.18 : 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 24, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  category,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppTheme.darkTextMuted
                        : AppTheme.lightTextMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text(
                    mainValue,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: isDark
                          ? AppTheme.darkTextPrimary
                          : AppTheme.lightTextPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subValue,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? AppTheme.darkTextSecondary
                        : AppTheme.lightTextSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // 2. Motherboard Layout (Large Image 140px + Clean Details + Brand Badge)
  // -------------------------------------------------------------
  Widget _buildMotherboardCard(
    MotherboardInfo mb,
    BiosInfo bios,
    bool isDark,
    Color accent,
    SystemInfoController systemCtrl,
    bool isCompact,
  ) {
    final imgSize = isCompact ? 100.0 : 135.0;
    final brandColor = mb.brandColor;

    return Container(
      padding: EdgeInsets.all(isCompact ? 14 : 18),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'مادربرد و پلتفرم سیستم (Motherboard)',
                style: TextStyle(
                  fontSize: isCompact ? 16 : 17.5,
                  fontWeight: FontWeight.w800,
                  color: isDark
                      ? AppTheme.darkTextPrimary
                      : AppTheme.lightTextPrimary,
                ),
              ),
              const Spacer(),
              MotherboardBrandBadge(motherboard: mb, compact: isCompact),
              const SizedBox(width: 8),
              const StatusDot(
                label: 'سالم',
                status: BadgeStatus.success,
                fontSize: 13,
              ),
            ],
          ),

          const SizedBox(height: 14),

          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: imgSize,
                height: imgSize,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF0F172A)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: brandColor.withValues(alpha: isDark ? 0.35 : 0.2),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: brandColor.withValues(alpha: isDark ? 0.08 : 0.04),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Image.asset(
                  'assets/Parts/motherboard.png',
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) =>
                      Icon(mb.brandIcon, size: 64, color: brandColor),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text(
                        mb.fullDisplayName,
                        style: TextStyle(
                          fontSize: isCompact ? 16.5 : 18.5,
                          fontWeight: FontWeight.w800,
                          color: isDark
                              ? AppTheme.darkTextPrimary
                              : AppTheme.lightTextPrimary,
                          letterSpacing: -0.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (mb.effectiveChipset.isNotEmpty ||
                        mb.effectiveFormFactor.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (mb.effectiveChipset.isNotEmpty) ...[
                            Text(
                              'چیپست ${mb.effectiveChipset}',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: brandColor,
                              ),
                            ),
                          ],
                          if (mb.effectiveChipset.isNotEmpty &&
                              mb.effectiveFormFactor.isNotEmpty)
                            Text(
                              ' • ',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? AppTheme.darkTextMuted
                                    : AppTheme.lightTextMuted,
                              ),
                            ),
                          if (mb.effectiveFormFactor.isNotEmpty) ...[
                            Text(
                              'سایز ${mb.effectiveFormFactor}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? AppTheme.darkTextSecondary
                                    : AppTheme.lightTextSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        if (mb.effectiveChipset.isNotEmpty)
                          MetaTag(
                            label: 'چیپست اصلی',
                            value: mb.effectiveChipset,
                            isLtrValue: true,
                            icon: Icons.developer_board_rounded,
                          ),
                        if (mb.effectiveFormFactor.isNotEmpty)
                          MetaTag(
                            label: 'سایز بورد',
                            value: mb.effectiveFormFactor,
                            isLtrValue: true,
                            icon: Icons.aspect_ratio_rounded,
                          ),
                        if (bios.version.isNotEmpty &&
                            bios.version != 'Not available')
                          MetaTag(
                            label: 'نسخه بایوس',
                            value: bios.version,
                            isLtrValue: true,
                            icon: Icons.security_rounded,
                          ),
                        if (bios.date.isNotEmpty &&
                            bios.date != 'Not available')
                          MetaTag(
                            label: 'تاریخ انتشار بایوس',
                            value: bios.date,
                            isLtrValue: true,
                          ),
                        if (mb.version.isNotEmpty && mb.version != '-')
                          MetaTag(
                            label: 'Revision',
                            value: mb.version,
                            isLtrValue: true,
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        if (mb.serial.isNotEmpty &&
                            mb.serial != 'Not available' &&
                            mb.serial != 'Default string' &&
                            mb.serial != '-') ...[
                          Tooltip(
                            message: 'کپی شماره سریال مادربرد',
                            child: InkWell(
                              borderRadius: BorderRadius.circular(6),
                              onTap: () => systemCtrl.copyToClipboard(
                                context,
                                mb.serial,
                                'شماره سریال مادربرد کپی شد: ${mb.serial}',
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF1E293B)
                                      : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isDark
                                        ? const Color(0xFF334155)
                                        : const Color(0xFFCBD5E1),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.qr_code_rounded,
                                      size: 14,
                                      color: brandColor,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'S/N: ${mb.serial}',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontFamily: 'monospace',
                                        fontWeight: FontWeight.w600,
                                        color: isDark
                                            ? AppTheme.darkTextSecondary
                                            : AppTheme.lightTextSecondary,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.copy_rounded,
                                      size: 12,
                                      color: isDark
                                          ? AppTheme.darkTextMuted
                                          : AppTheme.lightTextMuted,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                        const Spacer(),
                        OutlinedButton.icon(
                          onPressed: () => _showMotherboardDetails(
                            context,
                            mb,
                            bios,
                            isDark,
                            systemCtrl,
                          ),
                          icon: const Icon(
                            Icons.info_outline_rounded,
                            size: 15,
                          ),
                          label: const Text('جزئیات مادربرد و بایوس →'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            minimumSize: const Size(0, 34),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showMotherboardDetails(
    BuildContext context,
    MotherboardInfo mb,
    BiosInfo bios,
    bool isDark,
    SystemInfoController systemCtrl,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Text(
              'مشخصات مادربرد و بایوس',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const Spacer(),
            MotherboardBrandBadge(
              motherboard: mb,
              compact: true,
              showChipset: true,
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDialogRow(
              'مدل بورد:',
              mb.fullDisplayName,
              isDark,
              isLtrValue: true,
              onCopy: () => systemCtrl.copyToClipboard(
                context,
                mb.fullDisplayName,
                'مدل مادربرد کپی شد: ${mb.fullDisplayName}',
              ),
            ),
            _buildDialogRow(
              'سازنده برند:',
              '${mb.effectiveBrand} (${mb.effectiveBrandFa})',
              isDark,
              isLtrValue: false,
            ),
            if (mb.effectiveChipset.isNotEmpty)
              _buildDialogRow(
                'چیپست مادربرد:',
                mb.effectiveChipset,
                isDark,
                isLtrValue: true,
              ),
            if (mb.effectiveFormFactor.isNotEmpty)
              _buildDialogRow(
                'فرم فاکتور / ابعاد:',
                mb.effectiveFormFactor,
                isDark,
                isLtrValue: true,
              ),
            _buildDialogRow(
              'نام در بایوس / WMI:',
              mb.model,
              isDark,
              isLtrValue: true,
            ),
            _buildDialogRow(
              'شرکت ثبتی سازنده:',
              mb.manufacturer,
              isDark,
              isLtrValue: true,
            ),
            _buildDialogRow(
              'شماره سریال مادربرد:',
              mb.serial,
              isDark,
              isLtrValue: true,
              onCopy: () => systemCtrl.copyToClipboard(
                context,
                mb.serial,
                'شماره سریال مادربرد کپی شد: ${mb.serial}',
              ),
            ),
            _buildDialogRow(
              'شناسه سخت‌افزاری (UUID):',
              mb.uuid,
              isDark,
              isLtrValue: true,
              onCopy: () => systemCtrl.copyToClipboard(
                context,
                mb.uuid,
                'شناسه یکتای UUID کپی شد: ${mb.uuid}',
              ),
            ),
            _buildDialogRow(
              'نسخه بایوس:',
              bios.version,
              isDark,
              isLtrValue: true,
              onCopy: () => systemCtrl.copyToClipboard(
                context,
                bios.version,
                'نسخه بایوس کپی شد: ${bios.version}',
              ),
            ),
            _buildDialogRow(
              'تاریخ انتشار بایوس:',
              bios.date,
              isDark,
              isLtrValue: true,
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('بستن'),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // 3. CPU Layout (Normalized Model + Clean Chips)
  // -------------------------------------------------------------
  Widget _buildCpuCard(
    CpuInfo cpu,
    bool isDark,
    Color accent,
    SystemInfoController systemCtrl,
    bool isCompact,
  ) {
    final displayName = normalizeCpuName(cpu.name);
    final imgSize = isCompact ? 100.0 : 135.0;

    return Container(
      padding: EdgeInsets.all(isCompact ? 14 : 18),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'پردازنده مرکزی (CPU)',
                style: TextStyle(
                  fontSize: isCompact ? 16 : 17.5,
                  fontWeight: FontWeight.w800,
                  color: isDark
                      ? AppTheme.darkTextPrimary
                      : AppTheme.lightTextPrimary,
                ),
              ),
              const Spacer(),
              const StatusDot(
                label: 'عالی',
                status: BadgeStatus.success,
                fontSize: 13,
              ),
            ],
          ),

          const SizedBox(height: 14),

          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: imgSize,
                height: imgSize,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF0F172A)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                  ),
                ),
                child: Image.asset(
                  'assets/Parts/cpu.png',
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.developer_board_rounded,
                    size: 64,
                    color: Color(0xFF2563EB),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text(
                        displayName,
                        style: TextStyle(
                          fontSize: isCompact ? 16.5 : 18.5,
                          fontWeight: FontWeight.w800,
                          color: isDark
                              ? AppTheme.darkTextPrimary
                              : AppTheme.lightTextPrimary,
                          letterSpacing: -0.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        MetaTag(
                          label: 'تعداد هسته',
                          value: '${cpu.cores} هسته فیزیکی',
                          isLtrValue: false,
                          icon: Icons.tune_rounded,
                        ),
                        MetaTag(
                          label: 'تعداد رشته',
                          value: '${cpu.threads} رشته منطقی',
                          isLtrValue: false,
                          icon: Icons.linear_scale_rounded,
                        ),
                        if (cpu.maxClockDisplay.isNotEmpty &&
                            cpu.maxClockDisplay != 'Not available')
                          MetaTag(
                            label: 'فرکانس بوست',
                            value: cpu.maxClockDisplay,
                            isLtrValue: true,
                            icon: Icons.speed_rounded,
                          ),
                        if (cpu.manufacturer.isNotEmpty &&
                            cpu.manufacturer != 'Not available')
                          MetaTag(
                            label: 'سازنده',
                            value: cpu.manufacturer,
                            isLtrValue: true,
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _showCpuDetails(
                            context,
                            cpu,
                            displayName,
                            isDark,
                          ),
                          icon: const Icon(
                            Icons.info_outline_rounded,
                            size: 15,
                          ),
                          label: const Text('مشخصات کامل پردازنده →'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            minimumSize: const Size(0, 34),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showCpuDetails(
    BuildContext context,
    CpuInfo cpu,
    String normalizedName,
    bool isDark,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'مشخصات فنی پردازنده (CPU)',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDialogRow(
              'مدل نامگذاری استاندارد:',
              normalizedName,
              isDark,
              isLtrValue: true,
            ),
            _buildDialogRow(
              'تعداد هسته‌های فیزیکی:',
              '${cpu.cores} هسته فیزیکی (Physical Cores)',
              isDark,
              isLtrValue: false,
            ),
            _buildDialogRow(
              'تعداد رشته‌های منطقی:',
              '${cpu.threads} رشته پردازشی (Threads)',
              isDark,
              isLtrValue: false,
            ),
            _buildDialogRow(
              'فرکانس بیشینه کاری:',
              cpu.maxClockDisplay,
              isDark,
              isLtrValue: true,
            ),
            _buildDialogRow(
              'سازنده پردازنده:',
              cpu.manufacturer,
              isDark,
              isLtrValue: true,
            ),
            _buildDialogRow(
              'شماره سریال پردازنده:',
              cpu.serial,
              isDark,
              isLtrValue: true,
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('بستن'),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // 4. RAM Layout — Real DIMM Visual Rack
  // -------------------------------------------------------------
  Widget _buildRamVisualRackCard(
    RamInfo ram,
    bool isDark,
    Color accent,
    SystemInfoController systemCtrl,
  ) {
    final modules = ram.modules;
    final slots = ram.slots.isNotEmpty
        ? ram.slots
        : [
            for (var i = 0; i < (ram.totalSlots ?? modules.length); i++)
              RamSlot(
                label: i < modules.length ? modules[i].slot : 'محل گزارش نشده',
                moduleIndex: i < modules.length ? i : null,
              ),
          ];
    final totalSlots = slots.length;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'حافظه رم (RAM)',
                style: TextStyle(
                  fontSize: 17.5,
                  fontWeight: FontWeight.w800,
                  color: isDark
                      ? AppTheme.darkTextPrimary
                      : AppTheme.lightTextPrimary,
                ),
              ),
              const SizedBox(width: 10),
              Directionality(
                textDirection: TextDirection.ltr,
                child: Text(
                  '${ram.totalDisplay} ${ram.speedDisplay}',
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFF59E0B),
                  ),
                ),
              ),
              const Spacer(),
              StatusBadge(
                label: totalSlots > modules.length
                    ? '${modules.length} از $totalSlots اسلات دارای رم'
                    : '${modules.length} ماژول رم شناسایی شد',
                status: modules.isNotEmpty
                    ? BadgeStatus.info
                    : BadgeStatus.neutral,
                showIcon: false,
                fontSize: 12.5,
              ),
            ],
          ),

          const SizedBox(height: 14),

          Column(
            children: List.generate(totalSlots, (index) {
              final moduleIndex = slots[index].moduleIndex;
              final isFilled =
                  moduleIndex != null &&
                  moduleIndex >= 0 &&
                  moduleIndex < modules.length;
              final mod = isFilled ? modules[moduleIndex] : null;
              final slotLabel = slots[index].label;
              final isFocused = isFilled && focusedRamIndex == moduleIndex;

              return InkWell(
                onTap: isFilled
                    ? () {
                        setState(() {
                          focusedRamIndex = isFocused ? null : moduleIndex;
                        });
                      }
                    : null,
                borderRadius: BorderRadius.circular(8),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isFilled
                        ? (isFocused
                              ? const Color(
                                  0xFFF59E0B,
                                ).withValues(alpha: isDark ? 0.22 : 0.12)
                              : (isDark
                                    ? const Color(0xFF0F172A)
                                    : const Color(0xFFF8FAFC)))
                        : (isDark
                              ? Colors.transparent
                              : const Color(0xFFF1F5F9)),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isFocused
                          ? const Color(0xFFF59E0B)
                          : (isFilled
                                ? (isDark
                                      ? const Color(0xFF2A3A54)
                                      : const Color(0xFFCBD5E1))
                                : (isDark
                                      ? const Color(0xFF1E293B)
                                      : const Color(0xFFE2E8F0))),
                      width: isFocused ? 1.8 : 1.2,
                    ),
                  ),
                  child: Row(
                    children: [
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: isFilled
                                ? const Color(0xFFF59E0B).withValues(alpha: 0.2)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            slotLabel,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: isFilled
                                  ? const Color(0xFFF59E0B)
                                  : (isDark
                                        ? AppTheme.darkTextMuted
                                        : AppTheme.lightTextMuted),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      if (isFilled && mod != null) ...[
                        Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: AppTheme.statusSuccess,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Directionality(
                            textDirection: TextDirection.ltr,
                            child: Row(
                              children: [
                                Text(
                                  '${mod.capacityDisplay} ${mod.type} @ ${mod.speedDisplay}',
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w800,
                                    color: isDark
                                        ? AppTheme.darkTextPrimary
                                        : AppTheme.lightTextPrimary,
                                  ),
                                ),
                                if (mod.manufacturer.isNotEmpty &&
                                    mod.manufacturer != 'Not available') ...[
                                  const SizedBox(width: 10),
                                  Text(
                                    '(${mod.manufacturer})',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark
                                          ? AppTheme.darkTextMuted
                                          : AppTheme.lightTextMuted,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        Icon(
                          isFocused
                              ? Icons.expand_less_rounded
                              : Icons.expand_more_rounded,
                          size: 18,
                          color: const Color(0xFFF59E0B),
                        ),
                      ] else ...[
                        Expanded(
                          child: Text(
                            slots[index].occupied == false
                                ? '[ اسلات خالی / Empty Slot ]'
                                : '[ وضعیت/محل دقیق گزارش نشده ]',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontStyle: FontStyle.italic,
                              color: isDark
                                  ? AppTheme.darkTextMuted
                                  : AppTheme.lightTextMuted,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
          ),

          if (focusedRamIndex != null && focusedRamIndex! < modules.length) ...[
            const SizedBox(height: 8),
            _buildFocusedRamPanel(modules[focusedRamIndex!], isDark, accent),
          ],
        ],
      ),
    );
  }

  Widget _buildFocusedRamPanel(RamModule mod, bool isDark, Color accent) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${mod.clDisplay} • ${mod.formFactor}',
            textDirection: TextDirection.ltr,
          ),
          Text(
            'مشخصات فنی ماژول رم در اسلات ${mod.slot}:',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Color(0xFFF59E0B),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              _buildSmallSpec(
                'ظرفیت و نوع',
                '${mod.capacityDisplay} ${mod.type} @ ${mod.speedDisplay}',
                isDark,
              ),
              if (mod.partNumber.isNotEmpty && mod.partNumber != '-')
                _buildSmallSpec('Part Number', mod.partNumber, isDark),
              if (mod.serial.isNotEmpty && mod.serial != '-')
                _buildSmallSpec('Serial Number', mod.serial, isDark),
              if (mod.manufacturer.isNotEmpty &&
                  mod.manufacturer != 'Not available')
                _buildSmallSpec('سازنده ماژول', mod.manufacturer, isDark),
            ],
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // 5. GPU Layout
  // -------------------------------------------------------------
  Widget _buildGpuCard(
    List<GpuInfo> gpus,
    bool isDark,
    Color accent,
    SystemInfoController systemCtrl,
    bool isCompact,
  ) {
    final primary = gpus.isNotEmpty
        ? gpus.first
        : GpuInfo(
            name: 'Display Adapter',
            manufacturer: 'Standard',
            vramDisplay: 'Shared',
            driverVersion: 'Standard',
          );
    final gpuTitle = gpus.length > 1
        ? gpus.map((g) => formatGpuTitle(g.name, g.vramDisplay)).join(' + ')
        : formatGpuTitle(primary.name, primary.vramDisplay);
    final imgSize = isCompact ? 100.0 : 135.0;
    final needsGraphicsDriver = gpus.any(
      (gpu) => gpu.isMicrosoftBasicDisplayAdapter,
    );

    return Container(
      padding: EdgeInsets.all(isCompact ? 14 : 18),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'پردازنده گرافیکی (GPU)',
                style: TextStyle(
                  fontSize: isCompact ? 16 : 17.5,
                  fontWeight: FontWeight.w800,
                  color: isDark
                      ? AppTheme.darkTextPrimary
                      : AppTheme.lightTextPrimary,
                ),
              ),
              const Spacer(),
              StatusDot(
                label: needsGraphicsDriver
                    ? 'درایور گرافیک نصب نیست'
                    : 'عملکرد بهینه',
                status: needsGraphicsDriver
                    ? BadgeStatus.warning
                    : BadgeStatus.success,
                fontSize: 13,
              ),
            ],
          ),

          const SizedBox(height: 14),

          if (needsGraphicsDriver) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.statusWarning.withValues(
                  alpha: isDark ? 0.16 : 0.10,
                ),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(
                  color: AppTheme.statusWarning.withValues(alpha: 0.42),
                ),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: AppTheme.statusWarning,
                  ),
                  SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'Microsoft Basic Display Adapter شناسایی شد؛ درایور اصلی کارت گرافیک را نصب کنید.',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: imgSize,
                height: imgSize,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF0F172A)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                  ),
                ),
                child: Image.asset(
                  'assets/Parts/graphic.png',
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.videogame_asset_rounded,
                    size: 64,
                    color: Color(0xFF10B981),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text(
                        gpuTitle,
                        style: TextStyle(
                          fontSize: isCompact ? 16.5 : 18.5,
                          fontWeight: FontWeight.w800,
                          color: isDark
                              ? AppTheme.darkTextPrimary
                              : AppTheme.lightTextPrimary,
                          letterSpacing: -0.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        MetaTag(
                          label: 'حافظه اختصاصی VRAM',
                          value: primary.vramDisplay.isNotEmpty
                              ? primary.vramDisplay
                              : 'Shared',
                          isLtrValue: true,
                          icon: Icons.memory_rounded,
                        ),
                        if (primary.driverVersion.isNotEmpty &&
                            primary.driverVersion != 'Not available')
                          MetaTag(
                            label: 'ورژن درایور',
                            value: primary.driverVersion,
                            isLtrValue: true,
                            icon: Icons.verified_rounded,
                          ),
                        if (primary.manufacturer.isNotEmpty &&
                            primary.manufacturer != 'Not available')
                          MetaTag(
                            label: 'سازنده چیپست',
                            value: primary.manufacturer,
                            isLtrValue: true,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // 6. Power Source (Desktop) vs Battery Card (Laptop)
  // -------------------------------------------------------------
  Widget _buildPowerOrBatteryCard(
    BatteryInfo battery,
    bool isDark,
    Color accent,
  ) {
    if (!battery.hasBattery) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
            width: 1.2,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(
                  0xFF0284C7,
                ).withValues(alpha: isDark ? 0.18 : 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.power_rounded,
                size: 28,
                color: Color(0xFF0284C7),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'منبع تغذیه (Power Source)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: isDark
                              ? AppTheme.darkTextPrimary
                              : AppTheme.lightTextPrimary,
                        ),
                      ),
                      const Spacer(),
                      const StatusDot(
                        label: 'برق شهری (AC Line)',
                        status: BadgeStatus.success,
                        fontSize: 13,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'سیستم رومیزی (Desktop) متصل به جریان مستقیم برق شهری • ${battery.psuDisplay}',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark
                          ? AppTheme.darkTextSecondary
                          : AppTheme.lightTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final health = battery.healthPercent ?? 100.0;
    final isGood = health >= 75.0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: (isGood ? AppTheme.statusSuccess : AppTheme.statusWarning)
                  .withValues(alpha: isDark ? 0.18 : 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              battery.isCharging
                  ? Icons.battery_charging_full_rounded
                  : Icons.battery_full_rounded,
              size: 28,
              color: isGood ? AppTheme.statusSuccess : AppTheme.statusWarning,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'باتری دستگاه (Laptop Battery)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: isDark
                            ? AppTheme.darkTextPrimary
                            : AppTheme.lightTextPrimary,
                      ),
                    ),
                    const Spacer(),
                    StatusDot(
                      label: '${health.toStringAsFixed(0)}% سلامت',
                      status: isGood
                          ? BadgeStatus.success
                          : BadgeStatus.warning,
                      fontSize: 13,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${battery.powerSourceFa} • ظرفیت شارژ کامل: ${battery.fullChargeCapacityMwh} mWh (اسمی: ${battery.designCapacityMwh} mWh)',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark
                        ? AppTheme.darkTextSecondary
                        : AppTheme.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // 7. Storage Devices Layout (No Fake Health %, Clean Real Hardware Data)
  // -------------------------------------------------------------
  Widget _buildStorageDevicesCard(
    List<StorageInfo> storage,
    bool isDark,
    Color accent,
    SystemInfoController systemCtrl,
    BuildContext context,
  ) {
    final totalDrives = storage.length;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'حافظه‌های ذخیره‌سازی (Storage)',
                style: TextStyle(
                  fontSize: 17.5,
                  fontWeight: FontWeight.w800,
                  color: isDark
                      ? AppTheme.darkTextPrimary
                      : AppTheme.lightTextPrimary,
                ),
              ),
              const Spacer(),
              StatusBadge(
                label: '$totalDrives درایو داخلی',
                status: BadgeStatus.info,
                showIcon: false,
                fontSize: 12.5,
              ),
            ],
          ),

          const SizedBox(height: 14),

          if (storage.isEmpty)
            Text(
              'هیچ درایو ذخیره‌سازی در سیستم شناسایی نشد.',
              style: TextStyle(
                fontSize: 13,
                color: isDark
                    ? AppTheme.darkTextMuted
                    : AppTheme.lightTextMuted,
              ),
            )
          else
            ...storage.map((d) => _buildStorageDeviceRow(d, isDark, accent)),

          // Real-time Connected USB Flash Drives & Removable Media
          Obx(() {
            final usbs = systemCtrl.usbDrives;
            if (usbs.isEmpty) return const SizedBox.shrink();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.usb_rounded, size: 18, color: Color(0xFF0284C7)),
                      const SizedBox(width: 8),
                      Text(
                        'حافظه‌های فلش متصل (${usbs.length})',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                        ),
                      ),
                      const Spacer(),
                      const StatusBadge(
                        label: 'لحظه‌ای (Real-time)',
                        status: BadgeStatus.success,
                        showIcon: true,
                        fontSize: 11,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                ...usbs.map((usb) => _buildUsbDeviceRow(usb, isDark, accent, systemCtrl, context)),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildUsbDeviceRow(
    UsbDriveInfo usb,
    bool isDark,
    Color accent,
    SystemInfoController systemCtrl,
    BuildContext context,
  ) {
    final title = usb.volumeName.isNotEmpty && usb.volumeName != 'فلش مموری'
        ? '${usb.volumeName} (${usb.driveLetter})'
        : 'فلش مموری (${usb.driveLetter})';
    final vendorProduct = '${usb.vendor} ${usb.product}'.trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFF0284C7).withValues(alpha: isDark ? 0.4 : 0.25),
          width: 1.2,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 76,
            height: 76,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Image.asset(
              'assets/Parts/usb_flash.png',
              fit: BoxFit.contain,
              errorBuilder: (ctx, err, stack) => const Icon(
                Icons.usb_rounded,
                size: 38,
                color: Color(0xFF0284C7),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${usb.totalGb.toStringAsFixed(1)} GB',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0284C7),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  vendorProduct.isNotEmpty
                      ? '$vendorProduct • فرمت ${usb.fileSystem}'
                      : 'درایو یو‌اس‌بی • فرمت ${usb.fileSystem}',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (usb.percentUsed / 100.0).clamp(0.0, 1.0),
                          minHeight: 6,
                          backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                          color: usb.percentUsed > 90
                              ? const Color(0xFFEF4444)
                              : const Color(0xFF0284C7),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${usb.freeGb.toStringAsFixed(1)} GB آزاد',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: () => systemCtrl.safeEjectDrive(context, usb.driveLetter),
            icon: const Icon(Icons.eject_rounded, size: 16, color: Color(0xFFEF4444)),
            label: const Text(
              'خروج ایمن',
              style: TextStyle(fontSize: 11.5, color: Color(0xFFEF4444)),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFEF4444), width: 1.1),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: const Size(0, 36),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStorageDeviceRow(StorageInfo drive, bool isDark, Color accent) {
    final typeLower = drive.type.toLowerCase();
    final modelLower = drive.model.toLowerCase();
    final busLower = drive.busType.toLowerCase();
    final typeDescLower = drive.typeDescription.toLowerCase();

    String assetPath;
    if (typeDescLower.contains('usb') ||
        typeLower.contains('usb') ||
        busLower.contains('usb') ||
        modelLower.contains('usb') ||
        typeLower.contains('removable') ||
        typeDescLower.contains('removable') ||
        modelLower.contains('sandisk') ||
        modelLower.contains('cruzer') ||
        modelLower.contains('flash')) {
      assetPath = 'assets/Parts/usb_flash.png';
    } else if (typeDescLower.contains('nvme') ||
        typeLower.contains('nvme') ||
        busLower.contains('nvme') ||
        modelLower.contains('nvme')) {
      assetPath = 'assets/Parts/ssd_m2.png';
    } else if (typeDescLower.contains('ssd') ||
        typeLower.contains('ssd') ||
        modelLower.contains('ssd')) {
      assetPath = 'assets/Parts/ssd_sata.png';
    } else {
      assetPath = 'assets/Parts/hdd.png';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
          width: 1.2,
        ),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 76,
                height: 76,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Image.asset(
                  assetPath,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.album_rounded,
                    size: 40,
                    color: Color(0xFF0284C7),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Directionality(
                            textDirection: TextDirection.ltr,
                            child: Text(
                              drive.model,
                              style: TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w800,
                                color: isDark
                                    ? AppTheme.darkTextPrimary
                                    : AppTheme.lightTextPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          drive.capacityDisplay,
                          style: const TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0284C7),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF0284C7,
                            ).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            drive.typeDescription,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0284C7),
                            ),
                          ),
                        ),
                        if (drive.smartStatus.isNotEmpty &&
                            drive.smartStatus != 'UNKNOWN') ...[
                          const SizedBox(width: 8),
                          StatusBadge(
                            label: 'SMART: ${drive.smartStatus}',
                            status: drive.smartStatus == 'PASSED'
                                ? BadgeStatus.success
                                : BadgeStatus.danger,
                            showIcon: false,
                            fontSize: 11,
                          ),
                        ],
                        if (drive.temperatureC != null) ...[
                          const SizedBox(width: 8),
                          Row(
                            children: [
                              const Icon(
                                Icons.thermostat_rounded,
                                size: 14,
                                color: Color(0xFFF59E0B),
                              ),
                              const SizedBox(width: 2),
                              Text(
                                '${drive.temperatureC}°C',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? AppTheme.darkTextPrimary
                                      : AppTheme.lightTextPrimary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed: () => _showStorageDetails(context, drive, isDark),
                icon: const Icon(Icons.analytics_outlined, size: 14),
                label: const Text('گزارش کامل SMART و پارامترها →'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  minimumSize: const Size(0, 30),
                  textStyle: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showStorageDetails(
    BuildContext context,
    StorageInfo drive,
    bool isDark,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'گزارش مشخصات فنی و SMART: ${drive.model}',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDialogRow('مدل دیسک:', drive.model, isDark, isLtrValue: true),
            _buildDialogRow(
              'نوع درایو و رابط:',
              drive.typeDescription,
              isDark,
              isLtrValue: true,
            ),
            _buildDialogRow(
              'ظرفیت کل دیسک:',
              drive.capacityDisplay,
              isDark,
              isLtrValue: true,
            ),
            _buildDialogRow(
              'وضعیت کلی SMART:',
              drive.smartStatus,
              isDark,
              isLtrValue: true,
            ),
            if (drive.temperatureC != null)
              _buildDialogRow(
                'دمای فعلی دیسک:',
                '${drive.temperatureC}°C',
                isDark,
                isLtrValue: true,
              ),
            if (drive.powerOnHours != null)
              _buildDialogRow(
                'کارکرد روشن بودن (Power-On Hours):',
                '${drive.powerOnHours} ساعت',
                isDark,
                isLtrValue: false,
              ),
            if (drive.powerCycles != null)
              _buildDialogRow(
                'تعداد دفعات روشن/خاموش (Power Cycles):',
                '${drive.powerCycles} مرتبه',
                isDark,
                isLtrValue: false,
              ),
            if (drive.reallocatedSectors != null)
              _buildDialogRow(
                'سکتورهای بازتخصیص‌یافته (Reallocated):',
                '${drive.reallocatedSectors}',
                isDark,
                isLtrValue: true,
              ),
            if (drive.pendingSectors != null)
              _buildDialogRow(
                'سکتورهای مشکوک (Pending):',
                '${drive.pendingSectors}',
                isDark,
                isLtrValue: true,
              ),
            if (drive.uncorrectableSectors != null)
              _buildDialogRow(
                'سکتورهای تصحیح‌نشده (Uncorrectable):',
                '${drive.uncorrectableSectors}',
                isDark,
                isLtrValue: true,
              ),
            if (drive.mediaErrors != null)
              _buildDialogRow(
                'خطاهای مدیا و دیتا (Media Errors):',
                '${drive.mediaErrors}',
                isDark,
                isLtrValue: true,
              ),
            _buildDialogRow(
              'شماره سریال دیسک:',
              drive.serial,
              isDark,
              isLtrValue: true,
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('بستن'),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallSpec(String label, String value, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 12,
            color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted,
          ),
        ),
        Directionality(
          textDirection: TextDirection.ltr,
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: isDark
                  ? AppTheme.darkTextPrimary
                  : AppTheme.lightTextPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDialogRow(
    String label,
    String value,
    bool isDark, {
    bool isLtrValue = false,
    VoidCallback? onCopy,
  }) {
    final canCopy =
        onCopy != null &&
        value.isNotEmpty &&
        value != '-' &&
        value != 'Not available';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label ',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted,
            ),
          ),
          Expanded(
            child: isLtrValue
                ? Directionality(
                    textDirection: TextDirection.ltr,
                    child: Text(
                      value.isNotEmpty ? value : '-',
                      textAlign: TextAlign.left,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? AppTheme.darkTextPrimary
                            : AppTheme.lightTextPrimary,
                      ),
                    ),
                  )
                : Text(
                    value.isNotEmpty ? value : '-',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? AppTheme.darkTextPrimary
                          : AppTheme.lightTextPrimary,
                    ),
                  ),
          ),
          if (canCopy) ...[
            const SizedBox(width: 8),
            InkWell(
              onTap: onCopy,
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.all(2.5),
                child: Icon(
                  Icons.copy_rounded,
                  size: 14,
                  color: isDark
                      ? const Color(0xFF64748B)
                      : const Color(0xFF94A3B8),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
