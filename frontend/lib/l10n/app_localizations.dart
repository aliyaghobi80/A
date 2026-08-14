import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'app_en.dart';
import 'app_fa.dart';

abstract class AppLocalizations {
  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  static const List<Locale> supportedLocales = [
    Locale('fa'),
    Locale('en'),
  ];

  static AppLocalizations of(BuildContext context) {
    final localized = Localizations.of<AppLocalizations>(context, AppLocalizations);
    if (localized != null) {
      return localized;
    }
    final locale = Localizations.maybeLocaleOf(context);
    if (locale?.languageCode == 'en') {
      return AppLocalizationsEn();
    }
    return AppLocalizationsFa();
  }

  static AppLocalizations fromLocale(Locale locale) {
    if (locale.languageCode == 'en') {
      return AppLocalizationsEn();
    }
    return AppLocalizationsFa();
  }

  // App Branding
  String get appName;
  String get appSubtitle;
  String get liveInspector;

  // Mode Switcher
  String get simpleMode;
  String get advancedMode;
  String get simpleModeTooltip;
  String get advancedModeTooltip;

  // Language Switcher
  String get languageEn;
  String get languageFa;

  // Common Actions
  String get refresh;
  String get refreshing;
  String get retryConnection;
  String get copy;
  String get copiedToClipboard;
  String get notAvailable;
  String get switchToLightMode;
  String get switchToDarkMode;

  // Simple Mode UI
  String get simpleModeHeaderTitle;
  String get simpleModeHeaderSubtitle;
  String get invoiceCheckBadge;
  String get copyAllSpecs;
  String get specsCopied;

  // Hardware Category Titles
  String get cpu;
  String get ram;
  String get ramMemory;
  String get gpu;
  String get gpuGraphics;
  String get motherboard;
  String get storage;
  String get physicalStorageDevices;
  String get windows;
  String get windowsInformation;
  String get bios;
  String get biosUefi;
  String get network;
  String get networkAdapters;

  // CPU Fields
  String get physicalCores;
  String get logicalThreads;
  String get maxClockSpeed;
  String coresThreads(dynamic cores, dynamic threads);

  // RAM Fields
  String get totalCapacity;
  String get installedModules;
  String get configuration;
  String get configuredSpeed;
  String get moduleDetails;
  String get slot;
  String modulesCount(int count);

  // GPU Fields
  String get dedicatedVram;
  String get driverVersion;
  String gpusDetected(int count);
  String get noGpuDetected;
  String get dedicatedGraphics;

  // Motherboard Fields
  String get modelProduct;
  String get manufacturer;
  String get serialNumber;

  // Storage Fields
  String get capacity;
  String get interfaceBus;
  String get healthStatus;
  String get healthy;
  String drivesCount(int count);
  String get noStorageDetected;

  // Windows Fields
  String get osEdition;
  String get version;
  String get buildNumber;
  String get architecture;
  String get computerName;
  String get systemModel;

  // BIOS Fields
  String get manufacturerVendor;
  String get biosVersion;
  String get releaseDate;

  // Network Fields
  String get ipv4Address;
  String get macAddress;
  String get linkSpeed;
  String get status;
  String get connected;
  String get disconnected;
  String activeAdaptersCount(int active, int total);
  String get noNetworkDetected;

  // Loading & Error Views
  String get loadingMessage;
  String get initializingMessage;
  String get inspectionFailed;

  // Footer
  String scanCompleted(double durationMs, String hostName);
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['fa', 'en'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(AppLocalizations.fromLocale(locale));
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
