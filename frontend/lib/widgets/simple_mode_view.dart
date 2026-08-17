import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/activation_controller.dart';
import '../controllers/software_controller.dart';
import '../controllers/system_info_controller.dart';
import '../l10n/app_localizations.dart';
import '../models/system_info.dart';
import 'cards/battery_card.dart';
import 'common/hardware_illustrations.dart';
import 'qc/qc_summary_banner.dart';

class SimpleModeView extends StatelessWidget {
  final SystemInfo info;
  final PackagesResponse? initialPackages;

  const SimpleModeView({
    super.key,
    required this.info,
    this.initialPackages,
  });

  @override
  Widget build(BuildContext context) {
    final systemCtrl = Get.find<SystemInfoController>();
    final softwareCtrl = Get.find<SoftwareController>();
    final activationCtrl = Get.find<ActivationController>();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Full System QC Summary Banner (Top)
        const QcSummaryBanner(),

        // 1.5 Quick System Summary Strip (Compact one-liner)
        _buildSystemSummaryStrip(context, info, isDark, l10n, systemCtrl),
        const SizedBox(height: 14),

        // 2. Hardware Section Header with 1-click Copy
        _buildSectionHeader(
          context: context,
          icon: Icons.memory_rounded,
          title: l10n.hardware,
          color: const Color(0xFF3B82F6),
          trailing: OutlinedButton.icon(
            onPressed: () => systemCtrl.copyToClipboard(
              context,
              systemCtrl.buildAllSpecsSummary(l10n, softwareCtrl.packagesResponse.value),
              l10n.specsCopied,
            ),
            icon: const Icon(Icons.copy_all_rounded, size: 16),
            label: Text(l10n.copyAllSpecs),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF3B82F6),
              side: BorderSide(
                color: const Color(0xFF3B82F6).withValues(alpha: isDark ? 0.6 : 0.4),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),

        // 6 Large Prominent Hardware Spec Cards
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 850;

            final cpuSerial = (info.cpu.serial != 'Not available' && info.cpu.serial != 'None') ? info.cpu.serial : null;
            final cardCpu = _buildProminentSpecCard(
              context: context,
              stepNumber: 1,
              categoryTitle: l10n.cpu,
              icon: Icons.memory_rounded,
              accentColor: const Color(0xFF3B82F6),
              illustration: const CpuIllustration(),
              primaryValue: info.cpu.name,
              secondaryValue: l10n.coresThreads(info.cpu.cores, info.cpu.threads),
              specPills: [
                '${info.cpu.cores} ${l10n.isPersian ? 'هسته' : 'Cores'}',
                '${info.cpu.threads} ${l10n.isPersian ? 'رشته' : 'Threads'}',
                if (info.cpu.maxClockDisplay != 'Not available') info.cpu.maxClockDisplay,
              ],
              serialNumber: cpuSerial,
              copyValue: info.cpu.name,
              onCopy: (val) => systemCtrl.copyToClipboard(context, val, '${l10n.copiedToClipboard}: $val'),
            );

            final cardRam = _buildProminentSpecCard(
              context: context,
              stepNumber: 2,
              categoryTitle: l10n.ram,
              icon: Icons.storage_rounded,
              accentColor: const Color(0xFFF59E0B),
              illustration: const RamIllustration(),
              primaryValue: info.ram.totalDisplay,
              copyValue: info.ram.totalDisplay,
              onCopy: (val) => systemCtrl.copyToClipboard(context, val, '${l10n.copiedToClipboard}: $val'),
              customContent: _buildRamModulesVisualRack(
                context,
                info.ram,
                isDark,
                l10n,
                systemCtrl,
              ),
            );

            final gpuPrimary = info.gpu.isNotEmpty ? info.gpu.first.name : l10n.noGpuDetected;
            final gpuSecondary = info.gpu.isNotEmpty && info.gpu.first.vramDisplay != 'Not available'
                ? '${l10n.dedicatedVram}: ${info.gpu.first.vramDisplay}'
                : null;

            final cardGpu = _buildProminentSpecCard(
              context: context,
              stepNumber: 3,
              categoryTitle: l10n.gpu,
              icon: Icons.videogame_asset_rounded,
              accentColor: const Color(0xFF8B5CF6),
              illustration: const GpuIllustration(),
              primaryValue: gpuPrimary,
              secondaryValue: gpuSecondary,
              specPills: [
                if (info.gpu.isNotEmpty && info.gpu.first.vramDisplay != 'Not available') info.gpu.first.vramDisplay,
                if (info.gpu.isNotEmpty && info.gpu.first.driverVersion != 'Not available') 'Driver: ${info.gpu.first.driverVersion}',
              ],
              copyValue: gpuPrimary,
              onCopy: (val) => systemCtrl.copyToClipboard(context, val, '${l10n.copiedToClipboard}: $val'),
            );

            final mbSerial = (info.motherboard.serial != 'Not available' && info.motherboard.serial != 'Default string' && info.motherboard.serial.isNotEmpty)
                ? info.motherboard.serial
                : ((info.system.serial != 'Not available' && info.system.serial != 'Default string' && info.system.serial.isNotEmpty) ? info.system.serial : null);

            final cardMotherboard = _buildProminentSpecCard(
              context: context,
              stepNumber: 4,
              categoryTitle: l10n.motherboard,
              icon: Icons.developer_board_rounded,
              accentColor: const Color(0xFF10B981),
              illustration: const MotherboardIllustration(),
              primaryValue: info.motherboard.model != 'Not available' ? info.motherboard.model : info.motherboard.manufacturer,
              secondaryValue: info.motherboard.manufacturer != 'Not available' ? info.motherboard.manufacturer : null,
              specPills: [
                if (info.bios.manufacturer != 'Not available') 'BIOS: ${info.bios.manufacturer}',
                if (info.bios.version != 'Not available') info.bios.version,
              ],
              serialNumber: mbSerial,
              copyValue: info.motherboard.model,
              onCopy: (val) => systemCtrl.copyToClipboard(context, val, '${l10n.copiedToClipboard}: $val'),
            );

            final cardStorage = _buildProminentSpecCard(
              context: context,
              stepNumber: 5,
              categoryTitle: l10n.storage,
              icon: Icons.album_rounded,
              accentColor: const Color(0xFF06B6D4),
              illustration: const StorageIllustration(),
              primaryValue: '',
              copyValue: info.storage.map((d) => '${d.capacityDisplay} ${d.type} ${d.serial}').join(', '),
              onCopy: (val) => systemCtrl.copyToClipboard(context, val, '${l10n.copiedToClipboard}: $val'),
              customContent: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (info.storage.isEmpty)
                    Text(
                      l10n.noStorageDetected,
                      style: TextStyle(
                        fontSize: 16,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    )
                  else
                    ...info.storage.map((d) => Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF06B6D4).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      d.capacityDisplay,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF06B6D4),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Directionality(
                                      textDirection: TextDirection.ltr,
                                      child: Text(
                                        '${d.type} (${d.model})',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (d.serial.isNotEmpty && d.serial != 'Not available' && d.serial != 'Default string') ...[
                                const SizedBox(height: 3),
                                InkWell(
                                  onTap: () => systemCtrl.copyToClipboard(
                                    context,
                                    d.serial.trim(),
                                    '${l10n.copiedToClipboard}: ${d.serial.trim()}',
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                                        width: 0.8,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.qr_code_2_rounded, size: 11, color: Color(0xFF06B6D4)),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${l10n.isPersian ? "سریال:" : "S/N:"} ',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                          ),
                                        ),
                                        Directionality(
                                          textDirection: TextDirection.ltr,
                                          child: Text(
                                            d.serial.trim(),
                                            style: TextStyle(
                                              fontFamily: 'Consolas',
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Icon(
                                          Icons.copy_rounded,
                                          size: 10,
                                          color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        )),
                ],
              ),
            );

            final isWinActivated = info.windowsActivation.activated;
            final cardWindows = _buildProminentSpecCard(
              context: context,
              stepNumber: 6,
              categoryTitle: l10n.windows,
              icon: Icons.window_rounded,
              accentColor: const Color(0xFF0284C7),
              illustration: const WindowsIllustration(),
              primaryValue: info.windows.edition != 'Not available' ? info.windows.edition : 'Windows 11',
              secondaryValue: '${info.windows.architecture}${info.windows.version != 'Not available' ? ' • ${info.windows.version}' : ''}',
              specPills: [
                info.windows.architecture,
                if (info.windows.version != 'Not available') info.windows.version,
                if (info.windows.build != 'Not available') 'Build ${info.windows.build}',
              ],
              headerTrailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (isWinActivated ? const Color(0xFF10B981) : const Color(0xFFEF4444)).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: (isWinActivated ? const Color(0xFF10B981) : const Color(0xFFEF4444)).withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  isWinActivated ? '✓ ${l10n.activated}' : '✕ ${l10n.notActivated}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isWinActivated ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                  ),
                ),
              ),
              copyValue: info.windows.edition,
              onCopy: (val) => systemCtrl.copyToClipboard(context, val, '${l10n.copiedToClipboard}: $val'),
              actionWidget: (!isWinActivated)
                  ? Obx(() {
                      final isRunning = activationCtrl.isActivatingWindows.value;
                      return SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: isRunning ? null : () => activationCtrl.activateWindows(context),
                          icon: isRunning
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.verified_user_rounded, size: 15),
                          label: Text(
                            isRunning ? l10n.activatingWindows : l10n.activateWindows,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0284C7),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      );
                    })
                  : null,
            );

            final officeInstalled = info.officeActivation.installed;
            final officeActivated = info.officeActivation.activated;
            final officeStatusColor = !officeInstalled
                ? const Color(0xFF64748B)
                : (officeActivated ? const Color(0xFF10B981) : const Color(0xFFEF4444));
            final officeStatusLabel = !officeInstalled
                ? '✕ ${l10n.notInstalled}'
                : (officeActivated ? '✓ ${l10n.activated}' : '✕ ${l10n.notActivated}');

            final cardOffice = _buildProminentSpecCard(
              context: context,
              stepNumber: 7,
              categoryTitle: l10n.microsoftOffice,
              icon: Icons.business_center_rounded,
              accentColor: const Color(0xFFD97706),
              illustration: const OfficeIllustration(),
              primaryValue: officeInstalled ? info.officeActivation.product : l10n.notInstalled,
              secondaryValue: officeInstalled && info.officeActivation.version != 'Not available'
                  ? '${info.officeActivation.architecture} • ${info.officeActivation.version}'
                  : null,
              specPills: officeInstalled
                  ? [
                      info.officeActivation.architecture,
                      if (info.officeActivation.version != 'Not available') 'v${info.officeActivation.version}',
                      if (info.officeActivation.channel != 'Not available') info.officeActivation.channel,
                    ]
                  : null,
              headerTrailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: officeStatusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: officeStatusColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  officeStatusLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: officeStatusColor,
                  ),
                ),
              ),
              copyValue: officeInstalled ? info.officeActivation.product : null,
              onCopy: (val) => systemCtrl.copyToClipboard(context, val, '${l10n.copiedToClipboard}: $val'),
              actionWidget: (officeInstalled && !officeActivated)
                  ? Obx(() {
                      final isRunning = activationCtrl.isActivatingOffice.value;
                      return SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: isRunning ? null : () => activationCtrl.activateOffice(context),
                          icon: isRunning
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.verified_user_rounded, size: 15),
                          label: Text(
                            isRunning ? l10n.activatingOffice : l10n.activateOffice,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD97706),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      );
                    })
                  : null,
            );

            final cardBattery = BatteryCard(battery: info.battery);

            if (isWide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        cardCpu,
                        const SizedBox(height: 14),
                        cardGpu,
                        const SizedBox(height: 14),
                        cardStorage,
                        const SizedBox(height: 14),
                        cardOffice,
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      children: [
                        cardRam,
                        const SizedBox(height: 14),
                        cardMotherboard,
                        const SizedBox(height: 14),
                        cardWindows,
                        const SizedBox(height: 14),
                        cardBattery,
                      ],
                    ),
                  ),
                ],
              );
            } else {
              return Column(
                children: [
                  cardCpu,
                  const SizedBox(height: 14),
                  cardRam,
                  const SizedBox(height: 14),
                  cardGpu,
                  const SizedBox(height: 14),
                  cardMotherboard,
                  const SizedBox(height: 14),
                  cardStorage,
                  const SizedBox(height: 14),
                  cardWindows,
                  const SizedBox(height: 14),
                  cardOffice,
                  const SizedBox(height: 14),
                  cardBattery,
                ],
              );
            }
          },
        ),
        const SizedBox(height: 28),

        // 3. Important Drivers Checklist Section
        _buildSectionHeader(
          context: context,
          icon: Icons.settings_suggest_rounded,
          title: l10n.drivers,
          color: const Color(0xFF0D9488),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: (info.driverSummary.allHealthy ? const Color(0xFF10B981) : const Color(0xFFF59E0B)).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: (info.driverSummary.allHealthy ? const Color(0xFF10B981) : const Color(0xFFF59E0B)).withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              l10n.driverSummaryCount(info.driverSummary.healthyCount, info.driverSummary.totalPresentCount),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: info.driverSummary.allHealthy ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Drivers Grid
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF131D33) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? const Color(0xFF22304E) : const Color(0xFFE2E8F0),
              width: 1.2,
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: info.drivers.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(l10n.notAvailable),
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final isMultiCol = constraints.maxWidth > 650;
                    final items = info.drivers.map((d) => _buildSimpleDriverRow(context, d, isDark, l10n)).toList();

                    if (isMultiCol) {
                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: items.map((w) => SizedBox(width: (constraints.maxWidth - 12) / 2, child: w)).toList(),
                      );
                    } else {
                      return Column(
                        children: items.map((w) => Padding(padding: const EdgeInsets.only(bottom: 8), child: w)).toList(),
                      );
                    }
                  },
                ),
        ),
        const SizedBox(height: 28),

        // 4. Software Section (Header + Reactive Scan & Folder Change buttons)
        Obx(() {
          final isScanning = softwareCtrl.isScanning.value;
          return _buildSectionHeader(
            context: context,
            icon: Icons.apps_rounded,
            title: l10n.software,
            color: const Color(0xFF6366F1),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedButton.icon(
                  onPressed: isScanning ? null : () => softwareCtrl.changePackagesDirectory(context),
                  icon: const Icon(Icons.folder_open_rounded, size: 15),
                  label: Text(
                    l10n.isPersian ? 'تغییر پوشه' : 'Change Folder',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF6366F1),
                    side: const BorderSide(color: Color(0xFF6366F1)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: isScanning ? null : () => softwareCtrl.scanPackages(),
                  icon: isScanning
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.refresh_rounded, size: 15),
                  label: Text(
                    isScanning ? l10n.scanning : l10n.scan,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 12),

        // Software Container (Reactive with Obx)
        Obx(() {
          final pkgRes = softwareCtrl.packagesResponse.value;
          final packages = pkgRes.packages;
          final directoryExists = pkgRes.directoryExists;
          final currentDir = pkgRes.packagesDirectory;

          return Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF131D33) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? const Color(0xFF22304E) : const Color(0xFFE2E8F0),
                width: 1.2,
              ),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Active Packages Directory Banner
                if (currentDir.isNotEmpty) ...[
                  InkWell(
                    onTap: () => softwareCtrl.changePackagesDirectory(context),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.folder_rounded,
                            size: 14,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${l10n.scanningDirectory} ',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                          Expanded(
                            child: Directionality(
                              textDirection: TextDirection.ltr,
                              child: Text(
                                currentDir,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            Icons.edit_outlined,
                            size: 14,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                // If software directory is missing, display alert
                if (!directoryExists) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.folder_off_rounded, color: Color(0xFFF59E0B), size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            l10n.softwareDirectoryNotFound,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFF59E0B),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // Discovered .exe installers list with upgraded UI/UX
                if (packages.isNotEmpty) ...[
                  ...packages.map((pkg) => _buildUpgradedPackageCard(context, pkg, isDark, l10n, softwareCtrl)),
                ] else if (info.software.isNotEmpty) ...[
                  // Fallback to configured required software checklist
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isMultiCol = constraints.maxWidth > 650;
                      final items = info.software.map((s) => _buildSimpleSoftwareRow(context, s, isDark, l10n)).toList();

                      if (isMultiCol) {
                        return Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: items.map((w) => SizedBox(width: (constraints.maxWidth - 12) / 2, child: w)).toList(),
                        );
                      } else {
                        return Column(
                          children: items.map((w) => Padding(padding: const EdgeInsets.only(bottom: 8), child: w)).toList(),
                        );
                      }
                    },
                  ),
                ] else
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.inventory_2_outlined, size: 36, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                          const SizedBox(height: 8),
                          Text(
                            l10n.noPackagesFound,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          );
        }),
        const SizedBox(height: 28),

        // 5. Required Files & Folders Checklist Section
        _buildSectionHeader(
          context: context,
          icon: Icons.folder_special_rounded,
          title: l10n.requiredFiles,
          color: const Color(0xFF0EA5E9),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: (info.filesSummary.allPresent ? const Color(0xFF10B981) : const Color(0xFFF59E0B)).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: (info.filesSummary.allPresent ? const Color(0xFF10B981) : const Color(0xFFF59E0B)).withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              l10n.filesSummaryCount(info.filesSummary.presentCount, info.filesSummary.totalCount),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: info.filesSummary.allPresent ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Files Grid
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF131D33) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? const Color(0xFF22304E) : const Color(0xFFE2E8F0),
              width: 1.2,
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: info.requiredFiles.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(l10n.noFilesConfigured),
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final isMultiCol = constraints.maxWidth > 650;
                    final items = info.requiredFiles.map((f) => _buildSimpleFileRow(context, f, isDark, l10n)).toList();

                    if (isMultiCol) {
                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: items.map((w) => SizedBox(width: (constraints.maxWidth - 12) / 2, child: w)).toList(),
                      );
                    } else {
                      return Column(
                        children: items.map((w) => Padding(padding: const EdgeInsets.only(bottom: 8), child: w)).toList(),
                      );
                    }
                  },
                ),
        ),
      ],
    );
  }



  Widget _buildSystemSummaryStrip(
    BuildContext context,
    SystemInfo info,
    bool isDark,
    AppLocalizations l10n,
    SystemInfoController systemCtrl,
  ) {
    // Determine device type: laptop vs desktop
    final isLaptop = info.driverSummary.recommendations.isLaptop ||
        info.system.model.toLowerCase().contains('laptop') ||
        info.system.model.toLowerCase().contains('notebook') ||
        info.battery.hasBattery;

    // Build compact summary parts
    final parts = <String>[];

    // 1) Device identifier (brand + model for laptop, motherboard for desktop)
    if (isLaptop) {
      final sysModel = info.system.model != 'Not available' ? info.system.model : '';
      final sysMfg = info.system.manufacturer != 'Not available' ? info.system.manufacturer : '';
      if (sysModel.isNotEmpty) {
        // If model already contains manufacturer name, just use model
        if (sysModel.toLowerCase().contains(sysMfg.toLowerCase()) || sysMfg.isEmpty) {
          parts.add(sysModel);
        } else {
          parts.add('$sysMfg $sysModel');
        }
      } else if (sysMfg.isNotEmpty) {
        parts.add(sysMfg);
      }
    } else {
      // Desktop: motherboard brand + model
      final mbModel = info.motherboard.model != 'Not available' ? info.motherboard.model : '';
      final mbMfg = info.motherboard.manufacturer != 'Not available' ? info.motherboard.manufacturer : '';
      if (mbModel.isNotEmpty) {
        if (mbModel.toLowerCase().contains(mbMfg.toLowerCase()) || mbMfg.isEmpty) {
          parts.add(mbModel);
        } else {
          parts.add('$mbMfg $mbModel');
        }
      } else if (mbMfg.isNotEmpty) {
        parts.add(mbMfg);
      }
    }

    // 2) CPU short name (trim to essentials)
    if (info.cpu.name != 'Not available') {
      var cpuShort = info.cpu.name;
      // Shorten common CPU prefixes for compact display
      cpuShort = cpuShort.replaceAll(RegExp(r'\(R\)|\(TM\)', caseSensitive: false), '');
      cpuShort = cpuShort.replaceAll(RegExp(r'\s+'), ' ').trim();
      // Remove trailing "CPU @ X.XXGHz" if present for brevity
      cpuShort = cpuShort.replaceAll(RegExp(r'\s*CPU\s*@.*$', caseSensitive: false), '');
      cpuShort = cpuShort.trim();
      parts.add(cpuShort);
    }

    // 3) RAM total
    if (info.ram.totalDisplay != 'Not available') {
      parts.add(info.ram.totalDisplay);
    }

    // 4) Storage summary (total capacity of all drives)
    if (info.storage.isNotEmpty) {
      final storageTexts = info.storage.map((d) {
        final cap = d.capacityDisplay != 'Not available' ? d.capacityDisplay : '';
        final type = d.type != 'Not available' && d.type != 'Storage' ? d.type : '';
        return '$cap $type'.trim();
      }).where((s) => s.isNotEmpty).toList();
      if (storageTexts.isNotEmpty) {
        parts.add(storageTexts.join(' + '));
      }
    }

    // 5) GPU (dedicated only if available, skip integrated for desktop summary)
    if (info.gpu.isNotEmpty) {
      var gpuName = info.gpu.first.name;
      gpuName = gpuName.replaceAll(RegExp(r'\(R\)|\(TM\)', caseSensitive: false), '');
      gpuName = gpuName.replaceAll(RegExp(r'\s+'), ' ').trim();
      final vram = info.gpu.first.vramDisplay != 'Not available' ? ' ${info.gpu.first.vramDisplay}' : '';
      parts.add('$gpuName$vram');
    }

    final summaryText = parts.join('  •  ');

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF0F1B32), const Color(0xFF152240), const Color(0xFF1A2A4E)]
              : [const Color(0xFFF0F4FF), const Color(0xFFE8EDFA), const Color(0xFFE0E8F8)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF253B66) : const Color(0xFFBFCFE8),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Device type icon
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withValues(alpha: isDark ? 0.2 : 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFF3B82F6).withValues(alpha: 0.3),
                width: 0.8,
              ),
            ),
            child: Icon(
              isLaptop ? Icons.laptop_mac_rounded : Icons.desktop_windows_rounded,
              size: 20,
              color: const Color(0xFF3B82F6),
            ),
          ),
          const SizedBox(width: 12),

          // Summary text
          Expanded(
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Text(
                summaryText,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                  letterSpacing: -0.2,
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Copy button
          Tooltip(
            message: l10n.isPersian ? 'کپی خلاصه مشخصات' : 'Copy Summary',
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => systemCtrl.copyToClipboard(
                context,
                summaryText,
                '${l10n.copiedToClipboard}: ${l10n.isPersian ? "خلاصه مشخصات" : "System Summary"}',
              ),
              child: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withValues(alpha: isDark ? 0.15 : 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.25),
                    width: 0.8,
                  ),
                ),
                child: const Icon(
                  Icons.copy_rounded,
                  size: 15,
                  color: Color(0xFF3B82F6),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required BuildContext context,
    required IconData icon,
    required String title,
    required Color color,
    Widget? trailing,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
            letterSpacing: -0.3,
          ),
        ),
        const Spacer(),
        ?trailing,
      ],
    );
  }

  Widget _buildProminentSpecCard({
    required BuildContext context,
    required int stepNumber,
    required String categoryTitle,
    required IconData icon,
    required Color accentColor,
    required String primaryValue,
    Widget? illustration,
    String? secondaryValue,
    List<String>? specPills,
    String? serialNumber,
    Widget? customContent,
    Widget? headerTrailing,
    Widget? actionWidget,
    String? copyValue,
    required ValueChanged<String> onCopy,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131D33) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF22304E) : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: isDark ? 0.2 : 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: accentColor.withValues(alpha: isDark ? 0.5 : 0.3),
                    width: 1,
                  ),
                ),
                child: Center(
                  child: Text(
                    '$stepNumber',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: accentColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Icon(icon, size: 20, color: accentColor),
              const SizedBox(width: 8),
              Text(
                categoryTitle,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
              const Spacer(),
              if (headerTrailing != null) ...[
                headerTrailing,
                const SizedBox(width: 8),
              ],
              if (copyValue != null && copyValue.isNotEmpty)
                Tooltip(
                  message: l10n.copy,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () => onCopy(copyValue),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        Icons.copy_rounded,
                        size: 14,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Main Spec Body: Illustration on side + Specs Column
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (illustration != null) ...[
                HardwareIllustrationBadge(
                  illustration: illustration,
                  accentColor: accentColor,
                  size: 68,
                ),
                const SizedBox(width: 14),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (customContent != null)
                      customContent
                    else ...[
                      Directionality(
                        textDirection: TextDirection.ltr,
                        child: Text(
                          primaryValue,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                            letterSpacing: -0.4,
                            height: 1.2,
                          ),
                        ),
                      ),
                      if (secondaryValue != null && secondaryValue.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Directionality(
                          textDirection: TextDirection.ltr,
                          child: Text(
                            secondaryValue,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: accentColor,
                            ),
                          ),
                        ),
                      ],
                      if (specPills != null && specPills.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: specPills.map((pill) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: isDark ? 0.15 : 0.08),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: accentColor.withValues(alpha: isDark ? 0.35 : 0.2),
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              pill,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: accentColor,
                              ),
                            ),
                          )).toList(),
                        ),
                      ],
                      if (serialNumber != null &&
                          serialNumber.isNotEmpty &&
                          serialNumber != 'Not available' &&
                          serialNumber != 'Default string' &&
                          serialNumber != 'None') ...[
                        const SizedBox(height: 10),
                        InkWell(
                          onTap: () => onCopy(serialNumber),
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                                width: 0.8,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.qr_code_2_rounded,
                                  size: 13,
                                  color: accentColor,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${l10n.isPersian ? "سریال:" : "S/N:"} ',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                  ),
                                ),
                                Flexible(
                                  child: Directionality(
                                    textDirection: TextDirection.ltr,
                                    child: Text(
                                      serialNumber,
                                      style: TextStyle(
                                        fontFamily: 'Consolas',
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.copy_rounded,
                                  size: 11,
                                  color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ],
          ),

          if (actionWidget != null) ...[
            const SizedBox(height: 14),
            actionWidget,
          ],
        ],
      ),
    );
  }

  Widget _buildRamModulesVisualRack(
    BuildContext context,
    RamInfo ram,
    bool isDark,
    AppLocalizations l10n,
    SystemInfoController systemCtrl,
  ) {
    if (ram.modules.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Directionality(
            textDirection: TextDirection.ltr,
            child: Text(
              ram.totalDisplay,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
              ),
            ),
          ),
          if (ram.speedDisplay != 'Not available') ...[
            const SizedBox(height: 4),
            Directionality(
              textDirection: TextDirection.ltr,
              child: Text(
                ram.speedDisplay,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFF59E0B)),
              ),
            ),
          ],
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Total summary row
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Directionality(
              textDirection: TextDirection.ltr,
              child: Text(
                ram.totalDisplay,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                  letterSpacing: -0.5,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.2 : 0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
                  width: 0.8,
                ),
              ),
              child: Text(
                ram.modules.length > 1
                    ? '${ram.modules.length} ${l10n.isPersian ? "ماژول" : "Sticks"}'
                    : (l10n.isPersian ? "۱ ماژول" : "1 Stick"),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFF59E0B),
                ),
              ),
            ),
            if (ram.speedDisplay != 'Not available') ...[
              const SizedBox(width: 8),
              Directionality(
                textDirection: TextDirection.ltr,
                child: Text(
                  ram.speedDisplay,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),

        // Visual RAM Sticks Rack (Side by side or vertical if narrow)
        LayoutBuilder(
          builder: (context, constraints) {
            final isMultiCol = constraints.maxWidth > 280 && ram.modules.length >= 2;

            final stickWidgets = ram.modules.asMap().entries.map((entry) {
              final idx = entry.key;
              final mod = entry.value;
              final serialText = (mod.serial != 'Not available' && mod.serial != '00000000' && mod.serial.isNotEmpty)
                  ? mod.serial
                  : (mod.partNumber != 'Not available' ? mod.partNumber : null);

              return Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF0F172A), const Color(0xFF162036)]
                        : [const Color(0xFFF8FAFC), const Color(0xFFF1F5F9)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? const Color(0xFF243352) : const Color(0xFFE2E8F0),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Stick Header: Mini RAM illustration + Slot Name
                    Row(
                      children: [
                        Container(
                          width: 26,
                          height: 26,
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                              width: 0.8,
                            ),
                          ),
                          child: const RamIllustration(color: Color(0xFFF59E0B)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${l10n.isPersian ? "رم" : "RAM"} ${idx + 1}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                                ),
                              ),
                              if (mod.slot.isNotEmpty && mod.slot != 'Slot')
                                Text(
                                  mod.slot,
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w500,
                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Capacity & Speed Pill
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.15 : 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Directionality(
                            textDirection: TextDirection.ltr,
                            child: Text(
                              mod.capacityDisplay,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFFF59E0B),
                              ),
                            ),
                          ),
                          Directionality(
                            textDirection: TextDirection.ltr,
                            child: Text(
                              '${mod.type}${mod.speedDisplay != 'Not available' ? " • ${mod.speedDisplay}" : ""}',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: isDark ? const Color(0xFFFDE68A) : const Color(0xFFB45309),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Manufacturer / Model details
                    if (mod.manufacturer != 'Not available' || mod.partNumber != 'Not available') ...[
                      const SizedBox(height: 6),
                      Directionality(
                        textDirection: TextDirection.ltr,
                        child: Text(
                          mod.manufacturer != 'Not available' ? '${mod.manufacturer} (${mod.partNumber})' : mod.partNumber,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],

                    // Serial Number Row with copy
                    if (serialText != null && serialText.isNotEmpty && serialText != 'Default string') ...[
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: () => systemCtrl.copyToClipboard(
                          context,
                          serialText.trim(),
                          '${l10n.copiedToClipboard}: ${serialText.trim()}',
                        ),
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: (isDark ? const Color(0xFF0B1120) : Colors.white),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: (isDark ? const Color(0xFF1E293B) : const Color(0xFFCBD5E1)),
                              width: 0.7,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.qr_code_2_rounded, size: 10, color: Color(0xFFF59E0B)),
                              const SizedBox(width: 3),
                              Text(
                                '${l10n.isPersian ? "سریال:" : "S/N:"} ',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                ),
                              ),
                              Flexible(
                                child: Directionality(
                                  textDirection: TextDirection.ltr,
                                  child: Text(
                                    serialText.trim(),
                                    style: TextStyle(
                                      fontFamily: 'Consolas',
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 3),
                              Icon(
                                Icons.copy_rounded,
                                size: 9,
                                color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }).toList();

            if (isMultiCol) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: stickWidgets.map((w) => Expanded(child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: w,
                ))).toList(),
              );
            } else {
              return Column(
                children: stickWidgets.map((w) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: w,
                )).toList(),
              );
            }
          },
        ),
      ],
    );
  }

  Widget _buildUpgradedPackageCard(
    BuildContext context,
    SoftwarePackage pkg,
    bool isDark,
    AppLocalizations l10n,
    SoftwareController softwareCtrl,
  ) {
    final isInstalled = pkg.isInstalled;
    final installAllowed = pkg.installAllowed;
    final isCurrentInstalling = softwareCtrl.isCurrentInstalling(pkg);

    final statusColor = isInstalled ? const Color(0xFF10B981) : const Color(0xFF6366F1);

    Widget iconWidget;
    if (pkg.iconBase64 != null && pkg.iconBase64!.isNotEmpty) {
      try {
        final raw = pkg.iconBase64!;
        final b64 = (raw.contains(',') ? raw.split(',').last : raw)
            .trim()
            .replaceAll('\n', '')
            .replaceAll('\r', '');
        final bytes = base64Decode(b64);
        iconWidget = Image.memory(
          bytes,
          width: 28,
          height: 28,
          filterQuality: FilterQuality.high,
          errorBuilder: (context, error, stackTrace) => Icon(
            Icons.apps_rounded,
            size: 24,
            color: statusColor,
          ),
        );
      } catch (_) {
        iconWidget = Icon(
          Icons.apps_rounded,
          size: 24,
          color: statusColor,
        );
      }
    } else {
      iconWidget = Icon(
        Icons.apps_rounded,
        size: 24,
        color: statusColor,
      );
    }

    final hasVersion = pkg.version.isNotEmpty && pkg.version != 'Unknown';
    final hasInstalledVer = pkg.installedVersion.isNotEmpty && pkg.installedVersion != 'Not available';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isInstalled
              ? statusColor.withValues(alpha: isDark ? 0.35 : 0.25)
              : (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
          width: isInstalled ? 1.4 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Application Icon Container with Install Path Tooltip
          Tooltip(
            message: pkg.installPathTooltip,
            waitDuration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0B132B) : const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark ? const Color(0xFF38BDF8).withValues(alpha: 0.4) : const Color(0xFF64748B),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            textStyle: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            child: Container(
              width: 42,
              height: 42,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: statusColor.withValues(alpha: 0.25),
                  width: 1,
                ),
              ),
              child: Center(child: iconWidget),
            ),
          ),
          const SizedBox(width: 14),

          // Application Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Directionality(
                        textDirection: TextDirection.ltr,
                        child: Text(
                          pkg.name,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    if (hasInstalledVer) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Directionality(
                          textDirection: TextDirection.ltr,
                          child: Text(
                            'v${pkg.installedVersion}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF10B981),
                            ),
                          ),
                        ),
                      ),
                    ] else if (hasVersion) ...[
                      const SizedBox(width: 8),
                      Directionality(
                        textDirection: TextDirection.ltr,
                        child: Text(
                          'v${pkg.version}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text(
                        pkg.filename.isNotEmpty ? pkg.filename : pkg.relativePath,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (pkg.fileSizeDisplay.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Text(
                          '•',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                          ),
                        ),
                      ),
                      Directionality(
                        textDirection: TextDirection.ltr,
                        child: Text(
                          pkg.fileSizeDisplay,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),

          // Status Badge + Action Button
          if (installAllowed)
            ElevatedButton.icon(
              onPressed: isCurrentInstalling ? null : () => softwareCtrl.installPackageInteractive(context, pkg),
              icon: isCurrentInstalling
                  ? const SizedBox(
                      width: 13,
                      height: 13,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.install_desktop_rounded, size: 15),
              label: Text(
                isCurrentInstalling ? l10n.installing : l10n.install,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 2,
              ),
            )
          else
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.35),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_rounded, size: 15, color: statusColor),
                      const SizedBox(width: 6),
                      Text(
                        l10n.installed,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => softwareCtrl.openInstalledApp(context, pkg),
                  icon: const Icon(Icons.open_in_new_rounded, size: 14),
                  label: Text(
                    l10n.openApp,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                    foregroundColor: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    side: BorderSide(
                      color: isDark ? const Color(0xFF38BDF8).withValues(alpha: 0.35) : const Color(0xFF0284C7).withValues(alpha: 0.35),
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildSimpleDriverRow(BuildContext context, DriverItem drv, bool isDark, AppLocalizations l10n) {
    final isPresent = drv.isPresent;
    final isHealthy = drv.isHealthy;

    Color statusColor;
    String statusText;
    IconData statusIcon;

    final isProblem = !isHealthy && isPresent;

    if (!isPresent) {
      statusColor = isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8);
      statusText = l10n.isPersian ? 'موجود نیست' : 'Not Present';
      statusIcon = Icons.remove_rounded;
    } else if (isHealthy) {
      statusColor = const Color(0xFF10B981);
      statusText = l10n.isPersian ? 'سالم (نصب شده)' : 'Installed (OK)';
      statusIcon = Icons.check_rounded;
    } else {
      statusColor = const Color(0xFFEF4444);
      statusText = drv.problemCode == 28
          ? (l10n.isPersian ? 'نیاز به نصب درایور (کد ۲۸)' : 'Driver Missing (Code 28)')
          : (l10n.isPersian ? 'خطای درایور (کد ${drv.problemCode})' : 'Driver Error (Code ${drv.problemCode})');
      statusIcon = Icons.close_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark
            ? (isProblem ? const Color(0xFF1F1318) : const Color(0xFF0F172A))
            : (isProblem ? const Color(0xFFFFF1F2) : const Color(0xFFF8FAFC)),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: (!isPresent)
              ? (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0))
              : isHealthy
                  ? statusColor.withValues(alpha: isDark ? 0.3 : 0.2)
                  : const Color(0xFFEF4444).withValues(alpha: 0.5),
          width: isProblem ? 1.4 : 1.0,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(statusIcon, size: 16, color: statusColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        drv.displayName,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (drv.manufacturer.isNotEmpty && drv.manufacturer != 'Unknown' && drv.manufacturer != 'N/A') ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          drv.manufacturer,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D9488).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        l10n.isPersian ? drv.categoryFa : drv.category,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0D9488),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        l10n.isPersian ? drv.statusDescription : drv.statusDescriptionEn,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: isProblem
                              ? const Color(0xFFEF4444)
                              : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: statusColor.withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              statusText,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleSoftwareRow(BuildContext context, SoftwareItem item, bool isDark, AppLocalizations l10n) {
    final isInstalled = item.isInstalled;
    final statusColor = isInstalled ? const Color(0xFF10B981) : const Color(0xFFEF4444);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isInstalled
              ? statusColor.withValues(alpha: isDark ? 0.3 : 0.2)
              : (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              isInstalled ? Icons.check_rounded : Icons.close_rounded,
              size: 16,
              color: statusColor,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text(
                    item.displayName,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isInstalled && item.version != 'Not available')
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text(
                        'v${item.version}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              isInstalled ? l10n.installed : l10n.notInstalled,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleFileRow(BuildContext context, RequiredFileItem item, bool isDark, AppLocalizations l10n) {
    final exists = item.exists;
    final statusColor = exists ? const Color(0xFF10B981) : const Color(0xFFEF4444);
    final isFolder = item.type.toLowerCase() == 'folder';
    final systemCtrl = Get.find<SystemInfoController>();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: exists
              ? statusColor.withValues(alpha: isDark ? 0.35 : 0.2)
              : (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Icon + Display Name + Tag + Status Badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isFolder
                      ? (exists ? Icons.folder_rounded : Icons.folder_off_rounded)
                      : (exists ? Icons.insert_drive_file_rounded : Icons.file_present_rounded),
                  size: 18,
                  color: statusColor,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Directionality(
                        textDirection: TextDirection.ltr,
                        child: Text(
                          item.displayName,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)).withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isFolder ? l10n.folder : l10n.file,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  exists ? '✓ ${l10n.present}' : '✕ ${l10n.missing}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Bottom Row: Exact File Path container with copy button
          InkWell(
            onTap: () => systemCtrl.copyToClipboard(
              context,
              item.path,
              '${l10n.copiedToClipboard}: ${item.path}',
            ),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF070D1E) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFCBD5E1),
                  width: 0.8,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.link_rounded,
                    size: 14,
                    color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text(
                        item.path,
                        style: TextStyle(
                          fontFamily: 'Consolas',
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.copy_rounded,
                    size: 13,
                    color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => systemCtrl.changeFileRequirementPath(context, item.id, item.displayName),
              icon: const Icon(Icons.folder_open_rounded, size: 14),
              label: Text(
                l10n.isPersian ? 'تغییر مسیر' : 'Change Path',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              ),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF0EA5E9),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
