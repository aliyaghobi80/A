import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class BackendProcessManager {
  static Process? _process;
  static int activePort = 18088;
  static const List<int> candidatePorts = [18088, 18080, 18089];

  static String get baseUrl => 'http://127.0.0.1:$activePort';

  static Future<bool> isBackendRunningOnPort(int port) async {
    try {
      final response = await http
          .get(Uri.parse('http://127.0.0.1:$port/api/health'))
          .timeout(const Duration(milliseconds: 1500));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'ok') {
          return true;
        }
      }
    } catch (_) {}
    return false;
  }

  static String? findStandaloneBackendExe() {
    final List<String> searchRoots = [];

    try {
      final exeFile = File(Platform.resolvedExecutable);
      Directory current = exeFile.parent;
      for (int i = 0; i < 6; i++) {
        searchRoots.add(current.path);
        final parent = current.parent;
        if (parent.path == current.path) break;
        current = parent;
      }
    } catch (_) {}

    try {
      Directory current = Directory.current;
      for (int i = 0; i < 6; i++) {
        if (!searchRoots.contains(current.path)) {
          searchRoots.add(current.path);
        }
        final parent = current.parent;
        if (parent.path == current.path) break;
        current = parent;
      }
    } catch (_) {}

    for (final root in searchRoots) {
      final candidates = [
        '$root/backend/backend_server.exe',
        '$root/backend_server.exe',
        '$root/build_backend_out/dist/backend_server.exe',
        '$root/dist/backend_server.exe',
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

  static String? findBackendScript() {
    final List<String> searchRoots = [];

    try {
      final exeFile = File(Platform.resolvedExecutable);
      Directory current = exeFile.parent;
      for (int i = 0; i < 6; i++) {
        searchRoots.add(current.path);
        final parent = current.parent;
        if (parent.path == current.path) break;
        current = parent;
      }
    } catch (_) {}

    try {
      Directory current = Directory.current;
      for (int i = 0; i < 6; i++) {
        if (!searchRoots.contains(current.path)) {
          searchRoots.add(current.path);
        }
        final parent = current.parent;
        if (parent.path == current.path) break;
        current = parent;
      }
    } catch (_) {}

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
    // 1. Check if backend is already running on any candidate port
    for (final port in candidatePorts) {
      if (await isBackendRunningOnPort(port)) {
        activePort = port;
        debugPrint('[BackendProcessManager] Connected to active backend on port $activePort.');
        return true;
      }
    }

    final targetPort = activePort;
    bool started = false;

    // 2. Production: Try starting standalone packaged backend_server.exe
    final standaloneExe = findStandaloneBackendExe();
    if (standaloneExe != null) {
      try {
        final exeFile = File(standaloneExe);
        final workDir = exeFile.parent.path.endsWith('backend')
            ? exeFile.parent.parent.path
            : exeFile.parent.path;

        debugPrint('[BackendProcessManager] Launching standalone backend: $standaloneExe on port $targetPort with workingDir: $workDir');
        _process = await Process.start(
          standaloneExe,
          ['--port', '$targetPort'],
          workingDirectory: workDir,
          mode: ProcessStartMode.detached,
        );
        started = true;
      } catch (e) {
        debugPrint('[BackendProcessManager] Failed to launch standalone backend binary: $e');
      }
    }

    // 3. Development Fallback: Try launching python script if standalone binary is not found
    if (!started) {
      final scriptPath = findBackendScript();
      if (scriptPath != null) {
        final scriptFile = File(scriptPath);
        final workDir = scriptFile.parent.parent.path;
        debugPrint('[BackendProcessManager] Launching development backend script: $scriptPath with workingDir: $workDir');

        final pythonCommands = ['pythonw', 'python', 'py'];
        for (final cmd in pythonCommands) {
          try {
            debugPrint('[BackendProcessManager] Attempting python start with "$cmd" on port $targetPort...');
            _process = await Process.start(
              cmd,
              [scriptFile.path, '--port', '$targetPort'],
              workingDirectory: workDir,
              mode: ProcessStartMode.detached,
            );
            started = true;
            break;
          } catch (_) {}
        }
      }
    }

    if (!started) {
      debugPrint('[BackendProcessManager] Could not start backend service.');
      return false;
    }

    // 4. Wait up to 10 seconds for backend to respond to health checks
    for (int i = 0; i < 20; i++) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (await isBackendRunningOnPort(targetPort)) {
        activePort = targetPort;
        debugPrint('[BackendProcessManager] Backend is UP and healthy on port $activePort.');
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

  static Future<void> terminateAll() async {
    try {
      _process?.kill();
    } catch (_) {}
  }
}
