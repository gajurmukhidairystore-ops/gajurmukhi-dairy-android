import 'dart:convert';
import '../data/database.dart';
import 'cloud_sync_service.dart';
import 'mobile_cloud_service.dart';

Map<String, dynamic> buildSyncEnvelope(Map<String, dynamic> row) {
  final payload = jsonDecode('${row['payload']}');
  return {
    'sync_id': row['id'],
    'entity': row['entity'],
    'entity_id': row['entity_id'],
    'operation': row['operation'],
    'payload': payload,
    'created_at': row['created_at'],
  };
}

class SyncCoordinator {
  final AppDatabase db;
  final CloudSyncService cloud;
  SyncCoordinator({required this.db, required this.cloud});

  Future<int> pushPending() async {
    var synced = 0;
    final pending = await db.pendingSync();
    for (final row in pending) {
      try {
        await cloud.push(buildSyncEnvelope(row));
        await db.markSynced('${row['id']}');
        synced++;
      } catch (_) {
        break;
      }
    }
    return synced;
  }

  Future<Map<String, dynamic>> pullSince(DateTime since) => cloud.pull(since.toUtc().toIso8601String());
}

class AuthenticatedSyncCoordinator {
  final AppDatabase db;
  final MobileCloudService cloud;
  final CloudSession session;
  AuthenticatedSyncCoordinator({required this.db, required this.cloud, required this.session});

  Future<int> syncNow({DateTime? since}) async {
    final pending = await db.pendingSync();
    if (pending.isNotEmpty) {
      final response = await cloud.push(session.token, pending.map((row) => buildSyncEnvelope(Map<String, dynamic>.from(row))).toList());
      final accepted = (response['accepted'] as List? ?? const []).map((value) => '$value').toSet();
      for (final row in pending) {
        if (accepted.contains('${row['id']}')) await db.markSynced('${row['id']}');
      }
    }
    final pull = await cloud.pull(session.token, since ?? DateTime.fromMillisecondsSinceEpoch(0));
    final records = (pull['records'] as List? ?? const []);
    for (final raw in records) {
      final record = Map<String, dynamic>.from(raw as Map);
      await db.applyCloudRecord(
        entity: '${record['entity']}',
        recordId: '${record['entity_id']}',
        operation: '${record['operation']}',
        payload: Map<String, dynamic>.from(record['payload'] as Map? ?? const {}),
      );
    }
    return records.length;
  }
}
