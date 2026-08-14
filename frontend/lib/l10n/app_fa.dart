import 'app_localizations.dart';

class AppLocalizationsFa implements AppLocalizations {
  @override
  String get appName => 'مرکزی سیستم چکر';

  @override
  String get appSubtitle => 'بررسی سخت‌افزار، ویندوز و نرم‌افزارهای موردنیاز';

  @override
  String get liveInspector => 'بررسی زنده';

  @override
  String get simpleMode => 'ساده';

  @override
  String get advancedMode => 'پیشرفته';

  @override
  String get simpleModeTooltip => 'حالت ساده: مقایسه سریع با فاکتور و چک‌لیست نرم‌افزارها';

  @override
  String get advancedModeTooltip => 'حالت پیشرفته: مشخصات کامل، جزئیات فنی و وضعیت فایل‌ها';

  @override
  String get languageEn => 'EN';

  @override
  String get languageFa => 'FA';

  @override
  String get refresh => 'به‌روزرسانی';

  @override
  String get refreshing => 'در حال به‌روزرسانی...';

  @override
  String get retryConnection => 'تلاش مجدد ارتباط';

  @override
  String get copy => 'کپی';

  @override
  String get copiedToClipboard => 'در حافظه کپی شد';

  @override
  String get notAvailable => 'موجود نیست';

  @override
  String get switchToLightMode => 'تغییر به تم روشن';

  @override
  String get switchToDarkMode => 'تغییر به تم تاریک';

  @override
  String get hardware => 'سخت‌افزار';

  @override
  String get ready => 'آماده';

  @override
  String get simpleModeHeaderTitle => 'مشخصات فنی و نرم‌افزارهای موردنیاز';

  @override
  String get simpleModeHeaderSubtitle => 'بررسی سریع و آسان مشخصات قطعات با فاکتور خرید و چک‌لیست نصب برنامه‌ها';

  @override
  String get invoiceCheckBadge => 'بررسی فاکتور';

  @override
  String get copyAllSpecs => 'کپی خلاصه مشخصات';

  @override
  String get specsCopied => 'مشخصات با موفقیت کپی شد';

  @override
  String get cpu => 'سی‌پی‌یو';

  @override
  String get ram => 'رم';

  @override
  String get ramMemory => 'رم';

  @override
  String get gpu => 'کارت گرافیک';

  @override
  String get gpuGraphics => 'کارت گرافیک';

  @override
  String get motherboard => 'مادربرد';

  @override
  String get storage => 'حافظه ذخیره‌سازی';

  @override
  String get physicalStorageDevices => 'حافظه ذخیره‌سازی';

  @override
  String get windows => 'ویندوز';

  @override
  String get windowsInformation => 'ویندوز';

  @override
  String get bios => 'BIOS / UEFI';

  @override
  String get biosUefi => 'BIOS / UEFI';

  @override
  String get network => 'شبکه';

  @override
  String get networkAdapters => 'کارت‌های شبکه';

  @override
  String get physicalCores => 'هسته‌های فیزیکی';

  @override
  String get logicalThreads => 'رشته‌های پردازشی';

  @override
  String get maxClockSpeed => 'حداکثر فرکانس';

  @override
  String coresThreads(dynamic cores, dynamic threads) {
    if (cores != 'Not available' && threads != 'Not available') {
      return '$cores هسته / $threads رشته';
    } else if (cores != 'Not available') {
      return '$cores هسته';
    } else if (threads != 'Not available') {
      return '$threads رشته';
    }
    return notAvailable;
  }

  @override
  String get totalCapacity => 'ظرفیت کل';

  @override
  String get installedModules => 'ماژول‌های نصب‌شده';

  @override
  String get configuration => 'ترکیب ماژول‌ها';

  @override
  String get configuredSpeed => 'فرکانس کاری';

  @override
  String get moduleDetails => 'جزئیات ماژول‌ها';

  @override
  String get slot => 'اسلات';

  @override
  String modulesCount(int count) => '$count ماژول';

  @override
  String get dedicatedVram => 'حافظه اختصاصی VRAM';

  @override
  String get driverVersion => 'نسخه درایور';

