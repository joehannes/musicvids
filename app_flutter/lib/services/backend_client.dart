import 'dart:convert';
import 'package:http/http.dart' as http;

class BackendClient {
  final String baseUrl;
  BackendClient({this.baseUrl = 'http://127.0.0.1:8787/api'});

  Future<List<String>> listProjects() async {
    final r = await http.get(Uri.parse('$baseUrl/projects'));
    if (r.statusCode >= 400) return [];
    return (jsonDecode(r.body) as List).cast<String>();
  }

  Future<Map<String, dynamic>> getSettings() async {
    final r = await http.get(Uri.parse('$baseUrl/settings'));
    if (r.statusCode >= 400) return {};
    return (jsonDecode(r.body) as Map<String, dynamic>);
  }

  Future<void> saveSettings(Map<String, dynamic> payload) async {
    await http.put(
      Uri.parse('$baseUrl/settings'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
  }
}
