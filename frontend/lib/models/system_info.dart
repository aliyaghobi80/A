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
  final List<SoftwareItem> software;
  final SoftwareSummary softwareSummary;
  final List<RequiredFileItem> requiredFiles;
  final FilesSummary filesSummary;

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
    this.software = const [],
    SoftwareSummary? softwareSummary,
    this.requiredFiles = const [],
    FilesSummary? filesSummary,
  })  : softwareSummary = softwareSummary ?? SoftwareSummary.empty(),
        filesSummary = filesSummary ?? FilesSummary.empty();

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
      software: (json['software'] as List<dynamic>? ?? [])
          .map((e) => SoftwareItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      softwareSummary: SoftwareSummary.fromJson(json['software_summary'] as Map<String, dynamic>? ?? {}),
      requiredFiles: (json['required_files'] as List<dynamic>? ?? [])
          .map((e) => RequiredFileItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      filesSummary: FilesSummary.fromJson(json['files_summary'] as Map<String, dynamic>? ?? {}),
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

  CpuInfo({
    required this.name,
    required this.manufacturer,
    required this.cores,
    required this.threads,
    this.maxClockMhz,
    required this.maxClockDisplay,
  });

  factory CpuInfo.fromJson(Map<String, dynamic> json) {
    return CpuInfo(
      name: json['name'] ?? 'Not available',
      manufacturer: json['manufacturer'] ?? 'Not available',
      cores: json['cores'] ?? 'Not available',
      threads: json['threads'] ?? 'Not available',
      maxClockMhz: json['max_clock_mhz'] as int?,
      maxClockDisplay: json['max_clock_display'] ?? 'Not available',
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

  RamModule({
    required this.slot,
    required this.capacityGb,
    required this.capacityDisplay,
    this.speedMhz,
    required this.speedDisplay,
    required this.type,
    required this.manufacturer,
    required this.partNumber,
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

  SystemMetaInfo({
    required this.computerName,
    required this.manufacturer,
    required this.model,
  });

  factory SystemMetaInfo.fromJson(Map<String, dynamic> json) {
    return SystemMetaInfo(
      computerName: json['computer_name'] ?? 'Not available',
      manufacturer: json['manufacturer'] ?? 'Not available',
      model: json['model'] ?? 'Not available',
    );
  }
}

class BiosInfo {
  final String manufacturer;
  final String version;
  final String date;

  BiosInfo({
    required this.manufacturer,
    required this.version,
    required this.date,
  });

  factory BiosInfo.fromJson(Map<String, dynamic> json) {
    return BiosInfo(
      manufacturer: json['manufacturer'] ?? 'Not available',
      version: json['version'] ?? 'Not available',
      date: json['date'] ?? 'Not available',
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
