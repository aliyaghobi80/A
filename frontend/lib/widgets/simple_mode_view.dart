import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../l10n/app_localizations.dart';
import '../models/system_info.dart';
import '../services/api_service.dart';

class SimpleModeView extends StatefulWidget {
  final SystemInfo info;
  final PackagesResponse? initialPackages;

  const SimpleModeView({
    super.key,
    required this.info,
    this.initialPackages,
  });

  @override
  State<SimpleModeView> createState() => _SimpleModeViewState();
}

class _SimpleModeViewState extends State<SimpleModeView> {
  final ApiService _apiService = ApiService();
  PackagesResponse _packagesResponse = PackagesResponse.empty();
  bool _isScanningPackages = false;
  String? _installingPackageId;

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

  void _copyToClipboard(BuildContext context, String text, String message) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _confirmAndInstall(BuildContext context, SoftwarePackage pkg) async {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF131D33) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.install_desktop_rounded, color: Color(0xFF2563EB), size: 24),
            const SizedBox(width: 10),
            Text(
              l10n.confirmInstallTitle,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        content: Text(
          l10n.confirmInstallMessage(pkg.name),
          style: TextStyle(
            fontSize: 14,
            color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(l10n.install),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() {
        _installingPackageId = pkg.id;
      });

      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('${l10n.installing} ${pkg.name}...'),
          duration: const Duration(seconds: 2),
        ),
      );

      final res = await _apiService.installPackage(pkg.id);
      if (mounted) {
        setState(() {
          _installingPackageId = null;
        });

        final success = res['success'] == true;
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
              res['message'] ?? (success ? l10n.installSuccess(pkg.name) : l10n.installFailed(pkg.name)),
            ),
            backgroundColor: success ? const Color(0xFF10B981) : const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
        _loadPackages();
      }
    }
  }

  String _buildAllSpecsSummary(AppLocalizations l10n, SystemInfo info) {
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

    buffer.writeln('${l10n.windows}: ${info.windows.edition} (${info.windows.architecture})');

    if (info.drivers.isNotEmpty) {
      buffer.writeln('\n[${l10n.drivers}]');
      for (final d in info.drivers) {
        final st = !d.isPresent ? l10n.notPresent : (d.isHealthy ? l10n.driverOk : l10n.driverProblem);
        buffer.writeln('- ${d.displayName} (${d.deviceName}): $st');
      }
    }

    if (info.software.isNotEmpty) {
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

  Widget _buildQuickStatusSummary(BuildContext context, SystemInfo info, AppLocalizations l10n, bool isDark) {
    // Determine overall state
    final isSystemReady = info.driverSummary.allHealthy &&
        info.softwareSummary.allInstalled &&
        info.filesSummary.allPresent;
    final statusColor = isSystemReady ? const Color(0xFF10B981) : const Color(0xFFF59E0B);
    final statusText = isSystemReady ? l10n.ready : l10n.needsAttention;

    final drvHealthy = info.driverSummary.healthyCount;
    final drvTotal = info.driverSummary.totalPresentCount;

    final softInstalled = info.softwareSummary.installedCount;
    final softTotal = info.softwareSummary.totalCount;

    final filesPresent = info.filesSummary.presentCount;
    final filesTotal = info.filesSummary.totalCount;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
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
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 750;

          final statusTile = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: statusColor.withValues(alpha: 0.5),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.systemStatus,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                  Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: statusColor,
                    ),
                  ),
                ],
              ),
            ],
          );

          Widget metricBadge({
            required IconData icon,
            required String label,
            required String countText,
            required Color color,
          }) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: isDark ? 0.15 : 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: color.withValues(alpha: 0.25)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 16, color: color),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                        ),
                      ),
                      Text(
                        countText,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }

          final drvBadge = metricBadge(
            icon: Icons.settings_suggest_rounded,
            label: l10n.drivers,
            countText: l10n.driverSummaryCount(drvHealthy, drvTotal),
            color: info.driverSummary.allHealthy ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
          );

          final softBadge = metricBadge(
            icon: Icons.apps_rounded,
            label: l10n.software,
            countText: l10n.softwareSummaryCount(softInstalled, softTotal),
            color: info.softwareSummary.allInstalled ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
          );

          final filesBadge = metricBadge(
            icon: Icons.folder_special_rounded,
            label: l10n.requiredFiles,
            countText: l10n.filesSummaryCount(filesPresent, filesTotal),
            color: info.filesSummary.allPresent ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
          );

          if (isCompact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                statusTile,
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [drvBadge, softBadge, filesBadge],
                ),
              ],
            );
          }

          return Row(
            children: [
              statusTile,
              const SizedBox(width: 24),
              Container(
                height: 32,
                width: 1,
                color: isDark ? const Color(0xFF22304E) : const Color(0xFFE2E8F0),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  alignment: WrapAlignment.start,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [drvBadge, softBadge, filesBadge],
                ),
              ),
            ],
          );
        },
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
    String? secondaryValue,
    Widget? customContent,
    String? copyValue,
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
              if (copyValue != null && copyValue.isNotEmpty)
                Tooltip(
                  message: l10n.copy,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () => _copyToClipboard(
                      context,
                      copyValue,
                      '${l10n.copiedToClipboard}: $copyValue',
                    ),
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

          // Main Prominent Value (20–24pt font for 5–10s invoice check)
          if (customContent != null)
            customContent
          else ...[
            Directionality(
              textDirection: TextDirection.ltr,
              child: Text(
                primaryValue,
                style: TextStyle(
                  fontSize: 22,
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
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final info = widget.info;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Quick Status Summary Bar (Top)
        _buildQuickStatusSummary(context, info, l10n, isDark),
        const SizedBox(height: 22),

        // 2. Hardware Section Header with 1-click Copy
        _buildSectionHeader(
          context: context,
          icon: Icons.memory_rounded,
          title: l10n.hardware,
          color: const Color(0xFF3B82F6),
          trailing: OutlinedButton.icon(
            onPressed: () => _copyToClipboard(
              context,
              _buildAllSpecsSummary(l10n, info),
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

            final cardCpu = _buildProminentSpecCard(
              context: context,
              stepNumber: 1,
              categoryTitle: l10n.cpu,
              icon: Icons.memory_rounded,
              accentColor: const Color(0xFF3B82F6),
              primaryValue: info.cpu.name,
              secondaryValue: l10n.coresThreads(info.cpu.cores, info.cpu.threads),
              copyValue: info.cpu.name,
            );

            final cardRam = _buildProminentSpecCard(
              context: context,
              stepNumber: 2,
              categoryTitle: l10n.ram,
              icon: Icons.storage_rounded,
              accentColor: const Color(0xFFF59E0B),
              primaryValue: info.ram.totalDisplay,
              secondaryValue: info.ram.moduleSummary != 'Not available'
                  ? '${info.ram.moduleSummary}${info.ram.speedDisplay != 'Not available' ? ' • ${info.ram.speedDisplay}' : ''}'
                  : info.ram.speedDisplay,
              copyValue: info.ram.totalDisplay,
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
              primaryValue: gpuPrimary,
              secondaryValue: gpuSecondary,
              copyValue: gpuPrimary,
            );

            final cardMotherboard = _buildProminentSpecCard(
              context: context,
              stepNumber: 4,
              categoryTitle: l10n.motherboard,
              icon: Icons.developer_board_rounded,
              accentColor: const Color(0xFF10B981),
              primaryValue: info.motherboard.model != 'Not available' ? info.motherboard.model : info.motherboard.manufacturer,
              secondaryValue: info.motherboard.manufacturer,
              copyValue: info.motherboard.model,
            );

            final cardStorage = _buildProminentSpecCard(
              context: context,
              stepNumber: 5,
              categoryTitle: l10n.storage,
              icon: Icons.album_rounded,
              accentColor: const Color(0xFF06B6D4),
              primaryValue: '',
              copyValue: info.storage.map((d) => '${d.capacityDisplay} ${d.type}').join(', '),
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
                          padding: const EdgeInsets.only(bottom: 6.0),
                          child: Row(
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
                                    fontSize: 15,
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
                                      fontSize: 14,
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
                        )),
                ],
              ),
            );

            final cardWindows = _buildProminentSpecCard(
              context: context,
              stepNumber: 6,
              categoryTitle: l10n.windows,
              icon: Icons.window_rounded,
              accentColor: const Color(0xFF0284C7),
              primaryValue: info.windows.edition,
              secondaryValue: '${info.windows.architecture}${info.windows.version != 'Not available' ? ' • ${info.windows.version}' : ''}',
              copyValue: info.windows.edition,
            );

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

        // 4. Required Software Checklist & Packages Section
        _buildSectionHeader(
          context: context,
          icon: Icons.apps_rounded,
          title: l10n.software,
          color: const Color(0xFF6366F1),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton.icon(
                onPressed: _isScanningPackages ? null : _handleScanPackages,
                icon: _isScanningPackages
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.refresh_rounded, size: 15),
                label: Text(
                  _isScanningPackages ? l10n.scanningPackages : l10n.scanPackages,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: (info.softwareSummary.allInstalled ? const Color(0xFF10B981) : const Color(0xFFF59E0B)).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: (info.softwareSummary.allInstalled ? const Color(0xFF10B981) : const Color(0xFFF59E0B)).withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  l10n.softwareSummaryCount(info.softwareSummary.installedCount, info.softwareSummary.totalCount),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: info.softwareSummary.allInstalled ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Software & Packages Container
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Configured Required Software Checklist
              if (info.software.isNotEmpty) ...[
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
              ],

              // Scanned Packages Section (if any packages discovered)
              if (_packagesResponse.packages.isNotEmpty) ...[
                const SizedBox(height: 16),
                Divider(
                  color: isDark ? const Color(0xFF1E2C4A) : const Color(0xFFF1F5F9),
                  thickness: 1,
                  height: 1,
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Icon(Icons.inventory_2_rounded, size: 16, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    const SizedBox(width: 8),
                    Text(
                      l10n.packages,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${_packagesResponse.summary.availableToInstall} ${l10n.availableToInstall}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ..._packagesResponse.packages.map((pkg) => _buildSimplePackageRow(context, pkg, isDark, l10n)),
              ],
            ],
          ),
        ),
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

  Widget _buildSimpleDriverRow(BuildContext context, DriverItem drv, bool isDark, AppLocalizations l10n) {
    final isPresent = drv.isPresent;
    final isHealthy = drv.isHealthy;

    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (!isPresent) {
      statusColor = isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8);
      statusText = l10n.notPresent;
      statusIcon = Icons.remove_rounded;
    } else if (isHealthy) {
      statusColor = const Color(0xFF10B981);
      statusText = l10n.driverOk;
      statusIcon = Icons.check_rounded;
    } else {
      statusColor = const Color(0xFFEF4444);
      statusText = l10n.driverProblem;
      statusIcon = Icons.close_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: (!isPresent)
              ? (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0))
              : isHealthy
                  ? statusColor.withValues(alpha: isDark ? 0.3 : 0.2)
                  : statusColor.withValues(alpha: 0.4),
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
                Text(
                  drv.displayName,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                  ),
                ),
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text(
                    drv.deviceName,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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

  Widget _buildSimplePackageRow(BuildContext context, SoftwarePackage pkg, bool isDark, AppLocalizations l10n) {
    final isInstalled = pkg.isInstalled;
    final installAllowed = pkg.installAllowed;
    final isCurrentInstalling = _installingPackageId == pkg.id;

    final statusColor = isInstalled ? const Color(0xFF10B981) : const Color(0xFF6366F1);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
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
              isInstalled ? Icons.check_circle_rounded : Icons.download_rounded,
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
                Row(
                  children: [
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text(
                        pkg.name,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text(
                        l10n.versionBadge(pkg.version),
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (installAllowed)
            ElevatedButton.icon(
              onPressed: isCurrentInstalling ? null : () => _confirmAndInstall(context, pkg),
              icon: isCurrentInstalling
                  ? const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.install_desktop_rounded, size: 13),
              label: Text(isCurrentInstalling ? l10n.installing : l10n.install),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
            )
          else
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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: exists
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
              exists ? Icons.check_rounded : Icons.close_rounded,
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
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    isFolder ? l10n.folder : l10n.file,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
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
            ),
            child: Text(
              exists ? l10n.present : l10n.missing,
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
}
