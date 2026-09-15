import 'package:flutter/material.dart';
import '../../models/system_info.dart';
import '../../l10n/app_localizations.dart';

class RamSlotSummary extends StatelessWidget {
  final RamInfo ram;
  const RamSlotSummary({super.key, required this.ram});

  @override
  Widget build(BuildContext context) {
    final fa = AppLocalizations.of(context).isPersian;
    final colors = Theme.of(context).colorScheme;
    final empty = ram.slots.where((slot) => slot.occupied == false).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          ram.totalSlots == null
              ? (fa
                    ? 'تعداد کل اسلات‌ها گزارش نشده'
                    : 'Total slot count unavailable')
              : (fa
                    ? '${ram.totalSlots} اسلات رم • ${ram.moduleCount} پُر • $empty خالی'
                    : '${ram.totalSlots} RAM slots • ${ram.moduleCount} occupied • $empty empty'),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ram.slots.map((slot) {
            final index = slot.moduleIndex;
            final module =
                index != null && index >= 0 && index < ram.modules.length
                ? ram.modules[index]
                : null;
            final state =
                module?.capacityDisplay ??
                (slot.occupied == false
                    ? (fa ? 'خالی' : 'Empty')
                    : (fa ? 'نامشخص' : 'Unknown'));
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: colors.outlineVariant),
                borderRadius: BorderRadius.circular(8),
                color: colors.surfaceContainerLow,
              ),
              child: Text(
                '${slot.label} — $state',
                textDirection: TextDirection.ltr,
                style: TextStyle(color: colors.onSurface, fontSize: 12),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 6),
        Text(
          fa
              ? 'نام جایگاه‌ها طبق BIOS؛ ترتیب نمایش، نقشهٔ فیزیکی مادربرد نیست.'
              : 'Firmware labels; display order is not a physical board layout.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        Text(
          fa
              ? 'CL از شماره‌قطعهٔ ماژول؛ CL فعال فعلی از این اطلاعات قابل تشخیص نیست.'
              : 'CL is from the module part number; current active CL is unavailable.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
