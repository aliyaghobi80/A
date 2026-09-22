import 'package:flutter/material.dart';

class SystemInfo {
  final String status;
  final String timestamp;
  final double scanDurationMs;
  final CpuInfo cpu;
  final MotherboardInfo motherboard;
  final RamInfo ram;
  final List<GpuInfo> gpu;
  final List<StorageInfo> storage;
  final WindowsInfo windows;
  final SystemMetaInfo system;
  final BiosInfo bios;
  final List<NetworkInfo> network;
  final List<DriverItem> drivers;
  final DriverSummary driverSummary;
  final List<SoftwareItem> software;
  final SoftwareSummary softwareSummary;
  final List<RequiredFileItem> requiredFiles;
  final FilesSummary filesSummary;
  final WindowsActivationInfo windowsActivation;
  final OfficeActivationInfo officeActivation;
  final BatteryInfo battery;
  final ProxyInfo proxy;
  final RebootInfo reboot;

  SystemInfo({
    required this.status,
    required this.timestamp,
    required this.scanDurationMs,
    required this.cpu,
    required this.motherboard,
    required this.ram,
    required this.gpu,
    required this.storage,
    required this.windows,
    required this.system,
    required this.bios,
    required this.network,
    this.drivers = const [],
    DriverSummary? driverSummary,
    this.software = const [],
    SoftwareSummary? softwareSummary,
    this.requiredFiles = const [],
    FilesSummary? filesSummary,
    WindowsActivationInfo? windowsActivation,
    OfficeActivationInfo? officeActivation,
    BatteryInfo? battery,
    ProxyInfo? proxy,
    RebootInfo? reboot,
  }) : driverSummary = driverSummary ?? DriverSummary.empty(),
       softwareSummary = softwareSummary ?? SoftwareSummary.empty(),
       filesSummary = filesSummary ?? FilesSummary.empty(),
       windowsActivation = windowsActivation ?? WindowsActivationInfo.empty(),
       officeActivation = officeActivation ?? OfficeActivationInfo.empty(),
       battery = battery ?? BatteryInfo.empty(),
       proxy = proxy ?? ProxyInfo.empty(),
       reboot = reboot ?? RebootInfo.empty();

