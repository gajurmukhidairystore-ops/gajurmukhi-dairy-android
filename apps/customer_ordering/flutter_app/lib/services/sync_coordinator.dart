import 'dart:convert';
import '../data/database.dart';
import 'cloud_sync_service.dart';

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
