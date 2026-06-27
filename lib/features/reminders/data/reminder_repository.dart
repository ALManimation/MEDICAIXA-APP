import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import '../../../core/database/database.dart';
import '../../../core/providers/core_providers.dart';
import 'reminder_api_client.dart';
import 'reminder_model.dart';
import 'dart:convert';
import '../../pairing/presentation/pairing_notifier.dart';
import '../../pairing/domain/connection_state.dart';

part 'reminder_repository.g.dart';

class ReminderRepository {
  final AppDatabase _db;
  final ReminderApiClient _apiClient;
  final Ref _ref;

  ReminderRepository(this._db, this._apiClient, this._ref);

  bool _isConnected() {
    final connState = _ref.read(pairingNotifierProvider);
    return connState.status == ConnectionStatus.connected;
  }

  ReminderModel _toModel(Reminder driftReminder) {
    return ReminderModel(
      id: driftReminder.id,
      title: driftReminder.title,
      description: driftReminder.description,
      enabled: driftReminder.enabled,
      hasTime: driftReminder.hasTime,
      hour: driftReminder.hour,
      minute: driftReminder.minute,
      period: driftReminder.period,
      interval: driftReminder.interval,
      startDate: driftReminder.startDate,
      notifyDaysBefore: driftReminder.notifyDaysBefore,
      lastCompletedDate: driftReminder.lastCompletedDate,
      color: driftReminder.color,
      lastModified: driftReminder.lastModified,
      pendingSync: driftReminder.pendingSync,
    );
  }

  RemindersCompanion _toCompanion(ReminderModel model) {
    return RemindersCompanion(
      id: Value(model.id),
      title: Value(model.title),
      description: Value(model.description),
      enabled: Value(model.enabled),
      hasTime: Value(model.hasTime),
      hour: Value(model.hour),
      minute: Value(model.minute),
      period: Value(model.period),
      interval: Value(model.interval),
      startDate: Value(model.startDate),
      notifyDaysBefore: Value(model.notifyDaysBefore),
      lastCompletedDate: Value(model.lastCompletedDate),
      color: Value(model.color),
      lastModified: Value(model.lastModified),
      pendingSync: Value(model.pendingSync),
    );
  }

  Stream<List<ReminderModel>> watchAllReminders() {
    return _db.select(_db.reminders).watch().map((list) {
      return list.map((driftReminder) => _toModel(driftReminder)).toList();
    });
  }

  Future<List<ReminderModel>> getAllReminders() async {
    final list = await _db.select(_db.reminders).get();
    return list.map((driftReminder) => _toModel(driftReminder)).toList();
  }

  // Watch active reminders for a specific date (Offline-first / Reactive)
  Stream<List<ReminderModel>> watchActiveReminders(DateTime date) {
    return watchAllReminders().map((list) {
      return list.where((r) => isReminderActiveOnDate(r, date)).toList();
    });
  }

  bool isReminderActiveOnDate(ReminderModel r, DateTime dateObj) {
    if (!r.enabled) return false;
    if (r.startDate.isEmpty) return false;

    try {
      final sd = DateTime.parse(r.startDate);
      final target = DateTime(dateObj.year, dateObj.month, dateObj.day);
      final start = DateTime(sd.year, sd.month, sd.day);

      if (target.isBefore(start)) {
        final ndb = r.notifyDaysBefore;
        if (ndb > 0) {
          final diffDays = start.difference(target).inDays;
          return diffDays <= ndb;
        }
        return false;
      }

      if (r.period.isEmpty) {
        return start.year == target.year && start.month == target.month && start.day == target.day;
      }

      final diffDays = target.difference(start).inDays;
      final interval = r.interval == 0 ? 1 : r.interval;

      if (r.period == 'day') {
        return diffDays % interval == 0;
      }
      if (r.period == 'week') {
        return diffDays % (interval * 7) == 0;
      }
      if (r.period == 'month') {
        final mDiff = (target.year - start.year) * 12 + (target.month - start.month);
        return mDiff >= 0 && mDiff % interval == 0 && target.day == start.day;
      }
      if (r.period == 'year') {
        final yDiff = target.year - start.year;
        return yDiff >= 0 && yDiff % interval == 0 && target.month == start.month && target.day == start.day;
      }
    } catch (e) {
      debugPrint("Error parsing start_date: ${r.startDate}");
    }
    return false;
  }

  Future<int> _generateLocalId() async {
    final reminders = await getAllReminders();
    if (reminders.isEmpty) return 256;
    final maxId = reminders.map((e) => e.id).reduce((a, b) => a > b ? a : b);
    return maxId < 256 ? 256 : maxId + 1;
  }

