import 'dart:convert';
import 'dart:io';

class LocalStorageService {
  static const String _appFolder = 'musicvids_studio';

  Future<Directory> _resolveBaseDir() async {
    final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '.';

    if (Platform.isMacOS) {
      return Directory('$home/Library/Application Support/$_appFolder');
    }
    if (Platform.isWindows) {
      final appData = Platform.environment['APPDATA'];
      if (appData != null && appData.isNotEmpty) {
        return Directory('$appData\\$_appFolder');
      }
      return Directory('$home\\AppData\\Roaming\\$_appFolder');
    }

    final xdg = Platform.environment['XDG_CONFIG_HOME'];
    if (xdg != null && xdg.isNotEmpty) {
      return Directory('$xdg/$_appFolder');
    }
    return Directory('$home/.config/$_appFolder');
  }

  Future<Directory> ensureAppDirectories() async {
    final base = await _resolveBaseDir();
    final settingsDir = Directory('${base.path}${Platform.pathSeparator}settings');
    final projectsDir = Directory('${base.path}${Platform.pathSeparator}projects');
    final cacheDir = Directory('${base.path}${Platform.pathSeparator}cache');

    for (final dir in [base, settingsDir, projectsDir, cacheDir]) {
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
    }
    return base;
  }

  Future<File> _settingsFile() async {
    final base = await ensureAppDirectories();
    return File('${base.path}${Platform.pathSeparator}settings${Platform.pathSeparator}settings.json');
  }

  Future<Map<String, dynamic>> loadSettings() async {
    final file = await _settingsFile();
    if (!await file.exists()) {
      return {};
    }

    final content = await file.readAsString();
    if (content.trim().isEmpty) {
      return {};
    }

    return (jsonDecode(content) as Map).cast<String, dynamic>();
  }

  Future<void> saveSettings(Map<String, dynamic> settings) async {
    final file = await _settingsFile();
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(settings),
      flush: true,
    );
  }
}
