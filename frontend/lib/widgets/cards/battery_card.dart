import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../models/system_info.dart';
import '../../services/api_service.dart';
import '../common/hardware_illustrations.dart';
import 'card_wrapper.dart';
import 'info_row.dart';

class BatteryCard extends StatefulWidget {
  final BatteryInfo battery;
  final VoidCallback? onRefresh;

  const BatteryCard({
    super.key,
    required this.battery,
    this.onRefresh,
  });

  @override
  State<BatteryCard> createState() => _BatteryCardState();
}

class _BatteryCardState extends State<BatteryCard> {
  final ApiService _apiService = ApiService();
  bool _isTesting = false;
  late BatteryInfo _currentBattery;

  @override
  void initState() {
    super.initState();
    _currentBattery = widget.battery;
  }

  @override
  void didUpdateWidget(covariant BatteryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.battery != widget.battery) {
      _currentBattery = widget.battery;
    }
  }

  Future<void> _runLiveBatteryTest() async {
    setState(() => _isTesting = true);
    final l10n = AppLocalizations.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      final res = await _apiService.testBatteryHealth();
      setState(() {
        _currentBattery = res;
        _isTesting = false;
      });

      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
              _currentBattery.hasBattery
                  ? (l10n.isPersian
                      ? '✓ تست باتری انجام شد: سلامت ${_currentBattery.healthPercent}٪ (${_currentBattery.healthGradeFa})'
                      : '✓ Battery test complete: ${_currentBattery.healthPercent}% Health (${_currentBattery.healthGrade})')
                  : (l10n.isPersian ? 'سیستم رومیزی است (بدون باتری)' : 'Desktop system (No battery)'),
            ),
            backgroundColor: _currentBattery.isHealthy ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      setState(() => _isTesting = false);
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Error testing battery: $e'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);

    final bat = _currentBattery;
    final hasBat = bat.hasBattery;
    final healthPct = bat.healthPercent ?? 100.0;

    Color statusColor;
    String statusLabel;

    if (!hasBat) {
      statusColor = const Color(0xFF0284C7);
      statusLabel = l10n.isPersian ? 'سیستم رومیزی (AC)' : 'Desktop (AC Power)';
    } else if (healthPct >= 80.0) {
      statusColor = const Color(0xFF10B981);
      statusLabel = l10n.isPersian ? '✓ سلامت عالی ($healthPct٪)' : '✓ Excellent ($healthPct%)';
    } else if (healthPct >= 60.0) {
      statusColor = const Color(0xFFF59E0B);
      statusLabel = l10n.isPersian ? '⚠ کارکرده ($healthPct٪)' : '⚠ Moderate ($healthPct%)';
    } else {
      statusColor = const Color(0xFFEF4444);
      statusLabel = l10n.isPersian ? '✕ ضعیف ($healthPct٪)' : '✕ Poor ($healthPct%)';
    }

    return CardWrapper(
      icon: Icons.battery_charging_full_rounded,
      title: l10n.isPersian ? 'سلامت و وضعیت باتری' : 'Battery & Power Status',
      iconColor: statusColor,
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: statusColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: statusColor.withValues(alpha: 0.3)),
        ),
        child: Text(
          statusLabel,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: statusColor,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Visual Hero Banner with Illustration & Health Stats
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              children: [
                HardwareIllustrationBadge(
                  illustration: BatteryIllustration(
                    color: statusColor,
                    healthPercent: hasBat ? healthPct : 100.0,
                    isCharging: bat.isCharging,
                  ),
                  accentColor: statusColor,
                  size: 64,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasBat
                            ? (l10n.isPersian ? 'سلامت باتری: $healthPct٪' : 'Battery Health: $healthPct%')
                            : (l10n.isPersian ? 'سیستم رومیزی (بدون باتری)' : 'Desktop Computer (No Battery)'),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        hasBat
                            ? (l10n.isPersian ? bat.summaryMessageFa : bat.summaryMessage)
                            : (l10n.isPersian ? 'تغذیه مستقیم از برق شهری' : 'Running on direct AC power source'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          if (hasBat) ...[
            InfoRow(
              label: l10n.isPersian ? 'وضعیت سلامت' : 'Health Grade',
              value: l10n.isPersian ? bat.healthGradeFa : bat.healthGrade,
              icon: Icons.health_and_safety_rounded,
            ),
            if (bat.currentChargePercent != null)
              InfoRow(
                label: l10n.isPersian ? 'درصد شارژ فعلی' : 'Current Charge',
                value: '${bat.currentChargePercent}٪',
                icon: Icons.battery_std_rounded,
              ),
            InfoRow(
              label: l10n.isPersian ? 'منبع تغذیه' : 'Power Source',
              value: l10n.isPersian ? bat.powerSourceFa : bat.powerSource,
              icon: Icons.power_rounded,
            ),
            if (bat.designCapacityMwh > 0 && bat.fullChargeCapacityMwh > 0)
              InfoRow(
                label: l10n.isPersian ? 'ظرفیت اولیه / فعلی' : 'Design / Full Capacity',
                value: '${bat.designCapacityMwh} mWh  /  ${bat.fullChargeCapacityMwh} mWh',
                icon: Icons.bolt_rounded,
                isMonospace: true,
              ),
            if (bat.cycleCount != null)
              InfoRow(
                label: l10n.isPersian ? 'تعداد سیکل شارژ' : 'Cycle Count',
                value: '${bat.cycleCount}',
                icon: Icons.repeat_rounded,
              ),
            if (bat.serial != 'Not available' && bat.serial.isNotEmpty)
              InfoRow(
                label: l10n.isPersian ? 'شماره سریال باتری' : 'Battery Serial',
                value: bat.serial,
                icon: Icons.qr_code_2_rounded,
                isMonospace: true,
                copyable: true,
              ),
            if (bat.manufacturer != 'Not available' && bat.manufacturer != 'Unknown')
              InfoRow(
                label: l10n.manufacturer,
                value: bat.manufacturer,
                icon: Icons.business_rounded,
              ),
          ] else ...[
            InfoRow(
              label: l10n.isPersian ? 'نوع دستگاه' : 'Device Type',
              value: l10n.isPersian ? 'کیس / مینی‌پی‌سی / سیستم رومیزی' : 'Desktop / Workstation PC',
              icon: Icons.desktop_windows_rounded,
            ),
            InfoRow(
              label: l10n.isPersian ? 'وضعیت برق' : 'Power Status',
              value: l10n.isPersian ? 'برق مستقیم آداپتور و شبکه شهری' : 'Direct AC Mains Connected',
              icon: Icons.electrical_services_rounded,
            ),
          ],

          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isTesting ? null : _runLiveBatteryTest,
              icon: _isTesting
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF10B981)),
                    )
                  : const Icon(Icons.refresh_rounded, size: 16),
              label: Text(
                _isTesting
                    ? (l10n.isPersian ? 'در حال تست سلامت باتری...' : 'Testing Battery Health...')
                    : (l10n.isPersian ? 'بررسی مجدد سلامت باتری' : 'Test Battery Health Again'),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF10B981),
                side: const BorderSide(color: Color(0xFF10B981)),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
