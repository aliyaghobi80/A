import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/system_info.dart';
import '../models/qc_report.dart';
import 'backend_process_manager.dart';
import 'cache_service.dart';

class ApiService {
  static String get baseUrl => BackendProcessManager.baseUrl;
  static const Duration timeoutDuration = Duration(seconds: 25);

  // Persistent HTTP client â€” reuses the same TCP connection to localhost.
  // Avoids handshake overhead on every API call.
  static final http.Client _client = http.Client();

  Future<SystemInfo> fetchSystemInfo({bool forceRefresh = false}) async {
    final isRunning = await BackendProcessManager.ensureBackendRunning();
    if (!isRunning) {
      throw Exception(
        'Unable to connect to local Python backend at $baseUrl.\n'
        'Please ensure Python is installed and backend/main.py is running.',
      );
    }

    try {
      final uri = forceRefresh
          ? Uri.parse('$baseUrl/api/refresh')
          : Uri.parse('$baseUrl/api/system-info');

      final response = forceRefresh
          ? await _client.post(uri).timeout(timeoutDuration)
          : await _client.get(uri).timeout(timeoutDuration);

      if (response.statusCode == 200) {
        final rawBody = utf8.decode(response.bodyBytes);
        CacheService.saveRawSystemInfoJson(rawBody);
        final Map<String, dynamic> data = json.decode(rawBody);
        return SystemInfo.fromJson(data);
      } else {
        throw Exception(
          'Server returned status ${response.statusCode}: ${response.body}',
        );
      }
    } on TimeoutException {
      throw Exception(
        'System hardware scan timed out. Click Refresh to try again.',
      );
    } catch (e) {
      debugPrint('[ApiService] fetchSystemInfo error: $e');
      rethrow;
    }
  }

