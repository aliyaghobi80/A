import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../models/system_info.dart';

class PackagesCard extends StatelessWidget {
  final List<SoftwarePackage> packages;
  final PackageSummary summary;
  final VoidCallback? onScan;
  final bool isScanning;
  final Function(String packageId, String name)? onInstall;

  const PackagesCard({
    super.key,
    required this.packages,
    required this.summary,
    this.onScan,
    this.isScanning = false,
    this.onInstall,
  });

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
                    color: const Color(0xFF8B5CF6).withValues(alpha: isDark ? 0.2 : 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.inventory_2_rounded,
                    color: Color(0xFF8B5CF6),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.packages,
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
                    label: Text(isScanning ? l10n.scanningPackages : l10n.scanPackages),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B5CF6),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Divider(
              color: isDark ? const Color(0xFF1E2C4A) : const Color(0xFFF1F5F9),
              thickness: 1,
              height: 1,
            ),
            const SizedBox(height: 16),

            if (packages.isEmpty)
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
    final isValid = pkg.isValid;
    final installAllowed = pkg.installAllowed;

    Color statusColor;
    String statusText;

    if (!isValid) {
      statusColor = const Color(0xFFF59E0B);
      statusText = l10n.unknown;
    } else if (isInstalled) {
      statusColor = const Color(0xFF10B981);
      statusText = l10n.installed;
    } else {
      statusColor = const Color(0xFF6366F1);
      statusText = l10n.notInstalled;
    }

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
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              isInstalled
                  ? Icons.check_circle_rounded
                  : (isValid ? Icons.download_rounded : Icons.warning_amber_rounded),
              size: 16,
              color: statusColor,
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
                ),
                const SizedBox(height: 2),
                if (!isValid && pkg.validationError != null)
                  Text(
                    pkg.validationError!,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFFF59E0B),
                    ),
                  )
                else
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Text(
                      isInstalled
                          ? '${l10n.version}: ${pkg.installedVersion}'
                          : (pkg.publisher.isNotEmpty ? pkg.publisher : pkg.packageFolder),
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (installAllowed && onInstall != null)
            ElevatedButton.icon(
              onPressed: () => onInstall!(pkg.id, pkg.name),
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
}
