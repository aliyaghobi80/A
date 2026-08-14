import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../l10n/app_localizations.dart';
import '../models/system_info.dart';

class SimpleModeView extends StatelessWidget {
  final SystemInfo info;

  const SimpleModeView({super.key, required this.info});

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

  String _buildAllSpecsSummary(AppLocalizations l10n) {
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
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
            letterSpacing: -0.2,
          ),
        ),
        const Spacer(),
        ?trailing,
      ],
    );
  }

  Widget _buildInvoiceCard({
    required BuildContext context,
    required int stepNumber,
    required String categoryTitle,
    required IconData icon,
    required Color accentColor,
    required Widget mainContent,
    String? copyValue,
    Widget? secondaryBadge,
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
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header Row: Step number + Category name + Trailing badge + Copy button
            Row(
              children: [
                // Step Indicator Badge
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
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
                    letterSpacing: -0.2,
                  ),
                ),
                const Spacer(),
                if (secondaryBadge != null) ...[
                  secondaryBadge,
                  const SizedBox(width: 8),
                ],
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
            Divider(
              color: isDark ? const Color(0xFF1E2C4A) : const Color(0xFFF1F5F9),
              thickness: 1,
              height: 1,
            ),
            const SizedBox(height: 14),
            mainContent,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top Banner / Instruction Bar for Simple Mode
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [const Color(0xFF162340), const Color(0xFF131D33)]
                  : [const Color(0xFFEFF6FF), const Color(0xFFF8FAFC)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? const Color(0xFF253966) : const Color(0xFFDBEAFE),
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 650;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB).withValues(alpha: isDark ? 0.25 : 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.receipt_long_rounded,
                          size: 24,
                          color: Color(0xFF3B82F6),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 10,
                          runSpacing: 4,
                          children: [
                            Text(
                              l10n.simpleModeHeaderTitle,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                l10n.invoiceCheckBadge,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF3B82F6),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!isNarrow) ...[
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed: () => _copyToClipboard(
                            context,
                            _buildAllSpecsSummary(l10n),
                            l10n.specsCopied,
                          ),
                          icon: const Icon(Icons.copy_all_rounded, size: 16),
                          label: Text(l10n.copyAllSpecs),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF3B82F6),
                            side: BorderSide(
                              color: const Color(0xFF3B82F6).withValues(alpha: isDark ? 0.6 : 0.4),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.simpleModeHeaderSubtitle,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                  if (isNarrow) ...[
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () => _copyToClipboard(
                        context,
                        _buildAllSpecsSummary(l10n),
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
                  ],
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 22),

        // SECTION 1: Hardware Specifications Header
        _buildSectionHeader(
          context: context,
          icon: Icons.memory_rounded,
          title: l10n.hardware,
          color: const Color(0xFF3B82F6),
        ),
        const SizedBox(height: 14),

        // 6 Priority Hardware Cards in 2-Column Responsive Grid
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 850;

            final card1Cpu = _buildInvoiceCard(
              context: context,
              stepNumber: 1,
              categoryTitle: l10n.cpu,
              icon: Icons.memory_rounded,
              accentColor: const Color(0xFF3B82F6),
              copyValue: info.cpu.name,
              secondaryBadge: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  l10n.coresThreads(info.cpu.cores, info.cpu.threads),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8),
                  ),
                ),
              ),
              mainContent: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Text(
                      info.cpu.name,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.business_rounded, size: 14, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                      const SizedBox(width: 6),
                      Text(
                        info.cpu.manufacturer,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                      if (info.cpu.maxClockDisplay != 'Not available') ...[
                        const SizedBox(width: 12),
                        Icon(Icons.speed_rounded, size: 14, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                        const SizedBox(width: 6),
                        Directionality(
                          textDirection: TextDirection.ltr,
                          child: Text(
                            info.cpu.maxClockDisplay,
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
                ],
              ),
            );

            final card2Ram = _buildInvoiceCard(
              context: context,
              stepNumber: 2,
              categoryTitle: l10n.ram,
              icon: Icons.storage_rounded,
              accentColor: const Color(0xFFF59E0B),
              copyValue: info.ram.totalDisplay,
              secondaryBadge: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text(
                    info.ram.speedDisplay != 'Not available' ? info.ram.speedDisplay : l10n.modulesCount(info.ram.moduleCount),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isDark ? const Color(0xFFFCD34D) : const Color(0xFFD97706),
                    ),
                  ),
                ),
              ),
              mainContent: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Text(
                      info.ram.totalDisplay,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: isDark ? const Color(0xFFFCD34D) : const Color(0xFFD97706),
                        letterSpacing: -0.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.splitscreen_rounded, size: 14, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                      const SizedBox(width: 6),
                      Directionality(
                        textDirection: TextDirection.ltr,
                        child: Text(
                          info.ram.moduleSummary != 'Not available'
                              ? info.ram.moduleSummary
                              : l10n.modulesCount(info.ram.moduleCount),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                          ),
                        ),
                      ),
                      if (info.ram.modules.isNotEmpty && info.ram.modules.first.type != 'Not available') ...[
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: (isDark ? const Color(0xFFF59E0B) : const Color(0xFFD97706)).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            info.ram.modules.first.type,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: isDark ? const Color(0xFFFCD34D) : const Color(0xFFD97706),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            );

            final card3Gpu = _buildInvoiceCard(
              context: context,
              stepNumber: 3,
              categoryTitle: l10n.gpu,
              icon: Icons.videogame_asset_rounded,
              accentColor: const Color(0xFF8B5CF6),
              copyValue: info.gpu.isNotEmpty ? info.gpu.first.name : l10n.noGpuDetected,
              secondaryBadge: info.gpu.isNotEmpty && info.gpu.first.vramDisplay != 'Not available'
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Directionality(
                        textDirection: TextDirection.ltr,
                        child: Text(
                          info.gpu.first.vramDisplay,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isDark ? const Color(0xFFDDD6FE) : const Color(0xFF6D28D9),
                          ),
                        ),
                      ),
                    )
                  : null,
              mainContent: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (info.gpu.isEmpty)
                    Text(
                      l10n.noGpuDetected,
                      style: TextStyle(
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                        color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                      ),
                    )
                  else
                    ...info.gpu.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final g = entry.value;
                      return Padding(
                        padding: EdgeInsets.only(top: idx > 0 ? 8 : 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Directionality(
                              textDirection: TextDirection.ltr,
                              child: Text(
                                g.name,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.business_rounded, size: 14, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                                const SizedBox(width: 6),
                                Text(
                                  g.manufacturer,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                  ),
                                ),
                                if (g.vramDisplay != 'Not available') ...[
                                  const SizedBox(width: 10),
                                  Text('•', style: TextStyle(color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1))),
                                  const SizedBox(width: 10),
                                  Directionality(
                                    textDirection: TextDirection.ltr,
                                    child: Text(
                                      '${l10n.dedicatedVram}: ${g.vramDisplay}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? const Color(0xFFC4B5FD) : const Color(0xFF7C3AED),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            );

            final card4Motherboard = _buildInvoiceCard(
              context: context,
              stepNumber: 4,
              categoryTitle: l10n.motherboard,
              icon: Icons.developer_board_rounded,
              accentColor: const Color(0xFF10B981),
              copyValue: info.motherboard.model,
              mainContent: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Text(
                      info.motherboard.model,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.domain_rounded, size: 14, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                      const SizedBox(width: 6),
                      Text(
                        info.motherboard.manufacturer,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );

            final card5Storage = _buildInvoiceCard(
              context: context,
              stepNumber: 5,
              categoryTitle: l10n.storage,
              icon: Icons.album_rounded,
              accentColor: const Color(0xFF06B6D4),
              copyValue: info.storage.map((d) => '${d.capacityDisplay} ${d.type}').join(', '),
              secondaryBadge: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF06B6D4).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  l10n.drivesCount(info.storage.length),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isDark ? const Color(0xFF67E8F9) : const Color(0xFF0E7490),
                  ),
                ),
              ),
              mainContent: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (info.storage.isEmpty)
                    Text(
                      l10n.noStorageDetected,
                      style: TextStyle(
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                        color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                      ),
                    )
                  else
                    ...info.storage.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final drive = entry.value;
                      final isSsd = drive.type.toUpperCase().contains('SSD') || drive.type.toUpperCase().contains('NVME');
                      final badgeColor = isSsd
                          ? (isDark ? const Color(0xFF06B6D4) : const Color(0xFF0891B2))
                          : (isDark ? const Color(0xFFF59E0B) : const Color(0xFFD97706));

                      return Container(
                        margin: EdgeInsets.only(top: idx > 0 ? 8 : 0),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                                color: badgeColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Icon(
                                isSsd ? Icons.speed_rounded : Icons.dns_rounded,
                                size: 16,
                                color: badgeColor,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Directionality(
                                    textDirection: TextDirection.ltr,
                                    child: Text(
                                      '${drive.capacityDisplay} ${drive.type}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Directionality(
                                    textDirection: TextDirection.ltr,
                                    child: Text(
                                      drive.model,
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
                            Directionality(
                              textDirection: TextDirection.ltr,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: badgeColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Text(
                                  drive.capacityDisplay,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: badgeColor,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            );

            final card6Windows = _buildInvoiceCard(
              context: context,
              stepNumber: 6,
              categoryTitle: l10n.windows,
              icon: Icons.window_rounded,
              accentColor: const Color(0xFF0284C7),
              copyValue: '${info.windows.edition} (${info.windows.architecture})',
              secondaryBadge: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text(
                    info.windows.architecture,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFF7DD3FC) : const Color(0xFF0369A1),
                    ),
                  ),
                ),
              ),
              mainContent: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Text(
                      info.windows.edition,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.computer_rounded, size: 14, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                      const SizedBox(width: 6),
                      Directionality(
                        textDirection: TextDirection.ltr,
                        child: Text(
                          info.system.computerName,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                      if (info.windows.version != 'Not available') ...[
                        const SizedBox(width: 10),
                        Text('•', style: TextStyle(color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1))),
                        const SizedBox(width: 10),
                        Directionality(
                          textDirection: TextDirection.ltr,
                          child: Text(
                            '${l10n.version} ${info.windows.version}',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            );

            if (isWide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        card1Cpu,
                        const SizedBox(height: 14),
                        card3Gpu,
                        const SizedBox(height: 14),
                        card5Storage,
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      children: [
                        card2Ram,
                        const SizedBox(height: 14),
                        card4Motherboard,
                        const SizedBox(height: 14),
                        card6Windows,
                      ],
                    ),
                  ),
                ],
              );
            } else {
              return Column(
                children: [
                  card1Cpu,
                  const SizedBox(height: 14),
                  card2Ram,
                  const SizedBox(height: 14),
                  card3Gpu,
                  const SizedBox(height: 14),
                  card4Motherboard,
                  const SizedBox(height: 14),
                  card5Storage,
                  const SizedBox(height: 14),
                  card6Windows,
                ],
              );
            }
          },
        ),
        const SizedBox(height: 28),

        // SECTION 2: Required Software Checklist
        _buildSectionHeader(
          context: context,
          icon: Icons.apps_rounded,
          title: l10n.software,
          color: const Color(0xFF6366F1),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
        ),
        const SizedBox(height: 12),

        // Software Checklist Grid
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
          child: info.software.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      l10n.noSoftwareConfigured,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final isMultiCol = constraints.maxWidth > 600;

                    final items = info.software.map((s) => _buildSoftwareRow(context, s, isDark, l10n)).toList();

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

        // SECTION 3: Required Files & Folders Checklist
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

        // Files Checklist Grid
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
                    child: Text(
                      l10n.noFilesConfigured,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final isMultiCol = constraints.maxWidth > 600;

                    final items = info.requiredFiles.map((f) => _buildFileRow(context, f, isDark, l10n)).toList();

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

  Widget _buildSoftwareRow(BuildContext context, SoftwareItem item, bool isDark, AppLocalizations l10n) {
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

  Widget _buildFileRow(BuildContext context, RequiredFileItem item, bool isDark, AppLocalizations l10n) {
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
