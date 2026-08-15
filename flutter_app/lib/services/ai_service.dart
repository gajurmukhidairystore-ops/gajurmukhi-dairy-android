import 'dart:convert';
import 'package:http/http.dart' as http;

class AiBusinessService {
  final String baseUrl;
  final String authToken;

  AiBusinessService({required this.baseUrl, required this.authToken});

  Future<String> ask({
    required String question,
    required Map<String,dynamic> businessSnapshot,
  }) async {
    final r = await http.post(
      Uri.parse('$baseUrl/api/ai/ask'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $authToken',
      },
      body: jsonEncode({
        'question': question,
        'business_snapshot': businessSnapshot,
      }),
    );
    if (r.statusCode >= 300) throw Exception('AI service unavailable');
    return (jsonDecode(r.body)['answer'] ?? '').toString();
  }
}
