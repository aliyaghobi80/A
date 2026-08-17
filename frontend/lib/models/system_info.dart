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
  })  : driverSummary = driverSummary ?? DriverSummary.empty(),
        softwareSummary = softwareSummary ?? SoftwareSummary.empty(),
        filesSummary = filesSummary ?? FilesSummary.empty(),
        windowsActivation = windowsActivation ?? WindowsActivationInfo.empty(),
        officeActivation = officeActivation ?? OfficeActivationInfo.empty(),
        battery = battery ?? BatteryInfo.empty();

  factory SystemInfo.fromJson(Map<String, dynamic> json) {
    return SystemInfo(
      status: json['status'] ?? 'unknown',
      timestamp: json['timestamp'] ?? '',
      scanDurationMs: (json['scan_duration_ms'] as num?)?.toDouble() ?? 0.0,
      cpu: CpuInfo.fromJson(json['cpu'] as Map<String, dynamic>? ?? {}),
      motherboard: MotherboardInfo.fromJson(json['motherboard'] as Map<String, dynamic>? ?? {}),
      ram: RamInfo.fromJson(json['ram'] as Map<String, dynamic>? ?? {}),
      gpu: (json['gpu'] as List<dynamic>? ?? [])
          .map((e) => GpuInfo.fromJson(e as Map<String, dynamic>))
          .toList(),
      storage: (json['storage'] as List<dynamic>? ?? [])
          .map((e) => StorageInfo.fromJson(e as Map<String, dynamic>))
          .toList(),
      windows: WindowsInfo.fromJson(json['windows'] as Map<String, dynamic>? ?? {}),
      system: SystemMetaInfo.fromJson(json['system'] as Map<String, dynamic>? ?? {}),
      bios: BiosInfo.fromJson(json['bios'] as Map<String, dynamic>? ?? {}),
      network: (json['network'] as List<dynamic>? ?? [])
          .map((e) => NetworkInfo.fromJson(e as Map<String, dynamic>))
          .toList(),
      drivers: (json['drivers'] as List<dynamic>? ?? [])
          .map((e) => DriverItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      driverSummary: DriverSummary.fromJson(json['driver_summary'] as Map<String, dynamic>? ?? {}),
      software: (json['software'] as List<dynamic>? ?? [])
          .map((e) => SoftwareItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      softwareSummary: SoftwareSummary.fromJson(json['software_summary'] as Map<String, dynamic>? ?? {}),
      requiredFiles: (json['required_files'] as List<dynamic>? ?? [])
          .map((e) => RequiredFileItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      filesSummary: FilesSummary.fromJson(json['files_summary'] as Map<String, dynamic>? ?? {}),
      windowsActivation: WindowsActivationInfo.fromJson(json['windows_activation'] as Map<String, dynamic>? ?? {}),
      officeActivation: OfficeActivationInfo.fromJson(json['office_activation'] as Map<String, dynamic>? ?? {}),
      battery: BatteryInfo.fromJson(json['battery'] as Map<String, dynamic>? ?? {}),
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
      statusDescription: json['status_description'] ?? 'دستگاه به درستی کار می‌کند',
      statusDescriptionEn: json['status_description_en'] ?? 'Device is working properly',
      instanceId: json['instance_id'] ?? 'Not available',
      manufacturer: json['manufacturer'] ?? 'Unknown',
      pnpClass: json['pnp_class'] ?? '',
      recommendation: json['recommendation'] is Map<String, dynamic>
          ? DriverRecommendation.fromJson(json['recommendation'] as Map<String, dynamic>)
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
      installationOrderFa: (json['installation_order_fa'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
      installationOrderEn: (json['installation_order_en'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
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
          ? SystemDriverRecommendations.fromJson(json['recommendations'] as Map<String, dynamic>)
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
  final String? detectionId;
  final String? silentArguments;
  final String fileSizeDisplay;
  final bool isValid;
  final String? validationError;
  final String status;
  final bool isInstalled;
  final String installedVersion;
  final bool installAllowed;
  final bool hasIcon;
  final String? iconBase64;
  final String? iconUrl;
  final String? installedExePath;
  final String? installLocation;

  SoftwarePackage({
    required this.id,
    required this.name,
    required this.filename,
    required this.relativePath,
    this.fullPath = '',
    required this.version,
    required this.publisher,
    this.detectionId,
    this.silentArguments,
    this.fileSizeDisplay = '',
    required this.isValid,
    this.validationError,
    required this.status,
    required this.isInstalled,
    required this.installedVersion,
    required this.installAllowed,
    required this.hasIcon,
    this.iconBase64,
    this.iconUrl,
    this.installedExePath,
    this.installLocation,
  });

  String get installPathTooltip {
    if (isInstalled) {
      if (installedExePath != null && installedExePath!.isNotEmpty) {
        return 'مسیر نصب:\n$installedExePath';
      }
      if (installLocation != null && installLocation!.isNotEmpty && installLocation != 'Not available') {
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
      detectionId: json['detection_id'],
      silentArguments: json['silent_arguments'],
      fileSizeDisplay: json['file_size_display'] ?? '',
      isValid: json['is_valid'] as bool? ?? true,
      validationError: json['validation_error'],
      status: json['status'] ?? (json['is_installed'] == true ? 'Installed' : 'Not Installed'),
      isInstalled: json['is_installed'] as bool? ?? false,
      installedVersion: json['installed_version'] ?? 'Not available',
      installAllowed: json['install_allowed'] as bool? ?? (!((json['is_installed'] as bool?) ?? false)),
      hasIcon: (json['has_icon'] as bool? ?? false) || json['icon_base64'] != null,
      iconBase64: json['icon_base64'],
      iconUrl: json['icon_url'],
      installedExePath: json['installed_exe_path'],
      installLocation: json['install_location'],
    );
  }
}

class PackageSummary {
  final int totalPackages;
  final int validPackages;
  final int installedPackages;
  final int availableToInstall;

  PackageSummary({
    required this.totalPackages,
    required this.validPackages,
    required this.installedPackages,
    required this.availableToInstall,
  });

  factory PackageSummary.empty() => PackageSummary(
        totalPackages: 0,
        validPackages: 0,
        installedPackages: 0,
        availableToInstall: 0,
      );

  factory PackageSummary.fromJson(Map<String, dynamic> json) {
    return PackageSummary(
      totalPackages: json['total_packages'] as int? ?? 0,
      validPackages: json['valid_packages'] as int? ?? 0,
      installedPackages: json['installed_packages'] as int? ?? 0,
      availableToInstall: json['available_to_install'] as int? ?? 0,
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
      summary: PackageSummary.fromJson(json['summary'] as Map<String, dynamic>? ?? {}),
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
      isInstalled: json['is_installed'] as bool? ?? (json['status'] == 'Installed'),
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

  factory SoftwareSummary.empty() => SoftwareSummary(
        installedCount: 0,
        totalCount: 0,
        allInstalled: false,
      );

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
      status: json['status'] ?? (json['exists'] == true ? 'Present' : 'Missing'),
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

  factory FilesSummary.empty() => FilesSummary(
        presentCount: 0,
        totalCount: 0,
        allPresent: false,
      );

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

  MotherboardInfo({
    required this.manufacturer,
    required this.model,
    required this.serial,
  });

  factory MotherboardInfo.fromJson(Map<String, dynamic> json) {
    return MotherboardInfo(
      manufacturer: json['manufacturer'] ?? 'Not available',
      model: json['model'] ?? 'Not available',
      serial: json['serial'] ?? 'Not available',
    );
  }
}

class RamInfo {
  final double totalGb;
  final String totalDisplay;
  final int moduleCount;
  final String moduleSummary;
  final dynamic speedMhz;
  final String speedDisplay;
  final List<RamModule> modules;

  RamInfo({
    required this.totalGb,
    required this.totalDisplay,
    required this.moduleCount,
    required this.moduleSummary,
    required this.speedMhz,
    required this.speedDisplay,
    required this.modules,
  });

  factory RamInfo.fromJson(Map<String, dynamic> json) {
    return RamInfo(
      totalGb: (json['total_gb'] as num?)?.toDouble() ?? 0.0,
      totalDisplay: json['total_display'] ?? 'Not available',
      moduleCount: json['module_count'] as int? ?? 0,
      moduleSummary: json['module_summary'] ?? 'Not available',
      speedMhz: json['speed_mhz'] ?? 'Not available',
      speedDisplay: json['speed_display'] ?? 'Not available',
      modules: (json['modules'] as List<dynamic>? ?? [])
          .map((e) => RamModule.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class RamModule {
  final String slot;
  final double capacityGb;
  final String capacityDisplay;
  final int? speedMhz;
  final String speedDisplay;
  final String type;
  final String manufacturer;
  final String partNumber;
  final String serial;

  RamModule({
    required this.slot,
    required this.capacityGb,
    required this.capacityDisplay,
    this.speedMhz,
    required this.speedDisplay,
    required this.type,
    required this.manufacturer,
    required this.partNumber,
    this.serial = 'Not available',
  });

  factory RamModule.fromJson(Map<String, dynamic> json) {
    return RamModule(
      slot: json['slot'] ?? 'Slot',
      capacityGb: (json['capacity_gb'] as num?)?.toDouble() ?? 0.0,
      capacityDisplay: json['capacity_display'] ?? 'Not available',
      speedMhz: json['speed_mhz'] as int?,
      speedDisplay: json['speed_display'] ?? 'Not available',
      type: json['type'] ?? 'RAM',
      manufacturer: json['manufacturer'] ?? 'Not available',
      partNumber: json['part_number'] ?? 'Not available',
      serial: json['serial'] ?? 'Not available',
    );
  }
}

class GpuInfo {
  final String name;
  final String manufacturer;
  final int? vramBytes;
  final double? vramGb;
  final String vramDisplay;
  final String driverVersion;

  GpuInfo({
    required this.name,
    required this.manufacturer,
    this.vramBytes,
    this.vramGb,
    required this.vramDisplay,
    required this.driverVersion,
  });

  factory GpuInfo.fromJson(Map<String, dynamic> json) {
    return GpuInfo(
      name: json['name'] ?? 'Not available',
      manufacturer: json['manufacturer'] ?? 'Not available',
      vramBytes: json['vram_bytes'] as int?,
      vramGb: (json['vram_gb'] as num?)?.toDouble(),
      vramDisplay: json['vram_display'] ?? 'Not available',
      driverVersion: json['driver_version'] ?? 'Not available',
    );
  }
}

class StorageInfo {
  final String model;
  final String type;
  final String busType;
  final int? capacityBytes;
  final double? capacityGb;
  final String capacityDisplay;
  final String serial;
  final String healthStatus;

  StorageInfo({
    required this.model,
    required this.type,
    required this.busType,
    this.capacityBytes,
    this.capacityGb,
    required this.capacityDisplay,
    required this.serial,
    required this.healthStatus,
  });

  factory StorageInfo.fromJson(Map<String, dynamic> json) {
    return StorageInfo(
      model: json['model'] ?? 'Not available',
      type: json['type'] ?? 'Storage',
      busType: json['bus_type'] ?? 'Not available',
      capacityBytes: json['capacity_bytes'] as int?,
      capacityGb: (json['capacity_gb'] as num?)?.toDouble(),
      capacityDisplay: json['capacity_display'] ?? 'Not available',
      serial: json['serial'] ?? 'Not available',
      healthStatus: json['health_status'] ?? 'Healthy',
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
}

class SystemMetaInfo {
  final String computerName;
  final String manufacturer;
  final String model;
  final String serial;

  SystemMetaInfo({
    required this.computerName,
    required this.manufacturer,
    required this.model,
    this.serial = 'Not available',
  });

  factory SystemMetaInfo.fromJson(Map<String, dynamic> json) {
    return SystemMetaInfo(
      computerName: json['computer_name'] ?? 'Not available',
      manufacturer: json['manufacturer'] ?? 'Not available',
      model: json['model'] ?? 'Not available',
      serial: json['serial'] ?? 'Not available',
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
      );

  factory WindowsActivationInfo.fromJson(Map<String, dynamic> json) {
    return WindowsActivationInfo(
      installed: json['installed'] as bool? ?? true,
      activated: json['activated'] as bool? ?? false,
      statusCode: json['status_code'] as int? ?? 0,
      statusText: json['status_text'] ?? (json['activated'] == true ? 'Licensed' : 'Not Activated'),
      channel: json['channel'] ?? 'Not available',
      partialKey: json['partial_key'] ?? 'Not available',
      edition: json['edition'] ?? 'Windows',
      description: json['description'] ?? 'Not available',
      expiration: json['expiration'] as String?,
      isPermanent: json['is_permanent'] as bool? ?? (json['expiration'] == null),
      toolAvailable: json['tool_available'] as bool? ?? false,
      toolPath: json['tool_path'] as String?,
    );
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
      );

  factory OfficeActivationInfo.fromJson(Map<String, dynamic> json) {
    final isInst = json['installed'] as bool? ?? false;
    final isAct = json['activated'] as bool? ?? false;
    return OfficeActivationInfo(
      installed: isInst,
      product: json['product'] ?? (isInst ? 'Microsoft Office' : 'Not installed'),
      version: json['version'] ?? 'Not available',
      architecture: json['architecture'] ?? 'Not available',
      installType: json['install_type'] ?? 'Unknown',
      activated: isAct,
      statusCode: json['status_code'] as int? ?? 0,
      statusText: json['status_text'] ?? (!isInst ? 'Not installed' : (isAct ? 'Licensed' : 'Not Activated')),
      channel: json['channel'] ?? 'Not available',
      partialKey: json['partial_key'] ?? 'Not available',
      expiration: json['expiration'] as String?,
      toolAvailable: json['tool_available'] as bool? ?? false,
      toolPath: json['tool_path'] as String?,
    );
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

  factory BatteryInfo.empty() => BatteryInfo(hasBattery: false, isDesktop: true);
}

