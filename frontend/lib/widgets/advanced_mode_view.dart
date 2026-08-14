import 'package:flutter/material.dart';
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

class AdvancedModeView extends StatelessWidget {
  final SystemInfo info;

  const AdvancedModeView({super.key, required this.info});

  @override
  Widget build(BuildContext context) {
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

            if (isWide) {
              // 2-Column Desktop Grid
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Column
                  Expanded(
                    child: Column(
                      children: [
                        CpuCard(cpu: info.cpu),
                        const SizedBox(height: 16),
                        GpuCard(gpus: info.gpu),
                        const SizedBox(height: 16),
                        StorageCard(storage: info.storage),
                        const SizedBox(height: 16),
                        SoftwareCard(
                          software: info.software,
                          summary: info.softwareSummary,
                        ),
                        const SizedBox(height: 16),
                        BiosCard(bios: info.bios),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Right Column
                  Expanded(
                    child: Column(
                      children: [
                        RamCard(ram: info.ram),
                        const SizedBox(height: 16),
                        MotherboardCard(motherboard: info.motherboard),
                        const SizedBox(height: 16),
                        WindowsCard(
                          windows: info.windows,
                          system: info.system,
                        ),
                        const SizedBox(height: 16),
                        FilesCard(
                          files: info.requiredFiles,
                          summary: info.filesSummary,
                        ),
                        const SizedBox(height: 16),
                        NetworkCard(network: info.network),
                      ],
                    ),
                  ),
                ],
              );
            } else {
              // Single Column Layout for narrow windows
              return Column(
                children: [
                  CpuCard(cpu: info.cpu),
                  const SizedBox(height: 16),
                  RamCard(ram: info.ram),
                  const SizedBox(height: 16),
                  GpuCard(gpus: info.gpu),
                  const SizedBox(height: 16),
                  MotherboardCard(motherboard: info.motherboard),
                  const SizedBox(height: 16),
                  StorageCard(storage: info.storage),
                  const SizedBox(height: 16),
                  WindowsCard(
                    windows: info.windows,
                    system: info.system,
                  ),
                  const SizedBox(height: 16),
                  SoftwareCard(
                    software: info.software,
                    summary: info.softwareSummary,
                  ),
                  const SizedBox(height: 16),
                  FilesCard(
                    files: info.requiredFiles,
                    summary: info.filesSummary,
                  ),
                  const SizedBox(height: 16),
                  BiosCard(bios: info.bios),
                  const SizedBox(height: 16),
                  NetworkCard(network: info.network),
                ],
              );
            }
          },
        ),
      ],
    );
  }
}
