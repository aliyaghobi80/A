import 'package:flutter/material.dart';
import '../models/system_info.dart';
import '../services/api_service.dart';
import 'summary_hero_bar.dart';
import 'cards/cpu_card.dart';
import 'cards/motherboard_card.dart';
import 'cards/ram_card.dart';
import 'cards/gpu_card.dart';
import 'cards/storage_card.dart';
import 'cards/windows_card.dart';
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
  final ApiService _apiService = ApiService();
  PackagesResponse _packagesResponse = PackagesResponse.empty();
  bool _isScanningPackages = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialPackages != null) {
      _packagesResponse = widget.initialPackages!;
    } else {
      _loadPackages();
    }
  }

  Future<void> _loadPackages() async {
    final res = await _apiService.fetchPackages();
    if (mounted) {
      setState(() {
        _packagesResponse = res;
      });
    }
  }

  Future<void> _handleScanPackages() async {
    setState(() {
      _isScanningPackages = true;
    });
    final res = await _apiService.scanPackages();
    if (mounted) {
      setState(() {
        _packagesResponse = res;
        _isScanningPackages = false;
      });
    }
  }

  Future<void> _handleInstallPackage(String packageId, String name) async {
    final scaffold = ScaffoldMessenger.of(context);
    scaffold.showSnackBar(
      SnackBar(
        content: Text('Installing $name...'),
        duration: const Duration(seconds: 2),
      ),
    );

    final res = await _apiService.installPackage(packageId);
    if (mounted) {
      final success = res['success'] == true;
      scaffold.showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? (success ? '$name installed successfully.' : 'Installation failed.')),
          backgroundColor: success ? const Color(0xFF10B981) : const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _loadPackages();
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = widget.info;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top Hero Overview Bar
        SummaryHeroBar(info: info),
        const SizedBox(height: 20),

        // Responsive Grid of Cards
        LayoutBuilder(
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
            final cardWindows = WindowsCard(windows: info.windows, system: info.system);
            final cardFiles = FilesCard(files: info.requiredFiles, summary: info.filesSummary);
            final cardPackages = PackagesCard(
              packages: _packagesResponse.packages,
              summary: _packagesResponse.summary,
              onScan: _handleScanPackages,
              isScanning: _isScanningPackages,
              onInstall: _handleInstallPackage,
            );
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
