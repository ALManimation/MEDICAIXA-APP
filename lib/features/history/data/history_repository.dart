import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:drift/drift.dart';
import '../../../core/database/database.dart';
import '../../../core/providers/core_providers.dart';

part 'history_repository.g.dart';

class HistoryRepository {
  final AppDatabase _db;

  HistoryRepository(this._db);

  // Watch all history events sorted by timestamp (newest first)
  Stream<List<HistoryEvent>> watchAllHistoryEvents() {
    return (_db.select(_db.historyEvents)
          ..orderBy([
            (t) => OrderingTerm(expression: t.timestamp, mode: OrderingMode.desc)
          ]))
        .watch();
  }

  // Get all history events
  Future<List<HistoryEvent>> getAllHistoryEvents() async {
    return await (_db.select(_db.historyEvents)
          ..orderBy([
            (t) => OrderingTerm(expression: t.timestamp, mode: OrderingMode.desc)
          ]))
        .get();
  }

  // Add a history event
  Future<void> addHistoryEvent({
    int? alarmId,
    int? reminderId,
    String? medName,
    String? dosage,
    required String status,
    required String type,
    bool pendingSync = false,
  }) async {
    final entry = HistoryEventsCompanion(
      alarmId: Value(alarmId),
      reminderId: Value(reminderId),
      medName: Value(medName),
      dosage: Value(dosage),
      timestamp: Value(DateTime.now().millisecondsSinceEpoch),
      status: Value(status),
      type: Value(type),
      pendingSync: Value(pendingSync),
    );
    await _db.into(_db.historyEvents).insert(entry);
  }

  // Delete a history event by ID
  Future<void> deleteHistoryEvent(int id) async {
    await (_db.delete(_db.historyEvents)..where((t) => t.id.equals(id))).go();
  }

  // Clear all history events
  Future<void> clearHistory() async {
    await _db.delete(_db.historyEvents).go();
  }

  // Watch system logs sorted by timestamp (newest first)
  Stream<List<SystemLog>> watchAllSystemLogs() {
    return (_db.select(_db.systemLogs)
          ..orderBy([
            (t) => OrderingTerm(expression: t.timestamp, mode: OrderingMode.desc)
          ]))
        .watch();
  }

  // Get all system logs
  Future<List<SystemLog>> getAllSystemLogs() async {
    return await (_db.select(_db.systemLogs)
          ..orderBy([
            (t) => OrderingTerm(expression: t.timestamp, mode: OrderingMode.desc)
          ]))
        .get();
  }

  // Add system log
  Future<void> addSystemLog({
    required String level,
    required String message,
    required String source,
  }) async {
    final entry = SystemLogsCompanion(
      timestamp: Value(DateTime.now().millisecondsSinceEpoch),
      level: Value(level),
      message: Value(message),
      source: Value(source),
    );
    await _db.into(_db.systemLogs).insert(entry);
  }

  // Clear all system logs
  Future<void> clearLogs() async {
    await _db.delete(_db.systemLogs).go();
  }
}

@Riverpod(keepAlive: true)
HistoryRepository historyRepository(HistoryRepositoryRef ref) {
  return HistoryRepository(ref.watch(databaseProvider));
}