  Future<void> createReminder(ReminderModel reminder) async {
    int finalId = reminder.id;
    bool isPending = false;

    if (_isConnected()) {
      try {
        finalId = await _apiClient.addReminder(reminder);
      } catch (e) {
        debugPrint("Error sending reminder to ESP32: $e. Saving offline.");
        finalId = await _generateLocalId();
        isPending = true;
      }
    } else {
      finalId = await _generateLocalId();
      isPending = true;
    }

    final newModel = ReminderModel(
      id: finalId,
      title: reminder.title,
      description: reminder.description,
      enabled: reminder.enabled,
      hasTime: reminder.hasTime,
      hour: reminder.hour,
      minute: reminder.minute,
      period: reminder.period,
      interval: reminder.interval,
      startDate: reminder.startDate,
      notifyDaysBefore: reminder.notifyDaysBefore,
      lastCompletedDate: reminder.lastCompletedDate,
      color: reminder.color,
      lastModified: DateTime.now().millisecondsSinceEpoch,
      pendingSync: isPending,
    );

    await _db.into(_db.reminders).insert(_toCompanion(newModel));
  }

  Future<void> updateReminder(ReminderModel reminder) async {
    bool isPending = false;

    if (_isConnected()) {
      try {
        await _apiClient.updateReminder(reminder);
      } catch (e) {
        debugPrint("Error updating reminder on ESP32: $e. Marking pending.");
        isPending = true;
      }
    } else {
      isPending = true;
    }

    final updatedModel = ReminderModel(
      id: reminder.id,
      title: reminder.title,
      description: reminder.description,
      enabled: reminder.enabled,
      hasTime: reminder.hasTime,
      hour: reminder.hour,
      minute: reminder.minute,
      period: reminder.period,
      interval: reminder.interval,
      startDate: reminder.startDate,
      notifyDaysBefore: reminder.notifyDaysBefore,
      lastCompletedDate: reminder.lastCompletedDate,
      color: reminder.color,
      lastModified: DateTime.now().millisecondsSinceEpoch,
      pendingSync: isPending,
    );

    await _db.update(_db.reminders).replace(_toCompanion(updatedModel));
  }

  Future<void> deleteReminder(int id) async {
    if (_isConnected()) {
      try {
        await _apiClient.removeReminder(id);
      } catch (e) {
        debugPrint("Error removing reminder on ESP32: $e");
      }
    }
    await (_db.delete(_db.reminders)..where((t) => t.id.equals(id))).go();
  }

  Future<void> toggleReminder(int id, bool enabled) async {
    final list = await (_db.select(_db.reminders)..where((t) => t.id.equals(id))).get();
    if (list.isEmpty) return;

    final reminder = _toModel(list.first);
    final updated = ReminderModel(
      id: reminder.id,
      title: reminder.title,
      description: reminder.description,
      enabled: enabled,
      hasTime: reminder.hasTime,
      hour: reminder.hour,
      minute: reminder.minute,
      period: reminder.period,
      interval: reminder.interval,
      startDate: reminder.startDate,
      notifyDaysBefore: reminder.notifyDaysBefore,
      lastCompletedDate: reminder.lastCompletedDate,
      color: reminder.color,
      lastModified: DateTime.now().millisecondsSinceEpoch,
      pendingSync: !_isConnected(),
    );

    if (_isConnected()) {
      try {
        await _apiClient.toggleReminder(id, enabled);
      } catch (e) {
        debugPrint("Error toggling reminder on ESP32: $e");
      }
    }

    await _db.update(_db.reminders).replace(_toCompanion(updated));
  }

  Future<void> completeReminder(int id) async {
    final list = await (_db.select(_db.reminders)..where((t) => t.id.equals(id))).get();
    if (list.isEmpty) return;

    final reminder = _toModel(list.first);
    final todayStr = "${DateTime.now().day.toString().padLeft(2, '0')}/${DateTime.now().month.toString().padLeft(2, '0')}/${DateTime.now().year}";
    final updated = ReminderModel(
      id: reminder.id,
      title: reminder.title,
      description: reminder.description,
      enabled: reminder.enabled,
      hasTime: reminder.hasTime,
      hour: reminder.hour,
      minute: reminder.minute,
      period: reminder.period,
      interval: reminder.interval,
      startDate: reminder.startDate,
      notifyDaysBefore: reminder.notifyDaysBefore,
      lastCompletedDate: todayStr,
      color: reminder.color,
      lastModified: DateTime.now().millisecondsSinceEpoch,
      pendingSync: !_isConnected(),
    );

    if (_isConnected()) {
      try {
        await _apiClient.completeReminder(id);
      } catch (e) {
        debugPrint("Error completing reminder on ESP32: $e");
      }
    }

    await _db.update(_db.reminders).replace(_toCompanion(updated));
  }

