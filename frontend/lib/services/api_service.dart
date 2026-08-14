import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/system_info.dart';
import 'backend_process_manager.dart';

class ApiService {
  static const int port = 18080;
  static const String baseUrl = 'http://127.0.0.1:$port';
  static const Duration timeoutDuration = Duration(seconds: 25);

  Future<SystemInfo> fetchSystemInfo({bool forceRefresh = false}) async {
    // Ensure backend is running
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
}
