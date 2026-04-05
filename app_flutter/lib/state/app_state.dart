import 'dart:convert';

import 'package:flutter/material.dart';

import '../services/backend_client.dart';

class AppState extends ChangeNotifier {
  final BackendClient api = BackendClient();
  List<String> projects = [];
  Map<String, dynamic> settings = {};
  Map<String, dynamic>? activeProject;
  Map<String, dynamic>? lastWorkflowReport;
  String? selectedProject;
  String? error;
  int selectedNavIndex = 0;
  bool loading = false;
  bool backendOnline = false;

  Future<void> bootstrap() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      await api.health();
      backendOnline = true;
      projects = await api.listProjects();
      settings = await api.getSettings();
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

  void setNav(int index) {
    selectedNavIndex = index;
    notifyListeners();
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

  void touch() => notifyListeners();

  Future<void> saveSettings(Map<String, dynamic> payload) async {
    await api.saveSettings(payload);
    settings = jsonDecode(jsonEncode(payload)) as Map<String, dynamic>;
    notifyListeners();
  }
}
