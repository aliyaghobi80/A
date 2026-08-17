import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../l10n/app_localizations.dart';
import '../models/system_info.dart';
import '../services/api_service.dart';
import '../services/folder_picker_service.dart';

class SystemInfoController extends GetxController {
  final ApiService _apiService = ApiService();

  final Rx<SystemInfo?> systemInfo = Rx<SystemInfo?>(null);
  final RxBool isLoading = true.obs;
  final RxBool isRefreshing = false.obs;
  final RxString errorMessage = ''.obs;

  @override
  void onInit() {
    super.onInit();
    fetchSystemInfo();
  }

  Future<void> changeFileRequirementPath(BuildContext context, String reqId, String reqName) async {
    final l10n = AppLocalizations.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    final selectedPath = await FolderPickerService.pickFolder(
      title: '${l10n.isPersian ? "انتخاب مسیر برای" : "Select Path for"} $reqName',
    );

    if (selectedPath != null && selectedPath.isNotEmpty) {
      try {
        final success = await _apiService.setFilesDirectory(reqId, selectedPath);
        if (success) {
          await fetchSystemInfo(forceRefresh: true);
          if (context.mounted) {
            scaffoldMessenger.showSnackBar(
              SnackBar(
                content: Text(
                  l10n.isPersian
                      ? '✓ مسیر $reqName به $selectedPath تغییر یافت.'
                      : '✓ Path for $reqName updated: $selectedPath',
                ),
                backgroundColor: const Color(0xFF10B981),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      } catch (e) {
        if (context.mounted) {
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text('Error updating path: $e'),
              backgroundColor: const Color(0xFFEF4444),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  Future<void> fetchSystemInfo({bool forceRefresh = false}) async {
    if (forceRefresh) {
      isRefreshing.value = true;
    } else {
      isLoading.value = true;
    }
    errorMessage.value = '';

    try {
      final info = await _apiService.fetchSystemInfo(forceRefresh: forceRefresh);
      systemInfo.value = info;
    } catch (e) {
      errorMessage.value = e.toString();
    } finally {
      isLoading.value = false;
      isRefreshing.value = false;
    }
  }

  void copyToClipboard(BuildContext context, String text, String message) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String buildAllSpecsSummary(AppLocalizations l10n, PackagesResponse? packagesRes) {
    final info = systemInfo.value;
    if (info == null) return '';

    final buffer = StringBuffer();
    buffer.writeln('=== ${l10n.appName} ===');
    buffer.writeln('[${l10n.hardware}]');
    buffer.writeln('${l10n.cpu}: ${info.cpu.name}');
    buffer.writeln('${l10n.ram}: ${info.ram.totalDisplay}${info.ram.speedDisplay != 'Not available' ? ' (${info.ram.speedDisplay})' : ''}');

    if (info.gpu.isNotEmpty) {
      final gpuList = info.gpu.map((g) => '${g.name}${g.vramDisplay != 'Not available' ? ' (${g.vramDisplay})' : ''}').join(', ');
      buffer.writeln('${l10n.gpu}: $gpuList');
    } else {
      buffer.writeln('${l10n.gpu}: ${l10n.noGpuDetected}');
    }

    buffer.writeln('${l10n.motherboard}: ${info.motherboard.model != 'Not available' ? info.motherboard.model : info.motherboard.manufacturer}');

    if (info.storage.isNotEmpty) {
      final drives = info.storage.map((d) => '${d.capacityDisplay} ${d.type} (${d.model})').join('\n  - ');
      buffer.writeln('${l10n.storage}:\n  - $drives');
    } else {
      buffer.writeln('${l10n.storage}: ${l10n.noStorageDetected}');
    }

    final winAct = info.windowsActivation.activated ? l10n.activated : l10n.notActivated;
    buffer.writeln('${l10n.windows}: ${info.windows.edition} (${info.windows.architecture}) - ${l10n.activation}: $winAct');

    if (info.officeActivation.installed) {
      final offAct = info.officeActivation.activated ? l10n.activated : l10n.notActivated;
      buffer.writeln('${l10n.microsoftOffice}: ${info.officeActivation.product} (${info.officeActivation.version}) - ${l10n.activation}: $offAct');
    } else {
      buffer.writeln('${l10n.microsoftOffice}: ${l10n.notInstalled}');
    }

    if (info.drivers.isNotEmpty) {
      buffer.writeln('\n[${l10n.drivers}]');
      for (final d in info.drivers) {
        final st = !d.isPresent ? l10n.notPresent : (d.isHealthy ? l10n.driverOk : l10n.driverProblem);
        buffer.writeln('- ${d.displayName} (${d.deviceName}): $st');
      }
    }

    if (packagesRes != null && packagesRes.packages.isNotEmpty) {
      buffer.writeln('\n[${l10n.availableSoftware}]');
      for (final p in packagesRes.packages) {
        final st = p.isInstalled ? '${l10n.installed} (${p.version})' : l10n.notInstalled;
        buffer.writeln('- ${p.name} (${p.filename}): $st');
      }
    } else if (info.software.isNotEmpty) {
      buffer.writeln('\n[${l10n.software}]');
      for (final s in info.software) {
        final statusStr = s.isInstalled ? '${l10n.installed} (${s.version})' : l10n.notInstalled;
        buffer.writeln('- ${s.displayName}: $statusStr');
      }
    }

    if (info.requiredFiles.isNotEmpty) {
      buffer.writeln('\n[${l10n.requiredFiles}]');
      for (final f in info.requiredFiles) {
        final statusStr = f.exists ? l10n.present : l10n.missing;
        buffer.writeln('- ${f.displayName}: $statusStr');
      }
    }

    return buffer.toString();
  }
}
