import 'dart:convert';
import 'package:http/http.dart' as http;

class CloudSyncService {
  final String baseUrl;
  final String token;

  CloudSyncService({required this.baseUrl, required this.token});

  Future<void> push(Map<String,dynamic> payload) async {
    final r = await http.post(
      Uri.parse('$baseUrl/api/sync/push'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token'
      },
      body: jsonEncode(payload),
    );
    if (r.statusCode >= 300) {
      throw Exception('Cloud sync failed: ${r.statusCode}');
    }
  }

  Future<Map<String,dynamic>> pull(String since) async {
    final r = await http.get(
      Uri.parse('$baseUrl/api/sync/pull?since=$since'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (r.statusCode >= 300) throw Exception('Cloud pull failed');
    return jsonDecode(r.body) as Map<String,dynamic>;
  }
}
