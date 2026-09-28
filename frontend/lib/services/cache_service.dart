import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/system_info.dart';

class CacheService {
  // The backend owns system_info_cache.json. Separate UI cache files prevent
  // two processes from concurrently truncating and corrupting the same JSON.
  static const String _systemInfoCacheFile = 'ui_system_info_cache.json';
  static const String _packagesCacheFile = 'ui_packages_cache.json';
  static Future<void> _systemWriteQueue = Future<void>.value();
  static Future<void> _packagesWriteQueue = Future<void>.value();

  static Directory? _getCacheDir() {
    try {
      String? basePath;
      if (Platform.isWindows) {
        basePath =
            Platform.environment['APPDATA'] ??
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

  static Future<void> _writeValidatedJson(File file, String jsonString) async {
    final decoded = json.decode(jsonString);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Cache payload must be a JSON object.');
    }

    final temp = File(
      '${file.path}.$pid.${DateTime.now().microsecondsSinceEpoch}.tmp',
    );
    try {
      await temp.writeAsString(json.encode(decoded), flush: true);
      if (await file.exists()) await file.delete();
      await temp.rename(file.path);
    } finally {
      if (await temp.exists()) await temp.delete();
    }
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
            debugPrint(
              '[CacheService] Successfully loaded cached system info.',
            );
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
    _systemWriteQueue = _systemWriteQueue
        .catchError((Object _) {})
        .then((_) async {
          final file = _getFile(_systemInfoCacheFile);
          if (file == null) return;
          await _writeValidatedJson(file, jsonString);
          debugPrint('[CacheService] Cached system info saved to disk.');
        })
        .catchError((Object e) {
          debugPrint('[CacheService] Error saving system info cache: $e');
        });
    await _systemWriteQueue;
  }

  /// Saves Map to persistent disk cache in background.
  static Future<void> saveCachedSystemInfo(Map<String, dynamic> data) async {
    await saveRawSystemInfoJson(json.encode(data));
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
    _packagesWriteQueue = _packagesWriteQueue
        .catchError((Object _) {})
        .then((_) async {
          final file = _getFile(_packagesCacheFile);
          if (file == null) return;
          await _writeValidatedJson(file, jsonString);
          debugPrint('[CacheService] Cached packages saved to disk.');
        })
        .catchError((Object e) {
          debugPrint('[CacheService] Error saving packages cache: $e');
        });
    await _packagesWriteQueue;
  }
}
