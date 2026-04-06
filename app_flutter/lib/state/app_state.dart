import 'dart:convert';

import 'package:flutter/material.dart';

import '../services/backend_client.dart';
import '../services/backend_runtime_service.dart';
import '../services/local_storage_service.dart';
import '../services/theme_schema_service.dart';

class AppState extends ChangeNotifier {
  AppState();

  final BackendClient api = BackendClient();
  final BackendRuntimeService backendRuntime = const BackendRuntimeService();
  final LocalStorageService localStorage = LocalStorageService();

  static const Map<String, String> defaultShortcutBindings = {
    'navigate.left': 'n h',
    'navigate.right': 'n l',
    'navigate.up': 'n k',
    'navigate.down': 'n j',
    'canvas.note.new': 'x n',
    'canvas.center': 'x c',
    'navigate.dashboard': 'n d',
    'navigate.projects': 'n p',
    'navigate.lyrics': 'n y',
    'navigate.channels': 'n c',
    'navigate.storyboard': 'n b',
    'navigate.characters': 'n a',
    'navigate.generation': 'n g',
    'navigate.preview': 'n v',
    'navigate.upload': 'n u',
    'project.new': 'p n',
    'project.open': 'p o',
    'project.save': 'p s',
    'project.refresh': 'p r',
    'channel.new': 'c n',
    'channel.sync': 'c s',
    'channel.update': 'c u',
    'lyrics.new': 'y n',
    'lyrics.delete': 'y d',
    'lyrics.chapter': 'y c',
    'storyboard.scene.new': 'b n',
    'character.new': 'a n',
    'generation.run': 'g r',
    'generation.next': 'g n',
    'generation.prev': 'g p',
    'settings.open': 's o',
  };

  static const Map<String, Map<String, String>> defaultShortcutMeta = {
    'navigate.left': {'category': 'Navigation', 'label': 'Previous screen', 'description': 'Cycle to previous fullscreen screen'},
    'navigate.right': {'category': 'Navigation', 'label': 'Next screen', 'description': 'Cycle to next fullscreen screen'},
    'navigate.up': {'category': 'Canvas', 'label': 'Pan up within current screen', 'description': 'Move the current screen canvas up'},
    'navigate.down': {'category': 'Canvas', 'label': 'Pan down within current screen', 'description': 'Move the current screen canvas down'},
    'canvas.note.new': {'category': 'Canvas', 'label': 'Add note widget', 'description': 'Add a new draggable note to this screen'},
    'canvas.center': {'category': 'Canvas', 'label': 'Re-center canvas', 'description': 'Reset current screen pan offset'},
    'navigate.dashboard': {'category': 'Navigation', 'label': 'Jump to Dashboard'},
    'navigate.projects': {'category': 'Navigation', 'label': 'Jump to Projects'},
    'navigate.lyrics': {'category': 'Navigation', 'label': 'Jump to Lyrics'},
    'navigate.channels': {'category': 'Navigation', 'label': 'Jump to Channels'},
    'navigate.storyboard': {'category': 'Navigation', 'label': 'Jump to Storyboard'},
    'navigate.characters': {'category': 'Navigation', 'label': 'Jump to Characters'},
    'navigate.generation': {'category': 'Navigation', 'label': 'Jump to Generation'},
    'navigate.preview': {'category': 'Navigation', 'label': 'Jump to Preview'},
    'navigate.upload': {'category': 'Navigation', 'label': 'Jump to Upload'},
    'project.new': {'category': 'Project', 'label': 'Create project'},
    'project.open': {'category': 'Project', 'label': 'Open first project'},
    'project.save': {'category': 'Project', 'label': 'Save active project'},
    'project.refresh': {'category': 'Project', 'label': 'Refresh backend/projects'},
    'channel.new': {'category': 'Channel', 'label': 'Create channel'},
    'channel.sync': {'category': 'Channel', 'label': 'Sync channels'},
    'channel.update': {'category': 'Channel', 'label': 'Update channel'},
    'lyrics.new': {'category': 'Lyrics', 'label': 'Add lyric section'},
    'lyrics.delete': {'category': 'Lyrics', 'label': 'Delete last lyric section'},
    'lyrics.chapter': {'category': 'Lyrics', 'label': 'Next chapter'},
    'storyboard.scene.new': {'category': 'Storyboard', 'label': 'Add scene'},
    'character.new': {'category': 'Characters', 'label': 'Add character'},
    'generation.run': {'category': 'Generation', 'label': 'Run full workflow'},
    'generation.next': {'category': 'Generation', 'label': 'Next generation slot'},
    'generation.prev': {'category': 'Generation', 'label': 'Previous generation slot'},
    'settings.open': {'category': 'Settings', 'label': 'Open settings dialog'},
  };

  List<String> projects = [];
  Map<String, dynamic> settings = {};
  Map<String, dynamic>? activeProject;
  Map<String, dynamic>? lastWorkflowReport;
  String? selectedProject;
  String? error;
  bool loading = false;
  bool backendOnline = false;
  int selectedEpisodeIndex = 0;

  final Map<String, String> shortcutBindings = {...defaultShortcutBindings};
  final Map<String, Map<String, String>> shortcutMeta = {...defaultShortcutMeta};
  List<Map<String, String>> customShortcuts = [];
  List<Map<String, dynamic>> themes = [];
  String activeThemeId = 'midnight_focus';
  ThemeData activeTheme = ThemeData.dark(useMaterial3: true);

