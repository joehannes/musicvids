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
    final themesDir = Directory('${base.path}${Platform.pathSeparator}themes');

    for (final dir in [base, settingsDir, projectsDir, cacheDir, themesDir]) {
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
    }
    await _seedThemes(themesDir);
    return base;
  }

  Future<void> _seedThemes(Directory themesDir) async {
    final defaults = <String, Map<String, dynamic>>{
      'midnight_focus.json': {
        'id': 'midnight_focus',
        'name': 'Midnight Focus',
        'mode': 'dark',
        'colors': {
          'primary': '#7C9EFF',
          'secondary': '#80CBC4',
          'background': '#0D1117',
          'surface': '#161B22',
          'error': '#F07178'
        }
      },
      'aurora_light.json': {
        'id': 'aurora_light',
        'name': 'Aurora Light',
        'mode': 'light',
        'colors': {
          'primary': '#3559E0',
          'secondary': '#0E9F6E',
          'background': '#F7FAFC',
          'surface': '#FFFFFF',
          'error': '#D64550'
        }
      },
      'contrast_slate.json': {
        'id': 'contrast_slate',
        'name': 'Contrast Slate',
        'mode': 'dark',
        'colors': {
          'primary': '#A3E635',
          'secondary': '#F59E0B',
          'background': '#0B1020',
          'surface': '#1E293B',
          'error': '#FB7185'
        }
      },
    };
    for (final entry in defaults.entries) {
      final file = File('${themesDir.path}${Platform.pathSeparator}${entry.key}');
      if (!await file.exists()) {
        await file.writeAsString(const JsonEncoder.withIndent('  ').convert(entry.value));
      }
    }
  }

  Future<List<Map<String, dynamic>>> loadThemes() async {
    final base = await ensureAppDirectories();
    final themesDir = Directory('${base.path}${Platform.pathSeparator}themes');
    if (!await themesDir.exists()) {
      return [];
    }
    final themes = <Map<String, dynamic>>[];
    await for (final entity in themesDir.list()) {
      if (entity is! File || !entity.path.endsWith('.json')) continue;
      try {
        final content = await entity.readAsString();
        themes.add((jsonDecode(content) as Map).cast<String, dynamic>());
      } catch (_) {}
    }
    return themes;
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
