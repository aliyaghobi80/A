import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

enum DisplayMode {
  simple,
  advanced,
}

class AppSettings {
  final String languageCode; // 'fa' or 'en'
  final DisplayMode displayMode;
  final String themeMode; // 'light' (default), 'dark', 'system'
  final String accentColorName; // 'blue' (default), 'purple', 'green', 'orange', 'red', 'teal', 'neutral'
  final String? customLogoPath;
  final String uiDensity; // 'comfortable', 'medium' (default), 'compact'
  final String temperatureUnit; // 'C' (default) or 'F'
  final bool autoScanOnStartup;
  final bool notificationsEnabled;
  final String? softwareDirectory;
  final String? driverDirectory;
  final String? toolsDirectory;

  const AppSettings({
    this.languageCode = 'fa',
    this.displayMode = DisplayMode.simple,
    this.themeMode = 'light',
    this.accentColorName = 'blue',
    this.customLogoPath,
    this.uiDensity = 'medium',
    this.temperatureUnit = 'C',
    this.autoScanOnStartup = true,
    this.notificationsEnabled = true,
    this.softwareDirectory,
    this.driverDirectory,
    this.toolsDirectory,
  });

  bool get isDarkMode => themeMode == 'dark';

  AppSettings copyWith({
    String? languageCode,
    DisplayMode? displayMode,
    String? themeMode,
    String? accentColorName,
    String? customLogoPath,
    String? uiDensity,
    String? temperatureUnit,
    bool? autoScanOnStartup,
    bool? notificationsEnabled,
    String? softwareDirectory,
    String? driverDirectory,
    String? toolsDirectory,
  }) {
    return AppSettings(
      languageCode: languageCode ?? this.languageCode,
      displayMode: displayMode ?? this.displayMode,
      themeMode: themeMode ?? this.themeMode,
      accentColorName: accentColorName ?? this.accentColorName,
      customLogoPath: customLogoPath ?? this.customLogoPath,
      uiDensity: uiDensity ?? this.uiDensity,
      temperatureUnit: temperatureUnit ?? this.temperatureUnit,
      autoScanOnStartup: autoScanOnStartup ?? this.autoScanOnStartup,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      softwareDirectory: softwareDirectory ?? this.softwareDirectory,
      driverDirectory: driverDirectory ?? this.driverDirectory,
      toolsDirectory: toolsDirectory ?? this.toolsDirectory,
    );
  }

  Map<String, dynamic> toJson() => {
        'languageCode': languageCode,
        'displayMode': displayMode.name,
        'themeMode': themeMode,
        'accentColorName': accentColorName,
        'customLogoPath': customLogoPath,
        'uiDensity': uiDensity,
        'temperatureUnit': temperatureUnit,
        'autoScanOnStartup': autoScanOnStartup,
        'notificationsEnabled': notificationsEnabled,
        'softwareDirectory': softwareDirectory,
        'driverDirectory': driverDirectory,
        'toolsDirectory': toolsDirectory,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      languageCode: json['languageCode'] as String? ?? 'fa',
      displayMode: (json['displayMode'] == 'advanced')
          ? DisplayMode.advanced
          : DisplayMode.simple,
      themeMode: json['themeMode'] as String? ??
          ((json['isDarkMode'] as bool? ?? false) ? 'dark' : 'light'),
      accentColorName: json['accentColorName'] as String? ?? 'blue',
      customLogoPath: json['customLogoPath'] as String?,
      uiDensity: json['uiDensity'] as String? ?? 'medium',
      temperatureUnit: json['temperatureUnit'] as String? ?? 'C',
      autoScanOnStartup: json['autoScanOnStartup'] as bool? ?? true,
      notificationsEnabled: json['notificationsEnabled'] as bool? ?? true,
      softwareDirectory: json['softwareDirectory'] as String?,
      driverDirectory: json['driverDirectory'] as String?,
      toolsDirectory: json['toolsDirectory'] as String?,
    );
  }
}

class SettingsService {
  static AppSettings _currentSettings = const AppSettings();
  static AppSettings get current => _currentSettings;

  static File? _getSettingsFile() {
    try {
      String? basePath;
      if (Platform.isWindows) {
        basePath = Platform.environment['APPDATA'] ??
            Platform.environment['LOCALAPPDATA'] ??
            Platform.environment['USERPROFILE'];
      }
      if (basePath != null && basePath.isNotEmpty) {
        final dir = Directory('$basePath\\CentralSystemChecker');
        if (!dir.existsSync()) {
          dir.createSync(recursive: true);
        }
        return File('${dir.path}\\settings.json');
      }
      return File('.settings.json');
    } catch (e) {
      debugPrint('[SettingsService] Error determining settings path: $e');
      return null;
    }
  }

  static Future<AppSettings> loadSettings() async {
    try {
      final file = _getSettingsFile();
      if (file != null && await file.exists()) {
        final content = await file.readAsString();
        final json = jsonDecode(content) as Map<String, dynamic>;
        _currentSettings = AppSettings.fromJson(json);
        return _currentSettings;
      }
    } catch (e) {
      debugPrint('[SettingsService] Failed to load settings: $e');
    }
    _currentSettings = const AppSettings();
    return _currentSettings;
  }

  static Future<void> saveSettings(AppSettings settings) async {
    _currentSettings = settings;
    try {
      final file = _getSettingsFile();
      if (file != null) {
        await file.writeAsString(jsonEncode(settings.toJson()));
      }
    } catch (e) {
      debugPrint('[SettingsService] Failed to save settings: $e');
    }
  }
}