  Future<PackagesResponse> fetchPackages({String? customDir}) async {
    final isRunning = await BackendProcessManager.ensureBackendRunning();
    if (!isRunning) {
      throw StateError(
        'سرویس بک‌اند برای دریافت فهرست نرم‌افزارها در دسترس نیست.',
      );
    }

    try {
      final uri = customDir != null && customDir.isNotEmpty
          ? Uri.parse(
              '$baseUrl/api/packages?dir=${Uri.encodeComponent(customDir)}',
            )
          : Uri.parse('$baseUrl/api/packages');

      final response = await _client
          .get(uri)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final rawBody = utf8.decode(response.bodyBytes);
        CacheService.saveRawPackagesJson(rawBody);
        final Map<String, dynamic> data = json.decode(rawBody);
        return PackagesResponse.fromJson(data);
      }
      throw HttpException(
        'Packages endpoint returned HTTP ${response.statusCode}.',
        uri: uri,
      );
    } catch (e) {
      debugPrint('[ApiService] fetchPackages error: $e');
      rethrow;
    }
  }

  Future<PackagesResponse> scanPackages() async {
    final isRunning = await BackendProcessManager.ensureBackendRunning();
    if (!isRunning) {
      throw StateError('سرویس بک‌اند برای اسکن نرم‌افزارها در دسترس نیست.');
    }

    try {
      final uri = Uri.parse('$baseUrl/api/packages/scan');
      final response = await _client
          .post(uri)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final rawBody = utf8.decode(response.bodyBytes);
        CacheService.saveRawPackagesJson(rawBody);
        final Map<String, dynamic> data = json.decode(rawBody);
        return PackagesResponse.fromJson(data);
      }
      throw HttpException(
        'Package scan returned HTTP ${response.statusCode}.',
        uri: uri,
      );
    } catch (e) {
      debugPrint('[ApiService] scanPackages error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> installPackage(String packageId) async {
    final isRunning = await BackendProcessManager.ensureBackendRunning();
    if (!isRunning) {
      return {'success': false, 'message': 'Backend service is not running.'};
    }

    try {
      final uri = Uri.parse('$baseUrl/api/packages/install');
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json; charset=utf-8'},
            body: json.encode({'package_id': packageId}),
          )
          .timeout(const Duration(minutes: 5));

      final Map<String, dynamic> data = json.decode(
        utf8.decode(response.bodyBytes),
      );
      return data;
    } catch (e) {
      debugPrint('[ApiService] installPackage error: $e');
      return {
        'success': false,
        'message': 'Error executing package installer: $e',
      };
    }
  }

  Future<Map<String, dynamic>> openPackage(
    String packageId, {
    bool confirmHomeUpdateBlock = false,
  }) async {
    final isRunning = await BackendProcessManager.ensureBackendRunning();
    if (!isRunning) {
      return {'success': false, 'message': 'Backend service is not running.'};
    }

    try {
      final uri = Uri.parse('$baseUrl/api/packages/open');
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json; charset=utf-8'},
            body: json.encode({
              'package_id': packageId,
              'confirm_home_update_block': confirmHomeUpdateBlock,
            }),
          )
          .timeout(const Duration(seconds: 15));

      final Map<String, dynamic> data = json.decode(
        utf8.decode(response.bodyBytes),
      );
      return data;
    } catch (e) {
      debugPrint('[ApiService] openPackage error: $e');
      return {'success': false, 'message': 'Error opening application: $e'};
    }
  }

  Future<Map<String, dynamic>> pinPackageToTaskbar(String packageId) async {
    return _postJson('/api/packages/pin-taskbar', {'package_id': packageId});
  }

  Future<Map<String, dynamic>> setWindowsUpdateState(
    String packageId, {
    required bool enable,
    bool confirmHomeUpdateBlock = false,
  }) async {
    return _postJson('/api/packages/windows-update', {
      'package_id': packageId,
      'enable': enable,
      'confirm_home_update_block': confirmHomeUpdateBlock,
    });
  }

  Future<Map<String, dynamic>> getDeviceSettingsStatus() async {
    final isRunning = await BackendProcessManager.ensureBackendRunning();
    if (!isRunning) return {'success': false};
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/api/device-settings/status'))
          .timeout(const Duration(seconds: 15));
      return json.decode(utf8.decode(response.bodyBytes));
    } catch (e) {
      return {'success': false, 'message': '$e'};
    }
  }

  Future<Map<String, dynamic>> pinWindowsSecurity() async {
    return _postJson('/api/device-settings/pin-windows-security', {});
  }

  Future<Map<String, dynamic>> showDesktopIcons() async =>
      _postJson('/api/device-settings/desktop-icons', {});
  Future<Map<String, dynamic>> setTehranTimezone() async =>
      _postJson('/api/device-settings/tehran-timezone', {});

  Future<Map<String, dynamic>> setLaptopSleepNever() async {
    return _postJson('/api/device-settings/sleep-never', {});
  }

  Future<Map<String, dynamic>> setLaptopPowerModes() async {
    return _postJson('/api/device-settings/laptop-power-modes', {});
  }

  Future<Map<String, dynamic>> disableAllStartupApps() async {
    return _postJson('/api/device-settings/disable-startup-apps', {});
  }

  Future<Map<String, dynamic>> disableWindows10BackgroundApps() async {
    return _postJson('/api/device-settings/disable-background-apps', {});
  }

  Future<Map<String, dynamic>> applyAllDeviceSettings() async {
    return _postJson('/api/device-settings/apply-all', {});
  }

  Future<Map<String, dynamic>> createOfficeDesktopShortcuts() async {
    return _postJson('/api/packages/office-shortcuts', {});
  }

  Future<Map<String, dynamic>> _postJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    final isRunning = await BackendProcessManager.ensureBackendRunning();
    if (!isRunning) {
      return {'success': false, 'message': 'Backend service is not running.'};
    }
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl$path'),
            headers: {'Content-Type': 'application/json; charset=utf-8'},
            body: json.encode(body),
          )
          .timeout(const Duration(seconds: 45));
      return json.decode(utf8.decode(response.bodyBytes));
    } catch (e) {
      return {'success': false, 'message': '$e'};
    }
  }

  Future<Map<String, dynamic>> openOfficeFolder([String? customDir]) async {
    final isRunning = await BackendProcessManager.ensureBackendRunning();
    if (!isRunning) {
      return {'success': false, 'message': 'Backend service is not running.'};
    }

    try {
      final uri = Uri.parse('$baseUrl/api/packages/open-office');
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json; charset=utf-8'},
            body: json.encode({'directory': customDir ?? ''}),
          )
          .timeout(const Duration(seconds: 15));

      final Map<String, dynamic> data = json.decode(
        utf8.decode(response.bodyBytes),
      );
      return data;
    } catch (e) {
      debugPrint('[ApiService] openOfficeFolder error: $e');
      return {'success': false, 'message': 'Error opening Office folder: $e'};
    }
  }

  Future<Map<String, dynamic>> uninstallPackage(String packageId) async {
    final isRunning = await BackendProcessManager.ensureBackendRunning();
    if (!isRunning) {
      return {'success': false, 'message': 'Backend service is not running.'};
    }

    try {
      final uri = Uri.parse('$baseUrl/api/packages/uninstall');
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json; charset=utf-8'},
            body: json.encode({'package_id': packageId}),
          )
          .timeout(const Duration(minutes: 5));

      final Map<String, dynamic> data = json.decode(
        utf8.decode(response.bodyBytes),
      );
      return data;
    } catch (e) {
      debugPrint('[ApiService] uninstallPackage error: $e');
      return {
        'success': false,
        'message': 'Error executing package uninstaller: $e',
      };
    }
  }

  Future<Map<String, dynamic>> disableProxy() async {
    final isRunning = await BackendProcessManager.ensureBackendRunning();
    if (!isRunning) {
      return {'success': false, 'message': 'Backend service is not running.'};
    }

    try {
      final uri = Uri.parse('$baseUrl/api/proxy/disable');
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json; charset=utf-8'},
          )
          .timeout(const Duration(seconds: 10));

      final Map<String, dynamic> data = json.decode(
        utf8.decode(response.bodyBytes),
      );
      return data;
    } catch (e) {
      debugPrint('[ApiService] disableProxy error: $e');
      return {'success': false, 'message': 'Error disabling proxy: $e'};
    }
  }

  Future<Map<String, dynamic>> restartSystem({
    int delaySeconds = 3,
    String reason = '',
  }) async {
    final isRunning = await BackendProcessManager.ensureBackendRunning();
    if (!isRunning) {
      return {'success': false, 'message': 'Backend service is not running.'};
    }

    try {
      final uri = Uri.parse('$baseUrl/api/reboot/restart');
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json; charset=utf-8'},
            body: json.encode({
              'delay_seconds': delaySeconds,
              'reason': reason,
            }),
          )
          .timeout(const Duration(seconds: 10));

      final Map<String, dynamic> data = json.decode(
        utf8.decode(response.bodyBytes),
      );
      return data;
    } catch (e) {
      debugPrint('[ApiService] restartSystem error: $e');
      return {'success': false, 'message': 'Error restarting system: $e'};
    }
  }

  Future<Map<String, dynamic>> cancelRestart() async {
    final isRunning = await BackendProcessManager.ensureBackendRunning();
    if (!isRunning) {
      return {'success': false, 'message': 'Backend service is not running.'};
    }

    try {
      final uri = Uri.parse('$baseUrl/api/reboot/cancel');
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json; charset=utf-8'},
          )
          .timeout(const Duration(seconds: 10));

      final Map<String, dynamic> data = json.decode(
        utf8.decode(response.bodyBytes),
      );
      return data;
    } catch (e) {
      debugPrint('[ApiService] cancelRestart error: $e');
      return {'success': false, 'message': 'Error cancelling restart: $e'};
    }
  }

  Future<ActivationResult> activateWindows() async {
    final isRunning = await BackendProcessManager.ensureBackendRunning();
    if (!isRunning) {
      return ActivationResult.error('Backend service is not running.');
    }

    try {
      final uri = Uri.parse('$baseUrl/api/activation/windows');
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json; charset=utf-8'},
          )
          .timeout(const Duration(minutes: 6));

      final Map<String, dynamic> data = json.decode(
        utf8.decode(response.bodyBytes),
      );
      return ActivationResult.fromJson(data);
    } catch (e) {
      debugPrint('[ApiService] activateWindows error: $e');
      return ActivationResult.error('خطا در ارتباط با سرور فعال‌سازی: $e');
    }
  }

  Future<Map<String, dynamic>> getActivationStatus() async {
    final isRunning = await BackendProcessManager.ensureBackendRunning();
    if (!isRunning) {
      throw Exception('Backend service is not running.');
    }

    final uri = Uri.parse('$baseUrl/api/activation/status');
    final response = await http
        .get(uri, headers: {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception('Activation status HTTP ${response.statusCode}');
    }
    return json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
  }

  Future<ActivationResult> activateOffice() async {
    final isRunning = await BackendProcessManager.ensureBackendRunning();
    if (!isRunning) {
      return ActivationResult.error('سرویس بک‌اند در حال اجرا نیست.');
    }

    try {
      final uri = Uri.parse('$baseUrl/api/activation/office');
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json; charset=utf-8'},
          )
          .timeout(const Duration(minutes: 4));

      final Map<String, dynamic> data = json.decode(
        utf8.decode(response.bodyBytes),
      );
      return ActivationResult.fromJson(data);
    } catch (e) {
      debugPrint('[ApiService] activateOffice error: $e');
      return ActivationResult.error('خطا در ارتباط با سرور فعال‌سازی: $e');
    }
  }

  Future<QcReport> fetchQcStatus() async {
    final isRunning = await BackendProcessManager.ensureBackendRunning();
    if (!isRunning) {
      return QcReport.empty();
    }

    try {
      final uri = Uri.parse('$baseUrl/api/qc/status');
      final response = await _client.get(uri).timeout(timeoutDuration);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(
          utf8.decode(response.bodyBytes),
        );
        return QcReport.fromJson(data);
      }
      return QcReport.empty();
    } catch (e) {
      debugPrint('[ApiService] fetchQcStatus error: $e');
      return QcReport.empty();
    }
  }

  Future<QcReport> runQcCheck() async {
    final isRunning = await BackendProcessManager.ensureBackendRunning();
    if (!isRunning) {
      return QcReport.empty();
    }

    try {
      final uri = Uri.parse('$baseUrl/api/qc/run');
      final response = await _client.post(uri).timeout(timeoutDuration);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(
          utf8.decode(response.bodyBytes),
        );
        return QcReport.fromJson(data);
      }
      return QcReport.empty();
    } catch (e) {
      debugPrint('[ApiService] runQcCheck error: $e');
      return QcReport.empty();
    }
  }

  Future<PackagesResponse> setPackagesDirectory(String dir) async {
    final isRunning = await BackendProcessManager.ensureBackendRunning();
    if (!isRunning) {
      throw StateError(
        'سرویس بک‌اند برای تغییر پوشه نرم‌افزارها در دسترس نیست.',
      );
    }

    try {
      final uri = Uri.parse('$baseUrl/api/packages/directory');
      final response = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json; charset=utf-8'},
            body: json.encode({'directory': dir}),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(
          utf8.decode(response.bodyBytes),
        );
        if (data.containsKey('packages_data')) {
          return PackagesResponse.fromJson(data['packages_data']);
        }
        return await fetchPackages();
      }
      throw HttpException(
        'Package directory update returned HTTP ${response.statusCode}.',
        uri: uri,
      );
    } catch (e) {
      debugPrint('[ApiService] setPackagesDirectory error: $e');
      rethrow;
    }
  }

  Future<ToolsDirectoryStatus> getToolsStatus() async {
    final isRunning = await BackendProcessManager.ensureBackendRunning();
    if (!isRunning) return ToolsDirectoryStatus.empty();

    try {
      final uri = Uri.parse('$baseUrl/api/tools/status');
      final response = await _client
          .get(uri)
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(
          utf8.decode(response.bodyBytes),
        );
        return ToolsDirectoryStatus.fromJson(data);
      }
      return ToolsDirectoryStatus.empty();
    } catch (e) {
      debugPrint('[ApiService] getToolsStatus error: $e');
      return ToolsDirectoryStatus.empty();
    }
  }

  Future<bool> setToolsDirectory(String dir) async {
    final isRunning = await BackendProcessManager.ensureBackendRunning();
    if (!isRunning) return false;

    try {
      final uri = Uri.parse('$baseUrl/api/tools/directory');
      final response = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json; charset=utf-8'},
            body: json.encode({'directory': dir}),
          )
          .timeout(const Duration(seconds: 15));

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[ApiService] setToolsDirectory error: $e');
      return false;
    }
  }

  Future<bool> setFilesDirectory(String id, String path) async {
    final isRunning = await BackendProcessManager.ensureBackendRunning();
    if (!isRunning) return false;

    try {
      final uri = Uri.parse('$baseUrl/api/files/directory');
      final response = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json; charset=utf-8'},
            body: json.encode({'id': id, 'path': path}),
          )
          .timeout(const Duration(seconds: 15));

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[ApiService] setFilesDirectory error: $e');
      return false;
    }
  }

  Future<BatteryInfo> fetchBatteryInfo() async {
    final isRunning = await BackendProcessManager.ensureBackendRunning();
    if (!isRunning) return BatteryInfo.empty();

    try {
      final uri = Uri.parse('$baseUrl/api/battery');
      final response = await _client
          .get(uri)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(
          utf8.decode(response.bodyBytes),
        );
        if (data['battery'] is Map<String, dynamic>) {
          return BatteryInfo.fromJson(data['battery'] as Map<String, dynamic>);
        }
      }
      return BatteryInfo.empty();
    } catch (e) {
      debugPrint('[ApiService] fetchBatteryInfo error: $e');
      return BatteryInfo.empty();
    }
  }

  Future<BatteryInfo> testBatteryHealth() async {
    final isRunning = await BackendProcessManager.ensureBackendRunning();
    if (!isRunning) return BatteryInfo.empty();

    try {
      final uri = Uri.parse('$baseUrl/api/battery/test');
      final response = await _client
          .post(uri)
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(
          utf8.decode(response.bodyBytes),
        );
        if (data['battery'] is Map<String, dynamic>) {
          return BatteryInfo.fromJson(data['battery'] as Map<String, dynamic>);
        }
      }
      return BatteryInfo.empty();
    } catch (e) {
      debugPrint('[ApiService] testBatteryHealth error: $e');
      return BatteryInfo.empty();
    }
  }

  // -------------------------------------------------------------
  // Batch Software Installation APIs
  // -------------------------------------------------------------

  Future<Map<String, dynamic>> startBatchInstall({
    List<String>? packageIds,
    String? customDir,
    bool? includeSystemSetup,
  }) async {
    final isRunning = await BackendProcessManager.ensureBackendRunning();
    if (!isRunning) {
      return {'success': false, 'message': 'سرویس بک‌اند در حال اجرا نیست.'};
    }

    try {
      final uri = Uri.parse('$baseUrl/api/packages/batch-install');
      final body = <String, dynamic>{};
      if (packageIds != null && packageIds.isNotEmpty) {
        body['package_ids'] = packageIds;
      }
      if (customDir != null && customDir.isNotEmpty) {
        body['custom_dir'] = customDir;
      }
      if (includeSystemSetup != null) {
        body['include_system_setup'] = includeSystemSetup;
      }

      final response = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json; charset=utf-8'},
            body: json.encode(body),
          )
          .timeout(const Duration(seconds: 15));

      final Map<String, dynamic> data = json.decode(
        utf8.decode(response.bodyBytes),
      );
      return data;
    } catch (e) {
      debugPrint('[ApiService] startBatchInstall error: $e');
      return {'success': false, 'message': 'خطا در شروع نصب خودکار: $e'};
    }
  }

  Future<BatchInstallStatus> getBatchInstallStatus() async {
    final isRunning = await BackendProcessManager.ensureBackendRunning();
    if (!isRunning) {
      throw StateError('سرویس بک‌اند برای دریافت وضعیت نصب در دسترس نیست.');
    }

    try {
      final uri = Uri.parse('$baseUrl/api/packages/batch-status');
      final response = await _client
          .get(uri)
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(
          utf8.decode(response.bodyBytes),
        );
        return BatchInstallStatus.fromJson(data);
      }
      throw HttpException(
        'Software queue status returned HTTP ${response.statusCode}.',
        uri: uri,
      );
    } catch (e) {
      debugPrint('[ApiService] getBatchInstallStatus error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> cancelBatchInstall() async {
    final isRunning = await BackendProcessManager.ensureBackendRunning();
    if (!isRunning) {
      return {'success': false, 'message': 'سرویس بک‌اند در حال اجرا نیست.'};
    }

    try {
      final uri = Uri.parse('$baseUrl/api/packages/batch-cancel');
      final response = await _client
          .post(uri)
          .timeout(const Duration(seconds: 10));

      final Map<String, dynamic> data = json.decode(
        utf8.decode(response.bodyBytes),
      );
      return data;
    } catch (e) {
      debugPrint('[ApiService] cancelBatchInstall error: $e');
      return {'success': false, 'message': 'خطا در لغو نصب خودکار: $e'};
    }
  }

  // -------------------------------------------------------------
  // Driver Folder Batch Installation APIs
  // -------------------------------------------------------------

  Future<Map<String, dynamic>> scanDriverFolder(String folderPath) async {
    final isRunning = await BackendProcessManager.ensureBackendRunning();
    if (!isRunning) {
      return {
        'success': false,
        'message': 'سرویس بک‌اند در حال اجرا نیست.',
        'files': [],
      };
    }

    try {
      final uri = Uri.parse('$baseUrl/api/drivers/scan-folder');
      final response = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json; charset=utf-8'},
            body: json.encode({'folder_path': folderPath}),
          )
          .timeout(const Duration(seconds: 30));

      final Map<String, dynamic> data = json.decode(
        utf8.decode(response.bodyBytes),
      );
      return data;
    } catch (e) {
      debugPrint('[ApiService] scanDriverFolder error: $e');
      return {
        'success': false,
        'message': 'خطا در اسکن پوشه درایورها: $e',
        'files': [],
      };
    }
  }

  Future<Map<String, dynamic>> startDriverBatchInstall(
    String folderPath,
  ) async {
    final isRunning = await BackendProcessManager.ensureBackendRunning();
    if (!isRunning) {
      return {'success': false, 'message': 'سرویس بک‌اند در حال اجرا نیست.'};
    }

    try {
      final uri = Uri.parse('$baseUrl/api/drivers/batch-install');
      final response = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json; charset=utf-8'},
            body: json.encode({'folder_path': folderPath}),
          )
          .timeout(const Duration(seconds: 15));

      final Map<String, dynamic> data = json.decode(
        utf8.decode(response.bodyBytes),
      );
      return data;
    } catch (e) {
      debugPrint('[ApiService] startDriverBatchInstall error: $e');
      return {
        'success': false,
        'message': 'خطا در شروع نصب خودکار درایورها: $e',
      };
    }
  }

  Future<DriverBatchStatus> getDriverBatchStatus() async {
    final isRunning = await BackendProcessManager.ensureBackendRunning();
    if (!isRunning) {
      throw StateError('سرویس بک‌اند برای دریافت وضعیت صف در دسترس نیست.');
    }

    try {
      final uri = Uri.parse('$baseUrl/api/drivers/batch-status');
      final response = await _client
          .get(uri)
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(
          utf8.decode(response.bodyBytes),
        );
        return DriverBatchStatus.fromJson(data);
      }
      throw HttpException(
        'Driver queue status returned HTTP ${response.statusCode}.',
        uri: uri,
      );
    } catch (e) {
      debugPrint('[ApiService] getDriverBatchStatus error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> cancelDriverBatchInstall() async {
    final isRunning = await BackendProcessManager.ensureBackendRunning();
    if (!isRunning) {
      return {'success': false, 'message': 'سرویس بک‌اند در حال اجرا نیست.'};
    }

    try {
      final uri = Uri.parse('$baseUrl/api/drivers/batch-cancel');
      final response = await _client
          .post(uri)
          .timeout(const Duration(seconds: 10));

      final Map<String, dynamic> data = json.decode(
        utf8.decode(response.bodyBytes),
      );
      return data;
    } catch (e) {
      debugPrint('[ApiService] cancelDriverBatchInstall error: $e');
      return {'success': false, 'message': 'خطا در لغو نصب درایورها: $e'};
    }
  }

  // -------------------------------------------------------------
  // Intelligent Driver Manager Endpoints (Phase 5)
  // -------------------------------------------------------------

  Future<Map<String, dynamic>> getDriverDirectoryConfig() async {
    final isRunning = await BackendProcessManager.ensureBackendRunning();
    if (!isRunning) {
      return {
        'exists': false,
        'configured_path': 'Drivers',
        'removable_sources': [],
      };
    }

    try {
      final uri = Uri.parse('$baseUrl/api/drivers/config');
      final response = await _client
          .get(uri)
          .timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        return json.decode(utf8.decode(response.bodyBytes));
      }
      return {
        'exists': false,
        'configured_path': 'Drivers',
        'removable_sources': [],
      };
    } catch (e) {
      debugPrint('[ApiService] getDriverDirectoryConfig error: $e');
      return {
        'exists': false,
        'configured_path': 'Drivers',
        'removable_sources': [],
      };
    }
  }

  Future<Map<String, dynamic>> setDriverDirectoryConfig(String newPath) async {
    final isRunning = await BackendProcessManager.ensureBackendRunning();
    if (!isRunning) {
      return {'success': false, 'message': 'سرویس بک‌اند در حال اجرا نیست.'};
    }

    try {
      final uri = Uri.parse('$baseUrl/api/drivers/config');
      final response = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json; charset=utf-8'},
            body: json.encode({'folder_path': newPath}),
          )
          .timeout(const Duration(seconds: 10));

      return json.decode(utf8.decode(response.bodyBytes));
    } catch (e) {
      debugPrint('[ApiService] setDriverDirectoryConfig error: $e');
      return {'success': false, 'message': 'خطا در ذخیره پوشه درایور: $e'};
    }
  }

  Future<DriverScanResult> intelligentScanDrivers({String? folderPath}) async {
    final isRunning = await BackendProcessManager.ensureBackendRunning();
    if (!isRunning) {
      return DriverScanResult(
        success: false,
        message: 'سرویس بک‌اند در حال اجرا نیست.',
        driverDirectory: folderPath ?? '',
      );
    }

    try {
      final uri = Uri.parse('$baseUrl/api/drivers/scan');
      final response = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json; charset=utf-8'},
            body: json.encode({'folder_path': folderPath ?? ''}),
          )
          .timeout(const Duration(seconds: 120));

      final Map<String, dynamic> data = json.decode(
        utf8.decode(response.bodyBytes),
      );
      return DriverScanResult.fromJson(data);
    } catch (e) {
      debugPrint('[ApiService] intelligentScanDrivers error: $e');
      final String msg;
      if (e is TimeoutException || e.toString().contains('TimeoutException')) {
        msg =
            'زمان پاسخگویی اسکن هوشمند درایورها به پایان رسید. لطفاً مجدداً تلاش کنید یا پوشه مشخص‌تری را انتخاب نمایید.';
      } else {
        msg = 'خطا در اسکن هوشمند درایورها: $e';
      }
      return DriverScanResult(
        success: false,
        message: msg,
        driverDirectory: folderPath ?? '',
      );
    }
  }

  Future<Map<String, dynamic>> startDriverQueueInstall({
    List<String>? packageIds,
    String? folderPath,
    bool resume = false,
  }) async {
    final isRunning = await BackendProcessManager.ensureBackendRunning();
    if (!isRunning) {
      return {'success': false, 'message': 'سرویس بک‌اند در حال اجرا نیست.'};
    }

    try {
      final uri = Uri.parse('$baseUrl/api/drivers/queue/install');
      final Map<String, dynamic> bodyMap = {};
      if (packageIds != null) bodyMap['package_ids'] = packageIds;
      if (folderPath != null) bodyMap['folder_path'] = folderPath;
      bodyMap['resume'] = resume;

      final response = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json; charset=utf-8'},
            body: json.encode(bodyMap),
          )
          .timeout(const Duration(seconds: 15));

      return json.decode(utf8.decode(response.bodyBytes));
    } catch (e) {
      debugPrint('[ApiService] startDriverQueueInstall error: $e');
      return {'success': false, 'message': 'خطا در شروع صف نصب درایورها: $e'};
    }
  }

  Future<DriverBatchStatus> getDriverQueueStatus() async {
    return getDriverBatchStatus();
  }

  Future<Map<String, dynamic>> cancelDriverQueue() async {
    return cancelDriverBatchInstall();
  }

  Future<List<Map<String, dynamic>>> getDriverInstallHistory() async {
    final isRunning = await BackendProcessManager.ensureBackendRunning();
    if (!isRunning) return [];

    try {
      final uri = Uri.parse('$baseUrl/api/drivers/history');
      final response = await _client
          .get(uri)
          .timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        return data.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      debugPrint('[ApiService] getDriverInstallHistory error: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> installDriverInteractive(
    String packageId, {
    String? folderPath,
  }) async {
    final isRunning = await BackendProcessManager.ensureBackendRunning();
    if (!isRunning) {
      return {'success': false, 'message': 'سرویس بک‌اند در حال اجرا نیست.'};
    }

    try {
      final uri = Uri.parse('$baseUrl/api/drivers/install-interactive');
      final Map<String, dynamic> bodyMap = {'package_id': packageId};
      if (folderPath != null) bodyMap['folder_path'] = folderPath;

      final response = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json; charset=utf-8'},
            body: json.encode(bodyMap),
          )
          .timeout(const Duration(seconds: 15));

      return json.decode(utf8.decode(response.bodyBytes));
    } catch (e) {
      debugPrint('[ApiService] installDriverInteractive error: $e');
      return {'success': false, 'message': 'خطا در باز کردن نصاب درایور: $e'};
    }
  }

  Future<Map<String, dynamic>> openDriverFolder(
    String packageId, {
    String? folderPath,
  }) async {
    final isRunning = await BackendProcessManager.ensureBackendRunning();
    if (!isRunning) {
      return {'success': false, 'message': 'سرویس بک‌اند در حال اجرا نیست.'};
    }

    try {
      final uri = Uri.parse('$baseUrl/api/drivers/open-folder');
      final Map<String, dynamic> bodyMap = {'package_id': packageId};
      if (folderPath != null) bodyMap['folder_path'] = folderPath;

      final response = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json; charset=utf-8'},
            body: json.encode(bodyMap),
          )
          .timeout(const Duration(seconds: 10));

      return json.decode(utf8.decode(response.bodyBytes));
    } catch (e) {
      debugPrint('[ApiService] openDriverFolder error: $e');
      return {'success': false, 'message': 'خطا در باز کردن پوشه درایور: $e'};
    }
  }

  // -------------------------------------------------------------
  // USB Flash Storage & Safe Eject APIs
  // -------------------------------------------------------------

  Future<List<UsbDriveInfo>> getConnectedUsbDrives() async {
    final isRunning = await BackendProcessManager.ensureBackendRunning();
    if (!isRunning) return [];

    try {
      final uri = Uri.parse('$baseUrl/api/system/usb-drives');
      final response = await _client
          .get(uri)
          .timeout(const Duration(seconds: 6));
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(
          utf8.decode(response.bodyBytes),
        );
        final List<dynamic> list = data['usb_drives'] ?? [];
        return list
            .map((item) => UsbDriveInfo.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('[ApiService] getConnectedUsbDrives error: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> safeEjectDrive(String driveLetter) async {
    final isRunning = await BackendProcessManager.ensureBackendRunning();
    if (!isRunning) {
      return {'success': false, 'message': 'سرویس بک‌اند در حال اجرا نیست.'};
    }

    try {
      final uri = Uri.parse('$baseUrl/api/system/eject-drive');
      final response = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json; charset=utf-8'},
            body: json.encode({'drive_letter': driveLetter}),
          )
          .timeout(const Duration(seconds: 15));

      final Map<String, dynamic> data = json.decode(
        utf8.decode(response.bodyBytes),
      );
      return data;
    } catch (e) {
      debugPrint('[ApiService] safeEjectDrive error: $e');
      return {'success': false, 'message': 'خطا در خروج ایمن درایو: $e'};
    }
  }

  Future<List<StorageInfo>> fetchStorageInfo() async {
    final isRunning = await BackendProcessManager.ensureBackendRunning();
    if (!isRunning) return [];

    try {
      final uri = Uri.parse('$baseUrl/api/system/storage');
      final response = await _client
          .get(uri)
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(
          utf8.decode(response.bodyBytes),
        );
        final List<dynamic> list = data['storage'] ?? [];
        return list
            .map((item) => StorageInfo.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('[ApiService] fetchStorageInfo error: $e');
      return [];
    }
  }
}
