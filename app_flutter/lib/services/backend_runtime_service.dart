import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

class BackendRuntimeService {
  const BackendRuntimeService();

  static const String defaultHealthUrl = 'http://127.0.0.1:8787/api/health';

  Future<void> ensureBackendRunning() async {
    if (!Platform.isLinux && !Platform.isMacOS && !Platform.isWindows) {
      return;
    }

    if (await _isHealthy()) {
      return;
    }

    final script = _candidateLaunchScripts().firstWhere(
      (candidate) => File(candidate).existsSync(),
      orElse: () => '',
    );

    if (script.isNotEmpty) {
      await Process.start(
        script,
        const [],
        mode: ProcessStartMode.detached,
        runInShell: true,
      );
    } else {
      await _fallbackLaunchFromRepo();
    }

    final deadline = DateTime.now().add(const Duration(seconds: 12));
    while (DateTime.now().isBefore(deadline)) {
      if (await _isHealthy()) {
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }
  }

  List<String> _candidateLaunchScripts() {
    final executableDir = File(Platform.resolvedExecutable).parent.path;
    return [
      '$executableDir/backend/start_backend.sh',
      '/opt/musicvids-studio/backend/start_backend.sh',
      '${Directory.current.path}/backend_python/start_backend.sh',
    ];
  }

  Future<void> _fallbackLaunchFromRepo() async {
    final command =
        'cd "${Directory.current.path}" && python3 -m uvicorn backend_python.app.main:app --host 127.0.0.1 --port 8787';
    await Process.start(
      'bash',
      ['-lc', command],
      mode: ProcessStartMode.detached,
      runInShell: true,
    );
  }

  Future<bool> _isHealthy() async {
    try {
      final response = await http.get(Uri.parse(defaultHealthUrl)).timeout(const Duration(seconds: 2));
      return response.statusCode < 400;
    } catch (_) {
      return false;
    }
  }
}
