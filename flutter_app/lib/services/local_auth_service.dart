import 'dart:convert';
import 'package:crypto/crypto.dart';

import '../data/database.dart';

class LocalSession {
  final String id;
  final String name;
  final String username;
  final String role;

  const LocalSession({required this.id, required this.name, required this.username, required this.role});
}

class LocalAuthService {
  final AppDatabase db;
  const LocalAuthService(this.db);

  String _hash(String pin) => sha256.convert(utf8.encode(pin)).toString();

  Future<bool> hasUsers() async {
    final rows = await db.query('users', where: 'active=1');
    return rows.isNotEmpty;
  }

  Future<LocalSession> createUser({required String name, required String username, required String pin, required String role}) async {
    if (name.trim().isEmpty || username.trim().isEmpty || pin.length < 4) {
      throw ArgumentError('Name, username, and a four-digit PIN are required.');
    }
    final existing = await db.query('users', where: 'username=?', args: [username.trim().toLowerCase()]);
    if (existing.isNotEmpty) throw StateError('That username already exists.');
    final id = '${DateTime.now().microsecondsSinceEpoch}-${username.trim().toLowerCase()}';
    await db.insert('users', {
      'id': id,
      'name': name.trim(),
      'username': username.trim().toLowerCase(),
      'role': role,
      'pin_hash': _hash(pin),
      'active': 1,
    });
    return LocalSession(id: id, name: name.trim(), username: username.trim().toLowerCase(), role: role);
  }

  Future<LocalSession?> login(String username, String pin) async {
    final rows = await db.query('users', where: 'username=? AND active=1', args: [username.trim().toLowerCase()]);
    if (rows.isEmpty || rows.first['pin_hash'] != _hash(pin)) return null;
    final row = rows.first;
    return LocalSession(id: '${row['id']}', name: '${row['name']}', username: '${row['username']}', role: '${row['role']}');
  }
}
