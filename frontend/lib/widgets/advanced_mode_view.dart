import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/software_controller.dart';
import '../controllers/system_info_controller.dart';
import '../l10n/app_localizations.dart';
import '../models/system_info.dart';
import 'summary_hero_bar.dart';
import 'qc/qc_summary_banner.dart';
import 'cards/cpu_card.dart';
import 'cards/motherboard_card.dart';
import 'cards/ram_card.dart';
import 'cards/gpu_card.dart';
import 'cards/storage_card.dart';
import 'cards/windows_card.dart';
import 'cards/office_card.dart';
import 'cards/battery_card.dart';
import 'cards/bios_card.dart';
import 'cards/network_card.dart';
import 'cards/software_card.dart';
import 'cards/files_card.dart';
import 'cards/driver_card.dart';
import 'cards/packages_card.dart';

class AdvancedModeView extends StatefulWidget {
  final SystemInfo info;
  final PackagesResponse? initialPackages;

  const AdvancedModeView({
    super.key,
    required this.info,
    this.initialPackages,
  });

  @override
  State<AdvancedModeView> createState() => _AdvancedModeViewState();
}

class _AdvancedModeViewState extends State<AdvancedModeView> {
  final TextEditingController _searchController = TextEditingController();
  String _searchFilter = '';
  bool? _globalExpanded;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _setGlobalExpanded(bool expand) {
    setState(() {
      _globalExpanded = expand;
    });
  }

  @override
  Widget build(BuildContext context) {
    final softwareCtrl = Get.find<SoftwareController>();
    final systemCtrl = Get.find<SystemInfoController>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);
    final info = widget.info;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Full System QC Summary Banner
        const QcSummaryBanner(),

        // 2. Top Hero Overview Bar
        SummaryHeroBar(info: info),
        const SizedBox(height: 16),

