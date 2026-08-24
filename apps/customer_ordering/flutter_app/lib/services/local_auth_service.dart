import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

import '../data/database.dart';

String hashPinValue(String pin) => sha256.convert(utf8.encode(pin)).toString();

class LocalSession {
  final String id;
  final String name;
  final String username;
  final String role;

  const LocalSession({required this.id, required this.name, required this.username, required this.role});
}

class LocalAuthService {
  final AppDatabase db;
  final LocalAuthentication biometric;
  final FlutterSecureStorage secureStorage;

  LocalAuthService(
    this.db, {
    LocalAuthentication? biometric,
    FlutterSecureStorage? secureStorage,
  })  : biometric = biometric ?? LocalAuthentication(),
        secureStorage = secureStorage ?? const FlutterSecureStorage();

  static const _biometricEnabledKey = 'gajurmukhi_biometric_enabled';
  static const _biometricUsernameKey = 'gajurmukhi_biometric_username';
  static const _biometricPinHashKey = 'gajurmukhi_biometric_pin_hash';

  String hashPin(String pin) => hashPinValue(pin);

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
      'pin_hash': hashPin(pin),
      'active': 1,
    });
    return LocalSession(id: id, name: name.trim(), username: username.trim().toLowerCase(), role: role);
  }

  Future<LocalSession?> login(String username, String pin) async {
    final rows = await db.query('users', where: 'username=? AND active=1', args: [username.trim().toLowerCase()]);
    if (rows.isEmpty || rows.first['pin_hash'] != hashPin(pin)) return null;
    return _sessionFromRow(rows.first);
  }

  Future<bool> isBiometricAvailable() async {
    try {
      final supported = await biometric.isDeviceSupported();
      final enrolled = await biometric.canCheckBiometrics;
      return supported && enrolled;
    } catch (_) {
      return false;
    }
  }

  Future<bool> hasBiometricLogin() async {
    final values = await Future.wait([
      secureStorage.read(key: _biometricEnabledKey),
      secureStorage.read(key: _biometricUsernameKey),
      secureStorage.read(key: _biometricPinHashKey),
    ]);
    return values[0] == 'true' && values[1]?.isNotEmpty == true && values[2]?.isNotEmpty == true;
  }

  Future<bool> enableBiometric(LocalSession session, String pin) async {
    if (!await isBiometricAvailable()) return false;
    final authenticated = await _authenticate();
    if (!authenticated) return false;
    await secureStorage.write(key: _biometricUsernameKey, value: session.username);
    await secureStorage.write(key: _biometricPinHashKey, value: hashPin(pin));
    await secureStorage.write(key: _biometricEnabledKey, value: 'true');
    return true;
  }

  Future<LocalSession?> loginWithBiometric() async {
    if (!await hasBiometricLogin()) return null;
    if (!await isBiometricAvailable()) return null;
    if (!await _authenticate()) return null;
    final username = await secureStorage.read(key: _biometricUsernameKey);
    final pinHash = await secureStorage.read(key: _biometricPinHashKey);
    if (username == null || pinHash == null) return null;
    final rows = await db.query('users', where: 'username=? AND active=1', args: [username]);
    if (rows.isEmpty || rows.first['pin_hash'] != pinHash) {
      await clearBiometricLogin();
      return null;
    }
    return _sessionFromRow(rows.first);
  }

  Future<void> clearBiometricLogin() async {
    await secureStorage.delete(key: _biometricEnabledKey);
    await secureStorage.delete(key: _biometricUsernameKey);
    await secureStorage.delete(key: _biometricPinHashKey);
  }

  Future<bool> _authenticate() => biometric.authenticate(
        localizedReason: 'Verify your identity to open Gajurmukhi',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );

  LocalSession _sessionFromRow(Map<String, Object?> row) => LocalSession(
        id: '${row['id']}',
        name: '${row['name']}',
        username: '${row['username']}',
        role: '${row['role']}',
      );
}
