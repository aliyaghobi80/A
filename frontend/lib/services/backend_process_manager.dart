import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class BackendProcessManager {
  static Process? _process;
  static const int port = 18080;
  static const String baseUrl = 'http://127.0.0.1:$port';

  static Future<bool> isBackendRunning() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/api/health'))
          .timeout(const Duration(milliseconds: 1500));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['status'] == 'ok';
      }
    } catch (_) {}
    return false;
  }

  static String? findBackendScript() {
    final List<String> searchRoots = [];

    try {
      // 1. From the executable path
      final exeFile = File(Platform.resolvedExecutable);
      Directory current = exeFile.parent;
      for (int i = 0; i < 10; i++) {
        searchRoots.add(current.path);
        final parent = current.parent;
        if (parent.path == current.path) break;
        current = parent;
      }
    } catch (_) {}

    try {
      // 2. From Directory.current
      Directory current = Directory.current;
      for (int i = 0; i < 10; i++) {
        if (!searchRoots.contains(current.path)) {
          searchRoots.add(current.path);
        }
        final parent = current.parent;
        if (parent.path == current.path) break;
        current = parent;
      }
    } catch (_) {}

    // Check candidate locations
    for (final root in searchRoots) {
      final candidates = [
        '$root/backend/main.py',
        '$root/data/backend/main.py',
        '$root/main.py',
      ];

      for (final candidate in candidates) {
        final file = File(candidate);
        if (file.existsSync()) {
          return file.absolute.path;
        }
      }
    }

    return null;
  }

  static Future<bool> ensureBackendRunning() async {
    if (await isBackendRunning()) {
      return true;
    }

    final scriptPath = findBackendScript();
    if (scriptPath == null) {
      debugPrint('[BackendProcessManager] backend/main.py could not be located.');
      return false;
    }

    final scriptFile = File(scriptPath);
    final workDir = scriptFile.parent.path;
    debugPrint('[BackendProcessManager] Found backend at: $scriptPath');

    // List of python executable commands to try
    final pythonCommands = [
      'python',
      'pythonw',
      'py',
      r'G:\python\python.exe',
      r'C:\Python312\python.exe',
      r'C:\Python311\python.exe',
      r'C:\Python310\python.exe',
      r'C:\Python314\python.exe',
      r'C:\Program Files\Python312\python.exe',
      r'C:\Program Files\Python311\python.exe',
    ];

    bool started = false;

    for (final cmd in pythonCommands) {
      try {
        debugPrint('[BackendProcessManager] Attempting to spawn backend with "$cmd"...');
        _process = await Process.start(
          cmd,
          [scriptFile.path, '--port', '$port'],
          workingDirectory: workDir,
          mode: ProcessStartMode.detached,
        );
        started = true;
        break;
      } catch (e) {
        debugPrint('[BackendProcessManager] Failed with command "$cmd": $e');
      }
    }

    if (!started) {
      debugPrint('[BackendProcessManager] Could not spawn python process with any known command.');
      return false;
    }

    // Wait up to 10 seconds for backend to become available
    for (int i = 0; i < 20; i++) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (await isBackendRunning()) {
        debugPrint('[BackendProcessManager] Backend is UP and responding on port $port.');
        return true;
      }
    }

    return false;
  }

  static void dispose() {
    try {
      _process?.kill();
    } catch (_) {}
  }
}
