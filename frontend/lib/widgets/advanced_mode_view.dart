import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/software_controller.dart';
import '../models/system_info.dart';
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

class AdvancedModeView extends StatelessWidget {
  final SystemInfo info;
  final PackagesResponse? initialPackages;

  const AdvancedModeView({
    super.key,
    required this.info,
    this.initialPackages,
  });

  @override
  Widget build(BuildContext context) {
    final softwareCtrl = Get.find<SoftwareController>();

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

            final cardPackages = Obx(() {
              final pkgRes = softwareCtrl.packagesResponse.value;
              final isScanning = softwareCtrl.isScanning.value;

              return PackagesCard(
                packages: pkgRes.packages,
                summary: pkgRes.summary,
                packagesDirectory: pkgRes.packagesDirectory,
                directoryExists: pkgRes.directoryExists,
                onScan: () => softwareCtrl.scanPackages(),
                isScanning: isScanning,
                onInstall: (packageId, name) {
                  final pkg = pkgRes.packages.firstWhereOrNull(
                    (p) => (p.relativePath.isNotEmpty ? p.relativePath : p.id) == packageId,
                  );
                  if (pkg != null) {
                    softwareCtrl.installPackageInteractive(context, pkg);
                  }
                },
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
