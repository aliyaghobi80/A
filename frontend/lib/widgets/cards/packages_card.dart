import 'dart:convert';
import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../models/system_info.dart';

import 'card_wrapper.dart';

class PackagesCard extends StatelessWidget {
  final List<SoftwarePackage> packages;
  final PackageSummary summary;
  final String packagesDirectory;
  final bool directoryExists;
  final VoidCallback? onScan;
  final VoidCallback? onChangeDirectory;
  final bool isScanning;
  final Function(String packageId, String name)? onInstall;
  final Function(SoftwarePackage pkg)? onInstallSilent;
  final Function(SoftwarePackage pkg)? onOpen;
  final Function(SoftwarePackage pkg)? onUninstall;
  final VoidCallback? onAutoInstallAll;
  final bool isBatchInstalling;
  final BatchInstallStatus? batchStatus;
  final VoidCallback? onCancelBatch;
  final VoidCallback? onOpenOfficeFolder;
  final bool isOfficeInstalled;
  final bool blockOfficeInstall;

  const PackagesCard({
    super.key,
    required this.packages,
    required this.summary,
    this.packagesDirectory = '',
    this.directoryExists = true,
    this.onScan,
    this.onChangeDirectory,
    this.isScanning = false,
    this.onInstall,
    this.onInstallSilent,
    this.onOpen,
    this.onUninstall,
    this.onAutoInstallAll,
    this.isBatchInstalling = false,
    this.batchStatus,
    this.onCancelBatch,
    this.onOpenOfficeFolder,
    this.isOfficeInstalled = false,
    this.blockOfficeInstall = false,
  });

  Widget _buildIcon(SoftwarePackage pkg, bool isDark) {
    if (pkg.iconBase64 != null && pkg.iconBase64!.isNotEmpty) {
      try {
        final raw = pkg.iconBase64!;
        final b64 = (raw.contains(',') ? raw.split(',').last : raw)
            .trim()
            .replaceAll('\n', '')
            .replaceAll('\r', '');
        final bytes = base64Decode(b64);
        return Image.memory(
          bytes,
          width: 24,
          height: 24,
          filterQuality: FilterQuality.high,
          errorBuilder: (context, error, stackTrace) =>
              _fallbackIcon(pkg, isDark),
        );
      } catch (_) {
        return _fallbackIcon(pkg, isDark);
      }
    }
    return _fallbackIcon(pkg, isDark);
  }

