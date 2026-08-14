import 'app_localizations.dart';

class AppLocalizationsEn implements AppLocalizations {
  @override
  String get appName => 'Central System Checker';

  @override
  String get appSubtitle => 'Hardware & Windows Information';

  @override
  String get liveInspector => 'Live Inspector';

  @override
  String get simpleMode => 'Simple';

  @override
  String get advancedMode => 'Advanced';

  @override
  String get simpleModeTooltip => 'Simple Mode: Fast Invoice Comparison';

  @override
  String get advancedModeTooltip => 'Advanced Mode: Detailed System Specifications';

  @override
  String get languageEn => 'EN';

  @override
  String get languageFa => 'FA';

  @override
  String get refresh => 'Refresh';

  @override
  String get refreshing => 'Refreshing...';

  @override
  String get retryConnection => 'Retry Connection';

  @override
  String get copy => 'Copy';

  @override
  String get copiedToClipboard => 'Copied to clipboard';

  @override
  String get notAvailable => 'Not available';

  @override
  String get switchToLightMode => 'Switch to Light Mode';

  @override
  String get switchToDarkMode => 'Switch to Dark Mode';

  @override
  String get simpleModeHeaderTitle => 'Hardware Specifications for Invoice Check';

  @override
  String get simpleModeHeaderSubtitle => 'Quickly compare actual PC hardware specifications with the purchase invoice';

  @override
  String get invoiceCheckBadge => 'Invoice Check';

  @override
  String get copyAllSpecs => 'Copy Specifications';

  @override
  String get specsCopied => 'All specifications copied to clipboard';

  @override
  String get cpu => 'CPU';

  @override
  String get ram => 'RAM';

  @override
  String get ramMemory => 'RAM (Memory)';

  @override
  String get gpu => 'GPU';

  @override
  String get gpuGraphics => 'GPU (Graphics)';

  @override
  String get motherboard => 'Motherboard';

  @override
  String get storage => 'Storage';

  @override
  String get physicalStorageDevices => 'Physical Storage Devices';

  @override
  String get windows => 'Windows';

  @override
  String get windowsInformation => 'Windows Information';

  @override
  String get bios => 'BIOS';

  @override
  String get biosUefi => 'BIOS / UEFI';

  @override
  String get network => 'Network';

  @override
  String get networkAdapters => 'Network Adapters';

  @override
  String get physicalCores => 'Physical Cores';

  @override
  String get logicalThreads => 'Logical Threads';

  @override
  String get maxClockSpeed => 'Max Clock Speed';

  @override
  String coresThreads(dynamic cores, dynamic threads) {
    if (cores != 'Not available' && threads != 'Not available') {
      return '$cores Cores / $threads Threads';
    } else if (cores != 'Not available') {
      return '$cores Cores';
    } else if (threads != 'Not available') {
      return '$threads Threads';
    }
    return notAvailable;
  }

  @override
  String get totalCapacity => 'Total Capacity';

  @override
  String get installedModules => 'Installed Modules';

  @override
  String get configuration => 'Configuration';

  @override
  String get configuredSpeed => 'Configured Speed';

  @override
  String get moduleDetails => 'Module Details';

  @override
  String get slot => 'Slot';

  @override
  String modulesCount(int count) => '$count ${count == 1 ? 'Module' : 'Modules'}';

  @override
  String get dedicatedVram => 'Dedicated VRAM';

  @override
  String get driverVersion => 'Driver Version';

  @override
  String gpusDetected(int count) => '$count ${count == 1 ? 'GPU Detected' : 'GPUs Detected'}';

  @override
  String get noGpuDetected => 'No graphics card detected';

  @override
  String get dedicatedGraphics => 'Dedicated Graphics';

  @override
  String get modelProduct => 'Model / Product';

  @override
  String get manufacturer => 'Manufacturer';

  @override
  String get serialNumber => 'Serial Number';

  @override
  String get capacity => 'Capacity';

  @override
  String get interfaceBus => 'Interface / Bus';

  @override
  String get healthStatus => 'Health Status';

  @override
  String get healthy => 'Healthy';

  @override
  String drivesCount(int count) => '$count ${count == 1 ? 'Drive' : 'Drives'}';

  @override
  String get noStorageDetected => 'No physical storage devices found';

  @override
  String get osEdition => 'OS Edition';

  @override
  String get version => 'Version';

  @override
  String get buildNumber => 'Build Number';

  @override
  String get architecture => 'Architecture';

  @override
  String get computerName => 'Computer Name';

  @override
  String get systemModel => 'System Model';

  @override
  String get manufacturerVendor => 'Manufacturer / Vendor';

  @override
  String get biosVersion => 'BIOS Version';

  @override
  String get releaseDate => 'Release Date';

  @override
  String get ipv4Address => 'IPv4 Address';

  @override
  String get macAddress => 'MAC Address';

  @override
  String get linkSpeed => 'Link Speed';

  @override
  String get status => 'Status';

  @override
  String get connected => 'Connected';

  @override
  String get disconnected => 'Disconnected';

  @override
  String activeAdaptersCount(int active, int total) => '$active Active / $total Total';

  @override
  String get noNetworkDetected => 'No network adapters detected';

  @override
  String get loadingMessage => 'Detecting hardware & Windows specifications...';

  @override
  String get initializingMessage => 'Initializing system inspector...';

  @override
  String get inspectionFailed => 'System Inspection Failed';

  @override
  String scanCompleted(double durationMs, String hostName) =>
      'Inspection scan completed in ${durationMs.toStringAsFixed(0)} ms • Local Windows Host ($hostName)';
}
