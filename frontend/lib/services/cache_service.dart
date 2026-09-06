import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/system_info.dart';

class CacheService {
  static const String _systemInfoCacheFile = 'system_info_cache.json';
  static const String _packagesCacheFile = 'packages_cache.json';

  static Directory? _getCacheDir() {
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
        return dir;
      }
      final fallbackDir = Directory('.cache');
      if (!fallbackDir.existsSync()) {
        fallbackDir.createSync(recursive: true);
      }
      return fallbackDir;
    } catch (e) {
      debugPrint('[CacheService] Error determining cache directory: $e');
      return null;
    }
  }

  static File? _getFile(String filename) {
    final dir = _getCacheDir();
    if (dir == null) return null;
    return File('${dir.path}${Platform.pathSeparator}$filename');
  }

  // ---------------------------------------------------------------------------
  // SystemInfo Cache
  // ---------------------------------------------------------------------------

  /// Loads cached SystemInfo from local disk instantly (< 10ms).
  static Future<SystemInfo?> loadCachedSystemInfo() async {
    try {
      final file = _getFile(_systemInfoCacheFile);
      if (file != null && await file.exists()) {
        final content = await file.readAsString();
        if (content.trim().isNotEmpty) {
          final Map<String, dynamic> data = json.decode(content);
          if (data['status'] == 'success' || data.containsKey('cpu')) {
            debugPrint('[CacheService] Successfully loaded cached system info.');
            return SystemInfo.fromJson(data);
          }
        }
      }
    } catch (e) {
      debugPrint('[CacheService] Error loading cached system info: $e');
    }
    return null;
  }

  /// Saves raw JSON response string to persistent disk cache in background.
  static Future<void> saveRawSystemInfoJson(String jsonString) async {
    try {
      final file = _getFile(_systemInfoCacheFile);
      if (file != null) {
        await file.writeAsString(jsonString);
        debugPrint('[CacheService] Cached system info saved to disk.');
      }
    } catch (e) {
      debugPrint('[CacheService] Error saving system info cache: $e');
    }
  }

  /// Saves Map to persistent disk cache in background.
  static Future<void> saveCachedSystemInfo(Map<String, dynamic> data) async {
    try {
      final file = _getFile(_systemInfoCacheFile);
      if (file != null) {
        await file.writeAsString(json.encode(data));
        debugPrint('[CacheService] Cached system info saved to disk.');
      }
    } catch (e) {
      debugPrint('[CacheService] Error saving system info cache: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // PackagesResponse Cache
  // ---------------------------------------------------------------------------

  /// Loads cached PackagesResponse from local disk instantly.
  static Future<PackagesResponse?> loadCachedPackages() async {
    try {
      final file = _getFile(_packagesCacheFile);
      if (file != null && await file.exists()) {
        final content = await file.readAsString();
        if (content.trim().isNotEmpty) {
          final Map<String, dynamic> data = json.decode(content);
          if (data.containsKey('packages')) {
            debugPrint('[CacheService] Successfully loaded cached packages.');
            return PackagesResponse.fromJson(data);
          }
        }
      }
    } catch (e) {
      debugPrint('[CacheService] Error loading cached packages: $e');
    }
    return null;
  }

  /// Saves raw JSON packages response to persistent disk cache in background.
  static Future<void> saveRawPackagesJson(String jsonString) async {
    try {
      final file = _getFile(_packagesCacheFile);
      if (file != null) {
        await file.writeAsString(jsonString);
        debugPrint('[CacheService] Cached packages saved to disk.');
      }
    } catch (e) {
      debugPrint('[CacheService] Error saving packages cache: $e');
    }
  }
}