  Widget _fallbackIcon(SoftwarePackage pkg, bool isDark) {
    return Icon(
      Icons.apps_rounded,
      size: 20,
      color: !pkg.isValid
          ? const Color(0xFFEF4444)
          : (pkg.isInstalled
                ? const Color(0xFF10B981)
                : const Color(0xFF6366F1)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);
    final availableToInstall = packages
        .where(
          (p) =>
              p.installAllowed &&
              p.autoInstallSupported &&
              p.isValid &&
              !p.isInstalled &&
              !(blockOfficeInstall && p.isMicrosoftOfficePackage),
        )
        .length;

    return CardWrapper(
      icon: Icons.apps_rounded,
      title: l10n.availableSoftware,
      summarySubtitle: summary.blockedPackages > 0
          ? '${summary.installedPackages} ${l10n.installed} • ${summary.blockedPackages} ${l10n.isPersian ? "مسدود" : "blocked"}'
          : '${summary.installedPackages} / ${summary.totalPackages} ${l10n.installed}',
      iconColor: const Color(0xFF6366F1),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onAutoInstallAll != null && availableToInstall > 0) ...[
            ElevatedButton.icon(
              onPressed: (isScanning || isBatchInstalling)
                  ? null
                  : onAutoInstallAll,
              icon: isBatchInstalling
                  ? const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.auto_fix_high_rounded, size: 13),
              label: Text(
                isBatchInstalling
                    ? (l10n.isPersian ? 'در حال نصب...' : 'Installing...')
                    : (l10n.isPersian
                          ? 'نصب خودکار همه ($availableToInstall)'
                          : 'Auto Install ($availableToInstall)'),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                textStyle: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
            const SizedBox(width: 6),
          ],
          if (onChangeDirectory != null) ...[
            OutlinedButton.icon(
              onPressed: (isScanning || isBatchInstalling)
                  ? null
                  : onChangeDirectory,
              icon: const Icon(Icons.folder_open_rounded, size: 14),
              label: Text(l10n.isPersian ? 'پوشه' : 'Folder'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF6366F1),
                side: const BorderSide(color: Color(0xFF6366F1)),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                textStyle: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
            const SizedBox(width: 6),
          ],
          if (onScan != null)
            ElevatedButton.icon(
              onPressed: (isScanning || isBatchInstalling) ? null : onScan,
              icon: isScanning
                  ? const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.refresh_rounded, size: 14),
              label: Text(isScanning ? l10n.scanning : l10n.scan),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                textStyle: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (packagesDirectory.isNotEmpty) ...[
            InkWell(
              onTap: onChangeDirectory,
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF0F172A)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF1E293B)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.folder_rounded,
                      size: 13,
                      color: isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF64748B),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${l10n.scanningDirectory} ',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B),
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
                            color: isDark
                                ? const Color(0xFFCBD5E1)
                                : const Color(0xFF475569),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    if (onChangeDirectory != null) ...[
                      const SizedBox(width: 4),
                      Icon(
                        Icons.edit_outlined,
                        size: 13,
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 14),
          Divider(
            color: isDark ? const Color(0xFF1E2C4A) : const Color(0xFFF1F5F9),
            thickness: 1,
            height: 1,
          ),
          const SizedBox(height: 16),

          // Batch Progress Banner
          if (batchStatus != null &&
              (batchStatus!.isRunning ||
                  (isBatchInstalling && batchStatus!.items.isNotEmpty))) ...[
            _buildBatchProgress(context, isDark, l10n),
            const SizedBox(height: 14),
          ],

          if (!directoryExists)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.folder_off_rounded,
                    color: Color(0xFFF59E0B),
                    size: 20,
                  ),
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
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF64748B),
                  ),
                ),
              ),
            )
          else ...[
            ...packages.map(
              (pkg) => _buildPackageRow(context, pkg, isDark, l10n),
            ),
            if (!isOfficeInstalled &&
                onOpenOfficeFolder != null &&
                packages.isNotEmpty &&
                directoryExists)
              _buildOfficeReminderBanner(context, isDark, l10n),
          ],
        ],
      ),
    );
  }

  Widget _buildOfficeReminderBanner(
    BuildContext context,
    bool isDark,
    AppLocalizations l10n,
  ) {
    if (isOfficeInstalled) {
      return const SizedBox.shrink();
    }
    if (blockOfficeInstall) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark
                    ? const Color(0xFF475569)
                    : const Color(0xFFCBD5E1),
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 620;
                final message = Row(
                  children: [
                    const Icon(
                      Icons.verified_user_rounded,
                      color: Color(0xFF10B981),
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        l10n.isPersian
                            ? 'Windows Home اورجینال شناسایی شد؛ نصب Office در این برنامه لازم نیست.'
                            : 'Original Windows Home detected; Office deployment is disabled by policy.',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                );
                final action = FilledButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.lock_outline_rounded, size: 16),
                  label: Text(
                    l10n.isPersian
                        ? 'نصب آفیس غیرفعال'
                        : 'Office install disabled',
                  ),
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                );
                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      message,
                      const SizedBox(height: 10),
                      Align(alignment: Alignment.centerLeft, child: action),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: message),
                    const SizedBox(width: 12),
                    action,
                  ],
                );
              },
            ),
          ),
        ],
      );
    }
    const officeColor = Color(0xFFEA580C);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: Container(
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFCBD5E1),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.dashboard_customize_rounded,
                    size: 14,
                    color: isDark
                        ? const Color(0xFF64748B)
                        : const Color(0xFF94A3B8),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    l10n.isPersian ? 'بخش اختصاصی آفیس' : 'Office Suite',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? const Color(0xFF64748B)
                          : const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFCBD5E1),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF1E140A).withValues(alpha: 0.75)
                : const Color(0xFFFFF7ED),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: officeColor.withValues(alpha: isDark ? 0.35 : 0.4),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: officeColor.withValues(alpha: isDark ? 0.15 : 0.06),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFEA580C), Color(0xFFC2410C)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Icon(
                    Icons.description_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.isPersian
                          ? 'یادت نره آفیس رو نصب کنی !'
                          : "Don't forget to install Office!",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: isDark
                            ? const Color(0xFFFDBA74)
                            : const Color(0xFFC2410C),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      l10n.isPersian
                          ? 'پوشه Microsoft Office را از روی هارد/فلش باز کنید و مراحل نصب آفیس را انجام دهید.'
                          : 'Open the Microsoft Office folder and complete the setup.',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: onOpenOfficeFolder,
                icon: const Icon(Icons.folder_open_rounded, size: 15),
                label: Text(
                  l10n.isPersian ? 'باز کردن پوشه آفیس' : 'Open Office Folder',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: officeColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPackageRow(
    BuildContext context,
    SoftwarePackage pkg,
    bool isDark,
    AppLocalizations l10n,
  ) {
    final isInstalled = pkg.isInstalled;
    final installAllowed = pkg.installAllowed;
    final officeHomeBlocked =
        blockOfficeInstall && pkg.isMicrosoftOfficePackage && !isInstalled;

    final statusColor = !pkg.isValid
        ? const Color(0xFFEF4444)
        : (isInstalled ? const Color(0xFF10B981) : const Color(0xFF6366F1));
    final statusText = !pkg.isValid
        ? (l10n.isPersian ? 'مسدود' : 'Blocked')
        : (isInstalled ? l10n.installed : l10n.notInstalled);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: !pkg.isValid
              ? const Color(0xFFEF4444).withValues(alpha: 0.5)
              : isInstalled
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
                color: isDark
                    ? const Color(0xFF38BDF8).withValues(alpha: 0.4)
                    : const Color(0xFF64748B),
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
                          color: isDark
                              ? const Color(0xFFF8FAFC)
                              : const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    if (pkg.version.isNotEmpty && pkg.version != 'Unknown') ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          color: (isDark
                              ? const Color(0xFF334155)
                              : const Color(0xFFE2E8F0)),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Directionality(
                          textDirection: TextDirection.ltr,
                          child: Text(
                            l10n.versionBadge(pkg.version),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? const Color(0xFF94A3B8)
                                  : const Color(0xFF475569),
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
                          color: isDark
                              ? const Color(0xFF64748B)
                              : const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                    const SizedBox(width: 6),
                    Text(
                      pkg.packageFormat,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text(
                    pkg.relativePath.isNotEmpty
                        ? pkg.relativePath
                        : pkg.filename,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF64748B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (!pkg.isValid && !pkg.isPortable)
            Tooltip(
              message: pkg.validationError ?? statusText,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.gpp_bad_outlined, size: 14, color: statusColor),
                    const SizedBox(width: 5),
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
            )
          else if (pkg.isPortable)
            ElevatedButton.icon(
              onPressed: onOpen != null ? () => onOpen!(pkg) : null,
              icon: const Icon(Icons.open_in_new_rounded, size: 14),
              label: Text(l10n.isPersian ? 'باز کردن' : 'Open'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0284C7),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                textStyle: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            )
          else if (isInstalled)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
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
                      Icon(
                        Icons.check_circle_rounded,
                        size: 13,
                        color: statusColor,
                      ),
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      textStyle: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ],
                if (onUninstall != null) ...[
                  const SizedBox(width: 6),
                  OutlinedButton.icon(
                    onPressed: () => onUninstall!(pkg),
                    icon: const Icon(Icons.delete_outline_rounded, size: 13),
                    label: Text(l10n.uninstall),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFEF4444),
                      side: BorderSide(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.5),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      textStyle: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ],
              ],
            )
          else if (officeHomeBlocked)
            const FilledButton(
              onPressed: null,
              child: Text('Windows Home اورجینال — نصب لازم نیست'),
            )
          else if (installAllowed)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (onInstallSilent != null && pkg.autoInstallSupported) ...[
                  ElevatedButton.icon(
                    onPressed: isBatchInstalling
                        ? null
                        : () => onInstallSilent!(pkg),
                    icon: const Icon(Icons.auto_fix_high_rounded, size: 13),
                    label: Text(l10n.isPersian ? 'نصب خودکار' : 'Auto Install'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      textStyle: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                if (onInstall != null)
                  OutlinedButton.icon(
                    onPressed: isBatchInstalling
                        ? null
                        : () => onInstall!(
                            pkg.relativePath.isNotEmpty
                                ? pkg.relativePath
                                : pkg.id,
                            pkg.name,
                          ),
                    icon: const Icon(Icons.open_in_new_rounded, size: 12),
                    label: Text(l10n.isPersian ? 'نصب دستی' : 'Manual Install'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF2563EB),
                      side: BorderSide(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.6),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      textStyle: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
              ],
            )
          else
            Text(
              l10n.isPersian ? 'نیازمند بررسی دستی' : 'Manual review',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFFF59E0B),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBatchProgress(
    BuildContext context,
    bool isDark,
    AppLocalizations l10n,
  ) {
    final b = batchStatus!;
    final isRunning = b.isRunning;
    final total = b.total;
    final percent = b.progressPercent;
    final currentItem = b.currentItemName;
    final failed = b.failed;

    Color color = isRunning
        ? const Color(0xFF10B981)
        : (failed == 0 ? const Color(0xFF10B981) : const Color(0xFFF59E0B));

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1E2E) : const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.6 : 0.4),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              isRunning
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF10B981),
                      ),
                    )
                  : Icon(
                      failed == 0
                          ? Icons.check_circle_rounded
                          : Icons.warning_amber_rounded,
                      color: color,
                      size: 18,
                    ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isRunning
                      ? (currentItem != null
                            ? 'نصب خودکار: $currentItem (${b.currentItemIndex + 1} از $total)'
                            : 'در حال نصب خودکار...')
                      : b.summaryMessage,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? const Color(0xFFF1F5F9)
                        : const Color(0xFF0F172A),
                  ),
                ),
              ),
              Text(
                '${percent.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              if (isRunning && onCancelBatch != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  onPressed: onCancelBatch,
                  tooltip: 'لغو',
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: Color(0xFFEF4444),
                  ),
                  style: IconButton.styleFrom(
                    padding: const EdgeInsets.all(4),
                    minimumSize: Size.zero,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: total > 0 ? (percent / 100.0).clamp(0.0, 1.0) : null,
              minHeight: 5,
              backgroundColor: isDark
                  ? const Color(0xFF1E293B)
                  : const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }
}
