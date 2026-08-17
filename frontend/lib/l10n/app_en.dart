import 'app_localizations.dart';

class AppLocalizationsEn implements AppLocalizations {
  @override
  bool get isPersian => false;

  @override
  String get appName => 'Central System Checker';

  @override
  String get appSubtitle => 'Automated Hardware, OS, Software & Driver Verification';

  @override
  String get liveInspector => 'LIVE INSPECTOR';

  @override
  String get simpleMode => 'Simple';

  @override
  String get advancedMode => 'Advanced';

  @override
  String get simpleModeTooltip => 'Simple Mode: Fast Invoice Comparison & Checklists';

  @override
  String get advancedModeTooltip => 'Advanced Mode: Complete Diagnostics, Drivers & Software';

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
  String get cancel => 'Cancel';

  @override
  String get hardware => 'Hardware';

  @override
  String get ready => 'Ready';

  @override
  String get needsAttention => 'Needs Attention';

  @override
  String get checking => 'Checking...';

  @override
  String get systemStatus => 'System Status';

  @override
  String get simpleModeHeaderTitle => 'Quick System Verification & Invoice Check';

  @override
  String get simpleModeHeaderSubtitle => 'Compare detected hardware components, drivers, software, and company files with your invoice.';

  @override
  String get invoiceCheckBadge => 'INVOICE CHECK';

  @override
  String get copyAllSpecs => 'Copy Specifications';

  @override
  String get specsCopied => 'Full specifications copied to clipboard';

  @override
  String get cpu => 'CPU';

  @override
  String get ram => 'RAM';

  @override
  String get ramMemory => 'RAM Memory';

  @override
  String get gpu => 'GPU';

  @override
  String get gpuGraphics => 'Graphics Card (GPU)';

  @override
  String get motherboard => 'Motherboard';

  @override
  String get storage => 'Storage';

  @override
  String get physicalStorageDevices => 'Physical Storage Disks';

  @override
  String get windows => 'Windows';

  @override
  String get windowsInformation => 'Windows OS Information';

  @override
  String get bios => 'BIOS / UEFI';

  @override
  String get biosUefi => 'BIOS / UEFI Firmware';

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
  String coresThreads(dynamic cores, dynamic threads) => '$cores Cores / $threads Threads';

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
  String modulesCount(int count) => '$count Module${count == 1 ? '' : 's'}';

  @override
  String get dedicatedVram => 'Dedicated VRAM';

  @override
  String get driverVersion => 'Driver Version';

  @override
  String gpusDetected(int count) => '$count GPU${count == 1 ? '' : 's'} Detected';

  @override
  String get noGpuDetected => 'No GPU detected';

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
  String drivesCount(int count) => '$count Drive${count == 1 ? '' : 's'}';

  @override
  String get noStorageDetected => 'No storage drives detected';

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
  String get manufacturerVendor => 'Vendor';

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

  // Drivers Section
  @override
  String get drivers => 'Drivers';

  @override
  String get driverStatus => 'Important Driver Status';

  @override
  String get driverOk => 'OK';

  @override
  String get driverProblem => 'Driver Problem';

  @override
  String get notPresent => 'Not Present';

  @override
  String get driverDeviceName => 'Device Name';

  @override
  String get driverCategory => 'Category';

  @override
  String driverSummaryCount(int healthy, int total) => '$healthy / $total Important Drivers OK';

  // Software Requirements & Discovery
  @override
  String get software => 'Software';

  @override
  String get availableSoftware => 'Software';

  @override
  String get scan => 'Scan';

  @override
  String get scanning => 'Scanning...';

  @override
  String get scanPackages => 'Scan';

  @override
  String get scanningPackages => 'Scanning...';

  @override
  String get packagesDirectory => 'Packages Directory';

  @override
  String get softwareDirectoryNotFound => 'Software directory not found.';

  @override
  String get scanningDirectory => 'Scanning:';

  @override
  String get filename => 'Filename';

  @override
  String get publisher => 'Publisher';

  @override
  String get fileSize => 'Size';

  @override
  String get installed => 'Installed';

  @override
  String get notInstalled => 'Not Installed';

  @override
  String get unknown => 'Unknown';

  @override
  String get detectionSource => 'Detection Source';

  @override
  String get installLocation => 'Install Location';

  @override
  String get softwareStatus => 'Software Status';

