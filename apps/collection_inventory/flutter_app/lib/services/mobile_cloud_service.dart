import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class CloudAccount {
  final String id;
  final String workspaceId;
  final String username;
  final String displayName;
  final String role;

  const CloudAccount({required this.id, required this.workspaceId, required this.username, required this.displayName, required this.role});

  factory CloudAccount.fromJson(Map<String, dynamic> json) => CloudAccount(
        id: '${json['id']}',
        workspaceId: '${json['workspaceId']}',
        username: '${json['username']}',
        displayName: '${json['displayName']}',
        role: '${json['role']}',
      );
}

class CloudSession {
  final String token;
  final DateTime expiresAt;
  final CloudAccount account;

  const CloudSession({required this.token, required this.expiresAt, required this.account});
}

class MobileCloudService {
  static const String baseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'https://gajurdairy-awcu8lwj.manus.space');
  static const _tokenKey = 'gajurmukhi_cloud_session_token';
  static const _expiresKey = 'gajurmukhi_cloud_session_expires';
  static const _accountKey = 'gajurmukhi_cloud_session_account';

  final FlutterSecureStorage storage;
  final http.Client client;

  MobileCloudService({FlutterSecureStorage? storage, http.Client? client}) : storage = storage ?? const FlutterSecureStorage(), client = client ?? http.Client();

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  Future<CloudSession> registerAdmin({required String workspaceName, required String displayName, required String username, required String pin, String deviceId = ''}) async {
    final body = await _post('/api/mobile/register-admin', {'workspaceName': workspaceName, 'displayName': displayName, 'username': username, 'pin': pin, 'deviceId': deviceId});
    return _saveSession(body);
  }

  Future<CloudSession> login({required String username, required String pin, String deviceId = ''}) async {
    final body = await _post('/api/mobile/login', {'username': username, 'pin': pin, 'deviceId': deviceId});
    return _saveSession(body);
  }

  Future<CloudSession?> savedSession() async {
    final values = await Future.wait([storage.read(key: _tokenKey), storage.read(key: _expiresKey), storage.read(key: _accountKey)]);
    if (values.any((value) => value == null || value.isEmpty)) return null;
    final expiry = DateTime.tryParse(values[1]!);
    if (expiry == null || expiry.isBefore(DateTime.now())) { await clearSession(); return null; }
    final account = CloudAccount.fromJson(jsonDecode(values[2]!) as Map<String, dynamic>);
    return CloudSession(token: values[0]!, expiresAt: expiry, account: account);
  }

  Future<void> clearSession() async {
    await storage.delete(key: _tokenKey);
    await storage.delete(key: _expiresKey);
    await storage.delete(key: _accountKey);
  }

  Future<Map<String, dynamic>> push(String token, List<Map<String, dynamic>> records) => _post('/api/mobile/sync/push', {'records': records}, token: token);

  Future<CloudAccount> createUser({required String displayName, required String username, required String pin, required String role}) async {
    final session = await savedSession();
    if (session == null) throw StateError('Sign in to the shared cloud before creating role accounts.');
    final body = await _post('/api/mobile/users', {'displayName': displayName, 'username': username, 'pin': pin, 'role': role}, token: session.token);
    return CloudAccount.fromJson(body['account'] as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> pull(String token, DateTime since) => _get('/api/mobile/sync/pull?since=${Uri.encodeQueryComponent(since.toUtc().toIso8601String())}', token: token);

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> payload, {String? token}) async {
    final response = await client.post(_uri(path), headers: {'Content-Type': 'application/json', if (token != null) 'Authorization': 'Bearer $token'}, body: jsonEncode(payload));
    return _decode(response);
  }

  Future<Map<String, dynamic>> _get(String path, {required String token}) async => _decode(await client.get(_uri(path), headers: {'Authorization': 'Bearer $token'}));

  Map<String, dynamic> _decode(http.Response response) {
    final body = response.body.isEmpty ? <String, dynamic>{} : jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 300) throw StateError('${body['error'] ?? 'Cloud service is unavailable.'}');
    return body;
  }

  Future<CloudSession> _saveSession(Map<String, dynamic> body) async {
    final session = body['session'] as Map<String, dynamic>;
    final account = CloudAccount.fromJson(body['account'] as Map<String, dynamic>);
    final result = CloudSession(token: '${session['token']}', expiresAt: DateTime.parse('${session['expiresAt']}'), account: account);
    await storage.write(key: _tokenKey, value: result.token);
    await storage.write(key: _expiresKey, value: result.expiresAt.toIso8601String());
    await storage.write(key: _accountKey, value: jsonEncode({'id': account.id, 'workspaceId': account.workspaceId, 'username': account.username, 'displayName': account.displayName, 'role': account.role}));
    return result;
  }
}