        // 3. Advanced Mode Interactive Toolbar (Search & Expand/Collapse All)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF131D33) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? const Color(0xFF22304E) : const Color(0xFFE2E8F0),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Search Input Box
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _searchFilter = val.trim().toLowerCase()),
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    decoration: InputDecoration(
                      hintText: l10n.isPersian ? 'جستجو در قطعات، درایورها و مشخصات...' : 'Search specs, drivers, hardware...',
                      hintStyle: TextStyle(
                        fontSize: 11,
                        color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                      ),
                      prefixIcon: const Icon(Icons.search_rounded, size: 16, color: Color(0xFF3B82F6)),
                      suffixIcon: _searchFilter.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 14),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchFilter = '');
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 1.2),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Expand All / Collapse All Buttons
              Tooltip(
                message: l10n.isPersian ? 'باز کردن تمامی کارت‌ها' : 'Expand All Cards',
                child: OutlinedButton.icon(
                  onPressed: () => _setGlobalExpanded(true),
                  icon: const Icon(Icons.unfold_more_rounded, size: 14),
                  label: Text(
                    l10n.isPersian ? 'باز کردن همه' : 'Expand All',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    side: BorderSide(color: isDark ? const Color(0xFF22304E) : const Color(0xFFCBD5E1)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Tooltip(
                message: l10n.isPersian ? 'بستن و خلاصه‌سازی تمامی کارت‌ها' : 'Collapse All Cards',
                child: OutlinedButton.icon(
                  onPressed: () => _setGlobalExpanded(false),
                  icon: const Icon(Icons.unfold_less_rounded, size: 14),
                  label: Text(
                    l10n.isPersian ? 'بستن همه' : 'Collapse All',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    side: BorderSide(color: isDark ? const Color(0xFF22304E) : const Color(0xFFCBD5E1)),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 4. Responsive Grid of Expandable Cards
        LayoutBuilder(
          key: ValueKey('grid_${_globalExpanded ?? "default"}'),
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 950;

            final cardCpu = CpuCard(cpu: info.cpu);
            final cardGpu = GpuCard(gpus: info.gpu);
            final cardStorage = StorageCard(storage: info.storage);
            final cardSoftware = SoftwareCard(software: info.software, summary: info.softwareSummary);
            final cardDrivers = DriverCard(drivers: info.drivers, summary: info.driverSummary);
            final cardBios = BiosCard(bios: info.bios);

            final cardRam = RamCard(ram: info.ram);
            final cardMotherboard = MotherboardCard(motherboard: info.motherboard);
            final cardWindows = WindowsCard(
              windows: info.windows,
              system: info.system,
              activation: info.windowsActivation,
            );
            final cardOffice = OfficeCard(office: info.officeActivation);
            final cardBattery = BatteryCard(battery: info.battery);
            final cardFiles = FilesCard(
              files: info.requiredFiles,
              summary: info.filesSummary,
              onChangePath: (id, name) => systemCtrl.changeFileRequirementPath(context, id, name),
            );

            final cardPackages = Obx(() {
              final pkgRes = softwareCtrl.packagesResponse.value;
              final isScanning = softwareCtrl.isScanning.value;

              return PackagesCard(
                packages: pkgRes.packages,
                summary: pkgRes.summary,
                packagesDirectory: pkgRes.packagesDirectory,
                directoryExists: pkgRes.directoryExists,
                onScan: () => softwareCtrl.scanPackages(),
                onChangeDirectory: () => softwareCtrl.changePackagesDirectory(context),
                isScanning: isScanning,
                onInstall: (packageId, name) {
                  final pkg = pkgRes.packages.firstWhereOrNull(
                    (p) => (p.relativePath.isNotEmpty ? p.relativePath : p.id) == packageId,
                  );
                  if (pkg != null) {
                    softwareCtrl.installPackageInteractive(context, pkg);
                  }
                },
                onOpen: (pkg) => softwareCtrl.openInstalledApp(context, pkg),
                onUninstall: (pkg) => softwareCtrl.uninstallPackageInteractive(context, pkg),
              );
            });

            final cardNetwork = NetworkCard(network: info.network);

            if (isWide) {
              // 2-Column Desktop Grid
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Column
                  Expanded(
                    child: Column(
                      children: [
                        cardCpu,
                        const SizedBox(height: 16),
                        cardGpu,
                        const SizedBox(height: 16),
                        cardStorage,
                        const SizedBox(height: 16),
                        cardSoftware,
                        const SizedBox(height: 16),
                        cardDrivers,
                        const SizedBox(height: 16),
                        cardBios,
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Right Column
                  Expanded(
                    child: Column(
                      children: [
                        cardRam,
                        const SizedBox(height: 16),
                        cardMotherboard,
                        const SizedBox(height: 16),
                        cardWindows,
                        const SizedBox(height: 16),
                        cardOffice,
                        const SizedBox(height: 16),
                        cardBattery,
                        const SizedBox(height: 16),
                        cardFiles,
                        const SizedBox(height: 16),
                        cardPackages,
                        const SizedBox(height: 16),
                        cardNetwork,
                      ],
                    ),
                  ),
                ],
              );
            } else {
              // Single Column Layout for narrow windows
              return Column(
                children: [
                  cardCpu,
                  const SizedBox(height: 16),
                  cardRam,
                  const SizedBox(height: 16),
                  cardGpu,
                  const SizedBox(height: 16),
                  cardMotherboard,
                  const SizedBox(height: 16),
                  cardStorage,
                  const SizedBox(height: 16),
                  cardWindows,
                  const SizedBox(height: 16),
                  cardOffice,
                  const SizedBox(height: 16),
                  cardBattery,
                  const SizedBox(height: 16),
                  cardDrivers,
                  const SizedBox(height: 16),
                  cardSoftware,
                  const SizedBox(height: 16),
                  cardPackages,
                  const SizedBox(height: 16),
                  cardFiles,
                  const SizedBox(height: 16),
                  cardBios,
                  const SizedBox(height: 16),
                  cardNetwork,
                ],
              );
            }
          },
        ),
      ],
    );
  }
}