  Future<void> bootstrap() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      await localStorage.ensureAppDirectories();
      try {
        await backendRuntime.ensureBackendRunning().timeout(const Duration(seconds: 15));
      } catch (_) {}
      await api.health();
      backendOnline = true;
      projects = await api.listProjects();

      final backendSettings = await api.getSettings();
      final localSettings = await localStorage.loadSettings();
      settings = _mergeSettings(backendSettings, localSettings);
      _hydrateShortcutBindings(settings);
      await _hydrateThemes(settings);

      if (projects.isNotEmpty) {
        await loadProject(projects.first);
      }
    } catch (e) {
      backendOnline = false;
      error = 'Backend startup failed at http://127.0.0.1:8787. Check local backend logs and click Refresh.';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> refreshProjects() async {
    projects = await api.listProjects();
    notifyListeners();
  }

  Future<void> createProject(String name) async {
    if (name.trim().isEmpty) return;
    final created = await api.createProject(name.trim());
    projects = await api.listProjects();
    selectedProject = created['name'] as String?;
    activeProject = created;
    notifyListeners();
  }

  Future<void> loadProject(String name) async {
    selectedProject = name;
    activeProject = await api.getProject(name);
    notifyListeners();
  }

  Future<void> saveActiveProject() async {
    if (selectedProject == null || activeProject == null) return;
    await api.saveProject(selectedProject!, activeProject!);
    notifyListeners();
  }

  Future<void> runWorkflow() async {
    if (selectedProject == null) return;
    loading = true;
    error = null;
    notifyListeners();
    try {
      lastWorkflowReport = await api.runWorkflow(selectedProject!);
    } catch (e) {
      error = 'Workflow execution failed: $e';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void nextEpisode() {
    selectedEpisodeIndex += 1;
    notifyListeners();
  }

  void previousEpisode() {
    if (selectedEpisodeIndex > 0) {
      selectedEpisodeIndex -= 1;
      notifyListeners();
    }
  }

  void touch() => notifyListeners();

  Future<void> saveSettings(Map<String, dynamic> payload) async {
    final prepared = jsonDecode(jsonEncode(payload)) as Map<String, dynamic>;
    _hydrateShortcutBindings(prepared);
    await _hydrateThemes(prepared);
    await api.saveSettings(prepared);
    await localStorage.saveSettings(prepared);
    settings = prepared;
    notifyListeners();
  }

  Future<void> _hydrateThemes(Map<String, dynamic> sourceSettings) async {
    themes = await localStorage.loadThemes();
    final ui = (sourceSettings['ui'] as Map?)?.cast<String, dynamic>() ?? {};
    final theme = (ui['theme'] as Map?)?.cast<String, dynamic>() ?? {};
    activeThemeId = theme['active']?.toString() ?? activeThemeId;
    final selected = themes.firstWhere(
      (entry) => entry['id']?.toString() == activeThemeId,
      orElse: () => themes.isNotEmpty ? themes.first : {'id': 'midnight_focus', 'mode': 'dark', 'colors': {}},
    );
    activeThemeId = selected['id']?.toString() ?? activeThemeId;
    activeTheme = ThemeSchemaService.buildTheme(selected);
    sourceSettings['ui'] = {
      ...ui,
      'theme': {'active': activeThemeId},
    };
  }

  Map<String, dynamic> _mergeSettings(Map<String, dynamic> backendSettings, Map<String, dynamic> localSettings) {
    final merged = <String, dynamic>{
      ...jsonDecode(jsonEncode(backendSettings)) as Map<String, dynamic>,
      ...jsonDecode(jsonEncode(localSettings)) as Map<String, dynamic>,
    };

    final backendShortcuts = ((backendSettings['ui'] as Map?)?['shortcuts'] as Map?)?.cast<String, dynamic>() ?? {};
    final localShortcuts = ((localSettings['ui'] as Map?)?['shortcuts'] as Map?)?.cast<String, dynamic>() ?? {};
    final shortcuts = <String, dynamic>{...backendShortcuts, ...localShortcuts};

    final ui = ((merged['ui'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{});
    ui['shortcuts'] = shortcuts;
    merged['ui'] = ui;
    return merged;
  }

  void _hydrateShortcutBindings(Map<String, dynamic> sourceSettings) {
    shortcutBindings
      ..clear()
      ..addAll(defaultShortcutBindings);
    final ui = (sourceSettings['ui'] as Map?)?.cast<String, dynamic>() ?? {};
    final configured = (ui['shortcuts'] as Map?)?.cast<String, dynamic>() ?? {};
    for (final entry in configured.entries) {
      final shortcut = entry.value.toString().trim();
      if (shortcut.isNotEmpty) {
        shortcutBindings[entry.key] = shortcut;
      }
    }
    final customConfigured = (ui['custom_shortcuts'] as List?)
            ?.whereType<Map>()
            .map((e) => e.map((key, value) => MapEntry(key.toString(), value.toString())))
            .toList() ??
        <Map<String, String>>[];
    customShortcuts = customConfigured;

    sourceSettings['ui'] = {
      ...ui,
      'shortcuts': shortcutBindings,
      'custom_shortcuts': customShortcuts,
    };
  }
}