  Future<void> syncWithDevice() async {
    if (!_isConnected()) return;

    try {
      final remoteReminders = await _apiClient.fetchReminders();
      final localReminders = await getAllReminders();

      final localMap = {for (final r in localReminders) r.id: r};
      final remoteMap = {for (final r in remoteReminders) r.id: r};

      // 1. Upload offline modifications
      for (final local in localReminders) {
        if (local.pendingSync) {
          if (local.id >= 256) {
            try {
              final newId = await _apiClient.addReminder(local);
              await deleteReminder(local.id);
              final uploaded = ReminderModel(
                id: newId,
                title: local.title,
                description: local.description,
                enabled: local.enabled,
                hasTime: local.hasTime,
                hour: local.hour,
                minute: local.minute,
                period: local.period,
                interval: local.interval,
                startDate: local.startDate,
                notifyDaysBefore: local.notifyDaysBefore,
                lastCompletedDate: local.lastCompletedDate,
                color: local.color,
                lastModified: DateTime.now().millisecondsSinceEpoch,
                pendingSync: false,
              );
              await _db.into(_db.reminders).insert(_toCompanion(uploaded));
            } catch (e) {
              debugPrint("Failed to upload new local reminder ${local.id}: $e");
            }
          } else {
            try {
              await _apiClient.updateReminder(local);
              await _db.update(_db.reminders).replace(
                    _toCompanion(local.copyWith(pendingSync: false)),
                  );
            } catch (e) {
              debugPrint("Failed to update reminder ${local.id} on device: $e");
            }
          }
        }
      }

      // Re-fetch local list
      final updatedLocalReminders = await getAllReminders();
      final updatedLocalMap = {for (final r in updatedLocalReminders) r.id: r};

      // 2. Pull remote updates
      for (final remote in remoteReminders) {
        final local = updatedLocalMap[remote.id];
        if (local == null) {
          await _db.into(_db.reminders).insert(_toCompanion(remote));
        } else if (!local.pendingSync) {
          await _db.update(_db.reminders).replace(_toCompanion(remote));
        }
      }

      // 3. Clean up deleted reminders
      for (final local in updatedLocalReminders) {
        if (local.id < 256 && !remoteMap.containsKey(local.id) && !local.pendingSync) {
          await (_db.delete(_db.reminders)..where((t) => t.id.equals(local.id))).go();
        }
      }
    } catch (e) {
      debugPrint("Error syncing reminders: $e");
    }
  }

  Future<void> loadBackupFixture(String jsonContent) async {
    try {
      final Map<String, dynamic> data = json.decode(jsonContent);
      if (data.containsKey('reminders') && data['reminders'] is List) {
        final list = data['reminders'] as List;
        await _db.delete(_db.reminders).go();
        for (final item in list) {
          final model = ReminderModel.fromJson(item as Map<String, dynamic>);
          await _db.into(_db.reminders).insert(_toCompanion(model));
        }
      }
    } catch (e) {
      debugPrint("Error loading reminders backup fixture: $e");
    }
  }
}

@Riverpod(keepAlive: true)
ReminderRepository reminderRepository(ReminderRepositoryRef ref) {
  return ReminderRepository(
    ref.watch(databaseProvider),
    ref.watch(reminderApiClientProvider),
    ref,
  );
}

extension ReminderModelCopyWith on ReminderModel {
  ReminderModel copyWith({
    int? id,
    String? title,
    String? description,
    bool? enabled,
    bool? hasTime,
    int? hour,
    int? minute,
    String? period,
    int? interval,
    String? startDate,
    int? notifyDaysBefore,
    String? lastCompletedDate,
    String? color,
    int? lastModified,
    bool? pendingSync,
  }) {
    return ReminderModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      enabled: enabled ?? this.enabled,
      hasTime: hasTime ?? this.hasTime,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      period: period ?? this.period,
      interval: interval ?? this.interval,
      startDate: startDate ?? this.startDate,
      notifyDaysBefore: notifyDaysBefore ?? this.notifyDaysBefore,
      lastCompletedDate: lastCompletedDate ?? this.lastCompletedDate,
      color: color ?? this.color,
      lastModified: lastModified ?? this.lastModified,
      pendingSync: pendingSync ?? this.pendingSync,
    );
  }
}