  factory SystemInfo.fromJson(Map<String, dynamic> json) {
    return SystemInfo(
      status: json['status'] ?? 'unknown',
      timestamp: json['timestamp'] ?? '',
      scanDurationMs: (json['scan_duration_ms'] as num?)?.toDouble() ?? 0.0,
      cpu: CpuInfo.fromJson(json['cpu'] as Map<String, dynamic>? ?? {}),
      motherboard: MotherboardInfo.fromJson(
        json['motherboard'] as Map<String, dynamic>? ?? {},
      ),
      ram: RamInfo.fromJson(json['ram'] as Map<String, dynamic>? ?? {}),
      gpu: (json['gpu'] as List<dynamic>? ?? [])
          .map((e) => GpuInfo.fromJson(e as Map<String, dynamic>))
          .toList(),
      storage: (json['storage'] as List<dynamic>? ?? [])
          .map((e) => StorageInfo.fromJson(e as Map<String, dynamic>))
          .toList(),
      windows: WindowsInfo.fromJson(
        json['windows'] as Map<String, dynamic>? ?? {},
      ),
      system: SystemMetaInfo.fromJson(
        json['system'] as Map<String, dynamic>? ?? {},
      ),
      bios: BiosInfo.fromJson(json['bios'] as Map<String, dynamic>? ?? {}),
      network: (json['network'] as List<dynamic>? ?? [])
          .map((e) => NetworkInfo.fromJson(e as Map<String, dynamic>))
          .toList(),
      drivers: (json['drivers'] as List<dynamic>? ?? [])
          .map((e) => DriverItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      driverSummary: DriverSummary.fromJson(
        json['driver_summary'] as Map<String, dynamic>? ?? {},
      ),
      software: (json['software'] as List<dynamic>? ?? [])
          .map((e) => SoftwareItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      softwareSummary: SoftwareSummary.fromJson(
        json['software_summary'] as Map<String, dynamic>? ?? {},
      ),
      requiredFiles: (json['required_files'] as List<dynamic>? ?? [])
          .map((e) => RequiredFileItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      filesSummary: FilesSummary.fromJson(
        json['files_summary'] as Map<String, dynamic>? ?? {},
      ),
      windowsActivation: WindowsActivationInfo.fromJson(
        json['windows_activation'] as Map<String, dynamic>? ?? {},
      ),
      officeActivation: OfficeActivationInfo.fromJson(
        json['office_activation'] as Map<String, dynamic>? ?? {},
      ),
      battery: BatteryInfo.fromJson(
        json['battery'] as Map<String, dynamic>? ?? {},
      ),
      proxy: ProxyInfo.fromJson(json['proxy'] as Map<String, dynamic>? ?? {}),
      reboot: RebootInfo.fromJson(
        json['reboot'] as Map<String, dynamic>? ?? {},
      ),
    );
  }

  SystemInfo copyWith({
    String? status,
    String? timestamp,
    double? scanDurationMs,
    CpuInfo? cpu,
    MotherboardInfo? motherboard,
    RamInfo? ram,
    List<GpuInfo>? gpu,
    List<StorageInfo>? storage,
    WindowsInfo? windows,
    SystemMetaInfo? system,
    BiosInfo? bios,
    List<NetworkInfo>? network,
    List<DriverItem>? drivers,
    DriverSummary? driverSummary,
    List<SoftwareItem>? software,
    SoftwareSummary? softwareSummary,
    List<RequiredFileItem>? requiredFiles,
    FilesSummary? filesSummary,
    WindowsActivationInfo? windowsActivation,
    OfficeActivationInfo? officeActivation,
    BatteryInfo? battery,
    ProxyInfo? proxy,
    RebootInfo? reboot,
  }) {
    return SystemInfo(
      status: status ?? this.status,
      timestamp: timestamp ?? this.timestamp,
      scanDurationMs: scanDurationMs ?? this.scanDurationMs,
      cpu: cpu ?? this.cpu,
      motherboard: motherboard ?? this.motherboard,
      ram: ram ?? this.ram,
      gpu: gpu ?? this.gpu,
      storage: storage ?? this.storage,
      windows: windows ?? this.windows,
      system: system ?? this.system,
      bios: bios ?? this.bios,
      network: network ?? this.network,
      drivers: drivers ?? this.drivers,
      driverSummary: driverSummary ?? this.driverSummary,
      software: software ?? this.software,
      softwareSummary: softwareSummary ?? this.softwareSummary,
      requiredFiles: requiredFiles ?? this.requiredFiles,
      filesSummary: filesSummary ?? this.filesSummary,
      windowsActivation: windowsActivation ?? this.windowsActivation,
      officeActivation: officeActivation ?? this.officeActivation,
      battery: battery ?? this.battery,
      proxy: proxy ?? this.proxy,
      reboot: reboot ?? this.reboot,
    );
  }
}

class DriverItem {
  final String id;
  final String name;
  final String displayName;
  final String deviceName;
  final String category;
  final String categoryFa;
  final String status;
  final bool isHealthy;
  final bool isPresent;
  final int problemCode;
  final String statusDescription;
  final String statusDescriptionEn;
  final String instanceId;
  final String manufacturer;
  final String pnpClass;
  final DriverRecommendation? recommendation;

  DriverItem({
    required this.id,
    required this.name,
    required this.displayName,
    required this.deviceName,
    required this.category,
    this.categoryFa = 'سیستم',
    required this.status,
    required this.isHealthy,
    required this.isPresent,
    required this.problemCode,
    required this.statusDescription,
    this.statusDescriptionEn = 'Device is working properly',
    required this.instanceId,
    this.manufacturer = 'Unknown',
    this.pnpClass = '',
    this.recommendation,
  });

  factory DriverItem.fromJson(Map<String, dynamic> json) {
    return DriverItem(
      id: json['id'] ?? 'unknown',
      name: json['name'] ?? 'Unknown Driver',
      displayName: json['display_name'] ?? json['name'] ?? 'Unknown Driver',
      deviceName: json['device_name'] ?? 'Device',
      category: json['category'] ?? 'System',
      categoryFa: json['category_fa'] ?? 'سیستم',
      status: json['status'] ?? 'Unknown',
      isHealthy: json['is_healthy'] as bool? ?? false,
      isPresent: json['is_present'] as bool? ?? true,
      problemCode: json['problem_code'] as int? ?? 0,
      statusDescription:
          json['status_description'] ?? 'دستگاه به درستی کار می‌کند',
      statusDescriptionEn:
          json['status_description_en'] ?? 'Device is working properly',
      instanceId: json['instance_id'] ?? 'Not available',
      manufacturer: json['manufacturer'] ?? 'Unknown',
      pnpClass: json['pnp_class'] ?? '',
      recommendation: json['recommendation'] is Map<String, dynamic>
          ? DriverRecommendation.fromJson(
              json['recommendation'] as Map<String, dynamic>,
            )
          : null,
    );
  }
}

class DriverRecommendation {
  final String portalName;
  final String portalNameFa;
  final String portalUrl;
  final String searchQuery;
  final String guideFa;
  final String guideEn;

  DriverRecommendation({
    required this.portalName,
    required this.portalNameFa,
    required this.portalUrl,
    required this.searchQuery,
    required this.guideFa,
    required this.guideEn,
  });

  factory DriverRecommendation.fromJson(Map<String, dynamic> json) {
    return DriverRecommendation(
      portalName: json['portal_name'] ?? '',
      portalNameFa: json['portal_name_fa'] ?? '',
      portalUrl: json['portal_url'] ?? '',
      searchQuery: json['search_query'] ?? '',
      guideFa: json['guide_fa'] ?? '',
      guideEn: json['guide_en'] ?? '',
    );
  }
}

class SystemDriverRecommendations {
  final String brand;
  final String brandFa;
  final String model;
  final String deviceTypeFa;
  final bool isLaptop;
  final String portalName;
  final String portalNameFa;
  final String portalUrl;
  final String mainSearchQuery;
  final int missingCount;
  final bool hasMissing;
  final List<String> installationOrderFa;
  final List<String> installationOrderEn;
  final String techTipsFa;

  SystemDriverRecommendations({
    required this.brand,
    required this.brandFa,
    required this.model,
    required this.deviceTypeFa,
    required this.isLaptop,
    required this.portalName,
    required this.portalNameFa,
    required this.portalUrl,
    required this.mainSearchQuery,
    required this.missingCount,
    required this.hasMissing,
    required this.installationOrderFa,
    required this.installationOrderEn,
    required this.techTipsFa,
  });

  factory SystemDriverRecommendations.fromJson(Map<String, dynamic> json) {
    return SystemDriverRecommendations(
      brand: json['brand'] ?? '',
      brandFa: json['brand_fa'] ?? '',
      model: json['model'] ?? '',
      deviceTypeFa: json['device_type_fa'] ?? '',
      isLaptop: json['is_laptop'] ?? false,
      portalName: json['portal_name'] ?? '',
      portalNameFa: json['portal_name_fa'] ?? '',
      portalUrl: json['portal_url'] ?? '',
      mainSearchQuery: json['main_search_query'] ?? '',
      missingCount: json['missing_count'] as int? ?? 0,
      hasMissing: json['has_missing'] ?? false,
      installationOrderFa:
          (json['installation_order_fa'] as List<dynamic>? ?? [])
              .map((e) => e.toString())
              .toList(),
      installationOrderEn:
          (json['installation_order_en'] as List<dynamic>? ?? [])
              .map((e) => e.toString())
              .toList(),
      techTipsFa: json['tech_tips_fa'] ?? '',
    );
  }

  factory SystemDriverRecommendations.empty() => SystemDriverRecommendations(
    brand: '',
    brandFa: '',
    model: '',
    deviceTypeFa: '',
    isLaptop: false,
    portalName: '',
    portalNameFa: '',
    portalUrl: '',
    mainSearchQuery: '',
    missingCount: 0,
    hasMissing: false,
    installationOrderFa: [],
    installationOrderEn: [],
    techTipsFa: '',
  );
}

class DriverSummary {
  final int healthyCount;
  final int totalPresentCount;
  final int totalScannedCount;
  final int problemCount;
  final int missingCount;
  final bool allHealthy;
  final bool hasMissingDrivers;
  final bool hasProblem;
  final String statusText;
  final List<DriverItem> missingDevices;
  final SystemDriverRecommendations recommendations;

  DriverSummary({
    required this.healthyCount,
    required this.totalPresentCount,
    this.totalScannedCount = 0,
    this.problemCount = 0,
    this.missingCount = 0,
    required this.allHealthy,
    this.hasMissingDrivers = false,
    required this.hasProblem,
    required this.statusText,
    this.missingDevices = const [],
    SystemDriverRecommendations? recommendations,
  }) : recommendations = recommendations ?? SystemDriverRecommendations.empty();

  factory DriverSummary.empty() => DriverSummary(
    healthyCount: 0,
    totalPresentCount: 0,
    totalScannedCount: 0,
    problemCount: 0,
    missingCount: 0,
    allHealthy: false,
    hasMissingDrivers: false,
    hasProblem: false,
    statusText: 'Checking',
    missingDevices: [],
    recommendations: SystemDriverRecommendations.empty(),
  );

  factory DriverSummary.fromJson(Map<String, dynamic> json) {
    return DriverSummary(
      healthyCount: json['healthy_count'] as int? ?? 0,
      totalPresentCount: json['total_present_count'] as int? ?? 0,
      totalScannedCount: json['total_scanned_count'] as int? ?? 0,
      problemCount: json['problem_count'] as int? ?? 0,
      missingCount: json['missing_count'] as int? ?? 0,
      allHealthy: json['all_healthy'] as bool? ?? false,
      hasMissingDrivers: json['has_missing_drivers'] as bool? ?? false,
      hasProblem: json['has_problem'] as bool? ?? false,
      statusText: json['status_text'] ?? 'Checking',
      missingDevices: (json['missing_devices'] as List<dynamic>? ?? [])
          .map((e) => DriverItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      recommendations: json['recommendations'] is Map<String, dynamic>
          ? SystemDriverRecommendations.fromJson(
              json['recommendations'] as Map<String, dynamic>,
            )
          : SystemDriverRecommendations.empty(),
    );
  }
}

class SoftwarePackage {
  final String id;
  final String name;
  final String filename;
  final String relativePath;
  final String fullPath;
  final String version;
  final String publisher;
  final String packageFormat;
  final String installerType;
  final String? detectionId;
  final String? silentArguments;
  final String fileSizeDisplay;
  final bool isValid;
  final String? validationError;
  final String validationCode;
  final String trustLevel;
  final String status;
  final bool isInstalled;
  final String installedVersion;
  final bool installAllowed;
  final bool autoInstallSupported;
  final bool manualInstallSupported;
  final String detectionSource;
  final bool hasIcon;
  final String? iconBase64;
  final String? iconUrl;
  final String? installedExePath;
  final String? installLocation;
  final bool isDuplicate;
  final String? duplicateOf;
  final int duplicateCount;
  final String folderName;
  final bool isPortableTool;
  final bool canOpenTool;
  final bool windowsUpdateBlocked;
  final bool windowsUpdateStateKnown;

  SoftwarePackage({
    required this.id,
    required this.name,
    required this.filename,
    required this.relativePath,
    this.fullPath = '',
    required this.version,
    required this.publisher,
    this.packageFormat = 'EXE',
    this.installerType = 'unknown',
    this.detectionId,
    this.silentArguments,
    this.fileSizeDisplay = '',
    required this.isValid,
    this.validationError,
    this.validationCode = 'ok',
    this.trustLevel = 'unknown',
    required this.status,
    required this.isInstalled,
    required this.installedVersion,
    required this.installAllowed,
    this.autoInstallSupported = false,
    this.manualInstallSupported = true,
    this.detectionSource = 'none',
    required this.hasIcon,
    this.iconBase64,
    this.iconUrl,
    this.installedExePath,
    this.installLocation,
    this.isDuplicate = false,
    this.duplicateOf,
    this.duplicateCount = 0,
    this.folderName = '',
    this.isPortableTool = false,
    this.canOpenTool = false,
    this.windowsUpdateBlocked = false,
    this.windowsUpdateStateKnown = false,
  });

  bool get isPortable => isPortableTool || canOpenTool;

  bool get isWindowsUpdateBlocker {
    final value = '$name $filename $relativePath'.toLowerCase();
    final compact = value.replaceAll(RegExp(r'[^a-z0-9]+'), '');
    return compact.contains('windowsupdateblocker') ||
        RegExp(r'(^|[^a-z])wub(_x64)?\.exe').hasMatch(value);
  }

  bool get isMicrosoftOfficePackage {
    final value = '$id $name $filename $relativePath $installerType'
        .toLowerCase();
    final compact = value.replaceAll(RegExp(r'[^a-z0-9]+'), '');
    return installerType == 'office_cmd' ||
        id == 'office_2024_pro_plus' ||
        compact.contains('microsoftoffice');
  }

  String get installPathTooltip {
    if (isPortable) {
      final exe = (installedExePath != null && installedExePath!.isNotEmpty)
          ? installedExePath!
          : fullPath;
      return 'ابزار پرتابل و آماده اجرا:\n$exe';
    }
    if (isInstalled) {
      if (installedExePath != null && installedExePath!.isNotEmpty) {
        return 'مسیر نصب:\n$installedExePath';
      }
      if (installLocation != null &&
          installLocation!.isNotEmpty &&
          installLocation != 'Not available') {
        return 'مسیر نصب:\n$installLocation';
      }
      return 'نرم‌افزار در رجیستری ویندوز ثبت شده است.';
    } else {
      if (fullPath.isNotEmpty) {
        return 'مسیر فایل نصبی:\n$fullPath';
      }
      return 'نرم‌افزار هنوز روی سیستم نصب نشده است.';
    }
  }

  factory SoftwarePackage.fromJson(Map<String, dynamic> json) {
    return SoftwarePackage(
      id: json['id'] ?? 'unknown',
      name: json['name'] ?? json['display_name'] ?? 'Unknown Software',
      filename: json['filename'] ?? json['installer_file'] ?? '',
      relativePath: json['relative_path'] ?? json['package_folder'] ?? '',
      fullPath: json['full_path'] ?? '',
      version: json['version'] ?? 'Unknown',
      publisher: json['publisher'] ?? '',
      packageFormat: json['package_format'] ?? 'EXE',
      installerType: json['installer_type'] ?? 'unknown',
      detectionId: json['detection_id'],
      silentArguments: json['silent_arguments'],
      fileSizeDisplay: json['file_size_display'] ?? '',
      isValid: json['is_valid'] as bool? ?? true,
      validationError: json['validation_error'],
      validationCode: json['validation_code'] ?? 'ok',
      trustLevel: json['trust_level'] ?? 'unknown',
      status: json['status'] ?? 'Not Installed',
      isInstalled: json['is_installed'] as bool? ?? false,
      installedVersion: json['installed_version'] ?? 'Not available',
      installAllowed: json['install_allowed'] as bool? ?? true,
      autoInstallSupported: json['auto_install_supported'] as bool? ?? false,
      manualInstallSupported: json['manual_install_supported'] as bool? ?? true,
      detectionSource: json['detection_source'] ?? 'none',
      hasIcon: json['has_icon'] as bool? ?? false,
      iconBase64: json['icon_base64'],
      iconUrl: json['icon_url'],
      installedExePath: json['installed_exe_path'],
      installLocation: json['install_location'],
      isDuplicate: json['is_duplicate'] as bool? ?? false,
      duplicateOf: json['duplicate_of'],
      duplicateCount: (json['duplicate_count'] as int?) ?? 0,
      folderName: json['folder_name'] ?? '',
      isPortableTool: json['is_portable_tool'] as bool? ?? false,
      canOpenTool: json['can_open_tool'] as bool? ?? false,
      windowsUpdateBlocked: json['windows_update_blocked'] as bool? ?? false,
      windowsUpdateStateKnown:
          json['windows_update_state_known'] as bool? ?? false,
    );
  }

  SoftwarePackage copyWith({
    String? id,
    String? name,
    String? filename,
    String? relativePath,
    String? fullPath,
    String? version,
    String? publisher,
    String? packageFormat,
    String? installerType,
    String? detectionId,
    String? silentArguments,
    String? fileSizeDisplay,
    bool? isValid,
    String? validationError,
    String? validationCode,
    String? trustLevel,
    String? status,
    bool? isInstalled,
    String? installedVersion,
    bool? installAllowed,
    bool? autoInstallSupported,
    bool? manualInstallSupported,
    String? detectionSource,
    bool? hasIcon,
    String? iconBase64,
    String? iconUrl,
    String? installedExePath,
    String? installLocation,
    bool? isDuplicate,
    String? duplicateOf,
    int? duplicateCount,
    String? folderName,
    bool? isPortableTool,
    bool? canOpenTool,
    bool? windowsUpdateBlocked,
    bool? windowsUpdateStateKnown,
  }) {
    return SoftwarePackage(
      id: id ?? this.id,
      name: name ?? this.name,
      filename: filename ?? this.filename,
      relativePath: relativePath ?? this.relativePath,
      fullPath: fullPath ?? this.fullPath,
      version: version ?? this.version,
      publisher: publisher ?? this.publisher,
      packageFormat: packageFormat ?? this.packageFormat,
      installerType: installerType ?? this.installerType,
      detectionId: detectionId ?? this.detectionId,
      silentArguments: silentArguments ?? this.silentArguments,
      fileSizeDisplay: fileSizeDisplay ?? this.fileSizeDisplay,
      isValid: isValid ?? this.isValid,
      validationError: validationError ?? this.validationError,
      validationCode: validationCode ?? this.validationCode,
      trustLevel: trustLevel ?? this.trustLevel,
      status: status ?? this.status,
      isInstalled: isInstalled ?? this.isInstalled,
      installedVersion: installedVersion ?? this.installedVersion,
      installAllowed: installAllowed ?? this.installAllowed,
      autoInstallSupported: autoInstallSupported ?? this.autoInstallSupported,
      manualInstallSupported:
          manualInstallSupported ?? this.manualInstallSupported,
      detectionSource: detectionSource ?? this.detectionSource,
      hasIcon: hasIcon ?? this.hasIcon,
      iconBase64: iconBase64 ?? this.iconBase64,
      iconUrl: iconUrl ?? this.iconUrl,
      installedExePath: installedExePath ?? this.installedExePath,
      installLocation: installLocation ?? this.installLocation,
      isDuplicate: isDuplicate ?? this.isDuplicate,
      duplicateOf: duplicateOf ?? this.duplicateOf,
      duplicateCount: duplicateCount ?? this.duplicateCount,
      folderName: folderName ?? this.folderName,
      isPortableTool: isPortableTool ?? this.isPortableTool,
      canOpenTool: canOpenTool ?? this.canOpenTool,
      windowsUpdateBlocked: windowsUpdateBlocked ?? this.windowsUpdateBlocked,
      windowsUpdateStateKnown:
          windowsUpdateStateKnown ?? this.windowsUpdateStateKnown,
    );
  }
}

class PackageSummary {
  final int totalPackages;
  final int validPackages;
  final int installedPackages;
  final int availableToInstall;
  final int autoInstallable;
  final int manualOnly;
  final int blockedPackages;
  final int duplicatePackages;

  PackageSummary({
    required this.totalPackages,
    required this.validPackages,
    required this.installedPackages,
    required this.availableToInstall,
    this.autoInstallable = 0,
    this.manualOnly = 0,
    this.blockedPackages = 0,
    this.duplicatePackages = 0,
  });

  factory PackageSummary.empty() => PackageSummary(
    totalPackages: 0,
    validPackages: 0,
    installedPackages: 0,
    availableToInstall: 0,
    autoInstallable: 0,
    manualOnly: 0,
    blockedPackages: 0,
    duplicatePackages: 0,
  );

  factory PackageSummary.fromJson(Map<String, dynamic> json) {
    return PackageSummary(
      totalPackages: json['total_packages'] as int? ?? 0,
      validPackages: json['valid_packages'] as int? ?? 0,
      installedPackages: json['installed_packages'] as int? ?? 0,
      availableToInstall: json['available_to_install'] as int? ?? 0,
      autoInstallable: json['auto_installable'] as int? ?? 0,
      manualOnly: json['manual_only'] as int? ?? 0,
      blockedPackages: json['blocked_packages'] as int? ?? 0,
      duplicatePackages: json['duplicate_packages'] as int? ?? 0,
    );
  }
}

class PackagesResponse {
  final bool directoryExists;
  final String packagesDirectory;
  final List<SoftwarePackage> packages;
  final PackageSummary summary;

  PackagesResponse({
    this.directoryExists = true,
    required this.packagesDirectory,
    required this.packages,
    required this.summary,
  });

  factory PackagesResponse.empty() => PackagesResponse(
    directoryExists: true,
    packagesDirectory: '',
    packages: [],
    summary: PackageSummary.empty(),
  );

  factory PackagesResponse.fromJson(Map<String, dynamic> json) {
    return PackagesResponse(
      directoryExists: json['directory_exists'] as bool? ?? true,
      packagesDirectory: json['packages_directory'] ?? '',
      packages: (json['packages'] as List<dynamic>? ?? [])
          .map((e) => SoftwarePackage.fromJson(e as Map<String, dynamic>))
          .toList(),
      summary: PackageSummary.fromJson(
        json['summary'] as Map<String, dynamic>? ?? {},
      ),
    );
  }

  PackagesResponse copyWith({
    bool? directoryExists,
    String? packagesDirectory,
    List<SoftwarePackage>? packages,
    PackageSummary? summary,
  }) {
    return PackagesResponse(
      directoryExists: directoryExists ?? this.directoryExists,
      packagesDirectory: packagesDirectory ?? this.packagesDirectory,
      packages: packages ?? this.packages,
      summary: summary ?? this.summary,
    );
  }
}

class SoftwareItem {
  final String id;
  final String name;
  final String displayName;
  final String status;
  final bool isInstalled;
  final String version;
  final String productName;
  final String detectionSource;
  final String installLocation;
  final bool required;

  SoftwareItem({
    required this.id,
    required this.name,
    required this.displayName,
    required this.status,
    required this.isInstalled,
    required this.version,
    required this.productName,
    required this.detectionSource,
    required this.installLocation,
    required this.required,
  });

  factory SoftwareItem.fromJson(Map<String, dynamic> json) {
    return SoftwareItem(
      id: json['id'] ?? 'unknown',
      name: json['name'] ?? 'Unknown Software',
      displayName: json['display_name'] ?? json['name'] ?? 'Unknown Software',
      status: json['status'] ?? 'Not Installed',
      isInstalled:
          json['is_installed'] as bool? ?? (json['status'] == 'Installed'),
      version: json['version'] ?? 'Not available',
      productName: json['product_name'] ?? json['display_name'] ?? 'Unknown',
      detectionSource: json['detection_source'] ?? 'None',
      installLocation: json['install_location'] ?? 'Not available',
      required: json['required'] as bool? ?? true,
    );
  }
}

class SoftwareSummary {
  final int installedCount;
  final int totalCount;
  final bool allInstalled;

  SoftwareSummary({
    required this.installedCount,
    required this.totalCount,
    required this.allInstalled,
  });

  factory SoftwareSummary.empty() =>
      SoftwareSummary(installedCount: 0, totalCount: 0, allInstalled: false);

  factory SoftwareSummary.fromJson(Map<String, dynamic> json) {
    return SoftwareSummary(
      installedCount: json['installed_count'] as int? ?? 0,
      totalCount: json['total_count'] as int? ?? 0,
      allInstalled: json['all_installed'] as bool? ?? false,
    );
  }
}

class RequiredFileItem {
  final String id;
  final String name;
  final String displayName;
  final String path;
  final String type;
  final String status;
  final bool exists;
  final bool required;
  final String? errorMessage;

  RequiredFileItem({
    required this.id,
    required this.name,
    required this.displayName,
    required this.path,
    required this.type,
    required this.status,
    required this.exists,
    required this.required,
    this.errorMessage,
  });

  factory RequiredFileItem.fromJson(Map<String, dynamic> json) {
    return RequiredFileItem(
      id: json['id'] ?? 'unknown',
      name: json['name'] ?? 'Unknown File',
      displayName: json['display_name'] ?? json['name'] ?? 'Unknown File',
      path: json['path'] ?? '',
      type: json['type'] ?? 'folder',
      status:
          json['status'] ?? (json['exists'] == true ? 'Present' : 'Missing'),
      exists: json['exists'] as bool? ?? false,
      required: json['required'] as bool? ?? true,
      errorMessage: json['error_message'],
    );
  }
}

class FilesSummary {
  final int presentCount;
  final int totalCount;
  final bool allPresent;

  FilesSummary({
    required this.presentCount,
    required this.totalCount,
    required this.allPresent,
  });

  factory FilesSummary.empty() =>
      FilesSummary(presentCount: 0, totalCount: 0, allPresent: false);

  factory FilesSummary.fromJson(Map<String, dynamic> json) {
    return FilesSummary(
      presentCount: json['present_count'] as int? ?? 0,
      totalCount: json['total_count'] as int? ?? 0,
      allPresent: json['all_present'] as bool? ?? false,
    );
  }
}

class CpuInfo {
  final String name;
  final String manufacturer;
  final dynamic cores;
  final dynamic threads;
  final int? maxClockMhz;
  final String maxClockDisplay;
  final String serial;

  CpuInfo({
    required this.name,
    required this.manufacturer,
    required this.cores,
    required this.threads,
    this.maxClockMhz,
    required this.maxClockDisplay,
    this.serial = 'Not available',
  });

  factory CpuInfo.fromJson(Map<String, dynamic> json) {
    return CpuInfo(
      name: json['name'] ?? 'Not available',
      manufacturer: json['manufacturer'] ?? 'Not available',
      cores: json['cores'] ?? 'Not available',
      threads: json['threads'] ?? 'Not available',
      maxClockMhz: json['max_clock_mhz'] as int?,
      maxClockDisplay: json['max_clock_display'] ?? 'Not available',
      serial: json['serial'] ?? 'Not available',
    );
  }

  String get coresThreadsDisplay {
    if (cores != 'Not available' && threads != 'Not available') {
      return '$cores Cores / $threads Threads';
    } else if (cores != 'Not available') {
      return '$cores Cores';
    } else if (threads != 'Not available') {
      return '$threads Threads';
    }
    return 'Not available';
  }
}

class MotherboardInfo {
  final String manufacturer;
  final String model;
  final String serial;
  final String uuid;
  final String version;
  final String brand;
  final String brandFa;
  final String cleanModel;
  final String chipset;
  final String formFactor;
  final String displayName;

  MotherboardInfo({
    required this.manufacturer,
    required this.model,
    required this.serial,
    this.uuid = '-',
    this.version = '-',
    this.brand = '',
    this.brandFa = '',
    this.cleanModel = '',
    this.chipset = '',
    this.formFactor = '',
    this.displayName = '',
  });

  factory MotherboardInfo.fromJson(Map<String, dynamic> json) {
    return MotherboardInfo(
      manufacturer: json['manufacturer'] ?? 'Not available',
      model: json['model'] ?? 'Not available',
      serial: json['serial'] ?? '-',
      uuid: json['uuid'] ?? '-',
      version: json['version'] ?? '-',
      brand: json['brand'] ?? '',
      brandFa: json['brand_fa'] ?? '',
      cleanModel: json['clean_model'] ?? '',
      chipset: json['chipset'] ?? '',
      formFactor: json['form_factor'] ?? '',
      displayName: json['display_name'] ?? '',
    );
  }

  String get effectiveBrand {
    if (brand.isNotEmpty && brand != 'Unknown' && brand != 'Not available') {
      return brand;
    }
    final combined = '$manufacturer $model'.toLowerCase();
    if (combined.contains('asustek') ||
        combined.contains('asus') ||
        combined.contains('rog') ||
        combined.contains('tuf')) {
      return 'ASUS';
    }
    if (combined.contains('gigabyte') ||
        combined.contains('giga-byte') ||
        combined.contains('aorus')) {
      return 'GIGABYTE';
    }
    if (combined.contains('micro-star') || combined.contains('msi')) {
      return 'MSI';
    }
    if (combined.contains('asrock')) return 'ASRock';
    if (combined.contains('biostar')) return 'BIOSTAR';
    if (combined.contains('colorful')) return 'Colorful';
    if (combined.contains('maxsun')) return 'MAXSUN';
    if (combined.contains('nzxt')) return 'NZXT';
    if (combined.contains('evga')) return 'EVGA';
    if (combined.contains('dell') || combined.contains('alienware')) {
      return 'Dell';
    }
    if (combined.contains('lenovo') ||
        combined.contains('thinkcentre') ||
        combined.contains('legion')) {
      return 'Lenovo';
    }
    if (combined.contains('hp') ||
        combined.contains('hewlett-packard') ||
        combined.contains('omen')) {
      return 'HP';
    }
    if (combined.contains('acer') || combined.contains('predator')) {
      return 'Acer';
    }
    if (combined.contains('machinist')) return 'Machinist';
    if (combined.contains('huananzhi')) return 'Huananzhi';
    if (combined.contains('jingsha')) return 'JingSha';
    if (manufacturer.isNotEmpty && manufacturer != 'Not available') {
      return manufacturer
          .replaceAll(
            RegExp(
              r'(?:,\s*)?(?:Co\.|Ltd\.|Inc\.|Corp\.|Corporation)\b',
              caseSensitive: false,
            ),
            '',
          )
          .trim();
    }
    return 'Standard';
  }

  String get effectiveBrandFa {
    if (brandFa.isNotEmpty && brandFa != 'نامشخص') return brandFa;
    final b = effectiveBrand.toUpperCase();
    if (b.contains('ASUS')) return 'ایسوس';
    if (b.contains('GIGABYTE') || b.contains('AORUS')) return 'گیگابایت';
    if (b.contains('MSI')) return 'ام‌اس‌آی';
    if (b.contains('ASROCK')) return 'ازراک';
    if (b.contains('BIOSTAR')) return 'بایواستار';
    if (b.contains('COLORFUL')) return 'کالرفول';
    if (b.contains('MAXSUN')) return 'مکس‌سان';
    if (b.contains('NZXT')) return 'ان‌زد‌اکس‌تی';
    if (b.contains('EVGA')) return 'ای‌وی‌جی‌ای';
    if (b.contains('DELL')) return 'دل';
    if (b.contains('LENOVO')) return 'لنوو';
    if (b.contains('HP')) return 'اچ‌پی';
    if (b.contains('ACER')) return 'ایسر';
    if (b.contains('MACHINIST')) return 'ماکینیست';
    if (b.contains('HUANANZHI')) return 'هوانانژی';
    return effectiveBrand;
  }

  Color get brandColor {
    final b = effectiveBrand.toUpperCase();
    if (b.contains('ASUS')) return const Color(0xFF0072C6);
    if (b.contains('GIGABYTE') || b.contains('AORUS')) {
      return const Color(0xFFF97316);
    }
    if (b.contains('MSI')) return const Color(0xFFEF4444);
    if (b.contains('ASROCK')) return const Color(0xFF0EA5E9);
    if (b.contains('BIOSTAR')) return const Color(0xFFF5A623);
    if (b.contains('COLORFUL')) return const Color(0xFFE11D48);
    if (b.contains('MAXSUN')) return const Color(0xFFD97706);
    if (b.contains('NZXT')) return const Color(0xFF8B5CF6);
    if (b.contains('DELL')) return const Color(0xFF0284C7);
    if (b.contains('HP')) return const Color(0xFF0096D6);
    if (b.contains('LENOVO')) return const Color(0xFF2563EB);
    return const Color(0xFF7C3AED);
  }

  IconData get brandIcon {
    final b = effectiveBrand.toUpperCase();
    if (b.contains('ASUS')) return Icons.shield_rounded;
    if (b.contains('GIGABYTE') || b.contains('AORUS')) {
      return Icons.flash_on_rounded;
    }
    if (b.contains('MSI')) return Icons.sports_esports_rounded;
    if (b.contains('ASROCK')) return Icons.auto_awesome_rounded;
    if (b.contains('BIOSTAR')) return Icons.star_rounded;
    if (b.contains('DELL') || b.contains('HP') || b.contains('LENOVO')) {
      return Icons.business_rounded;
    }
    return Icons.developer_board_rounded;
  }

  String get effectiveCleanModel {
    var res = cleanModel.isNotEmpty && cleanModel != 'Not available'
        ? cleanModel
        : model;
    final b = effectiveBrand;
    res = res.replaceAll(
      RegExp('^${RegExp.escape(b)}\\s+', caseSensitive: false),
      '',
    );
    res = res.replaceAll(
      RegExp('^${RegExp.escape(manufacturer)}\\s+', caseSensitive: false),
      '',
    );
    res = res.replaceAll(
      RegExp('\\s+${RegExp.escape(manufacturer)}\$', caseSensitive: false),
      '',
    );
    res = res.replaceAll(
      RegExp(
        r'\s+(?:Gigabyte|ASUS|ASUSTeK|MSI|Micro-Star|ASRock|Biostar|Colorful|Dell|HP|Lenovo)(?:\s+Technology|\s+Co\.|\s+Ltd\.|\s+INC\.)*$',
        caseSensitive: false,
      ),
      '',
    );
    return res.trim().isNotEmpty ? res.trim() : model;
  }

  String get fullDisplayName {
    if (displayName.isNotEmpty && displayName != 'Not available') {
      final hasSuffix = RegExp(
        r'\s+(?:Gigabyte|ASUS|ASUSTeK|MSI|Micro-Star|ASRock|Biostar|Colorful|Dell|HP|Lenovo)(?:\s+Technology|\s+Co\.|\s+Ltd\.|\s+INC\.)*$',
        caseSensitive: false,
      ).hasMatch(displayName);
      if (!hasSuffix) return displayName;
    }
    final b = effectiveBrand;
    final m = effectiveCleanModel;
    if (m.toLowerCase().startsWith(b.toLowerCase())) return m;
    if (b == 'Standard') return m;
    return '$b $m';
  }

  String get effectiveChipset {
    if (chipset.isNotEmpty && chipset != 'Not available') return chipset;
    final text = '$model $manufacturer'.toUpperCase();
    final intelMatch = RegExp(
      r'\b(Z890|B860|H810|Z790|B760|H770|H710|Z690|B660|H670|H610|Z590|B560|H570|H510|Z490|B460|H470|H410|W480|Z390|Z370|B365|B360|H370|H310|Z270|B250|H270|Z170|B150|H170|H110|Z97|H97|Z87|H87|B85|H81|Z77|H77|B75|Z68|H67|H61|X79|X99|X299)(?=[MIA\s\-_]|$)',
      caseSensitive: false,
    ).firstMatch(text);
    if (intelMatch != null) return 'Intel ${intelMatch.group(1)}';

    final amdMatch = RegExp(
      r'\b(X870E|X870|B850|B840|X670E|X670|B650E|B650|A620|X570S|X570|B550|A520|X470|B450|X370|B350|A320|WRX90|TRX50|WRX80|TRX40|X399)(?=[MIA\s\-_]|$)',
      caseSensitive: false,
    ).firstMatch(text);
    if (amdMatch != null) return 'AMD ${amdMatch.group(1)}';

    return '';
  }

  String get effectiveFormFactor {
    if (formFactor.isNotEmpty && formFactor != 'Not available') {
      return formFactor;
    }
    final text = model.toUpperCase();
    if (text.contains('MINI-ITX') ||
        RegExp(
          r'\b[A-Z0-9]+-ITX\b|\b[A-Z0-9]+-I\b|\b[A-Z0-9]{3,}I\b(?<!WIFI)',
        ).hasMatch(text)) {
      return 'Mini-ITX';
    }
    if (text.contains('MICRO-ATX') ||
        text.contains('MATX') ||
        RegExp(r'\b[A-Z0-9]+M\b').hasMatch(text)) {
      return 'Micro-ATX';
    }
    if (text.contains('E-ATX') || text.contains('EXTENDED-ATX')) return 'E-ATX';
    return 'ATX';
  }
}

class RamInfo {
  final List<RamSlot> slots;
  final double totalGb;
  final String totalDisplay;
  final int moduleCount;
  final String moduleSummary;
  final dynamic speedMhz;
  final String speedDisplay;
  final int? totalSlots;
  final List<RamModule> modules;

  RamInfo({
    this.slots = const [],
    required this.totalGb,
    required this.totalDisplay,
    required this.moduleCount,
    required this.moduleSummary,
    required this.speedMhz,
    required this.speedDisplay,
    this.totalSlots,
    required this.modules,
  });

  factory RamInfo.fromJson(Map<String, dynamic> json) {
    return RamInfo(
      slots: (json['slots'] as List<dynamic>? ?? [])
          .map((e) => RamSlot.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalGb: (json['total_gb'] as num?)?.toDouble() ?? 0.0,
      totalDisplay: json['total_display'] ?? 'Not available',
      moduleCount: json['module_count'] as int? ?? 0,
      moduleSummary: json['module_summary'] ?? 'Not available',
      speedMhz: json['speed_mhz'] ?? 'Not available',
      speedDisplay: json['speed_display'] ?? 'Not available',
      totalSlots: json['total_slots'] as int?,
      modules: (json['modules'] as List<dynamic>? ?? [])
          .map((e) => RamModule.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class RamSlot {
  final String label;
  final bool? occupied;
  final int? moduleIndex;
  const RamSlot({required this.label, this.occupied, this.moduleIndex});
  factory RamSlot.fromJson(Map<String, dynamic> json) => RamSlot(
    label: json['slot'] ?? 'Unknown',
    occupied: json['occupied'] as bool?,
    moduleIndex: json['module_index'] as int?,
  );
}

class RamModule {
  final int? ratedCl;
  final String formFactor;
  String get clDisplay =>
      ratedCl == null ? 'CL: نامشخص / Unknown' : 'CL$ratedCl (Part Number)';
  final String slot;
  final String deviceLocator;
  final String bankLabel;
  final String slotDetails;
  final String slotConfidence;
  final double capacityGb;
  final String capacityDisplay;
  final int? speedMhz;
  final String speedDisplay;
  final String type;
  final String manufacturer;
  final String partNumber;
  final String serial;

  RamModule({
    this.ratedCl,
    this.formFactor = 'Not available',
    required this.slot,
    this.deviceLocator = 'Not available',
    this.bankLabel = 'Not available',
    this.slotDetails = '',
    this.slotConfidence = 'unknown',
    required this.capacityGb,
    required this.capacityDisplay,
    this.speedMhz,
    required this.speedDisplay,
    required this.type,
    required this.manufacturer,
    required this.partNumber,
    this.serial = '-',
  });

  factory RamModule.fromJson(Map<String, dynamic> json) {
    return RamModule(
      ratedCl: json['rated_cl'] as int?,
      formFactor: json['form_factor'] ?? 'Not available',
      slot: json['slot'] ?? 'Slot',
      deviceLocator: json['device_locator'] ?? 'Not available',
      bankLabel: json['bank_label'] ?? 'Not available',
      slotDetails: json['slot_details'] ?? '',
      slotConfidence: json['slot_confidence'] ?? 'unknown',
      capacityGb: (json['capacity_gb'] as num?)?.toDouble() ?? 0.0,
      capacityDisplay: json['capacity_display'] ?? 'Not available',
      speedMhz: json['speed_mhz'] as int?,
      speedDisplay: json['speed_display'] ?? 'Not available',
      type: json['type'] ?? 'RAM',
      manufacturer: json['manufacturer'] ?? 'Not available',
      partNumber: json['part_number'] ?? '-',
      serial: json['serial'] ?? '-',
    );
  }
}

class GpuInfo {
  final String name;
  final String rawName;
  final String manufacturer;
  final int? vramBytes;
  final double? vramGb;
  final String vramDisplay;
  final String driverVersion;
  final String pnpDeviceId;
  final bool driverMissing;
  final String driverState;
  final String gpuType;
  final bool isDiscrete;
  final bool isIntegrated;
  final bool needsDriver;

  GpuInfo({
    required this.name,
    this.rawName = '',
    required this.manufacturer,
    this.vramBytes,
    this.vramGb,
    required this.vramDisplay,
    required this.driverVersion,
    this.pnpDeviceId = '',
    this.driverMissing = false,
    this.driverState = 'installed',
    this.gpuType = 'unknown',
    this.isDiscrete = false,
    this.isIntegrated = false,
    this.needsDriver = false,
  });

  factory GpuInfo.fromJson(Map<String, dynamic> json) {
    final manufacturer = json['manufacturer'] ?? 'Not available';
    final name = json['name'] ?? 'Not available';
    final rawName = json['raw_name'] ?? json['name'] ?? '';
    final isDisc = json['is_discrete'] == true ||
        (json['gpu_type'] == 'discrete') ||
        manufacturer.toString().toUpperCase().contains('NVIDIA') ||
        name.toString().toUpperCase().contains('GEFORCE') ||
        name.toString().toUpperCase().contains('RTX ') ||
        name.toString().toUpperCase().contains('GTX ');
    final isInteg = json['is_integrated'] == true ||
        (json['gpu_type'] == 'integrated') ||
        (!isDisc &&
            (manufacturer.toString().toUpperCase().contains('INTEL') ||
                name.toString().toUpperCase().contains('UHD') ||
                name.toString().toUpperCase().contains('IRIS') ||
                name.toString().toUpperCase().contains('RADEON(TM) GRAPHICS')));

    final missing = json['driver_missing'] == true ||
        json['needs_driver'] == true ||
        name.toString().toLowerCase().contains('microsoft basic display adapter') ||
        name.toString().toLowerCase().contains('driver not installed') ||
        name.toString().toLowerCase().contains('کارت گرافیک پایه مایکروسافت') ||
        name.toString().toLowerCase().contains('نیاز به نصب درایور');

    return GpuInfo(
      name: name,
      rawName: rawName,
      manufacturer: manufacturer,
      vramBytes: json['vram_bytes'] as int?,
      vramGb: (json['vram_gb'] as num?)?.toDouble(),
      vramDisplay: json['vram_display'] ?? 'Not available',
      driverVersion: json['driver_version'] ?? 'Not available',
      pnpDeviceId: json['pnp_device_id'] ?? '',
      driverMissing: missing,
      driverState: json['driver_state'] ?? (missing ? 'basic_display_driver' : 'installed'),
      gpuType: json['gpu_type'] ?? (isDisc ? 'discrete' : (isInteg ? 'integrated' : 'unknown')),
      isDiscrete: isDisc,
      isIntegrated: isInteg,
      needsDriver: missing,
    );
  }

  bool get isMicrosoftBasicDisplayAdapter {
    final value = '$name $rawName'.toLowerCase();
    return driverMissing ||
        needsDriver ||
        value.contains('microsoft basic display adapter') ||
        value.contains('کارت گرافیک پایه مایکروسافت') ||
        value.contains('driver not installed') ||
        value.contains('نیاز به نصب درایور');
  }

  String get typeLabelFa =>
      isDiscrete ? 'کارت گرافیک مجزا' : (isIntegrated ? 'گرافیک پردازنده' : 'کارت گرافیک');
}

class StorageInfo {
  final String model;
  final String rawModel;
  final String typeDescription;
  final String partNumber;
  final String type;
  final String busType;
  final int? capacityBytes;
  final double? capacityGb;
  final String capacityDisplay;
  final String serial;
  final String healthStatus;
  final int? healthPercent;
  final String healthType; // 'REAL' | 'ESTIMATED' | 'UNKNOWN'
  final String
  healthGrade; // 'EXCELLENT' | 'GOOD' | 'WARNING' | 'CRITICAL' | 'UNKNOWN'
  final String healthGradeFa;
  final String healthSource;
  final String source;
  final int? wearPercent;
  final int? temperatureC;
  final int? powerOnHours;
  final int? powerCycles;
  final int? unsafeShutdowns;
  final int? mediaErrors;
  final int? availableSparePercent;
  final int? reallocatedSectors;
  final int? pendingSectors;
  final int? uncorrectableSectors;
  final String smartStatus;
  final String diagnosticError;

  StorageInfo({
    required this.model,
    this.rawModel = '',
    this.typeDescription = 'Storage',
    this.partNumber = '-',
    required this.type,
    required this.busType,
    this.capacityBytes,
    this.capacityGb,
    required this.capacityDisplay,
    required this.serial,
    required this.healthStatus,
    this.healthPercent,
    this.healthType = 'UNKNOWN',
    this.healthGrade = 'UNKNOWN',
    this.healthGradeFa = 'نامشخص',
    this.healthSource = 'Unknown',
    this.source = 'Unknown',
    this.wearPercent,
    this.temperatureC,
    this.powerOnHours,
    this.powerCycles,
    this.unsafeShutdowns,
    this.mediaErrors,
    this.availableSparePercent,
    this.reallocatedSectors,
    this.pendingSectors,
    this.uncorrectableSectors,
    this.smartStatus = 'UNKNOWN',
    this.diagnosticError = '',
  });

  factory StorageInfo.fromJson(Map<String, dynamic> json) {
    return StorageInfo(
      model: json['model'] ?? 'Not available',
      rawModel: json['raw_model'] ?? json['model'] ?? 'Not available',
      typeDescription: json['type_description'] ?? json['type'] ?? 'Storage',
      partNumber: json['part_number'] ?? '-',
      type: json['type'] ?? 'Storage',
      busType: json['bus_type'] ?? 'Not available',
      capacityBytes: json['capacity_bytes'] as int?,
      capacityGb: (json['capacity_gb'] as num?)?.toDouble(),
      capacityDisplay: json['capacity_display'] ?? 'Not available',
      serial: json['serial'] ?? '-',
      healthStatus: json['health_status'] ?? 'Healthy',
      healthPercent: json['health_percent'] as int?,
      healthType: json['health_type'] ?? 'UNKNOWN',
      healthGrade: json['health_grade'] ?? 'UNKNOWN',
      healthGradeFa: json['health_grade_fa'] ?? 'نامشخص',
      healthSource: json['health_source'] ?? json['source'] ?? 'Unknown',
      source: json['source'] ?? json['health_source'] ?? 'Unknown',
      wearPercent: json['wear_percent'] as int?,
      temperatureC: json['temperature_c'] as int?,
      powerOnHours: json['power_on_hours'] as int?,
      powerCycles: json['power_cycles'] as int?,
      unsafeShutdowns: json['unsafe_shutdowns'] as int?,
      mediaErrors: json['media_errors'] as int?,
      availableSparePercent: json['available_spare_percent'] as int?,
      reallocatedSectors: json['reallocated_sectors'] as int?,
      pendingSectors: json['pending_sectors'] as int?,
      uncorrectableSectors: json['uncorrectable_sectors'] as int?,
      smartStatus: json['smart_status'] ?? 'UNKNOWN',
      diagnosticError: json['diagnostic_error'] ?? '',
    );
  }
}

class WindowsInfo {
  final String edition;
  final String version;
  final String build;
  final String architecture;

  WindowsInfo({
    required this.edition,
    required this.version,
    required this.build,
    required this.architecture,
  });

  factory WindowsInfo.fromJson(Map<String, dynamic> json) {
    return WindowsInfo(
      edition: json['edition'] ?? 'Not available',
      version: json['version'] ?? 'Not available',
      build: json['build'] ?? 'Not available',
      architecture: json['architecture'] ?? 'Not available',
    );
  }

  bool get isHomeEdition {
    final value = edition.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ');
    return value.contains('windows 10 home') ||
        value.contains('windows 11 home') ||
        RegExp(
          r'\b(core|core single language|home single language)\b',
        ).hasMatch(value);
  }
}

class SystemMetaInfo {
  final String computerName;
  final String manufacturer;
  final String model;
  final String serial;
  final String uuid;
  final String sku;
  final String assetTag;
  final String chassisType;

  SystemMetaInfo({
    required this.computerName,
    required this.manufacturer,
    required this.model,
    this.serial = 'Not available',
    this.uuid = 'Not available',
    this.sku = 'Not available',
    this.assetTag = 'Not available',
    this.chassisType = 'Unknown',
  });

  factory SystemMetaInfo.fromJson(Map<String, dynamic> json) {
    return SystemMetaInfo(
      computerName: json['computer_name'] ?? 'Not available',
      manufacturer: json['manufacturer'] ?? 'Not available',
      model: json['model'] ?? 'Not available',
      serial: json['serial'] ?? 'Not available',
      uuid: json['uuid'] ?? 'Not available',
      sku: json['sku'] ?? 'Not available',
      assetTag: json['asset_tag'] ?? 'Not available',
      chassisType: json['chassis_type'] ?? 'Unknown',
    );
  }
}

class BiosInfo {
  final String manufacturer;
  final String version;
  final String date;
  final String serial;

  BiosInfo({
    required this.manufacturer,
    required this.version,
    required this.date,
    this.serial = 'Not available',
  });

  factory BiosInfo.fromJson(Map<String, dynamic> json) {
    return BiosInfo(
      manufacturer: json['manufacturer'] ?? 'Not available',
      version: json['version'] ?? 'Not available',
      date: json['date'] ?? 'Not available',
      serial: json['serial'] ?? 'Not available',
    );
  }
}

class NetworkInfo {
  final String name;
  final String description;
  final String macAddress;
  final String ipv4Address;
  final String status;
  final String linkSpeed;
  final bool isConnected;

  NetworkInfo({
    required this.name,
    required this.description,
    required this.macAddress,
    required this.ipv4Address,
    required this.status,
    required this.linkSpeed,
    required this.isConnected,
  });

  factory NetworkInfo.fromJson(Map<String, dynamic> json) {
    return NetworkInfo(
      name: json['name'] ?? 'Not available',
      description: json['description'] ?? 'Not available',
      macAddress: json['mac_address'] ?? 'Not available',
      ipv4Address: json['ipv4_address'] ?? 'Not available',
      status: json['status'] ?? 'Disconnected',
      linkSpeed: json['link_speed'] ?? 'Not available',
      isConnected: json['is_connected'] as bool? ?? false,
    );
  }
}

class WindowsActivationInfo {
  final bool installed;
  final bool activated;
  final int statusCode;
  final String statusText;
  final String channel;
  final String partialKey;
  final String edition;
  final String description;
  final String? expiration;
  final bool isPermanent;
  final bool toolAvailable;
  final String? toolPath;
  final bool isGenuine;
  final String genuineType;
  final bool oa3xKeyPresent;
  final bool needsActivation;
  final String activationSummaryFa;
  final String badgeLabel;

  WindowsActivationInfo({
    required this.installed,
    required this.activated,
    required this.statusCode,
    required this.statusText,
    required this.channel,
    required this.partialKey,
    required this.edition,
    required this.description,
    this.expiration,
    required this.isPermanent,
    required this.toolAvailable,
    this.toolPath,
    this.isGenuine = false,
    this.genuineType = '',
    this.oa3xKeyPresent = false,
    this.needsActivation = false,
    this.activationSummaryFa = '',
    this.badgeLabel = '',
  });

  factory WindowsActivationInfo.empty() => WindowsActivationInfo(
    installed: true,
    activated: false,
    statusCode: 0,
    statusText: 'Not available',
    channel: 'Not available',
    partialKey: 'Not available',
    edition: 'Windows',
    description: 'Not available',
    expiration: null,
    isPermanent: true,
    toolAvailable: false,
    toolPath: null,
    isGenuine: false,
    genuineType: '',
    oa3xKeyPresent: false,
    needsActivation: true,
    activationSummaryFa: '',
    badgeLabel: '',
  );

  factory WindowsActivationInfo.fromJson(Map<String, dynamic> json) {
    final act = json['activated'] as bool? ?? false;
    final perm = json['is_permanent'] as bool? ?? (json['expiration'] == null);
    final isGen = json['is_genuine'] as bool? ?? false;
    final ed = (json['edition'] as String? ?? 'Windows').toLowerCase();
    final ch = (json['channel'] as String? ?? '').toLowerCase();
    final desc = (json['description'] as String? ?? '').toLowerCase();
    final isHome =
        ed.contains('home') ||
        ed.contains('core') ||
        ed.contains('singlelanguage');
    final isOem = ch.contains('oem') || desc.contains('oem');
    final isRetail = ch.contains('retail') || desc.contains('retail');

    final computedGenuine =
        isGen || (act && perm && (isHome || isOem || isRetail));

    return WindowsActivationInfo(
      installed: json['installed'] as bool? ?? true,
      activated: act,
      statusCode: json['status_code'] as int? ?? (act ? 1 : 0),
      statusText: json['status_text'] ?? (act ? 'Licensed' : 'Not Activated'),
      channel: json['channel'] ?? 'Not available',
      partialKey: json['partial_key'] ?? 'Not available',
      edition: json['edition'] ?? 'Windows',
      description: json['description'] ?? 'Not available',
      expiration: json['expiration'] as String?,
      isPermanent: perm,
      toolAvailable: json['tool_available'] as bool? ?? false,
      toolPath: json['tool_path'] as String?,
      isGenuine: computedGenuine,
      genuineType:
          json['genuine_type'] as String? ??
          (computedGenuine ? 'OEM / Digital License' : ''),
      oa3xKeyPresent: json['oa3x_key_present'] as bool? ?? false,
      needsActivation: json['needs_activation'] as bool? ?? (!act || !perm),
      activationSummaryFa: json['activation_summary_fa'] as String? ?? '',
      badgeLabel: json['badge_label'] as String? ?? '',
    );
  }

  bool get isGenuineOriginal {
    if (isGenuine) return true;
    final ed = edition.toLowerCase();
    final ch = channel.toLowerCase();
    final desc = description.toLowerCase();
    final isHome =
        ed.contains('home') ||
        ed.contains('core') ||
        ed.contains('singlelanguage');
    final isOem = ch.contains('oem') || desc.contains('oem');
    final isRetail = ch.contains('retail') || desc.contains('retail');
    return activated &&
        isPermanent &&
        (isHome || isOem || isRetail || oa3xKeyPresent);
  }

  String get effectiveActivationSummaryFa {
    if (activationSummaryFa.isNotEmpty) return activationSummaryFa;
    if (isGenuineOriginal) {
      return 'ویندوز اورجینال است و نیازی به فعال‌سازی ندارد.';
    }
    if (activated) return 'ویندوز با موفقیت فعال است.';
    return 'ویندوز فعال نیست و نیاز به فعال‌سازی دارد.';
  }

  String get effectiveBadgeLabel {
    if (badgeLabel.isNotEmpty) return badgeLabel;
    if (isGenuineOriginal) return 'ویندوز اورجینال';
    if (activated) return 'فعال شده';
    return 'غیرفعال';
  }
}

class OfficeActivationInfo {
  final bool installed;
  final String product;
  final String version;
  final String architecture;
  final String installType;
  final bool activated;
  final int statusCode;
  final String statusText;
  final String channel;
  final String partialKey;
  final String? expiration;
  final bool toolAvailable;
  final String? toolPath;
  final bool isGenuine;
  final String genuineType;
  final bool needsActivation;
  final String activationSummaryFa;
  final String badgeLabel;

  OfficeActivationInfo({
    required this.installed,
    required this.product,
    required this.version,
    required this.architecture,
    required this.installType,
    required this.activated,
    required this.statusCode,
    required this.statusText,
    required this.channel,
    required this.partialKey,
    this.expiration,
    required this.toolAvailable,
    this.toolPath,
    this.isGenuine = false,
    this.genuineType = '',
    this.needsActivation = false,
    this.activationSummaryFa = '',
    this.badgeLabel = '',
  });

  factory OfficeActivationInfo.empty() => OfficeActivationInfo(
    installed: false,
    product: 'Not installed',
    version: 'Not available',
    architecture: 'Not available',
    installType: 'Unknown',
    activated: false,
    statusCode: 0,
    statusText: 'Not installed',
    channel: 'Not available',
    partialKey: 'Not available',
    expiration: null,
    toolAvailable: false,
    toolPath: null,
    isGenuine: false,
    genuineType: '',
    needsActivation: false,
    activationSummaryFa: '',
    badgeLabel: '',
  );

  factory OfficeActivationInfo.fromJson(Map<String, dynamic> json) {
    final isInst = json['installed'] as bool? ?? false;
    final isAct = json['activated'] as bool? ?? false;
    final isGen = json['is_genuine'] as bool? ?? false;
    final pr = (json['product'] as String? ?? '').toLowerCase();
    final ch = (json['channel'] as String? ?? '').toLowerCase();
    final isSub =
        pr.contains('365') || ch.contains('365') || pr.contains('subscription');
    final isRetail =
        ch.contains('retail') ||
        pr.contains('retail') ||
        pr.contains('home & student') ||
        pr.contains('home & business');
    final computedGen = isGen || (isAct && (isSub || isRetail));

    return OfficeActivationInfo(
      installed: isInst,
      product:
          json['product'] ?? (isInst ? 'Microsoft Office' : 'Not installed'),
      version: json['version'] ?? 'Not available',
      architecture: json['architecture'] ?? 'Not available',
      installType: json['install_type'] ?? 'Unknown',
      activated: isAct,
      statusCode: json['status_code'] as int? ?? 0,
      statusText:
          json['status_text'] ??
          (!isInst ? 'Not installed' : (isAct ? 'Licensed' : 'Not Activated')),
      channel: json['channel'] ?? 'Not available',
      partialKey: json['partial_key'] ?? 'Not available',
      expiration: json['expiration'] as String?,
      toolAvailable: json['tool_available'] as bool? ?? false,
      toolPath: json['tool_path'] as String?,
      isGenuine: computedGen,
      genuineType:
          json['genuine_type'] as String? ??
          (computedGen ? 'Retail / Subscription' : ''),
      needsActivation: json['needs_activation'] as bool? ?? (isInst && !isAct),
      activationSummaryFa: json['activation_summary_fa'] as String? ?? '',
      badgeLabel: json['badge_label'] as String? ?? '',
    );
  }

  bool get isGenuineOriginal {
    if (isGenuine) return true;
    final pr = product.toLowerCase();
    final ch = channel.toLowerCase();
    final isSub =
        pr.contains('365') || ch.contains('365') || pr.contains('subscription');
    final isRetail =
        ch.contains('retail') ||
        pr.contains('retail') ||
        pr.contains('home & student') ||
        pr.contains('home & business');
    return activated && (isSub || isRetail);
  }

  String get effectiveActivationSummaryFa {
    if (activationSummaryFa.isNotEmpty) return activationSummaryFa;
    if (!installed) return 'مایکروسافت آفیس روی سیستم نصب نیست.';
    if (isGenuineOriginal) {
      return 'لایسنس آفیس اورجینال است و نیازی به فعال‌سازی ندارد.';
    }
    if (activated) return 'مایکروسافت آفیس با موفقیت فعال است.';
    return 'آفیس فعال نیست و نیاز به فعال‌سازی دارد.';
  }

  String get effectiveBadgeLabel {
    if (badgeLabel.isNotEmpty) return badgeLabel;
    if (!installed) return 'نصب نیست';
    if (isGenuineOriginal) return 'آفیس اورجینال';
    if (activated) return 'فعال شده';
    return 'غیرفعال';
  }
}

class ActivationResult {
  final bool success;
  final bool cancelled;
  final int exitCode;
  final String output;
  final String error;
  final String message;

  ActivationResult({
    required this.success,
    required this.cancelled,
    required this.exitCode,
    required this.output,
    required this.error,
    required this.message,
  });

  factory ActivationResult.fromJson(Map<String, dynamic> json) {
    return ActivationResult(
      success: json['success'] as bool? ?? false,
      cancelled: json['cancelled'] as bool? ?? false,
      exitCode: json['exit_code'] as int? ?? (json['success'] == true ? 0 : -1),
      output: json['output'] ?? '',
      error: json['error'] ?? '',
      message: json['message'] ?? '',
    );
  }

  factory ActivationResult.error(String msg) => ActivationResult(
    success: false,
    cancelled: false,
    exitCode: -1,
    output: '',
    error: msg,
    message: msg,
  );
}

class BatteryInfo {
  final bool hasBattery;
  final bool isDesktop;
  final double? healthPercent;
  final String healthGrade;
  final String healthGradeFa;
  final int designCapacityMwh;
  final int fullChargeCapacityMwh;
  final int? currentChargePercent;
  final bool isCharging;
  final bool acConnected;
  final String powerSource;
  final String powerSourceFa;
  final int? psuWattage;
  final String psuDisplay;
  final bool psuDetected;
  final int? cycleCount;
  final String name;
  final String manufacturer;
  final String serial;
  final String chemistry;
  final bool isHealthy;
  final String summaryMessage;
  final String summaryMessageFa;

  BatteryInfo({
    required this.hasBattery,
    this.isDesktop = false,
    this.healthPercent,
    this.healthGrade = 'Not Applicable',
    this.healthGradeFa = 'بدون باتری (سیستم رومیزی)',
    this.designCapacityMwh = 0,
    this.fullChargeCapacityMwh = 0,
    this.currentChargePercent,
    this.isCharging = false,
    this.acConnected = true,
    this.powerSource = 'AC Power',
    this.powerSourceFa = 'برق مستقیم',
    this.psuWattage,
    this.psuDisplay = 'PSU: Not Detected',
    this.psuDetected = false,
    this.cycleCount,
    this.name = 'Desktop (No Battery)',
    this.manufacturer = 'Not available',
    this.serial = 'Not available',
    this.chemistry = 'N/A',
    this.isHealthy = true,
    this.summaryMessage = '',
    this.summaryMessageFa = '',
  });

  factory BatteryInfo.fromJson(Map<String, dynamic> json) {
    return BatteryInfo(
      hasBattery: json['has_battery'] ?? false,
      isDesktop: json['is_desktop'] ?? true,
      healthPercent: (json['health_percent'] as num?)?.toDouble(),
      healthGrade: json['health_grade'] ?? 'Not Applicable',
      healthGradeFa: json['health_grade_fa'] ?? 'بدون باتری (سیستم رومیزی)',
      designCapacityMwh: json['design_capacity_mwh'] as int? ?? 0,
      fullChargeCapacityMwh: json['full_charge_capacity_mwh'] as int? ?? 0,
      currentChargePercent: json['current_charge_percent'] as int?,
      isCharging: json['is_charging'] ?? false,
      acConnected: json['ac_connected'] ?? true,
      powerSource: json['power_source'] ?? 'AC Power',
      powerSourceFa: json['power_source_fa'] ?? 'برق مستقیم',
      psuWattage: json['psu_wattage'] as int?,
      psuDisplay: json['psu_display'] ?? 'PSU: Not Detected',
      psuDetected: json['psu_detected'] ?? false,
      cycleCount: json['cycle_count'] as int?,
      name: json['name'] ?? 'Not available',
      manufacturer: json['manufacturer'] ?? 'Not available',
      serial: json['serial'] ?? 'Not available',
      chemistry: json['chemistry'] ?? 'N/A',
      isHealthy: json['is_healthy'] ?? true,
      summaryMessage: json['summary_message'] ?? '',
      summaryMessageFa: json['summary_message_fa'] ?? '',
    );
  }

  factory BatteryInfo.empty() =>
      BatteryInfo(hasBattery: false, isDesktop: true);
}

class ProxyInfo {
  final bool enabled;
  final String server;
  final String ip;
  final String port;
  final String override;
  final bool hasManualProxy;
  final bool isWarning;
  final String statusText;
  final String statusTextEn;

  ProxyInfo({
    required this.enabled,
    required this.server,
    this.ip = '',
    this.port = '',
    this.override = '',
    required this.hasManualProxy,
    this.isWarning = false,
    this.statusText = 'خاموش',
    this.statusTextEn = 'Disabled',
  });

  factory ProxyInfo.empty() =>
      ProxyInfo(enabled: false, server: '', hasManualProxy: false);

  factory ProxyInfo.fromJson(Map<String, dynamic> json) {
    return ProxyInfo(
      enabled: json['enabled'] as bool? ?? false,
      server: json['server'] ?? '',
      ip: json['ip'] ?? '',
      port: json['port'] ?? '',
      override: json['override'] ?? '',
      hasManualProxy: json['has_manual_proxy'] as bool? ?? false,
      isWarning: json['is_warning'] as bool? ?? false,
      statusText: json['status_text'] ?? 'خاموش',
      statusTextEn: json['status_text_en'] ?? 'Disabled',
    );
  }
}

class RebootInfo {
  final bool rebootRequired;
  final List<String> reasons;
  final List<String> details;
  final String summary;
  final String summaryEn;

  RebootInfo({
    required this.rebootRequired,
    this.reasons = const [],
    this.details = const [],
    this.summary = '',
    this.summaryEn = '',
  });

  factory RebootInfo.empty() => RebootInfo(rebootRequired: false);

  factory RebootInfo.fromJson(Map<String, dynamic> json) {
    return RebootInfo(
      rebootRequired: json['reboot_required'] as bool? ?? false,
      reasons: (json['reasons'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      details: (json['details'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      summary: json['summary'] ?? '',
      summaryEn: json['summary_en'] ?? '',
    );
  }
}

// -------------------------------------------------------------
// Batch Software Installation Models
// -------------------------------------------------------------

class BatchInstallItem {
  final String id;
  final String name;
  final String filename;
  final String relativePath;
  final String status; // queued, installing, completed, failed, skipped
  final String message;
  final String installedVersion;
  final int? exitCode;
  final String? orchestratorAction;
  final String? installerType;

  BatchInstallItem({
    required this.id,
    required this.name,
    this.filename = '',
    this.relativePath = '',
    this.status = 'queued',
    this.message = '',
    this.installedVersion = '',
    this.exitCode,
    this.orchestratorAction,
    this.installerType,
  });

  factory BatchInstallItem.fromJson(Map<String, dynamic> json) {
    return BatchInstallItem(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      filename: json['filename'] ?? '',
      relativePath: json['relative_path'] ?? '',
      status: json['status'] ?? 'queued',
      message: json['message'] ?? '',
      installedVersion: json['installed_version'] ?? '',
      exitCode: json['exit_code'] as int?,
      orchestratorAction: json['orchestrator_action'] as String?,
      installerType: json['installer_type'] as String?,
    );
  }

  bool get isOrchestrator =>
      orchestratorAction != null && orchestratorAction!.isNotEmpty;

  /// Returns stage index: 1 = Prerequisites & Activation, 2 = Software, 3 = Device Settings
  int get stage {
    if (orchestratorAction == 'office_extract' ||
        orchestratorAction == 'kms_activate' ||
        orchestratorAction == 'desktop_icons') {
      return 1;
    }
    if (orchestratorAction == 'sleep_never' ||
        orchestratorAction == 'power_modes' ||
        orchestratorAction == 'tehran_timezone' ||
        orchestratorAction == 'startup_apps' ||
        orchestratorAction == 'background_apps') {
      return 3;
    }
    return 2;
  }

  String get stageNameFa {
    switch (stage) {
      case 1:
        return 'پیش‌نیازها و فعال‌سازی';
      case 2:
        return 'نصب نرم‌افزارها';
      case 3:
        return 'تنظیمات و بهینه‌سازی';
      default:
        return 'عملیات سیستم';
    }
  }

  String get friendlyDescription {
    switch (orchestratorAction) {
      case 'office_extract':
        return 'بررسی و استخراج آفیس';
      case 'kms_activate':
        return 'استخراج KMS و فعال‌سازی ویندوز';
      case 'desktop_icons':
        return 'تنظیم ۳ آیکن دسکتاپ (This PC، سطل آشغال، کنترل پنل)';
      case 'sleep_never':
        return 'تنظیم Sleep و خاموشی صفحه روی Never';
      case 'power_modes':
        return 'طرح توان باتری و برق لپ‌تاپ';
      case 'tehran_timezone':
        return 'منطقه زمانی تهران و ساعت خودکار';
      case 'startup_apps':
        return 'بهینه‌سازی برنامه‌های استارتاپ';
      case 'background_apps':
        return 'غیرفعال‌سازی برنامه‌های پس‌زمینه';
      default:
        return name;
    }
  }
}

class BatchInstallStatus {
  final bool isRunning;
  final bool cancelled;
  final int total;
  final int completed;
  final int failed;
  final int skipped;
  final bool rebootRequired;
  final String? currentItemName;
  final int currentItemIndex;
  final double progressPercent;
  final List<BatchInstallItem> items;
  final String summaryMessage;

  BatchInstallStatus({
    required this.isRunning,
    this.cancelled = false,
    this.total = 0,
    this.completed = 0,
    this.failed = 0,
    this.skipped = 0,
    this.rebootRequired = false,
    this.currentItemName,
    this.currentItemIndex = 0,
    this.progressPercent = 0.0,
    this.items = const [],
    this.summaryMessage = '',
  });

  factory BatchInstallStatus.empty() => BatchInstallStatus(isRunning: false);

  factory BatchInstallStatus.fromJson(Map<String, dynamic> json) {
    return BatchInstallStatus(
      isRunning: json['is_running'] as bool? ?? false,
      cancelled: json['cancelled'] as bool? ?? false,
      total: json['total'] as int? ?? 0,
      completed: json['completed'] as int? ?? 0,
      failed: json['failed'] as int? ?? 0,
      skipped: json['skipped'] as int? ?? 0,
      rebootRequired: json['reboot_required'] as bool? ?? false,
      currentItemName: json['current_item_name'] as String?,
      currentItemIndex: json['current_item_index'] as int? ?? 0,
      progressPercent: (json['progress_percent'] as num?)?.toDouble() ?? 0.0,
      items: (json['items'] as List<dynamic>? ?? [])
          .map((e) => BatchInstallItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      summaryMessage: json['summary_message'] ?? '',
    );
  }

  List<BatchInstallItem> get stage1Items =>
      items.where((it) => it.stage == 1).toList();
  List<BatchInstallItem> get stage2Items =>
      items.where((it) => it.stage == 2).toList();
  List<BatchInstallItem> get stage3Items =>
      items.where((it) => it.stage == 3).toList();

  bool isStageRunning(int stageNum) {
    final stageItems = items.where((it) => it.stage == stageNum);
    return stageItems.any((it) => it.status == 'installing');
  }

  bool isStageCompleted(int stageNum) {
    final stageItems = items.where((it) => it.stage == stageNum);
    if (stageItems.isEmpty) return false;
    return stageItems.every((it) =>
        it.status == 'completed' || it.status == 'failed' || it.status == 'skipped');
  }

  int get currentStage {
    if (isStageRunning(1)) return 1;
    if (isStageRunning(2)) return 2;
    if (isStageRunning(3)) return 3;
    if (stage3Items.isNotEmpty && isStageCompleted(3)) return 3;
    if (stage2Items.isNotEmpty && isStageCompleted(2)) return 2;
    if (stage1Items.isNotEmpty && isStageCompleted(1)) return 1;
    return 1;
  }
}

// -------------------------------------------------------------
// Driver Batch Installation Models
// -------------------------------------------------------------

class ScannedDriverFile {
  final String filename;
  final String relativePath;
  final String fullPath;
  final String type; // exe, msi, inf
  final int fileSizeBytes;
  final String fileSizeDisplay;
  final String installerType;
  final bool autoInstallSupported;
  final bool isValid;
  final String? validationError;

  ScannedDriverFile({
    required this.filename,
    required this.relativePath,
    required this.fullPath,
    required this.type,
    this.fileSizeBytes = 0,
    this.fileSizeDisplay = '',
    this.installerType = 'unknown',
    this.autoInstallSupported = false,
    this.isValid = true,
    this.validationError,
  });

  factory ScannedDriverFile.fromJson(Map<String, dynamic> json) {
    return ScannedDriverFile(
      filename: json['filename'] ?? '',
      relativePath: json['relative_path'] ?? '',
      fullPath: json['full_path'] ?? '',
      type: json['type'] ?? 'exe',
      fileSizeBytes: json['file_size_bytes'] as int? ?? 0,
      fileSizeDisplay: json['file_size_display'] ?? '',
      installerType: json['installer_type'] ?? 'unknown',
      autoInstallSupported: json['auto_install_supported'] as bool? ?? false,
      isValid: json['is_valid'] as bool? ?? true,
      validationError: json['validation_error'],
    );
  }
}

class DriverInstallItem {
  final String filename;
  final String relativePath;
  final String type;
  final String fileSizeDisplay;
  final String status; // queued, installing, completed, failed, skipped
  final String message;
  final int? exitCode;
  final String? packageId;
  final String? displayName;
  final String? failureReason;

  DriverInstallItem({
    required this.filename,
    this.relativePath = '',
    this.type = 'exe',
    this.fileSizeDisplay = '',
    this.status = 'queued',
    this.message = '',
    this.exitCode,
    this.packageId,
    this.displayName,
    this.failureReason,
  });

  factory DriverInstallItem.fromJson(Map<String, dynamic> json) {
    return DriverInstallItem(
      filename:
          json['filename'] ??
          json['display_name'] ??
          json['installer_file'] ??
          '',
      relativePath: json['relative_path'] ?? '',
      type: json['type'] ?? 'exe',
      fileSizeDisplay: json['file_size_display'] ?? '',
      status: json['status'] ?? 'queued',
      message: json['message'] ?? '',
      exitCode: json['exit_code'] as int?,
      packageId: json['package_id'] as String?,
      displayName: json['display_name'] as String?,
      failureReason: json['failure_reason'] as String?,
    );
  }
}

class DriverBatchStatus {
  final bool isRunning;
  final bool cancelled;
  final int total;
  final int completed;
  final int failed;
  final int skipped;
  final String? currentFile;
  final int currentIndex;
  final double progressPercent;
  final String folderPath;
  final bool rebootRequired;
  final String summaryMessage;
  final List<DriverInstallItem> items;

  DriverBatchStatus({
    required this.isRunning,
    this.cancelled = false,
    this.total = 0,
    this.completed = 0,
    this.failed = 0,
    this.skipped = 0,
    this.currentFile,
    this.currentIndex = 0,
    this.progressPercent = 0.0,
    this.folderPath = '',
    this.rebootRequired = false,
    this.summaryMessage = '',
    this.items = const [],
  });

  factory DriverBatchStatus.empty() => DriverBatchStatus(isRunning: false);

  factory DriverBatchStatus.fromJson(Map<String, dynamic> json) {
    return DriverBatchStatus(
      isRunning: json['is_running'] as bool? ?? false,
      cancelled: json['cancelled'] as bool? ?? false,
      total: json['total'] as int? ?? 0,
      completed: json['completed'] as int? ?? 0,
      failed: json['failed'] as int? ?? 0,
      skipped: json['skipped'] as int? ?? 0,
      currentFile: (json['current_file'] ?? json['current_package']) as String?,
      currentIndex: json['current_index'] as int? ?? 0,
      progressPercent: (json['progress_percent'] as num?)?.toDouble() ?? 0.0,
      folderPath: json['folder_path'] ?? '',
      rebootRequired: json['reboot_required'] as bool? ?? false,
      summaryMessage: json['summary_message'] ?? '',
      items: (json['items'] as List<dynamic>? ?? [])
          .map((e) => DriverInstallItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ActivationToolItem {
  final String name;
  final String relativePath;
  final String fullPath;
  final String extension;
  final String description;
  final String statusText;
  final bool isValid;

  ActivationToolItem({
    required this.name,
    required this.relativePath,
    this.fullPath = '',
    this.extension = 'CMD',
    required this.description,
    this.statusText = 'آماده',
    this.isValid = true,
  });

  factory ActivationToolItem.fromJson(Map<String, dynamic> json) {
    return ActivationToolItem(
      name: json['name'] ?? '',
      relativePath: json['relative_path'] ?? json['name'] ?? '',
      fullPath: json['full_path'] ?? '',
      extension: json['extension'] ?? 'CMD',
      description: json['description'] ?? 'ابزار فعال‌سازی',
      statusText: json['status_text'] ?? 'آماده',
      isValid: json['is_valid'] as bool? ?? true,
    );
  }
}

class ToolsDirectoryStatus {
  final bool success;
  final String toolsDirectory;
  final bool isConfigured;
  final int totalTools;
  final List<ActivationToolItem> tools;

  ToolsDirectoryStatus({
    this.success = true,
    required this.toolsDirectory,
    this.isConfigured = false,
    this.totalTools = 0,
    required this.tools,
  });

  factory ToolsDirectoryStatus.empty() => ToolsDirectoryStatus(
    success: true,
    toolsDirectory: '',
    isConfigured: false,
    totalTools: 0,
    tools: [],
  );

  factory ToolsDirectoryStatus.fromJson(Map<String, dynamic> json) {
    return ToolsDirectoryStatus(
      success: json['success'] as bool? ?? true,
      toolsDirectory: json['tools_directory'] ?? '',
      isConfigured: json['is_configured'] as bool? ?? false,
      totalTools: json['total_tools'] as int? ?? 0,
      tools: (json['tools'] as List<dynamic>? ?? [])
          .map((e) => ActivationToolItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

// -------------------------------------------------------------
// Intelligent Driver Manager Models (Phase 5)
// -------------------------------------------------------------

class DriverHardwareMatch {
  final bool isMatched;
  final String confidence; // HIGH, MEDIUM, LOW, NOT_APPLICABLE
  final String
  status; // needs_install, update_available, up_to_date, not_applicable
  final String statusFa;
  final String statusEn;
  final String matchedDeviceName;
  final String matchedDeviceId;
  final String installedVersion;
  final String packageVersion;
  final String recommendation; // recommended, optional, skip
  final List<String> reasons;

  DriverHardwareMatch({
    required this.isMatched,
    required this.confidence,
    required this.status,
    required this.statusFa,
    required this.statusEn,
    required this.matchedDeviceName,
    required this.matchedDeviceId,
    required this.installedVersion,
    required this.packageVersion,
    required this.recommendation,
    required this.reasons,
  });

  factory DriverHardwareMatch.fromJson(Map<String, dynamic> json) {
    return DriverHardwareMatch(
      isMatched: json['is_matched'] as bool? ?? false,
      confidence: json['confidence'] ?? 'NOT_APPLICABLE',
      status: json['status'] ?? 'not_applicable',
      statusFa: json['status_fa'] ?? '',
      statusEn: json['status_en'] ?? '',
      matchedDeviceName: json['matched_device_name'] ?? '',
      matchedDeviceId: json['matched_device_id'] ?? '',
      installedVersion: json['installed_version'] ?? '',
      packageVersion: json['package_version'] ?? '',
      recommendation: json['recommendation'] ?? 'skip',
      reasons: (json['reasons'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
    );
  }
}

class IntelligentDriverPackage {
  final String packageId;
  final String displayName;
  final String category;
  final String categoryFa;
  final int categoryOrder;
  final String packageType; // zip, folder, self_extracting_exe, inf
  final String sourcePath;
  final String relativePath;
  final String installerFile;
  final String installMethod;
  final String fileSizeDisplay;
  final int sizeBytes;
  final String fingerprint;
  final List<String> hardwareIds;
  final String driverVersion;
  final String driverDate;
  final String provider;
  final List<String> alternativeInstallers;
  final DriverHardwareMatch? match;
  final bool isDuplicate;

  IntelligentDriverPackage({
    required this.packageId,
    required this.displayName,
    required this.category,
    required this.categoryFa,
    this.categoryOrder = 99,
    required this.packageType,
    required this.sourcePath,
    required this.relativePath,
    required this.installerFile,
    required this.installMethod,
    this.fileSizeDisplay = '',
    this.sizeBytes = 0,
    required this.fingerprint,
    this.hardwareIds = const [],
    this.driverVersion = '',
    this.driverDate = '',
    this.provider = '',
    this.alternativeInstallers = const [],
    this.match,
    this.isDuplicate = false,
  });

  factory IntelligentDriverPackage.fromJson(Map<String, dynamic> json) {
    return IntelligentDriverPackage(
      packageId: json['package_id'] ?? '',
      displayName: json['display_name'] ?? '',
      category: json['category'] ?? 'other',
      categoryFa: json['category_fa'] ?? 'سایر دستگاه‌ها',
      categoryOrder: json['category_order'] as int? ?? 99,
      packageType: json['package_type'] ?? 'folder',
      sourcePath: json['source_path'] ?? '',
      relativePath: json['relative_path'] ?? '',
      installerFile: json['installer_file'] ?? '',
      installMethod: json['install_method'] ?? 'setup_exe',
      fileSizeDisplay: json['file_size_display'] ?? '',
      sizeBytes: json['size_bytes'] as int? ?? 0,
      fingerprint: json['fingerprint'] ?? '',
      hardwareIds: (json['hardware_ids'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      driverVersion: json['driver_version'] ?? '',
      driverDate: json['driver_date'] ?? '',
      provider: json['provider'] ?? '',
      alternativeInstallers:
          (json['alternative_installers'] as List<dynamic>? ?? [])
              .map((e) => e.toString())
              .toList(),
      match: json['match'] != null
          ? DriverHardwareMatch.fromJson(json['match'] as Map<String, dynamic>)
          : null,
      isDuplicate: json['is_duplicate'] as bool? ?? false,
    );
  }
}

class RemovableDriverSource {
  final String driveLetter;
  final String volumeName;
  final String driverPath;
  final String displayName;

  RemovableDriverSource({
    required this.driveLetter,
    required this.volumeName,
    required this.driverPath,
    required this.displayName,
  });

  factory RemovableDriverSource.fromJson(Map<String, dynamic> json) {
    return RemovableDriverSource(
      driveLetter: json['drive_letter'] ?? '',
      volumeName: json['volume_name'] ?? '',
      driverPath: json['driver_path'] ?? '',
      displayName: json['display_name'] ?? '',
    );
  }
}

class DriverScanResult {
  final bool success;
  final String message;
  final String driverDirectory;
  final int totalPackages;
  final List<IntelligentDriverPackage> packages;
  final List<RemovableDriverSource> removableSources;
  final int matchingCount;
  final int needsInstallCount;
  final int updateAvailableCount;
  final int upToDateCount;
  final int notApplicableCount;
  final int duplicateCount;

  DriverScanResult({
    required this.success,
    required this.message,
    required this.driverDirectory,
    this.totalPackages = 0,
    this.packages = const [],
    this.removableSources = const [],
    this.matchingCount = 0,
    this.needsInstallCount = 0,
    this.updateAvailableCount = 0,
    this.upToDateCount = 0,
    this.notApplicableCount = 0,
    this.duplicateCount = 0,
  });

  factory DriverScanResult.empty() =>
      DriverScanResult(success: false, message: '', driverDirectory: '');

  factory DriverScanResult.fromJson(Map<String, dynamic> json) {
    final summary = json['summary'] as Map<String, dynamic>? ?? {};
    final rawPkgs = json['packages'] as List<dynamic>? ?? [];
    final rawRemovables = json['removable_sources'] as List<dynamic>? ?? [];

    return DriverScanResult(
      success: json['success'] as bool? ?? false,
      message: json['message'] ?? '',
      driverDirectory: json['driver_directory'] ?? '',
      totalPackages: json['total_packages'] as int? ?? rawPkgs.length,
      packages: rawPkgs
          .map(
            (e) => IntelligentDriverPackage.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
      removableSources: rawRemovables
          .map((e) => RemovableDriverSource.fromJson(e as Map<String, dynamic>))
          .toList(),
      matchingCount: summary['matching'] as int? ?? 0,
      needsInstallCount: summary['needs_install'] as int? ?? 0,
      updateAvailableCount: summary['update_available'] as int? ?? 0,
      upToDateCount: summary['up_to_date'] as int? ?? 0,
      notApplicableCount: summary['not_applicable'] as int? ?? 0,
      duplicateCount: summary['duplicates'] as int? ?? 0,
    );
  }
}

class UsbDriveInfo {
  final String driveLetter;
  final String volumeName;
  final String fileSystem;
  final String vendor;
  final String product;
  final String serial;
  final int totalBytes;
  final int freeBytes;
  final int usedBytes;
  final double totalGb;
  final double freeGb;
  final double usedGb;
  final double percentUsed;
  final bool isRemovable;

  UsbDriveInfo({
    required this.driveLetter,
    required this.volumeName,
    required this.fileSystem,
    required this.vendor,
    required this.product,
    this.serial = '',
    this.totalBytes = 0,
    this.freeBytes = 0,
    this.usedBytes = 0,
    required this.totalGb,
    required this.freeGb,
    required this.usedGb,
    required this.percentUsed,
    required this.isRemovable,
  });

  factory UsbDriveInfo.fromJson(Map<String, dynamic> json) {
    final total = (json['total_gb'] as num?)?.toDouble() ?? 0.0;
    final free = (json['free_gb'] as num?)?.toDouble() ?? 0.0;
    final used =
        (json['used_gb'] as num?)?.toDouble() ??
        (total > free ? (total - free) : 0.0);
    final pct =
        (json['percent_used'] as num?)?.toDouble() ??
        (total > 0 ? ((used / total) * 100.0) : 0.0);

    return UsbDriveInfo(
      driveLetter: (json['drive_letter'] ?? '').toString(),
      volumeName: (json['volume_name'] ?? '').toString(),
      fileSystem: (json['file_system'] ?? '').toString(),
      vendor: (json['vendor'] ?? '').toString(),
      product: (json['product'] ?? '').toString(),
      serial: (json['serial'] ?? '').toString(),
      totalBytes: (json['total_bytes'] as num?)?.toInt() ?? 0,
      freeBytes: (json['free_bytes'] as num?)?.toInt() ?? 0,
      usedBytes: (json['used_bytes'] as num?)?.toInt() ?? 0,
      totalGb: total,
      freeGb: free,
      usedGb: used,
      percentUsed: pct,
      isRemovable: json['is_removable'] == true,
    );
  }

  String get displayName {
    final parts = <String>[];
    if (vendor.isNotEmpty) parts.add(vendor);
    if (product.isNotEmpty) parts.add(product);
    if (parts.isNotEmpty) {
      if (volumeName.isNotEmpty &&
          volumeName != 'فلش مموری' &&
          volumeName != 'USB Drive') {
        return '${parts.join(' ')} ($volumeName)';
      }
      return parts.join(' ');
    }
    if (volumeName.isNotEmpty) return volumeName;
    return 'فلش مموری $driveLetter';
  }
}
