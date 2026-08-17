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
  bool get isPersian;
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
  String get cancel;

  // Summary & Overview
  String get hardware;
  String get ready;
  String get needsAttention;
  String get checking;
  String get systemStatus;

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

  // Drivers Section
  String get drivers;
  String get driverStatus;
  String get driverOk;
  String get driverProblem;
  String get notPresent;
  String get driverDeviceName;
  String get driverCategory;
  String driverSummaryCount(int healthy, int total);

  // Software Requirements & Discovery
  String get software;
  String get availableSoftware;
  String get scan;
  String get scanning;
  String get scanPackages;
  String get scanningPackages;
  String get packagesDirectory;
  String get softwareDirectoryNotFound;
  String get scanningDirectory;
  String get filename;
  String get publisher;
  String get fileSize;
  String get installed;
  String get notInstalled;
  String get unknown;
  String get detectionSource;
  String get installLocation;
  String get softwareStatus;
  String softwareSummaryCount(int installed, int total);
  String get allSoftwareInstalled;
  String get someSoftwareMissing;
  String get noSoftwareConfigured;
  String get install;
  String get installing;
  String get openApp;
  bool get isRtl;
  String get confirmInstallTitle;
  String confirmInstallMessage(String name);
  String get availableToInstall;
  String get noPackagesFound;
  String installSuccess(String name);
  String installFailed(String name);
  String versionBadge(String ver);

  // File Requirements
  String get requiredFiles;
  String get present;
  String get missing;
  String get filePath;
  String get fileType;
  String get folder;
  String get file;
  String filesSummaryCount(int present, int total);
  String get allFilesPresent;
  String get someFilesMissing;
  String get noFilesConfigured;

  // Loading & Error Views
  String get loadingMessage;
  String get initializingMessage;
  String get inspectionFailed;

  // Phase 3 — Activation Getters
  String get activation;
  String get activated;
  String get notActivated;
  String get windowsActivation;
  String get officeActivation;
  String get activateWindows;
  String get activateOffice;
  String get activationTool;
  String get toolNotFound;
  String get toolAvailable;
  String get activationCompleted;
  String get windowsActivationCompleted;
  String get officeActivationCompleted;
  String get activationFailed;
  String get windowsActivationFailed;
  String get officeActivationFailed;
  String get activationCancelled;
  String get retry;
  String get licenseChannel;
  String get partialProductKey;
  String get licenseExpiration;
  String get permanentLicense;
  String get office;
  String get microsoftOffice;
  String get officeProduct;
  String get officeVersion;
  String get officeArchitecture;
  String get officeInstallType;
  String get confirmActivateWindowsTitle;
  String get confirmActivateWindowsMessage;
  String get confirmActivateOfficeTitle;
  String get confirmActivateOfficeMessage;
  String get runningActivation;
  String get activatingWindows;
  String get activatingOffice;

  // Footer
  String scanCompleted(double durationMs, String hostName);

  // Phase 4 — Full System QC & One-Click Preparation
  String get runFullCheck;
  String get fullSystemCheck;
  String get systemReady;
  String get prepareSystem;
  String get runCheckAgain;
  String get viewProblems;
  String get installSelected;
  String get passed;
  String get failed;
  String get warning;
  String get notPresentState;
  String get problems;
  String get noProblemsFound;
  String get prepareSystemDescription;
  String get confirmPrepareSystemTitle;
  String get confirmPrepareSystemMessage;
  String get selectActionsToExecute;
  String get executeSelectedActions;
  String qcProblemsFound(int count);
  String qcPassedCategoriesCount(int passed, int total);
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
