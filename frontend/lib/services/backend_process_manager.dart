import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class BackendProcessManager {
  static Process? _process;
  static Future<bool>? _startupFuture;
  static int activePort = 18088;
  static const List<int> candidatePorts = [18088, 18080, 18089, 18090, 18091];
  static const int requiredApiContractVersion = 2;

  static String get baseUrl => 'http://127.0.0.1:$activePort';

  static Future<bool> isBackendRunningOnPort(
    int port, [
    Duration timeout = const Duration(milliseconds: 250),
  ]) async {
    try {
      final response = await http
          .get(Uri.parse('http://127.0.0.1:$port/api/health'))
          .timeout(timeout);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final contractVersion = data['api_contract_version'];
        if (data['status'] == 'ok' &&
            contractVersion is num &&
            contractVersion.toInt() >= requiredApiContractVersion) {
          return true;
        }
        if (data['status'] == 'ok') {
          debugPrint(
            '[BackendProcessManager] Ignoring incompatible backend on port $port.',
          );
        }
      }
    } catch (_) {}
    return false;
  }

  static Future<bool> isPortAvailable(int port) async {
    try {
      final socket = await ServerSocket.bind(
        InternetAddress.loopbackIPv4,
        port,
        shared: false,
      );
      await socket.close();
      return true;
    } catch (_) {
      return false;
    }
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
        '$root/build_backend_out/dist/backend_server/backend_server.exe',
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
    final activeStartup = _startupFuture;
    if (activeStartup != null) {
      return activeStartup;
    }

    final startup = _ensureBackendRunning();
    _startupFuture = startup;
    try {
      return await startup;
    } finally {
      if (identical(_startupFuture, startup)) {
        _startupFuture = null;
      }
    }
  }

  static Future<bool> _ensureBackendRunning() async {
    // 1. Fast check: Check default activePort first (120ms)
    if (await isBackendRunningOnPort(
      activePort,
      const Duration(milliseconds: 120),
    )) {
      debugPrint(
        '[BackendProcessManager] Connected to active backend on port $activePort.',
      );
      return true;
    }

    // Parallel check across all candidate ports (~180ms max)
    final portChecks = await Future.wait(
      candidatePorts.map((p) async {
        if (p == activePort) return null;
        return (await isBackendRunningOnPort(
              p,
              const Duration(milliseconds: 180),
            ))
            ? p
            : null;
      }),
    );
    for (final port in portChecks) {
      if (port != null) {
        activePort = port;
        debugPrint(
          '[BackendProcessManager] Connected to active backend on port $activePort.',
        );
        return true;
      }
    }

    int? targetPort;
    for (final port in candidatePorts) {
      if (await isPortAvailable(port)) {
        targetPort = port;
        break;
      }
    }
    if (targetPort == null) {
      debugPrint('[BackendProcessManager] No available backend port found.');
      return false;
    }
    activePort = targetPort;
    bool started = false;

    // 2. Production: Try starting standalone packaged backend_server.exe
    final standaloneExe = findStandaloneBackendExe();
    if (standaloneExe != null) {
      try {
        final exeFile = File(standaloneExe);
        final workDir = exeFile.parent.path.endsWith('backend')
            ? exeFile.parent.parent.path
            : exeFile.parent.path;

        debugPrint(
          '[BackendProcessManager] Launching standalone backend: $standaloneExe on port $targetPort with workingDir: $workDir',
        );
        _process = await Process.start(
          standaloneExe,
          ['--port', '$targetPort', '--parent-pid', '$pid'],
          workingDirectory: workDir,
          mode: ProcessStartMode.detached,
        );
        started = true;
      } catch (e) {
        debugPrint(
          '[BackendProcessManager] Failed to launch standalone backend binary: $e',
        );
      }
    }

    // 3. Development Fallback: Try launching python script if standalone binary is not found
    if (!started) {
      final scriptPath = findBackendScript();
      if (scriptPath != null) {
        final scriptFile = File(scriptPath);
        final workDir = scriptFile.parent.parent.path;
        debugPrint(
          '[BackendProcessManager] Launching development backend script: $scriptPath with workingDir: $workDir',
        );

        final pythonCommands = ['pythonw', 'python', 'py'];
        for (final cmd in pythonCommands) {
          try {
            debugPrint(
              '[BackendProcessManager] Attempting python start with "$cmd" on port $targetPort...',
            );
            _process = await Process.start(
              cmd,
              [
                scriptFile.path,
                '--port',
                '$targetPort',
                '--parent-pid',
                '$pid',
              ],
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

    // 4. Resilient adaptive polling for backend startup (supports slow laptops & HDDs on fresh Windows)
    for (int i = 0; i < 70; i++) {
      final delayMs = i < 8 ? 100 : (i < 20 ? 300 : 500);
      await Future.delayed(Duration(milliseconds: delayMs));

      final checkTimeout = i < 8
          ? const Duration(milliseconds: 250)
          : const Duration(milliseconds: 1200);

      // Prioritize targetPort first
      if (await isBackendRunningOnPort(targetPort, checkTimeout)) {
        activePort = targetPort;
        debugPrint(
          '[BackendProcessManager] Backend is UP and healthy on port $activePort (iteration $i).',
        );
        return true;
      }

      // Check candidate ports in case backend auto-selected a fallback
      if (i >= 4) {
        for (final port in candidatePorts) {
          if (port == targetPort) continue;
          if (await isBackendRunningOnPort(port, checkTimeout)) {
            activePort = port;
            debugPrint(
              '[BackendProcessManager] Backend is UP on fallback port $activePort (iteration $i).',
            );
            return true;
          }
        }
      }
    }

    return false;
  }

  static Future<void> shutdownBackend() async {
    for (final port in candidatePorts) {
      try {
        await http
            .get(Uri.parse('http://127.0.0.1:$port/api/shutdown'))
            .timeout(const Duration(milliseconds: 600));
      } catch (_) {}
    }
    try {
      _process?.kill(ProcessSignal.sigkill);
    } catch (_) {}
    if (Platform.isWindows) {
      try {
        Process.runSync('taskkill.exe', [
          '/F',
          '/IM',
          'backend_server.exe',
          '/T',
        ], runInShell: false);
      } catch (_) {}
    }
  }

  static void dispose() {
    shutdownBackend();
  }

  static Future<void> terminateAll() async {
    await shutdownBackend();
  }
}
