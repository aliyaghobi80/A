import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class BackendProcessManager {
  static Process? _process;
  static int activePort = 18080;
  static const List<int> candidatePorts = [18080, 18088, 18089];

  static String get baseUrl => 'http://127.0.0.1:$activePort';

  static Future<bool> isBackendRunningOnPort(int port) async {
    try {
      final response = await http
          .get(Uri.parse('http://127.0.0.1:$port/api/health'))
          .timeout(const Duration(milliseconds: 1200));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final isOk = data['status'] == 'ok';
        final isSupported = data['phase'] != null || data['version'] != null;
        if (isOk && isSupported) {
          return true;
        }
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
    // 1. Check if an active Phase 2 backend is already running on any candidate port
    for (final port in candidatePorts) {
      if (await isBackendRunningOnPort(port)) {
        activePort = port;
        debugPrint('[BackendProcessManager] Connected to active Phase 2 backend on port $activePort.');
        return true;
      }
    }

    final scriptPath = findBackendScript();
    if (scriptPath == null) {
      debugPrint('[BackendProcessManager] backend/main.py could not be located.');
      return false;
    }

    final scriptFile = File(scriptPath);
    // Use repository root as working directory so relative config/Packages paths work
    final workDir = scriptFile.parent.parent.path;
    debugPrint('[BackendProcessManager] Spawning backend script: $scriptPath with workingDir: $workDir');

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

    final targetPort = activePort;
    bool started = false;

    for (final cmd in pythonCommands) {
      try {
        debugPrint('[BackendProcessManager] Attempting to spawn backend with "$cmd" on port $targetPort...');
        _process = await Process.start(
          cmd,
          [scriptFile.path, '--port', '$targetPort'],
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
      if (await isBackendRunningOnPort(targetPort)) {
        activePort = targetPort;
        debugPrint('[BackendProcessManager] Backend is UP and responding on port $activePort.');
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

    if (Platform.isWindows) {
      try {
        await Process.run('powershell.exe', [
          '-NoProfile',
          '-Command',
          'Get-NetTCPConnection -LocalPort 18088,18080 -ErrorAction SilentlyContinue | Select-Object -ExpandProperty OwningProcess | ForEach-Object { Stop-Process -Id \$_ -Force -ErrorAction SilentlyContinue }',
        ]);
      } catch (_) {}
    }
  }
}