  @override
  String gpusDetected(int count) => '$count کارت گرافیک';

  @override
  String get noGpuDetected => 'کارت گرافیکی شناسایی نشد';

  @override
  String get dedicatedGraphics => 'گرافیک اختصاصی';

  @override
  String get modelProduct => 'مدل سیستم';

  @override
  String get manufacturer => 'سازنده';

  @override
  String get serialNumber => 'شماره سریال';

  @override
  String get capacity => 'ظرفیت';

  @override
  String get interfaceBus => 'نوع رابط / باس';

  @override
  String get healthStatus => 'وضعیت سلامت';

  @override
  String get healthy => 'سالم';

  @override
  String drivesCount(int count) => '$count درایو';

  @override
  String get noStorageDetected => 'هیچ درایو ذخیره‌سازی شناسایی نشد';

  @override
  String get osEdition => 'ویرایش سیستم‌عامل';

  @override
  String get version => 'نسخه';

  @override
  String get buildNumber => 'شماره ساخت';

  @override
  String get architecture => 'معماری';

  @override
  String get computerName => 'نام کامپیوتر';

  @override
  String get systemModel => 'مدل سیستم';

  @override
  String get manufacturerVendor => 'سازنده';

  @override
  String get biosVersion => 'نسخه بایوس';

  @override
  String get releaseDate => 'تاریخ انتشار';

  @override
  String get ipv4Address => 'آدرس IPv4';

  @override
  String get macAddress => 'آدرس فیزیکی (MAC)';

  @override
  String get linkSpeed => 'سرعت اتصال';

  @override
  String get status => 'وضعیت';

  @override
  String get connected => 'متصل';

  @override
  String get disconnected => 'قطع';

  @override
  String activeAdaptersCount(int active, int total) => '$active فعال از $total';

  @override
  String get noNetworkDetected => 'هیچ کارت شبکه‌ای شناسایی نشد';

  // Phase 2: Software
  @override
  String get software => 'نرم‌افزارها';

  @override
  String get installed => 'نصب شده';

  @override
  String get notInstalled => 'نصب نشده';

  @override
  String get unknown => 'نامشخص';

  @override
  String get detectionSource => 'منبع شناسایی';

  @override
  String get installLocation => 'مسیر نصب';

  @override
  String get softwareStatus => 'وضعیت نرم‌افزارها';

  @override
  String softwareSummaryCount(int installed, int total) => '$installed از $total نصب شده';

  @override
  String get allSoftwareInstalled => 'تمام نرم‌افزارهای موردنیاز نصب شده‌اند';

  @override
  String get someSoftwareMissing => 'برخی نرم‌افزارها نصب نشده‌اند';

  @override
  String get noSoftwareConfigured => 'هیچ نرم‌افزاری پیکربندی نشده است';

  // Phase 2: Files
  @override
  String get requiredFiles => 'فایل‌ها و پوشه‌های موردنیاز';

  @override
  String get present => 'موجود است';

  @override
  String get missing => 'موجود نیست';

  @override
  String get filePath => 'مسیر';

  @override
  String get fileType => 'نوع';

  @override
  String get folder => 'پوشه';

  @override
  String get file => 'فایل';

  @override
  String filesSummaryCount(int present, int total) => '$present از $total موجود است';

  @override
  String get allFilesPresent => 'تمام فایل‌های موردنیاز موجود است';

  @override
  String get someFilesMissing => 'برخی فایل‌های موردنیاز موجود نیست';

  @override
  String get noFilesConfigured => 'هیچ فایلی پیکربندی نشده است';

  @override
  String get loadingMessage => 'در حال شناسایی مشخصات سخت‌افزار، ویندوز و نرم‌افزارها...';

  @override
  String get initializingMessage => 'در حال راه‌اندازی بررسی‌کننده سیستم...';

  @override
  String get inspectionFailed => 'خطا در بررسی مشخصات سیستم';

  @override
  String scanCompleted(double durationMs, String hostName) =>
      'بررسی مشخصات در ${durationMs.toStringAsFixed(0)} میلی‌ثانیه انجام شد • سیستم میزبان ($hostName)';
}
