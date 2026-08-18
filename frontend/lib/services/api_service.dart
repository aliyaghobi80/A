import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/system_info.dart';
import '../models/qc_report.dart';
import 'backend_process_manager.dart';

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
        final Map<String, dynamic> data = json.decode(utf8.decode(response.bodyBytes));
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
        final Map<String, dynamic> data = json.decode(utf8.decode(response.bodyBytes));
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
        final Map<String, dynamic> data = json.decode(utf8.decode(response.bodyBytes));
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
}

