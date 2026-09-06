import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/system_info.dart';
import '../models/qc_report.dart';
import 'backend_process_manager.dart';
import 'cache_service.dart';

class ApiService {
  static String get baseUrl => BackendProcessManager.baseUrl;
  static const Duration timeoutDuration = Duration(seconds: 25);

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
          ? await http.post(uri).timeout(timeoutDuration)
          : await http.get(uri).timeout(timeoutDuration);

      if (response.statusCode == 200) {
        final rawBody = utf8.decode(response.bodyBytes);
        CacheService.saveRawSystemInfoJson(rawBody);
        final Map<String, dynamic> data = json.decode(rawBody);
        return SystemInfo.fromJson(data);
      } else {
        throw Exception('Server returned status ${response.statusCode}: ${response.body}');
      }
    } on TimeoutException {
      throw Exception('System hardware scan timed out. Click Refresh to try again.');
    } catch (e) {
      debugPrint('[ApiService] fetchSystemInfo error: $e');
      rethrow;
    }
  }

  Future<PackagesResponse> fetchPackages({String? customDir}) async {
    final isRunning = await BackendProcessManager.ensureBackendRunning();
    if (!isRunning) {
      return PackagesResponse.empty();
    }

    try {
      final uri = customDir != null && customDir.isNotEmpty
          ? Uri.parse('$baseUrl/api/packages?dir=${Uri.encodeComponent(customDir)}')
          : Uri.parse('$baseUrl/api/packages');

      final response = await http.get(uri).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final rawBody = utf8.decode(response.bodyBytes);
        CacheService.saveRawPackagesJson(rawBody);
        final Map<String, dynamic> data = json.decode(rawBody);
        return PackagesResponse.fromJson(data);
      }
      return PackagesResponse.empty();
    } catch (e) {
      debugPrint('[ApiService] fetchPackages error: $e');
      return PackagesResponse.empty();
    }
  }

  Future<PackagesResponse> scanPackages() async {
    final isRunning = await BackendProcessManager.ensureBackendRunning();
    if (!isRunning) {
      return PackagesResponse.empty();
    }

    try {
      final uri = Uri.parse('$baseUrl/api/packages/scan');
      final response = await http.post(uri).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final rawBody = utf8.decode(response.bodyBytes);
        CacheService.saveRawPackagesJson(rawBody);
        final Map<String, dynamic> data = json.decode(rawBody);
        return PackagesResponse.fromJson(data);
      }
      return PackagesResponse.empty();
    } catch (e) {
      debugPrint('[ApiService] scanPackages error: $e');
      return PackagesResponse.empty();
    }
  }

  Future<Map<String, dynamic>> installPackage(String packageId) async {
    final isRunning = await BackendProcessManager.ensureBackendRunning();
    if (!isRunning) {
      return {
        'success': false,
        'message': 'Backend service is not running.',
      };
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

      final Map<String, dynamic> data = json.decode(utf8.decode(response.bodyBytes));
      return data;
    } catch (e) {
      debugPrint('[ApiService] installPackage error: $e');
      return {
        'success': false,
        'message': 'Error executing package installer: $e',
      };
    }
  }

  Future<Map<String, dynamic>> openPackage(String packageId) async {
    final isRunning = await BackendProcessManager.ensureBackendRunning();
    if (!isRunning) {
      return {
        'success': false,
        'message': 'Backend service is not running.',
      };
    }

    try {
      final uri = Uri.parse('$baseUrl/api/packages/open');
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json; charset=utf-8'},
            body: json.encode({'package_id': packageId}),
          )
          .timeout(const Duration(seconds: 15));

      final Map<String, dynamic> data = json.decode(utf8.decode(response.bodyBytes));
      return data;
    } catch (e) {
      debugPrint('[ApiService] openPackage error: $e');
      return {
        'success': false,
        'message': 'Error opening application: $e',
      };
    }
  }

  Future<Map<String, dynamic>> openOfficeFolder([String? customDir]) async {
    final isRunning = await BackendProcessManager.ensureBackendRunning();
    if (!isRunning) {
      return {
        'success': false,
        'message': 'Backend service is not running.',
      };
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

      final Map<String, dynamic> data = json.decode(utf8.decode(response.bodyBytes));
      return data;
    } catch (e) {
      debugPrint('[ApiService] openOfficeFolder error: $e');
      return {
        'success': false,
        'message': 'Error opening Office folder: $e',
      };
    }
  }

  Future<Map<String, dynamic>> uninstallPackage(String packageId) async {
    final isRunning = await BackendProcessManager.ensureBackendRunning();
    if (!isRunning) {
      return {
        'success': false,
        'message': 'Backend service is not running.',
      };
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

      final Map<String, dynamic> data = json.decode(utf8.decode(response.bodyBytes));
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
      return {
        'success': false,
        'message': 'Backend service is not running.',
      };
    }

    try {
      final uri = Uri.parse('$baseUrl/api/proxy/disable');
      final response = await http
          .post(uri, headers: {'Content-Type': 'application/json; charset=utf-8'})
          .timeout(const Duration(seconds: 10));

      final Map<String, dynamic> data = json.decode(utf8.decode(response.bodyBytes));
      return data;
    } catch (e) {
      debugPrint('[ApiService] disableProxy error: $e');
      return {
        'success': false,
        'message': 'Error disabling proxy: $e',
      };
    }
  }

  Future<Map<String, dynamic>> restartSystem({int delaySeconds = 3, String reason = ''}) async {
    final isRunning = await BackendProcessManager.ensureBackendRunning();
    if (!isRunning) {
      return {
        'success': false,
        'message': 'Backend service is not running.',
      };
    }

    try {
      final uri = Uri.parse('$baseUrl/api/reboot/restart');
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json; charset=utf-8'},
            body: json.encode({'delay_seconds': delaySeconds, 'reason': reason}),
          )
          .timeout(const Duration(seconds: 10));

      final Map<String, dynamic> data = json.decode(utf8.decode(response.bodyBytes));
      return data;
    } catch (e) {
      debugPrint('[ApiService] restartSystem error: $e');
      return {
        'success': false,
        'message': 'Error restarting system: $e',
      };
    }
  }

  Future<Map<String, dynamic>> cancelRestart() async {
    final isRunning = await BackendProcessManager.ensureBackendRunning();
    if (!isRunning) {
      return {
        'success': false,
        'message': 'Backend service is not running.',
      };
    }

    try {
      final uri = Uri.parse('$baseUrl/api/reboot/cancel');
      final response = await http
          .post(uri, headers: {'Content-Type': 'application/json; charset=utf-8'})
          .timeout(const Duration(seconds: 10));

      final Map<String, dynamic> data = json.decode(utf8.decode(response.bodyBytes));
      return data;
    } catch (e) {
      debugPrint('[ApiService] cancelRestart error: $e');
      return {
        'success': false,
        'message': 'Error cancelling restart: $e',
      };
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
          .post(uri, headers: {'Content-Type': 'application/json; charset=utf-8'})
          .timeout(const Duration(minutes: 4));

      final Map<String, dynamic> data = json.decode(utf8.decode(response.bodyBytes));
      return ActivationResult.fromJson(data);
    } catch (e) {
      debugPrint('[ApiService] activateWindows error: $e');
      return ActivationResult.error('خطا در ارتباط با سرور فعالسازی: $e');
    }
  }

  Future<ActivationResult> activateOffice() async {
    final isRunning = await BackendProcessManager.ensureBackendRunning();
    if (!isRunning) {
      return ActivationResult.error('Backend service is not running.');
    }

    try {
      final uri = Uri.parse('$baseUrl/api/activation/office');
      final response = await http
          .post(uri, headers: {'Content-Type': 'application/json; charset=utf-8'})
          .timeout(const Duration(minutes: 4));

      final Map<String, dynamic> data = json.decode(utf8.decode(response.bodyBytes));
      return ActivationResult.fromJson(data);
    } catch (e) {
      debugPrint('[ApiService] activateOffice error: $e');
      return ActivationResult.error('خطا در ارتباط با سرور فعالسازی: $e');
    }
  }

  Future<QcReport> fetchQcStatus() async {
    final isRunning = await BackendProcessManager.ensureBackendRunning();
    if (!isRunning) {
      return QcReport.empty();
    }

    try {
      final uri = Uri.parse('$baseUrl/api/qc/status');
      final response = await http.get(uri).timeout(timeoutDuration);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(utf8.decode(response.bodyBytes));
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
      final response = await http.post(uri).timeout(timeoutDuration);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(utf8.decode(response.bodyBytes));
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
    if (!isRunning) return PackagesResponse.empty();

    try {
      final uri = Uri.parse('$baseUrl/api/packages/directory');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: json.encode({'directory': dir}),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        if (data.containsKey('packages_data')) {
          return PackagesResponse.fromJson(data['packages_data']);
        }
      }
      return await fetchPackages();
    } catch (e) {
      debugPrint('[ApiService] setPackagesDirectory error: $e');
      return PackagesResponse.empty();
    }
  }

  Future<ToolsDirectoryStatus> getToolsStatus() async {
    final isRunning = await BackendProcessManager.ensureBackendRunning();
    if (!isRunning) return ToolsDirectoryStatus.empty();

    try {
      final uri = Uri.parse('$baseUrl/api/tools/status');
      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(utf8.decode(response.bodyBytes));
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
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: json.encode({'directory': dir}),
      ).timeout(const Duration(seconds: 15));

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
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: json.encode({'id': id, 'path': path}),
      ).timeout(const Duration(seconds: 15));

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
      final response = await http.get(uri).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(utf8.decode(response.bodyBytes));
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
      final response = await http.post(uri).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(utf8.decode(response.bodyBytes));
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

  Future<Map<String, dynamic>> startBatchInstall({List<String>? packageIds, String? customDir}) async {
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

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: json.encode(body),
      ).timeout(const Duration(seconds: 15));

      final Map<String, dynamic> data = json.decode(utf8.decode(response.bodyBytes));
      return data;
    } catch (e) {
      debugPrint('[ApiService] startBatchInstall error: $e');
      return {'success': false, 'message': 'خطا در شروع نصب خودکار: $e'};
    }
  }

  Future<BatchInstallStatus> getBatchInstallStatus() async {
    final isRunning = await BackendProcessManager.ensureBackendRunning();
    if (!isRunning) return BatchInstallStatus.empty();

    try {
      final uri = Uri.parse('$baseUrl/api/packages/batch-status');
      final response = await http.get(uri).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        return BatchInstallStatus.fromJson(data);
      }
      return BatchInstallStatus.empty();
    } catch (e) {
      debugPrint('[ApiService] getBatchInstallStatus error: $e');
      return BatchInstallStatus.empty();
    }
  }

  Future<Map<String, dynamic>> cancelBatchInstall() async {
    final isRunning = await BackendProcessManager.ensureBackendRunning();
    if (!isRunning) {
      return {'success': false, 'message': 'سرویس بک‌اند در حال اجرا نیست.'};
    }

    try {
      final uri = Uri.parse('$baseUrl/api/packages/batch-cancel');
      final response = await http.post(uri).timeout(const Duration(seconds: 10));

      final Map<String, dynamic> data = json.decode(utf8.decode(response.bodyBytes));
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
      return {'success': false, 'message': 'سرویس بک‌اند در حال اجرا نیست.', 'files': []};
    }

    try {
      final uri = Uri.parse('$baseUrl/api/drivers/scan-folder');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: json.encode({'folder_path': folderPath}),
      ).timeout(const Duration(seconds: 30));

      final Map<String, dynamic> data = json.decode(utf8.decode(response.bodyBytes));
      return data;
    } catch (e) {
      debugPrint('[ApiService] scanDriverFolder error: $e');
      return {'success': false, 'message': 'خطا در اسکن فولدر درایورها: $e', 'files': []};
    }
  }

  Future<Map<String, dynamic>> startDriverBatchInstall(String folderPath) async {
    final isRunning = await BackendProcessManager.ensureBackendRunning();
    if (!isRunning) {
      return {'success': false, 'message': 'سرویس بک‌اند در حال اجرا نیست.'};
    }

    try {
      final uri = Uri.parse('$baseUrl/api/drivers/batch-install');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: json.encode({'folder_path': folderPath}),
      ).timeout(const Duration(seconds: 15));

      final Map<String, dynamic> data = json.decode(utf8.decode(response.bodyBytes));
      return data;
    } catch (e) {
      debugPrint('[ApiService] startDriverBatchInstall error: $e');
      return {'success': false, 'message': 'خطا در شروع نصب خودکار درایورها: $e'};
    }
  }

  Future<DriverBatchStatus> getDriverBatchStatus() async {
    final isRunning = await BackendProcessManager.ensureBackendRunning();
    if (!isRunning) return DriverBatchStatus.empty();

    try {
      final uri = Uri.parse('$baseUrl/api/drivers/batch-status');
      final response = await http.get(uri).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        return DriverBatchStatus.fromJson(data);
      }
      return DriverBatchStatus.empty();
    } catch (e) {
      debugPrint('[ApiService] getDriverBatchStatus error: $e');
      return DriverBatchStatus.empty();
    }
  }

  Future<Map<String, dynamic>> cancelDriverBatchInstall() async {
    final isRunning = await BackendProcessManager.ensureBackendRunning();
    if (!isRunning) {
      return {'success': false, 'message': 'سرویس بک‌اند در حال اجرا نیست.'};
    }

    try {
      final uri = Uri.parse('$baseUrl/api/drivers/batch-cancel');
      final response = await http.post(uri).timeout(const Duration(seconds: 10));

      final Map<String, dynamic> data = json.decode(utf8.decode(response.bodyBytes));
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
    if (!isRunning) return {'exists': false, 'configured_path': 'Drivers', 'removable_sources': []};

    try {
      final uri = Uri.parse('$baseUrl/api/drivers/config');
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        return json.decode(utf8.decode(response.bodyBytes));
      }
      return {'exists': false, 'configured_path': 'Drivers', 'removable_sources': []};
    } catch (e) {
      debugPrint('[ApiService] getDriverDirectoryConfig error: $e');
      return {'exists': false, 'configured_path': 'Drivers', 'removable_sources': []};
    }
  }

  Future<Map<String, dynamic>> setDriverDirectoryConfig(String newPath) async {
    final isRunning = await BackendProcessManager.ensureBackendRunning();
    if (!isRunning) return {'success': false, 'message': 'سرویس بک‌اند در حال اجرا نیست.'};

    try {
      final uri = Uri.parse('$baseUrl/api/drivers/config');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: json.encode({'folder_path': newPath}),
      ).timeout(const Duration(seconds: 10));

      return json.decode(utf8.decode(response.bodyBytes));
    } catch (e) {
      debugPrint('[ApiService] setDriverDirectoryConfig error: $e');
      return {'success': false, 'message': 'خطا در ذخیره پوشه درایور: $e'};
    }
  }

  Future<DriverScanResult> intelligentScanDrivers({String? folderPath}) async {
    final isRunning = await BackendProcessManager.ensureBackendRunning();
    if (!isRunning) {
      return DriverScanResult(success: false, message: 'سرویس بک‌اند در حال اجرا نیست.', driverDirectory: folderPath ?? '');
    }

    try {
      final uri = Uri.parse('$baseUrl/api/drivers/scan');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: json.encode({'folder_path': folderPath ?? ''}),
      ).timeout(const Duration(seconds: 45));

      final Map<String, dynamic> data = json.decode(utf8.decode(response.bodyBytes));
      return DriverScanResult.fromJson(data);
    } catch (e) {
      debugPrint('[ApiService] intelligentScanDrivers error: $e');
      return DriverScanResult(success: false, message: 'خطا در اسکن هوشمند درایورها: $e', driverDirectory: folderPath ?? '');
    }
  }

  Future<Map<String, dynamic>> startDriverQueueInstall({List<String>? packageIds, String? folderPath}) async {
    final isRunning = await BackendProcessManager.ensureBackendRunning();
    if (!isRunning) return {'success': false, 'message': 'سرویس بک‌اند در حال اجرا نیست.'};

    try {
      final uri = Uri.parse('$baseUrl/api/drivers/queue/install');
      final Map<String, dynamic> bodyMap = {};
      if (packageIds != null) bodyMap['package_ids'] = packageIds;
      if (folderPath != null) bodyMap['folder_path'] = folderPath;

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: json.encode(bodyMap),
      ).timeout(const Duration(seconds: 15));

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
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
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
}
