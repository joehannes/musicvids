import 'dart:convert';
import 'package:http/http.dart' as http;

class BackendClient {
  final String baseUrl;
  BackendClient({this.baseUrl = 'http://127.0.0.1:8787/api'});

  Future<Map<String, dynamic>> health() async {
    final r = await http.get(Uri.parse('$baseUrl/health')).timeout(const Duration(seconds: 4));
    if (r.statusCode >= 400) {
      throw Exception('backend unavailable (${r.statusCode})');
    }
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<List<String>> listProjects() async {
    final r = await http.get(Uri.parse('$baseUrl/projects')).timeout(const Duration(seconds: 8));
    if (r.statusCode >= 400) return [];
    return (jsonDecode(r.body) as List).cast<String>();
  }

  Future<Map<String, dynamic>> createProject(String name) async {
    final r = await http.post(Uri.parse('$baseUrl/projects/$name')).timeout(const Duration(seconds: 8));
    if (r.statusCode >= 400) {
      throw Exception('failed to create project');
    }
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getProject(String name) async {
    final r = await http.get(Uri.parse('$baseUrl/projects/$name')).timeout(const Duration(seconds: 8));
    if (r.statusCode >= 400) {
      throw Exception('failed to load project');
    }
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<void> saveProject(String name, Map<String, dynamic> payload) async {
    final r = await http.put(
      Uri.parse('$baseUrl/projects/$name'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    ).timeout(const Duration(seconds: 12));
    if (r.statusCode >= 400) {
      throw Exception('failed to save project');
    }
  }

  Future<Map<String, dynamic>> runWorkflow(String name) async {
    final r = await http.post(Uri.parse('$baseUrl/workflow/run/$name')).timeout(const Duration(seconds: 60));
    if (r.statusCode >= 400) {
      throw Exception('workflow failed');
    }
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getSettings() async {
    final r = await http.get(Uri.parse('$baseUrl/settings')).timeout(const Duration(seconds: 8));
    if (r.statusCode >= 400) return {};
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<void> saveSettings(Map<String, dynamic> payload) async {
    final r = await http.put(
      Uri.parse('$baseUrl/settings'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    ).timeout(const Duration(seconds: 8));
    if (r.statusCode >= 400) {
      throw Exception('failed to save settings');
    }
  }
}
