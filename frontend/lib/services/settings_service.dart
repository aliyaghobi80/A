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
  final bool isDarkMode;

  const AppSettings({
    this.languageCode = 'fa',
    this.displayMode = DisplayMode.simple,
    this.isDarkMode = true,
  });

  AppSettings copyWith({
    String? languageCode,
    DisplayMode? displayMode,
    bool? isDarkMode,
  }) {
    return AppSettings(
      languageCode: languageCode ?? this.languageCode,
      displayMode: displayMode ?? this.displayMode,
      isDarkMode: isDarkMode ?? this.isDarkMode,
    );
  }

  Map<String, dynamic> toJson() => {
        'languageCode': languageCode,
        'displayMode': displayMode.name,
        'isDarkMode': isDarkMode,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      languageCode: json['languageCode'] as String? ?? 'fa',
      displayMode: (json['displayMode'] == 'advanced')
          ? DisplayMode.advanced
          : DisplayMode.simple,
      isDarkMode: json['isDarkMode'] as bool? ?? true,
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
