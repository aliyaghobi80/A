import 'dart:convert';
import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../models/system_info.dart';

class PackagesCard extends StatelessWidget {
  final List<SoftwarePackage> packages;
  final PackageSummary summary;
  final String packagesDirectory;
  final bool directoryExists;
  final VoidCallback? onScan;
  final bool isScanning;
  final Function(String packageId, String name)? onInstall;
  final Function(SoftwarePackage pkg)? onOpen;

  const PackagesCard({
    super.key,
    required this.packages,
    required this.summary,
    this.packagesDirectory = '',
    this.directoryExists = true,
    this.onScan,
    this.isScanning = false,
    this.onInstall,
    this.onOpen,
  });

  Widget _buildIcon(SoftwarePackage pkg, bool isDark) {
    if (pkg.iconBase64 != null && pkg.iconBase64!.isNotEmpty) {
      try {
        final b64 = pkg.iconBase64!.contains(',')
            ? pkg.iconBase64!.split(',').last
            : pkg.iconBase64!;
        final bytes = base64Decode(b64);
        return Image.memory(
          bytes,
          width: 24,
          height: 24,
          filterQuality: FilterQuality.medium,
          errorBuilder: (context, error, stackTrace) => _fallbackIcon(pkg, isDark),
        );
      } catch (_) {
        return _fallbackIcon(pkg, isDark);
      }
    }
    return _fallbackIcon(pkg, isDark);
  }

  Widget _fallbackIcon(SoftwarePackage pkg, bool isDark) {
    return Icon(
      pkg.isInstalled ? Icons.check_circle_rounded : Icons.download_rounded,
      size: 20,
      color: pkg.isInstalled ? const Color(0xFF10B981) : const Color(0xFF6366F1),
    );
  }

  @override
  Widget build(BuildContext context) {
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
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: isDark ? 0.2 : 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.apps_rounded,
                    color: Color(0xFF6366F1),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.availableSoftware,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
                    ),
                  ),
                ),
                if (onScan != null)
                  ElevatedButton.icon(
                    onPressed: isScanning ? null : onScan,
                    icon: isScanning
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.refresh_rounded, size: 16),
                    label: Text(isScanning ? l10n.scanning : l10n.scan),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
              ],
            ),

            if (packagesDirectory.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(
                children: [
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
                        packagesDirectory,
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
                ],
              ),
            ],

            const SizedBox(height: 14),
            Divider(
              color: isDark ? const Color(0xFF1E2C4A) : const Color(0xFFF1F5F9),
              thickness: 1,
              height: 1,
            ),
            const SizedBox(height: 16),

            if (!directoryExists)
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
              )
            else if (packages.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    l10n.noPackagesFound,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                ),
              )
            else
              ...packages.map((pkg) => _buildPackageRow(context, pkg, isDark, l10n)),
          ],
        ),
      ),
    );
  }

  Widget _buildPackageRow(BuildContext context, SoftwarePackage pkg, bool isDark, AppLocalizations l10n) {
    final isInstalled = pkg.isInstalled;
    final installAllowed = pkg.installAllowed;

    final statusColor = isInstalled ? const Color(0xFF10B981) : const Color(0xFF6366F1);
    final statusText = isInstalled ? l10n.installed : l10n.notInstalled;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
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
          Tooltip(
            message: pkg.installPathTooltip,
            waitDuration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
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
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
            child: Container(
              width: 36,
              height: 36,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(child: _buildIcon(pkg, isDark)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                    if (pkg.version.isNotEmpty && pkg.version != 'Unknown') ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Directionality(
                          textDirection: TextDirection.ltr,
                          child: Text(
                            l10n.versionBadge(pkg.version),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                            ),
                          ),
                        ),
                      ),
                    ],
                    if (pkg.fileSizeDisplay.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Text(
                        '(${pkg.fileSizeDisplay})',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text(
                    pkg.relativePath.isNotEmpty ? pkg.relativePath : pkg.filename,
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
          const SizedBox(width: 10),
          if (installAllowed && onInstall != null)
            ElevatedButton.icon(
              onPressed: () => onInstall!(pkg.relativePath.isNotEmpty ? pkg.relativePath : pkg.id, pkg.name),
              icon: const Icon(Icons.install_desktop_rounded, size: 14),
              label: Text(l10n.install),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
            )
          else
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_rounded, size: 13, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onOpen != null) ...[
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () => onOpen!(pkg),
                    icon: const Icon(Icons.open_in_new_rounded, size: 13),
                    label: Text(l10n.openApp),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0284C7),
                      side: const BorderSide(color: Color(0xFF38BDF8)),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }
}
