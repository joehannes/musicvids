import 'dart:convert';

import 'package:flutter/material.dart';

import '../services/backend_client.dart';

class AppState extends ChangeNotifier {
  final BackendClient api = BackendClient();
  List<String> projects = [];
  Map<String, dynamic> settings = {};
  String? selectedProject;
  bool loading = false;

  Future<void> bootstrap() async {
    loading = true;
    notifyListeners();
    projects = await api.listProjects();
    settings = await api.getSettings();
    loading = false;
    notifyListeners();
  }

  Future<void> saveSettings(Map<String, dynamic> payload) async {
    await api.saveSettings(payload);
    settings = jsonDecode(jsonEncode(payload));
    notifyListeners();
  }
}
