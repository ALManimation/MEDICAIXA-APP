import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../core/database/database.dart';
import '../../../core/providers/core_providers.dart';
import 'alarm_api_client.dart';
import 'alarm_model.dart';
import '../../../core/providers/connection_providers.dart';
import '../../pairing/domain/connection_state.dart';

import '../../history/data/history_repository.dart';

part 'alarm_repository.g.dart';

class AlarmRepository {
  final AppDatabase _db;
  final AlarmApiClient _apiClient;
  final Ref _ref;

  AlarmRepository(this._db, this._apiClient, this._ref);

  bool _isConnected() {
    final connState = _ref.read(deviceConnectionStateProvider);
    return connState.status == ConnectionStatus.connected;
  }

  // Convert Drift entity to AlarmModel
  AlarmModel _toModel(Alarm driftAlarm) {
    List<bool> parseBools(String jsonStr) {
      try {
        return (json.decode(jsonStr) as List).cast<bool>();
      } catch (e) {
        return List.filled(7, true);
      }
    }

    List<double> parseDoubles(String jsonStr) {
      try {
        return (json.decode(jsonStr) as List).map((e) => (e as num).toDouble()).toList();
      } catch (e) {
        return List.filled(7, 0.0);
      }
    }

    List<TaperStage>? parseTaperStages(String? jsonStr) {
      if (jsonStr == null) return null;
      try {
        return (json.decode(jsonStr) as List)
            .map((e) => TaperStage.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (e) {
        return null;
      }
    }

    return AlarmModel(
      id: driftAlarm.id,
      hour: driftAlarm.hour,
      minute: driftAlarm.minute,
      name: driftAlarm.name,
      medName: driftAlarm.medName,
      enabled: driftAlarm.enabled,
      active: driftAlarm.active,
      days: parseBools(driftAlarm.days),
      status: driftAlarm.status,
      color: driftAlarm.color,
      quantity: driftAlarm.quantity,
      daysQuantity: parseDoubles(driftAlarm.daysQuantity),
      type: driftAlarm.type,
      dosage: driftAlarm.dosage,
      lastStatus: driftAlarm.lastStatus,
      lastStatusDate: driftAlarm.lastStatusDate,
      snoozeMin: driftAlarm.snoozeMin,
      startDate: driftAlarm.startDate,
      durationDays: driftAlarm.durationDays,
      createdDate: driftAlarm.createdDate,
      cycleOnDays: driftAlarm.cycleOnDays,
      cycleOffDays: driftAlarm.cycleOffDays,
      cycleCurrentDay: driftAlarm.cycleCurrentDay,
      cycleIsPaused: driftAlarm.cycleIsPaused,
      isPrn: driftAlarm.isPrn,
      prnMinIntervalHours: driftAlarm.prnMinIntervalHours,
      prnMaxDailyDoses: driftAlarm.prnMaxDailyDoses,
      prnDosesToday: driftAlarm.prnDosesToday,
      pauseUntil: driftAlarm.pauseUntil,
      isDynamic: driftAlarm.isDynamic,
      dynamicInstruction: driftAlarm.dynamicInstruction,
      taperStageCount: driftAlarm.taperStageCount,
      taperCurrentStage: driftAlarm.taperCurrentStage,
      taperDayInStage: driftAlarm.taperDayInStage,
      taperStages: parseTaperStages(driftAlarm.taperStages),
      taperLoop: driftAlarm.taperLoop,
      specialInstruction: driftAlarm.specialInstruction,
      adjustStep: driftAlarm.adjustStep,
      adjustIntervalDays: driftAlarm.adjustIntervalDays,
      adjustLimit: driftAlarm.adjustLimit,
      requiresRemoval: driftAlarm.requiresRemoval,
      removalDelayMins: driftAlarm.removalDelayMins,
      siteRotationList: driftAlarm.siteRotationList,
      currentSiteIndex: driftAlarm.currentSiteIndex,
      dayOfMonth: driftAlarm.dayOfMonth,
      groupId: driftAlarm.groupId,
      intervalHours: driftAlarm.intervalHours,
      intervalDays: driftAlarm.intervalDays,
      intervalCountdown: driftAlarm.intervalCountdown,
      lastModified: driftAlarm.lastModified,
      pendingSync: driftAlarm.pendingSync,
    );
  }

  // Convert AlarmModel to Drift companion
  AlarmsCompanion _toCompanion(AlarmModel model) {
    return AlarmsCompanion(
      id: Value(model.id),
      hour: Value(model.hour),
      minute: Value(model.minute),
      name: Value(model.name),
      medName: Value(model.medName),
      enabled: Value(model.enabled),
      active: Value(model.active),
      days: Value(json.encode(model.days)),
      status: Value(model.status),
      color: Value(model.color),
      quantity: Value(model.quantity),
      daysQuantity: Value(json.encode(model.daysQuantity)),
      type: Value(model.type),
      dosage: Value(model.dosage),
      lastStatus: Value(model.lastStatus),
      lastStatusDate: Value(model.lastStatusDate),
      snoozeMin: Value(model.snoozeMin),
      startDate: Value(model.startDate),
      durationDays: Value(model.durationDays),
      createdDate: Value(model.createdDate),
      cycleOnDays: Value(model.cycleOnDays),
      cycleOffDays: Value(model.cycleOffDays),
      cycleCurrentDay: Value(model.cycleCurrentDay),
      cycleIsPaused: Value(model.cycleIsPaused),
      isPrn: Value(model.isPrn),
      prnMinIntervalHours: Value(model.prnMinIntervalHours),
      prnMaxDailyDoses: Value(model.prnMaxDailyDoses),
      prnDosesToday: Value(model.prnDosesToday),
      pauseUntil: Value(model.pauseUntil),
      isDynamic: Value(model.isDynamic),
      dynamicInstruction: Value(model.dynamicInstruction),
      taperStageCount: Value(model.taperStageCount),
      taperCurrentStage: Value(model.taperCurrentStage),
      taperDayInStage: Value(model.taperDayInStage),
      taperStages: Value(model.taperStages != null
          ? json.encode(model.taperStages!.map((e) => e.toJson()).toList())
          : null),
      taperLoop: Value(model.taperLoop),
      specialInstruction: Value(model.specialInstruction),
      adjustStep: Value(model.adjustStep),
      adjustIntervalDays: Value(model.adjustIntervalDays),
      adjustLimit: Value(model.adjustLimit),
      requiresRemoval: Value(model.requiresRemoval),
      removalDelayMins: Value(model.removalDelayMins),
      siteRotationList: Value(model.siteRotationList),
      currentSiteIndex: Value(model.currentSiteIndex),
      dayOfMonth: Value(model.dayOfMonth),
      groupId: Value(model.groupId),
      intervalHours: Value(model.intervalHours),
      intervalDays: Value(model.intervalDays),
      intervalCountdown: Value(model.intervalCountdown),
      lastModified: Value(model.lastModified),
      pendingSync: Value(model.pendingSync),
    );
  }

  Stream<List<AlarmModel>> watchAllAlarms() {
    final query = _db.select(_db.alarms).join([
      leftOuterJoin(_db.medications, _db.medications.name.equalsExp(_db.alarms.medName)),
    ]);
    return query.watch().map((rows) {
      return rows.map((row) {
        final driftAlarm = row.readTable(_db.alarms);
        final medication = row.readTableOrNull(_db.medications);
        final resolvedColor = medication != null ? medication.color : driftAlarm.color;
        return _toModel(driftAlarm).copyWith(color: resolvedColor);
      }).toList();
    });
  }

  Future<List<AlarmModel>> getAllAlarms() async {
    final query = _db.select(_db.alarms).join([
      leftOuterJoin(_db.medications, _db.medications.name.equalsExp(_db.alarms.medName)),
    ]);
    final rows = await query.get();
    return rows.map((row) {
      final driftAlarm = row.readTable(_db.alarms);
      final medication = row.readTableOrNull(_db.medications);
      final resolvedColor = medication != null ? medication.color : driftAlarm.color;
      return _toModel(driftAlarm).copyWith(color: resolvedColor);
    }).toList();
  }

  Future<int> _generateLocalId() async {
    final alarms = await getAllAlarms();
    if (alarms.isEmpty) return 256;
    final maxId = alarms.map((e) => e.id).reduce((a, b) => a > b ? a : b);
    return maxId < 256 ? 256 : maxId + 1;
  }

  Future<void> createAlarm(AlarmModel alarm) async {
    int finalId = alarm.id;
    bool isPending = false;

    if (_isConnected()) {
      try {
        finalId = await _apiClient.addAlarm(alarm);
      } catch (e) {
        debugPrint('Error sending alarm to ESP32: $e. Saving offline.');
        finalId = await _generateLocalId();
        isPending = true;
      }
    } else {
      finalId = await _generateLocalId();
      isPending = true;
    }

    final newModel = AlarmModel(
      id: finalId,
      hour: alarm.hour,
      minute: alarm.minute,
      name: alarm.name,
      medName: alarm.medName,
      enabled: alarm.enabled,
      active: alarm.active,
      days: alarm.days,
      status: alarm.status,
      color: alarm.color,
      quantity: alarm.quantity,
      daysQuantity: alarm.daysQuantity,
      type: alarm.type,
      dosage: alarm.dosage,
      lastStatus: alarm.lastStatus,
      lastStatusDate: alarm.lastStatusDate,
      snoozeMin: alarm.snoozeMin,
      startDate: alarm.startDate,
      durationDays: alarm.durationDays,
      createdDate: alarm.createdDate ?? DateTime.now().toIso8601String().substring(0, 10),
      cycleOnDays: alarm.cycleOnDays,
      cycleOffDays: alarm.cycleOffDays,
      cycleCurrentDay: alarm.cycleCurrentDay,
      cycleIsPaused: alarm.cycleIsPaused,
      isPrn: alarm.isPrn,
      prnMinIntervalHours: alarm.prnMinIntervalHours,
      prnMaxDailyDoses: alarm.prnMaxDailyDoses,
      prnDosesToday: alarm.prnDosesToday,
      pauseUntil: alarm.pauseUntil,
      isDynamic: alarm.isDynamic,
      dynamicInstruction: alarm.dynamicInstruction,
      taperStageCount: alarm.taperStageCount,
      taperCurrentStage: alarm.taperCurrentStage,
      taperDayInStage: alarm.taperDayInStage,
      taperStages: alarm.taperStages,
      taperLoop: alarm.taperLoop,
      specialInstruction: alarm.specialInstruction,
      adjustStep: alarm.adjustStep,
      adjustIntervalDays: alarm.adjustIntervalDays,
      adjustLimit: alarm.adjustLimit,
      requiresRemoval: alarm.requiresRemoval,
      removalDelayMins: alarm.removalDelayMins,
      siteRotationList: alarm.siteRotationList,
      currentSiteIndex: alarm.currentSiteIndex,
      dayOfMonth: alarm.dayOfMonth,
      groupId: alarm.groupId,
      intervalHours: alarm.intervalHours,
      intervalDays: alarm.intervalDays,
      intervalCountdown: alarm.intervalCountdown ?? (alarm.intervalDays != null && alarm.intervalDays! > 1 ? 0 : null),
      lastModified: DateTime.now().millisecondsSinceEpoch,
      pendingSync: isPending,
    );

    await _db.into(_db.alarms).insert(_toCompanion(newModel));
  }

  Future<void> updateAlarm(AlarmModel alarm) async {
    bool isPending = false;

    if (_isConnected()) {
      try {
        await _apiClient.updateAlarm(alarm);
      } catch (e) {
        debugPrint('Error updating alarm on ESP32: $e. Marking pending.');
        isPending = true;
      }
    } else {
      isPending = true;
    }

    final updatedModel = AlarmModel(
      id: alarm.id,
      hour: alarm.hour,
      minute: alarm.minute,
      name: alarm.name,
      medName: alarm.medName,
      enabled: alarm.enabled,
      active: alarm.active,
      days: alarm.days,
      status: alarm.status,
      color: alarm.color,
      quantity: alarm.quantity,
      daysQuantity: alarm.daysQuantity,
      type: alarm.type,
      dosage: alarm.dosage,
      lastStatus: alarm.lastStatus,
      lastStatusDate: alarm.lastStatusDate,
      snoozeMin: alarm.snoozeMin,
      startDate: alarm.startDate,
      durationDays: alarm.durationDays,
      createdDate: alarm.createdDate,
      cycleOnDays: alarm.cycleOnDays,
      cycleOffDays: alarm.cycleOffDays,
      cycleCurrentDay: alarm.cycleCurrentDay,
      cycleIsPaused: alarm.cycleIsPaused,
      isPrn: alarm.isPrn,
      prnMinIntervalHours: alarm.prnMinIntervalHours,
      prnMaxDailyDoses: alarm.prnMaxDailyDoses,
      prnDosesToday: alarm.prnDosesToday,
      pauseUntil: alarm.pauseUntil,
      isDynamic: alarm.isDynamic,
      dynamicInstruction: alarm.dynamicInstruction,
      taperStageCount: alarm.taperStageCount,
      taperCurrentStage: alarm.taperCurrentStage,
      taperDayInStage: alarm.taperDayInStage,
      taperStages: alarm.taperStages,
      taperLoop: alarm.taperLoop,
      specialInstruction: alarm.specialInstruction,
      adjustStep: alarm.adjustStep,
      adjustIntervalDays: alarm.adjustIntervalDays,
      adjustLimit: alarm.adjustLimit,
      requiresRemoval: alarm.requiresRemoval,
      removalDelayMins: alarm.removalDelayMins,
      siteRotationList: alarm.siteRotationList,
      currentSiteIndex: alarm.currentSiteIndex,
      dayOfMonth: alarm.dayOfMonth,
      groupId: alarm.groupId,
      intervalHours: alarm.intervalHours,
      intervalDays: alarm.intervalDays,
      intervalCountdown: alarm.intervalCountdown,
      lastModified: DateTime.now().millisecondsSinceEpoch,
      pendingSync: isPending,
    );

    await _db.update(_db.alarms).replace(_toCompanion(updatedModel));
  }

  Future<void> deleteAlarm(int id) async {
    if (_isConnected()) {
      try {
        await _apiClient.removeAlarm(id);
      } catch (e) {
        debugPrint('Error removing alarm on ESP32: $e');
      }
    }
    await (_db.delete(_db.alarms)..where((t) => t.id.equals(id))).go();
  }

  Future<void> toggleAlarm(int id, bool enabled) async {
    final alarmList = await (_db.select(_db.alarms)..where((t) => t.id.equals(id))).get();
    if (alarmList.isEmpty) return;

    final alarm = _toModel(alarmList.first);
    final updated = AlarmModel(
      id: alarm.id,
      hour: alarm.hour,
      minute: alarm.minute,
      name: alarm.name,
      medName: alarm.medName,
      enabled: enabled,
      active: enabled, // Active matches enabled state
      days: alarm.days,
      status: alarm.status,
      color: alarm.color,
      quantity: alarm.quantity,
      daysQuantity: alarm.daysQuantity,
      type: alarm.type,
      dosage: alarm.dosage,
      lastStatus: alarm.lastStatus,
      lastStatusDate: alarm.lastStatusDate,
      snoozeMin: alarm.snoozeMin,
      startDate: alarm.startDate,
      durationDays: alarm.durationDays,
      createdDate: alarm.createdDate,
      cycleOnDays: alarm.cycleOnDays,
      cycleOffDays: alarm.cycleOffDays,
      cycleCurrentDay: alarm.cycleCurrentDay,
      cycleIsPaused: alarm.cycleIsPaused,
      isPrn: alarm.isPrn,
      prnMinIntervalHours: alarm.prnMinIntervalHours,
      prnMaxDailyDoses: alarm.prnMaxDailyDoses,
      prnDosesToday: alarm.prnDosesToday,
      pauseUntil: alarm.pauseUntil,
      isDynamic: alarm.isDynamic,
      dynamicInstruction: alarm.dynamicInstruction,
      taperStageCount: alarm.taperStageCount,
      taperCurrentStage: alarm.taperCurrentStage,
      taperDayInStage: alarm.taperDayInStage,
      taperStages: alarm.taperStages,
      taperLoop: alarm.taperLoop,
      specialInstruction: alarm.specialInstruction,
      adjustStep: alarm.adjustStep,
      adjustIntervalDays: alarm.adjustIntervalDays,
      adjustLimit: alarm.adjustLimit,
      requiresRemoval: alarm.requiresRemoval,
      removalDelayMins: alarm.removalDelayMins,
      siteRotationList: alarm.siteRotationList,
      currentSiteIndex: alarm.currentSiteIndex,
      dayOfMonth: alarm.dayOfMonth,
      groupId: alarm.groupId,
      intervalHours: alarm.intervalHours,
      lastModified: DateTime.now().millisecondsSinceEpoch,
      pendingSync: !_isConnected(),
    );

    await _db.update(_db.alarms).replace(_toCompanion(updated));

    if (_isConnected()) {
      try {
        await _apiClient.toggleAlarm(id, enabled);
      } catch (e) {
        debugPrint('Error toggling alarm on ESP32: $e');
      }
    }
  }

  Future<void> markTaken(int id, {double? customQty}) async {
    final alarmList = await (_db.select(_db.alarms)..where((t) => t.id.equals(id))).get();
    if (alarmList.isEmpty) return;

    final alarm = _toModel(alarmList.first);
    final now = DateTime.now();
    final todayStr = "${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}";

    // Calculate delay to distinguish "Tomado" vs "Tomado fora hora"
    final nowMin = now.hour * 60 + now.minute;
    final alarmMin = alarm.hour * 60 + alarm.minute;
    var delayMin = nowMin - alarmMin;
    if (delayMin < 0) delayMin += 1440;

    final isLate = delayMin > 10;
    final historyStatus = isLate ? 'TOMADO FORA HORA' : 'TOMADO';
    final logText = isLate ? 'Tomado fora hora' : 'Tomado';

    // Calculate quantity for the current day of the week
    final wday = now.weekday % 7;
    final hasAsymmetric = alarm.daysQuantity.any((q) => q > 0);
    final double qtyTaken = customQty ?? ((hasAsymmetric && wday < alarm.daysQuantity.length && alarm.daysQuantity[wday] > 0)
        ? alarm.daysQuantity[wday]
        : alarm.quantity);

    final qtyStr = qtyTaken == qtyTaken.toInt() ? qtyTaken.toInt().toString() : qtyTaken.toStringAsFixed(1);

    String getUnitText(String type, double qty) {
      final t = type.toLowerCase();
      final isPlural = qty > 1;
      if (t == 'gota') return isPlural ? 'gotas' : 'gota';
      if (t == 'dose') return 'ml';
      if (t == 'capsula') return 'cáp.';
      if (t == 'adesivo') return 'ades.';
      if (t == 'injetavel') return 'aplic.';
      return isPlural ? 'comp.' : 'comp.';
    }
    final unitText = getUnitText(alarm.type, qtyTaken);
    final loggedDosage = '$qtyStr $unitText${alarm.dosage != null && alarm.dosage!.isNotEmpty ? ' (${alarm.dosage})' : ''}';

    // Rotate site if removal is required
    int? nextSiteIndex = alarm.currentSiteIndex;
    if (alarm.requiresRemoval == true && alarm.siteRotationList != null && alarm.siteRotationList!.isNotEmpty) {
      final sites = alarm.siteRotationList!.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      if (sites.isNotEmpty) {
        final currentIndex = alarm.currentSiteIndex ?? 0;
        nextSiteIndex = (currentIndex + 1) % sites.length;
      }
    }

    final updated = AlarmModel(
      id: alarm.id,
      hour: alarm.hour,
      minute: alarm.minute,
      name: alarm.name,
      medName: alarm.medName,
      enabled: alarm.enabled,
      active: alarm.active,
      days: alarm.days,
      status: 'PENDENTE', // ESP32 will reset status.
      color: alarm.color,
      quantity: alarm.quantity,
      daysQuantity: alarm.daysQuantity,
      type: alarm.type,
      dosage: alarm.dosage,
      lastStatus: 'Tomado',
      lastStatusDate: (alarm.status == 'ATIVO' || alarm.status == 'SNOOZED') ? (alarm.lastStatusDate ?? todayStr) : todayStr,
      snoozeMin: alarm.snoozeMin,
      startDate: alarm.startDate,
      durationDays: alarm.durationDays,
      createdDate: alarm.createdDate,
      cycleOnDays: alarm.cycleOnDays,
      cycleOffDays: alarm.cycleOffDays,
      cycleCurrentDay: alarm.cycleCurrentDay,
      cycleIsPaused: alarm.cycleIsPaused,
      isPrn: alarm.isPrn,
      prnMinIntervalHours: alarm.prnMinIntervalHours,
      prnMaxDailyDoses: alarm.prnMaxDailyDoses,
      prnDosesToday: alarm.prnDosesToday,
      pauseUntil: alarm.pauseUntil,
      isDynamic: alarm.isDynamic,
      dynamicInstruction: alarm.dynamicInstruction,
      taperStageCount: alarm.taperStageCount,
      taperCurrentStage: alarm.taperCurrentStage,
      taperDayInStage: alarm.taperDayInStage,
      taperStages: alarm.taperStages,
      taperLoop: alarm.taperLoop,
      specialInstruction: alarm.specialInstruction,
      adjustStep: alarm.adjustStep,
      adjustIntervalDays: alarm.adjustIntervalDays,
      adjustLimit: alarm.adjustLimit,
      requiresRemoval: alarm.requiresRemoval,
      removalDelayMins: alarm.removalDelayMins,
      siteRotationList: alarm.siteRotationList,
      currentSiteIndex: nextSiteIndex,
      dayOfMonth: alarm.dayOfMonth,
      groupId: alarm.groupId,
      intervalHours: alarm.intervalHours,
      lastModified: DateTime.now().millisecondsSinceEpoch,
      pendingSync: !_isConnected(),
    );

    await _db.update(_db.alarms).replace(_toCompanion(updated));

    final historyRepo = _ref.read(historyRepositoryProvider);
    await historyRepo.addHistoryEvent(
      alarmId: alarm.id,
      medName: alarm.medName.isNotEmpty ? alarm.medName : alarm.name,
      dosage: loggedDosage,
      status: historyStatus,
      type: 'alarm',
    );
    await historyRepo.addSystemLog(
      level: 'INFO',
      message: 'Medicamento "${alarm.medName.isNotEmpty ? alarm.medName : alarm.name}" ($loggedDosage) marcado como $logText',
      source: 'System',
    );

    if (_isConnected()) {
      try {
        await _apiClient.markTaken(id, qty: customQty);
      } catch (e) {
        debugPrint('Error marking taken on ESP32: $e');
      }
    }
  }

  Future<void> markSkipped(int id) async {
    final alarmList = await (_db.select(_db.alarms)..where((t) => t.id.equals(id))).get();
    if (alarmList.isEmpty) return;

    final alarm = _toModel(alarmList.first);
    final now = DateTime.now();
    final todayStr = "${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}";
    final updated = AlarmModel(
      id: alarm.id,
      hour: alarm.hour,
      minute: alarm.minute,
      name: alarm.name,
      medName: alarm.medName,
      enabled: alarm.enabled,
      active: alarm.active,
      days: alarm.days,
      status: 'PENDENTE',
      color: alarm.color,
      quantity: alarm.quantity,
      daysQuantity: alarm.daysQuantity,
      type: alarm.type,
      dosage: alarm.dosage,
      lastStatus: 'Não Tomado',
      lastStatusDate: (alarm.status == 'ATIVO' || alarm.status == 'SNOOZED') ? (alarm.lastStatusDate ?? todayStr) : todayStr,
      snoozeMin: alarm.snoozeMin,
      startDate: alarm.startDate,
      durationDays: alarm.durationDays,
      createdDate: alarm.createdDate,
      cycleOnDays: alarm.cycleOnDays,
      cycleOffDays: alarm.cycleOffDays,
      cycleCurrentDay: alarm.cycleCurrentDay,
      cycleIsPaused: alarm.cycleIsPaused,
      isPrn: alarm.isPrn,
      prnMinIntervalHours: alarm.prnMinIntervalHours,
      prnMaxDailyDoses: alarm.prnMaxDailyDoses,
      prnDosesToday: alarm.prnDosesToday,
      pauseUntil: alarm.pauseUntil,
      isDynamic: alarm.isDynamic,
      dynamicInstruction: alarm.dynamicInstruction,
      taperStageCount: alarm.taperStageCount,
      taperCurrentStage: alarm.taperCurrentStage,
      taperDayInStage: alarm.taperDayInStage,
      taperStages: alarm.taperStages,
      taperLoop: alarm.taperLoop,
      specialInstruction: alarm.specialInstruction,
      adjustStep: alarm.adjustStep,
      adjustIntervalDays: alarm.adjustIntervalDays,
      adjustLimit: alarm.adjustLimit,
      requiresRemoval: alarm.requiresRemoval,
      removalDelayMins: alarm.removalDelayMins,
      siteRotationList: alarm.siteRotationList,
      currentSiteIndex: alarm.currentSiteIndex,
      dayOfMonth: alarm.dayOfMonth,
      groupId: alarm.groupId,
      intervalHours: alarm.intervalHours,
      lastModified: DateTime.now().millisecondsSinceEpoch,
      pendingSync: !_isConnected(),
    );

    await _db.update(_db.alarms).replace(_toCompanion(updated));

    final historyRepo = _ref.read(historyRepositoryProvider);
    await historyRepo.addHistoryEvent(
      alarmId: alarm.id,
      medName: alarm.medName.isNotEmpty ? alarm.medName : alarm.name,
      dosage: alarm.dosage,
      status: 'PERDIDO',
      type: 'alarm',
    );
    await historyRepo.addSystemLog(
      level: 'WARNING',
      message: 'Medicamento "${alarm.medName.isNotEmpty ? alarm.medName : alarm.name}" marcado como Não Tomado (Perdido)',
      source: 'System',
    );

    if (_isConnected()) {
      try {
        await _apiClient.markSkipped(id);
      } catch (e) {
        debugPrint('Error marking skipped on ESP32: $e');
      }
    }
  }

  // Bidirectional Synchronization
  Future<void> syncWithDevice() async {
    if (!_isConnected()) return;

    try {
      // 1. Fetch remote alarms
      final remoteAlarms = await _apiClient.fetchAlarms();
      final localAlarms = await getAllAlarms();

      // Create map for lookup
      final remoteMap = {for (final a in remoteAlarms) a.id: a};

      // 2. Local-only modifications sync (Local -> Device)
      for (final local in localAlarms) {
        if (local.pendingSync) {
          if (local.id >= 256) {
            // New local alarm offline: Add to device
            try {
              final newId = await _apiClient.addAlarm(local);
              // Update local ID and clear pendingSync
              await deleteAlarm(local.id);
              final uploaded = AlarmModel(
                id: newId,
                hour: local.hour,
                minute: local.minute,
                name: local.name,
                medName: local.medName,
                enabled: local.enabled,
                active: local.active,
                days: local.days,
                status: local.status,
                color: local.color,
                quantity: local.quantity,
                daysQuantity: local.daysQuantity,
                type: local.type,
                dosage: local.dosage,
                lastStatus: local.lastStatus,
                lastStatusDate: local.lastStatusDate,
                snoozeMin: local.snoozeMin,
                startDate: local.startDate,
                durationDays: local.durationDays,
                createdDate: local.createdDate,
                cycleOnDays: local.cycleOnDays,
                cycleOffDays: local.cycleOffDays,
                cycleCurrentDay: local.cycleCurrentDay,
                cycleIsPaused: local.cycleIsPaused,
                isPrn: local.isPrn,
                prnMinIntervalHours: local.prnMinIntervalHours,
                prnMaxDailyDoses: local.prnMaxDailyDoses,
                prnDosesToday: local.prnDosesToday,
                pauseUntil: local.pauseUntil,
                isDynamic: local.isDynamic,
                dynamicInstruction: local.dynamicInstruction,
                taperStageCount: local.taperStageCount,
                taperCurrentStage: local.taperCurrentStage,
                taperDayInStage: local.taperDayInStage,
                taperStages: local.taperStages,
                taperLoop: local.taperLoop,
                specialInstruction: local.specialInstruction,
                adjustStep: local.adjustStep,
                adjustIntervalDays: local.adjustIntervalDays,
                adjustLimit: local.adjustLimit,
                requiresRemoval: local.requiresRemoval,
                removalDelayMins: local.removalDelayMins,
                siteRotationList: local.siteRotationList,
                currentSiteIndex: local.currentSiteIndex,
                dayOfMonth: local.dayOfMonth,
                groupId: local.groupId,
                intervalHours: local.intervalHours,
                lastModified: DateTime.now().millisecondsSinceEpoch,
                pendingSync: false,
              );
              await _db.into(_db.alarms).insert(_toCompanion(uploaded));
            } catch (e) {
              debugPrint('Failed to upload new local alarm ${local.id}: $e');
            }
          } else {
            // Existing alarm updated offline: Update on device
            try {
              await _apiClient.updateAlarm(local);
              await _db.update(_db.alarms).replace(
                    _toCompanion(local.copyWith(pendingSync: false)),
                  );
            } catch (e) {
              debugPrint('Failed to update alarm ${local.id} on device: $e');
            }
          }
        }
      }

      // Refresh local list after pushes
      final updatedLocalAlarms = await getAllAlarms();
      final updatedLocalMap = {for (final a in updatedLocalAlarms) a.id: a};

      // 3. Reconcile device changes (Device -> Local)
      for (final remote in remoteAlarms) {
        final local = updatedLocalMap[remote.id];
        if (local == null) {
          // New alarm on device: Save locally
          await _db.into(_db.alarms).insert(_toCompanion(remote));
        } else if (!local.pendingSync) {
          // Device state wins if local has no pending updates
          await _db.update(_db.alarms).replace(_toCompanion(remote));
        }
      }

      // 4. Clean up deleted alarms (Deleted on device -> Delete locally)
      for (final local in updatedLocalAlarms) {
        if (local.id < 256 && !remoteMap.containsKey(local.id) && !local.pendingSync) {
          await (_db.delete(_db.alarms)..where((t) => t.id.equals(local.id))).go();
        }
      }
    } catch (e) {
      debugPrint('Error syncing alarms: $e');
    }
  }

  /// Snooze an alarm for the given number of minutes.
  /// Pass 0 to cancel an active snooze.
  /// Replicates POST /snooze from the Web UI.
  Future<void> snoozeAlarm(int id, int minutes) async {
    final alarmList = await (_db.select(_db.alarms)..where((t) => t.id.equals(id))).get();
    if (alarmList.isEmpty) return;

    final alarm = _toModel(alarmList.first);
    final updated = alarm.copyWith(
      status: 'SNOOZED',
      snoozeMin: minutes,
      lastModified: DateTime.now().millisecondsSinceEpoch,
      pendingSync: !_isConnected(),
    );

    await _db.update(_db.alarms).replace(_toCompanion(updated));

    if (minutes > 0) {
      final historyRepo = _ref.read(historyRepositoryProvider);
      await historyRepo.addHistoryEvent(
        alarmId: alarm.id,
        medName: alarm.medName.isNotEmpty ? alarm.medName : alarm.name,
        dosage: alarm.dosage,
        status: 'SNOOZED',
        type: 'alarm',
      );
      await historyRepo.addSystemLog(
        level: 'INFO',
        message: 'Alarme do medicamento "${alarm.medName.isNotEmpty ? alarm.medName : alarm.name}" adiado por $minutes minutos',
        source: 'System',
      );
    }

    if (_isConnected()) {
      try {
        await _apiClient.snoozeAlarm(id, minutes);
      } catch (e) {
        debugPrint('Error snoozing alarm on ESP32: $e');
      }
    }
  }

  /// Registra o uso de um medicamento sob demanda (PRN)
  /// Replicates POST /take_prn from the Web UI.
  Future<void> takePrn(int id) async {
    final alarmList = await (_db.select(_db.alarms)..where((t) => t.id.equals(id))).get();
    if (alarmList.isEmpty) throw Exception('Alarme não encontrado');

    final alarm = _toModel(alarmList.first);
    if (alarm.isPrn != true) throw Exception('Este alarme não é do tipo Sob Demanda (PRN)');

    final now = DateTime.now();
    final todayStr = "${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}";

    int dosesToday = alarm.prnDosesToday ?? 0;
    // Reset if day changed
    if (alarm.lastStatusDate != todayStr) {
      dosesToday = 0;
    }

    // Check limit
    if (alarm.prnMaxDailyDoses != null && alarm.prnMaxDailyDoses! > 0) {
      if (dosesToday >= alarm.prnMaxDailyDoses!) {
        throw Exception('Limite diário de doses atingido (${alarm.prnMaxDailyDoses} doses)');
      }
    }

    // Check minimum interval
    if (alarm.prnMinIntervalHours != null && alarm.prnMinIntervalHours! > 0) {
      final historyList = await (_db.select(_db.historyEvents)
        ..where((t) => t.alarmId.equals(id))
        ..orderBy([(t) => OrderingTerm(expression: t.timestamp, mode: OrderingMode.desc)])
        ..limit(1))
        .get();

      if (historyList.isNotEmpty) {
        final lastTriggerMs = historyList.first.timestamp;
        final elapsedMs = now.millisecondsSinceEpoch - lastTriggerMs;
        final requiredMs = alarm.prnMinIntervalHours! * 3600 * 1000;
        if (elapsedMs < requiredMs) {
          final remainingSec = ((requiredMs - elapsedMs) / 1000).ceil();
          final remainingMin = (remainingSec / 60).ceil();
          if (remainingMin > 60) {
            final remainingHours = (remainingMin / 60).toStringAsFixed(1);
            throw Exception('Intervalo mínimo não respeitado. Aguarde mais $remainingHours horas.');
          } else {
            throw Exception('Intervalo mínimo não respeitado. Aguarde mais $remainingMin minutos.');
          }
        }
      }
    }

    // Take medication
    final updatedDoses = dosesToday + 1;
    final updated = alarm.copyWith(
      prnDosesToday: updatedDoses,
      status: 'PENDENTE',
      lastStatus: 'Tomado PRN',
      lastStatusDate: todayStr,
      snoozeMin: 0,
      lastModified: DateTime.now().millisecondsSinceEpoch,
      pendingSync: !_isConnected(),
    );

    if (_isConnected()) {
      try {
        await _apiClient.takePrn(id);
      } catch (e) {
        debugPrint('Error sending take_prn to device: $e');
      }
    }

    await _db.update(_db.alarms).replace(_toCompanion(updated));

    // Format detailed message for history/system logs
    final qtyStr = alarm.quantity == alarm.quantity.toInt() ? alarm.quantity.toInt().toString() : alarm.quantity.toStringAsFixed(1);
    
    String getUnitText(String type, double qty) {
      final t = type.toLowerCase();
      final isPlural = qty > 1;
      if (t == 'gota') return isPlural ? 'gotas' : 'gota';
      if (t == 'dose') return 'ml';
      if (t == 'capsula') return 'cáp.';
      if (t == 'adesivo') return 'ades.';
      if (t == 'injetavel') return 'aplic.';
      return isPlural ? 'comp.' : 'comp.';
    }
    final unitText = getUnitText(alarm.type, alarm.quantity);
    final loggedDosage = '$qtyStr $unitText${alarm.dosage != null && alarm.dosage!.isNotEmpty ? ' (${alarm.dosage})' : ''}';

    final historyRepo = _ref.read(historyRepositoryProvider);
    await historyRepo.addHistoryEvent(
      alarmId: alarm.id,
      medName: alarm.medName.isNotEmpty ? alarm.medName : alarm.name,
      dosage: loggedDosage,
      status: 'TOMADO PRN',
      type: 'alarm',
    );

    await historyRepo.addSystemLog(
      level: 'INFO',
      message: 'Medicamento Sob Demanda "${alarm.medName.isNotEmpty ? alarm.medName : alarm.name}" ($loggedDosage) registrado. Dose $updatedDoses do dia.',
      source: 'System',
    );
  }

  /// Recupera o horário do último registro de tomada de um alarme PRN
  Future<DateTime?> getLastPrnTakeTime(int id) async {
    final historyList = await (_db.select(_db.historyEvents)
      ..where((t) => t.alarmId.equals(id))
      ..orderBy([(t) => OrderingTerm(expression: t.timestamp, mode: OrderingMode.desc)])
      ..limit(1))
      .get();
    if (historyList.isEmpty) return null;
    return DateTime.fromMillisecondsSinceEpoch(historyList.first.timestamp);
  }

  /// Remove an alarm by ID.
  /// Convenience alias for deleteAlarm that matches the Web UI naming.
  Future<void> removeAlarm(int id) async {
    await deleteAlarm(id);
  }

  // Force loading from real JSON Backup fixture (Carolina's 25 alarms backup)
  Future<void> loadBackupFixture(String jsonContent) async {
    try {
      final Map<String, dynamic> data = json.decode(jsonContent);
      if (data.containsKey('alarms') && data['alarms'] is List) {
        final list = data['alarms'] as List;
        // Clear existing local database
        await _db.delete(_db.alarms).go();
        for (final item in list) {
          final model = AlarmModel.fromJson(item as Map<String, dynamic>);
          await _db.into(_db.alarms).insert(_toCompanion(model));
        }
      }
    } catch (e) {
      debugPrint('Error loading backup fixture: $e');
    }
  }
}

@Riverpod(keepAlive: true)
AlarmRepository alarmRepository(AlarmRepositoryRef ref) {
  return AlarmRepository(
    ref.watch(databaseProvider),
    ref.watch(alarmApiClientProvider),
    ref,
  );
}
