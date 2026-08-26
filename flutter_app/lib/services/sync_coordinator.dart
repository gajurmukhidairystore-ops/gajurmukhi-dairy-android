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

class SyncReport {
  final int received;
  final DateTime serverTime;
  final int pendingAfterPush;
  const SyncReport({required this.received, required this.serverTime, required this.pendingAfterPush});
}

class AuthenticatedSyncCoordinator {
  final AppDatabase db;
  final MobileCloudService cloud;
  final CloudSession session;
  AuthenticatedSyncCoordinator({required this.db, required this.cloud, required this.session});

  Future<SyncReport> syncNow({DateTime? since}) async {
    var pending = await db.pendingSync();
    while (pending.isNotEmpty) {
      final batch = pending.take(200).toList();
      final response = await cloud.push(session.token, batch.map((row) => buildSyncEnvelope(Map<String, dynamic>.from(row))).toList());
      final accepted = (response['accepted'] as List? ?? const []).map((value) => '$value').toSet();
      for (final row in batch) {
        if (accepted.contains('${row['id']}')) await db.markSynced('${row['id']}');
      }
      if (accepted.isEmpty) break;
      pending = await db.pendingSync();
    }
    final pendingAfterPush = pending.length;
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
    final serverTime = DateTime.tryParse('${pull['serverTime'] ?? ''}')?.toUtc() ?? DateTime.now().toUtc();
    return SyncReport(received: records.length, serverTime: serverTime, pendingAfterPush: pendingAfterPush);
  }
}
