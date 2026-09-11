class JalaliDate {
  const JalaliDate(this.year, this.month, this.day);

  final int year;
  final int month;
  final int day;
}

/// Converts a Gregorian date to the Solar Hijri (Jalali) calendar.
JalaliDate gregorianToJalali(DateTime value) {
  final gy = value.year;
  final gm = value.month;
  final gd = value.day;
  final gdm = <int>[0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334];

  var jy = gy <= 1600 ? 0 : 979;
  final adjustedYear = gy <= 1600 ? gy - 621 : gy - 1600;
  final gy2 = gm > 2 ? adjustedYear + 1 : adjustedYear;
  var days =
      365 * adjustedYear +
      ((gy2 + 3) ~/ 4) -
      ((gy2 + 99) ~/ 100) +
      ((gy2 + 399) ~/ 400) -
      80 +
      gd +
      gdm[gm - 1];

  jy += 33 * (days ~/ 12053);
  days %= 12053;
  jy += 4 * (days ~/ 1461);
  days %= 1461;
  if (days > 365) {
    jy += (days - 1) ~/ 365;
    days = (days - 1) % 365;
  }

  final jm = days < 186 ? 1 + (days ~/ 31) : 7 + ((days - 186) ~/ 30);
  final jd = 1 + (days < 186 ? days % 31 : (days - 186) % 30);
  return JalaliDate(jy, jm, jd);
}

const _persianMonths = <String>[
  'فروردین',
  'اردیبهشت',
  'خرداد',
  'تیر',
  'مرداد',
  'شهریور',
  'مهر',
  'آبان',
  'آذر',
  'دی',
  'بهمن',
  'اسفند',
];

const _persianWeekdays = <String>[
  'دوشنبه',
  'سه‌شنبه',
  'چهارشنبه',
  'پنجشنبه',
  'جمعه',
  'شنبه',
  'یکشنبه',
];

String toPersianDigits(Object value) {
  const latin = '0123456789';
  const persian = '۰۱۲۳۴۵۶۷۸۹';
  return value.toString().split('').map((char) {
    final index = latin.indexOf(char);
    return index < 0 ? char : persian[index];
  }).join();
}

String formatPersianDateTime(DateTime value) {
  final local = value.toLocal();
  final jalali = gregorianToJalali(local);
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${_persianWeekdays[local.weekday - 1]}، '
      '${toPersianDigits(jalali.day)} ${_persianMonths[jalali.month - 1]} '
      '${toPersianDigits(jalali.year)} • '
      '${toPersianDigits('$hour:$minute')}';
}

String formatCompactPersianDateTime(DateTime value) {
  final local = value.toLocal();
  final jalali = gregorianToJalali(local);
  final date =
      '${jalali.year.toString().padLeft(4, '0')}/'
      '${jalali.month.toString().padLeft(2, '0')}/'
      '${jalali.day.toString().padLeft(2, '0')}';
  final time =
      '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
  return toPersianDigits('$date • $time');
}