  @override
  String softwareSummaryCount(int installed, int total) => '$installed / $total Installed';

  @override
  String get allSoftwareInstalled => 'All Required Software Installed';

  @override
  String get someSoftwareMissing => 'Some Software Missing';

  @override
  String get noSoftwareConfigured => 'No required software configured.';

  @override
  String get install => 'Install';

  @override
  String get installing => 'Installing...';

  @override
  String get openApp => 'Open';

  @override
  bool get isRtl => false;

  @override
  String get confirmInstallTitle => 'Confirm Software Installation';

  @override
  String confirmInstallMessage(String name) => 'Are you sure you want to install $name?';

  @override
  String get availableToInstall => 'Available to Install';

  @override
  String get noPackagesFound => 'No installers found in directory';

  @override
  String installSuccess(String name) => '$name installed successfully';

  @override
  String installFailed(String name) => 'Failed to install $name';

  @override
  String versionBadge(String ver) => 'v$ver';

  // File Requirements
  @override
  String get requiredFiles => 'Required Files';

  @override
  String get present => 'Present';

  @override
  String get missing => 'Missing';

  @override
  String get filePath => 'Path';

  @override
  String get fileType => 'Type';

  @override
  String get folder => 'Folder';

  @override
  String get file => 'File';

  @override
  String filesSummaryCount(int present, int total) => '$present / $total Present';

  @override
  String get allFilesPresent => 'All Required Files Present';

  @override
  String get someFilesMissing => 'Some Files Missing';

  @override
  String get noFilesConfigured => 'No required files configured.';

  // Loading & Error Views
  @override
  String get loadingMessage => 'Detecting hardware & Windows specifications...';

  @override
  String get initializingMessage => 'Initializing inspection engine...';

  @override
  String get inspectionFailed => 'System Inspection Failed';

  // Phase 3 — Activation Strings
  @override
  String get activation => 'Activation';

  @override
  String get activated => 'Activated';

  @override
  String get notActivated => 'Not Activated';

  @override
  String get windowsActivation => 'Windows Activation';

  @override
  String get officeActivation => 'Office Activation';

  @override
  String get activateWindows => 'Activate Windows';

  @override
  String get activateOffice => 'Activate Office';

  @override
  String get activationTool => 'Activation Tool';

  @override
  String get toolNotFound => 'Activation tool not found.';

  @override
  String get toolAvailable => 'Available';

  @override
  String get activationCompleted => 'Activation Completed';

  @override
  String get windowsActivationCompleted => 'Windows activation completed successfully.';

  @override
  String get officeActivationCompleted => 'Microsoft Office activation completed successfully.';

  @override
  String get activationFailed => 'Activation Failed';

  @override
  String get windowsActivationFailed => 'Windows activation failed';

  @override
  String get officeActivationFailed => 'Microsoft Office activation failed';

  @override
  String get activationCancelled => 'Activation cancelled.';

  @override
  String get retry => 'Retry';

  @override
  String get licenseChannel => 'License Channel';

  @override
  String get partialProductKey => 'Partial Product Key';

  @override
  String get licenseExpiration => 'Expiration';

  @override
  String get permanentLicense => 'Permanent';

  @override
  String get office => 'Office';

  @override
  String get microsoftOffice => 'Microsoft Office';

  @override
  String get officeProduct => 'Product Edition';

  @override
  String get officeVersion => 'Office Version';

  @override
  String get officeArchitecture => 'Architecture';

  @override
  String get officeInstallType => 'Installation Type';

  @override
  String get confirmActivateWindowsTitle => 'Confirm Windows Activation';

  @override
  String get confirmActivateWindowsMessage =>
      'Are you sure you want to run the configured Windows activation tool with Administrator privileges (Run as Administrator)?';

  @override
  String get confirmActivateOfficeTitle => 'Confirm Microsoft Office Activation';

  @override
  String get confirmActivateOfficeMessage =>
      'Are you sure you want to run the configured Microsoft Office activation tool with Administrator privileges (Run as Administrator)?';

  @override
  String get runningActivation => 'Activating...';

  @override
  String get activatingWindows => 'Activating Windows...';

  @override
  String get activatingOffice => 'Activating Microsoft Office...';

  // Footer
  @override
  String scanCompleted(double durationMs, String hostName) =>
      'Scan completed in ${durationMs.toStringAsFixed(1)}ms on $hostName';
}

