import 'dart:convert';

import 'package:flutter/material.dart';

import '../services/backend_client.dart';
import '../services/local_storage_service.dart';

class AppState extends ChangeNotifier {
  AppState();

  final BackendClient api = BackendClient();
  final LocalStorageService localStorage = LocalStorageService();

  static const Map<String, String> defaultShortcutBindings = {
    'navigate.left': 'n h',
    'navigate.right': 'n l',
    'navigate.up': 'n k',
    'navigate.down': 'n j',
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

  Future<void> bootstrap() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      await localStorage.ensureAppDirectories();
      await api.health();
      backendOnline = true;
      projects = await api.listProjects();

      final backendSettings = await api.getSettings();
      final localSettings = await localStorage.loadSettings();
      settings = _mergeSettings(backendSettings, localSettings);
      _hydrateShortcutBindings(settings);

      if (projects.isNotEmpty) {
        await loadProject(projects.first);
      }
    } catch (e) {
      backendOnline = false;
      error = 'Backend not reachable at http://127.0.0.1:8787. Start backend and click Refresh.';
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
    await api.saveSettings(prepared);
    await localStorage.saveSettings(prepared);
    settings = prepared;
    notifyListeners();
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

    sourceSettings['ui'] = {
      ...ui,
      'shortcuts': shortcutBindings,
    };
  }
}
