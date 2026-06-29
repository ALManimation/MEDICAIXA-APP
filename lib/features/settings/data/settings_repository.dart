import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:medicaixa_app/core/database/database.dart';
import 'package:medicaixa_app/core/network/dio_client.dart';
import 'package:medicaixa_app/core/providers/core_providers.dart';
import 'package:medicaixa_app/features/pairing/presentation/pairing_notifier.dart';
import 'package:medicaixa_app/features/pairing/domain/connection_state.dart';
import 'package:medicaixa_app/features/settings/data/settings_models.dart';

part 'settings_repository.g.dart';

class SettingsRepository {
  final AppDatabase _db;
  final DioClient _dioClient;
  final Ref _ref;

  SettingsRepository(this._db, this._dioClient, this._ref);

  bool _isConnected() {
    final connState = _ref.read(pairingNotifierProvider);
    return connState.status == ConnectionStatus.connected;
  }

  Future<Setting> getSettings() async {
    final list = await _db.select(_db.settings).get();
    if (list.isEmpty) {
      // Create default row
      const defaultSettings = SettingsCompanion(
        id: Value(1),
        patientName: Value('Paciente'),
        speakerVolume: Value(20),
        brightness: Value(50),
        language: Value('pt'),
        wakeWord: Value('jarvis'),
        alarmSound: Value(0),
        alarmSpacingMs: Value(10000),
        alarmWizardEnabled: Value(true),
        themeMode: Value('dark'),
      );
      await _db.into(_db.settings).insert(defaultSettings);
      final newList = await _db.select(_db.settings).get();
      return newList.first;
    }
    return list.first;
  }

  Future<void> updatePatientName(String name) async {
    final current = await getSettings();
    final updated = current.copyWith(patientName: name);
    await _db.update(_db.settings).replace(updated);

    if (_isConnected()) {
      try {
        await _dioClient.post('/save_patient_name', data: {'patient_name': name});
      } catch (e) {
        debugPrint('Error sending patient name to ESP32: $e');
      }
    }
  }

  Future<void> updateSettings(Setting data) async {
    await _db.update(_db.settings).replace(data);

    if (_isConnected()) {
      try {
        final payload = {
          'alarm_sound': data.alarmSound,
          'alarm_spacing_ms': data.alarmSpacingMs,
          'patient_name': data.patientName,
          'wake_word': data.wakeWord,
          'brightness': data.brightness,
          'speaker_volume': data.speakerVolume,
          'language': data.language,
          'sleep_schedule_enabled': data.sleepScheduleEnabled,
          'alarm_wizard_enabled': data.alarmWizardEnabled,
        };
        if (data.sleepTime != null) payload['sleep_time'] = data.sleepTime!;
        if (data.wakeTime != null) payload['wake_time'] = data.wakeTime!;
        if (data.breakfastTime != null) payload['breakfast_time'] = data.breakfastTime!;
        if (data.lunchTime != null) payload['lunch_time'] = data.lunchTime!;
        if (data.dinnerTime != null) payload['dinner_time'] = data.dinnerTime!;
        if (data.geminiApiKey != null) payload['gemini_api_key'] = data.geminiApiKey!;
        if (data.prohibitedRanges != null) {
          try {
            payload['prohibited_ranges'] = json.decode(data.prohibitedRanges!);
          } catch (e) {
            debugPrint('Error parsing prohibitedRanges for ESP32 payload: $e');
          }
        }

        await _dioClient.post('/save_settings', data: payload);
      } catch (e) {
        debugPrint('Error sending settings to ESP32: $e');
      }
    }
  }

  Future<void> updateSoundSettings({
    int? ringtoneIndex,
    int? repeatIntervalMs,
  }) async {
    final current = await getSettings();
    final updated = current.copyWith(
      alarmSound: ringtoneIndex ?? current.alarmSound,
      alarmSpacingMs: repeatIntervalMs ?? current.alarmSpacingMs,
    );

    // Save locally
    await _db.update(_db.settings).replace(updated);

    // Update remote
    if (_isConnected()) {
      try {
        final payload = {
          'alarm_sound': updated.alarmSound,
          'alarm_spacing_ms': updated.alarmSpacingMs,
          'patient_name': updated.patientName,
          'wake_word': updated.wakeWord,
          'brightness': updated.brightness,
          'speaker_volume': updated.speakerVolume,
          'language': updated.language,
          'sleep_schedule_enabled': updated.sleepScheduleEnabled,
          'alarm_wizard_enabled': updated.alarmWizardEnabled,
        };
        if (updated.sleepTime != null) payload['sleep_time'] = updated.sleepTime!;
        if (updated.wakeTime != null) payload['wake_time'] = updated.wakeTime!;
        if (updated.breakfastTime != null) payload['breakfast_time'] = updated.breakfastTime!;
        if (updated.lunchTime != null) payload['lunch_time'] = updated.lunchTime!;
        if (updated.dinnerTime != null) payload['dinner_time'] = updated.dinnerTime!;
        if (updated.geminiApiKey != null) payload['gemini_api_key'] = updated.geminiApiKey!;
        if (updated.prohibitedRanges != null) {
          try {
            payload['prohibited_ranges'] = json.decode(updated.prohibitedRanges!);
          } catch (_) {}
        }
        await _dioClient.post('/save_settings', data: payload);
      } catch (e) {
        debugPrint('Error sending updated sound settings to ESP32: $e');
      }
    }
  }

  Future<void> testSound(int index) async {
    if (!_isConnected()) {
      throw Exception('O dispositivo MediCaixa está desconectado.');
    }

    final response = await _dioClient.post(
      '/test_sound',
      data: {'index': index},
    );
    
    if (response.statusCode != 200 || response.data?.toString() != 'OK') {
      throw Exception('Falha ao emitir som de teste no dispositivo.');
    }
  }

  Future<DeviceDateTime> fetchDeviceTime() async {
    if (!_isConnected()) {
      throw Exception('Dispositivo desconectado');
    }
    final response = await _dioClient.get('/server_time');
    if (response.statusCode == 200 && response.data is Map) {
      return DeviceDateTime.fromJson(Map<String, dynamic>.from(response.data as Map));
    }
    throw Exception('Falha ao obter horário do dispositivo');
  }

  Future<void> updateDeviceTime(DeviceDateTime deviceTime) async {
    if (!_isConnected()) {
      throw Exception('Dispositivo desconectado');
    }
    final response = await _dioClient.post(
      '/set_datetime',
      data: deviceTime.toJson(),
    );
    if (response.statusCode != 200) {
      throw Exception('Erro ao definir horário no dispositivo');
    }
  }

  Future<String> downloadBackupJson() async {
    if (_isConnected()) {
      final response = await _dioClient.get('/backup');
      if (response.statusCode == 200) {
        if (response.data is Map) {
          return jsonEncode(response.data);
        }
        return response.data.toString();
      }
      throw Exception('Falha ao baixar backup');
    } else {
      final medsList = await _db.select(_db.medications).get();
      final alarmsList = await _db.select(_db.alarms).get();
      final remindersList = await _db.select(_db.reminders).get();
      final historyList = await _db.select(_db.historyEvents).get();
      final settings = await getSettings();

      final backupData = {
        'backup_date': DateTime.now().toUtc().toIso8601String(),
        'meds': medsList.map((m) => {
          'name': m.name,
          'color': m.color,
          'type': m.type,
          'dosage': m.dosage,
        }).toList(),
        'alarms': alarmsList.map((a) => {
          'id': a.id,
          'hour': a.hour,
          'minute': a.minute,
          'name': a.name,
          'med_name': a.medName,
          'enabled': a.enabled,
          'active': a.active,
          'days': json.decode(a.days),
          'status': a.status,
          'color': a.color,
          'quantity': a.quantity,
          'days_quantity': json.decode(a.daysQuantity),
          'type': a.type,
          'dosage': a.dosage,
          'last_status': a.lastStatus,
          'last_status_date': a.lastStatusDate,
          'snooze_min': a.snoozeMin,
          'start_date': a.startDate,
          'duration_days': a.durationDays,
          'created_date': a.createdDate,
          if (a.cycleOnDays != null) 'cycle_on_days': a.cycleOnDays,
          if (a.cycleOffDays != null) 'cycle_off_days': a.cycleOffDays,
          if (a.cycleCurrentDay != null) 'cycle_current_day': a.cycleCurrentDay,
          if (a.cycleIsPaused != null) 'cycle_is_paused': a.cycleIsPaused,
          if (a.isPrn != null) 'is_prn': a.isPrn,
          if (a.prnMinIntervalHours != null) 'prn_min_interval_hours': a.prnMinIntervalHours,
          if (a.prnMaxDailyDoses != null) 'prn_max_daily_doses': a.prnMaxDailyDoses,
          if (a.prnDosesToday != null) 'prn_doses_today': a.prnDosesToday,
          if (a.pauseUntil != null) 'pause_until': a.pauseUntil,
          if (a.isDynamic != null) 'is_dynamic': a.isDynamic,
          if (a.dynamicInstruction != null) 'dynamic_instruction': a.dynamicInstruction,
          if (a.taperStageCount != null) 'taper_stage_count': a.taperStageCount,
          if (a.taperCurrentStage != null) 'taper_current_stage': a.taperCurrentStage,
          if (a.taperDayInStage != null) 'taper_day_in_stage': a.taperDayInStage,
          if (a.taperStages != null) 'taper_stages': json.decode(a.taperStages!),
          if (a.taperLoop != null) 'taper_loop': a.taperLoop,
          if (a.specialInstruction != null) 'special_instruction': a.specialInstruction,
          if (a.adjustStep != null) 'adjust_step': a.adjustStep,
          if (a.adjustIntervalDays != null) 'adjust_interval_days': a.adjustIntervalDays,
          if (a.adjustLimit != null) 'adjust_limit': a.adjustLimit,
          if (a.requiresRemoval != null) 'requires_removal': a.requiresRemoval,
          if (a.removalDelayMins != null) 'removal_delay_mins': a.removalDelayMins,
          if (a.siteRotationList != null) 'site_rotation_list': a.siteRotationList,
          if (a.currentSiteIndex != null) 'current_site_index': a.currentSiteIndex,
          if (a.dayOfMonth != null) 'day_of_month': a.dayOfMonth,
          if (a.groupId != null) 'group_id': a.groupId,
          if (a.intervalHours != null) 'interval_hours': a.intervalHours,
          if (a.intervalDays != null) 'interval_days': a.intervalDays,
          if (a.intervalCountdown != null) 'interval_countdown': a.intervalCountdown,
        }).toList(),
        'reminders': remindersList.map((r) => {
          'id': r.id,
          'title': r.title,
          'description': r.description,
          'enabled': r.enabled,
          'has_time': r.hasTime,
          'hour': r.hour,
          'minute': r.minute,
          'period': r.period,
          'interval': r.interval,
          'start_date': r.startDate,
          'notify_days_before': r.notifyDaysBefore,
          'last_completed_date': r.lastCompletedDate,
          'color': r.color,
        }).toList(),
        'history': historyList.map((h) => {
          'id': h.id,
          'alarm_id': h.alarmId,
          'reminder_id': h.reminderId,
          'med_name': h.medName,
          'dosage': h.dosage,
          'timestamp': h.timestamp,
          'status': h.status,
          'type': h.type,
        }).toList(),
        'settings': {
          'device_ip': settings.deviceIp,
          'patient_name': settings.patientName,
          'speaker_volume': settings.speakerVolume,
          'brightness': settings.brightness,
          'language': settings.language,
          'wake_word': settings.wakeWord,
          'alarm_sound': settings.alarmSound,
          'alarm_spacing_ms': settings.alarmSpacingMs,
          'alarm_wizard_enabled': settings.alarmWizardEnabled,
          'sleep_time': settings.sleepTime,
          'wake_time': settings.wakeTime,
          'sleep_schedule_enabled': settings.sleepScheduleEnabled,
          'breakfast_time': settings.breakfastTime,
          'lunch_time': settings.lunchTime,
          'dinner_time': settings.dinnerTime,
          'gemini_api_key': settings.geminiApiKey,
          'prohibited_ranges': settings.prohibitedRanges != null ? json.decode(settings.prohibitedRanges!) : null,
          'theme_mode': settings.themeMode,
        }
      };
      return jsonEncode(backupData);
    }
  }

  Future<int> executeBackupRestore(Map<String, dynamic> partialBackup) async {
    var totalRestored = 0;

    await _db.transaction(() async {
      // 1. meds
      if (partialBackup.containsKey('meds')) {
        await _db.delete(_db.medications).go();
        final list = partialBackup['meds'] as List;
        for (final rawItem in list) {
          final item = rawItem as Map<String, dynamic>;
          final med = MedicationsCompanion(
            name: Value(item['name'] as String? ?? item['med_name'] as String? ?? ''),
            color: Value(item['color'] as String? ?? 'white'),
            type: Value(item['type'] as String? ?? 'comprimido'),
            dosage: Value(item['dosage'] as String?),
            lastModified: Value(DateTime.now().millisecondsSinceEpoch),
            pendingSync: const Value(false),
          );
          await _db.into(_db.medications).insert(med, mode: InsertMode.insertOrReplace);
        }
        totalRestored += list.length;
      }

      // 2. alarms
      if (partialBackup.containsKey('alarms')) {
        await _db.delete(_db.alarms).go();
        final list = partialBackup['alarms'] as List;
        for (final rawItem in list) {
          final item = rawItem as Map<String, dynamic>;
          final alarm = AlarmsCompanion(
            id: Value(item['id'] as int),
            hour: Value(item['hour'] as int),
            minute: Value(item['minute'] as int),
            name: Value(item['name'] as String? ?? ''),
            medName: Value(item['med_name'] as String? ?? item['name'] as String? ?? ''),
            enabled: Value(item['enabled'] == true),
            active: Value(item['active'] == true),
            days: Value(json.encode(item['days'] ?? List.filled(7, true))),
            status: Value(item['status'] as String? ?? 'PENDENTE'),
            color: Value(item['color'] as String? ?? 'blue'),
            quantity: Value((item['quantity'] as num?)?.toDouble() ?? 1.0),
            daysQuantity: Value(json.encode(item['days_quantity'] ?? List.filled(7, 0.0))),
            type: Value(item['type'] as String? ?? 'comprimido'),
            dosage: Value(item['dosage'] as String?),
            lastStatus: Value(item['last_status'] as String?),
            lastStatusDate: Value(item['last_status_date'] as String?),
            snoozeMin: Value(item['snooze_min'] as int? ?? 0),
            startDate: Value(item['start_date'] as String?),
            durationDays: Value(item['duration_days'] as int? ?? 0),
            createdDate: Value(item['created_date'] as String?),
            cycleOnDays: Value(item['cycle_on_days'] as int?),
            cycleOffDays: Value(item['cycle_off_days'] as int?),
            cycleCurrentDay: Value(item['cycle_current_day'] as int?),
            cycleIsPaused: Value(item['cycle_is_paused'] as bool?),
            isPrn: Value(item['is_prn'] as bool?),
            prnMinIntervalHours: Value(item['prn_min_interval_hours'] as int?),
            prnMaxDailyDoses: Value(item['prn_max_daily_doses'] as int?),
            prnDosesToday: Value(item['prn_doses_today'] as int?),
            pauseUntil: Value(item['pause_until'] as int?),
            isDynamic: Value(item['is_dynamic'] as bool?),
            dynamicInstruction: Value(item['dynamic_instruction'] as String?),
            taperStageCount: Value(item['taper_stage_count'] as int?),
            taperCurrentStage: Value(item['taper_current_stage'] as int?),
            taperDayInStage: Value(item['taper_day_in_stage'] as int?),
            taperStages: Value(item['taper_stages'] != null ? json.encode(item['taper_stages']) : null),
            taperLoop: Value(item['taper_loop'] as bool?),
            specialInstruction: Value(item['special_instruction'] as String?),
            adjustStep: Value(item['adjust_step'] != null ? (item['adjust_step'] as num).toDouble() : null),
            adjustIntervalDays: Value(item['adjust_interval_days'] as int?),
            adjustLimit: Value(item['adjust_limit'] != null ? (item['adjust_limit'] as num).toDouble() : null),
            requiresRemoval: Value(item['requires_removal'] as bool?),
            removalDelayMins: Value(item['removal_delay_mins'] as int?),
            siteRotationList: Value(item['site_rotation_list'] as String?),
            currentSiteIndex: Value(item['current_site_index'] as int?),
            dayOfMonth: Value(item['day_of_month'] as int?),
            groupId: Value(item['group_id'] as int?),
            intervalHours: Value(item['interval_hours'] as int?),
            intervalDays: Value(item['interval_days'] as int?),
            intervalCountdown: Value(item['interval_countdown'] as int?),
            lastModified: Value(DateTime.now().millisecondsSinceEpoch),
            pendingSync: const Value(false),
          );
          await _db.into(_db.alarms).insert(alarm, mode: InsertMode.insertOrReplace);
        }
        totalRestored += list.length;
      }

      // 3. reminders
      if (partialBackup.containsKey('reminders')) {
        await _db.delete(_db.reminders).go();
        final list = partialBackup['reminders'] as List;
        for (final rawItem in list) {
          final item = rawItem as Map<String, dynamic>;
          final reminder = RemindersCompanion(
            id: Value(item['id'] as int),
            title: Value(item['title'] as String? ?? ''),
            description: Value(item['description'] as String? ?? ''),
            enabled: Value(item['enabled'] == true),
            hasTime: Value(item['has_time'] == true),
            hour: Value(item['hour'] as int?),
            minute: Value(item['minute'] as int?),
            period: Value(item['period'] as String? ?? ''),
            interval: Value(item['interval'] as int? ?? 1),
            startDate: Value(item['start_date'] as String? ?? ''),
            notifyDaysBefore: Value(item['notify_days_before'] as int? ?? 0),
            lastCompletedDate: Value(item['last_completed_date'] as String?),
            color: Value(item['color'] as String? ?? 'blue'),
            lastModified: Value(DateTime.now().millisecondsSinceEpoch),
            pendingSync: const Value(false),
          );
          await _db.into(_db.reminders).insert(reminder, mode: InsertMode.insertOrReplace);
        }
        totalRestored += list.length;
      }

      // 4. history
      if (partialBackup.containsKey('history')) {
        await _db.delete(_db.historyEvents).go();
        final list = partialBackup['history'] as List;
        for (final rawItem in list) {
          final item = rawItem as Map<String, dynamic>;
          final historyEvent = HistoryEventsCompanion(
            id: item['id'] != null ? Value(item['id'] as int) : const Value.absent(),
            alarmId: Value(item['alarm_id'] as int?),
            reminderId: Value(item['reminder_id'] as int?),
            medName: Value(item['med_name'] as String?),
            dosage: Value(item['dosage'] as String?),
            timestamp: Value(item['timestamp'] as int? ?? DateTime.now().millisecondsSinceEpoch),
            status: Value(item['status'] as String? ?? 'TOMADO'),
            type: Value(item['type'] as String? ?? 'alarm'),
            pendingSync: const Value(false),
          );
          await _db.into(_db.historyEvents).insert(historyEvent, mode: InsertMode.insertOrReplace);
        }
        totalRestored += list.length;
      }

      // 5. logs
      if (partialBackup.containsKey('logs')) {
        await _db.delete(_db.systemLogs).go();
        final list = partialBackup['logs'] as List;
        for (final rawItem in list) {
          final item = rawItem as Map<String, dynamic>;
          final log = SystemLogsCompanion(
            id: item['id'] != null ? Value(item['id'] as int) : const Value.absent(),
            timestamp: Value(item['timestamp'] as int? ?? DateTime.now().millisecondsSinceEpoch),
            level: Value(item['level'] as String? ?? 'INFO'),
            message: Value(item['message'] as String? ?? ''),
            source: Value(item['source'] as String? ?? 'System'),
          );
          await _db.into(_db.systemLogs).insert(log, mode: InsertMode.insertOrReplace);
        }
        totalRestored += list.length;
      }

      // 6. settings
      if (partialBackup.containsKey('settings')) {
        await _db.delete(_db.settings).go();
        final item = partialBackup['settings'] as Map<String, dynamic>;
        final setting = SettingsCompanion(
          id: const Value(1),
          deviceIp: Value(item['device_ip'] as String?),
          patientName: Value(item['patient_name'] as String? ?? 'Paciente'),
          speakerVolume: Value((item['speaker_volume'] as num?)?.toInt() ?? 20),
          brightness: Value((item['brightness'] as num?)?.toInt() ?? 50),
          language: Value(item['language'] as String? ?? 'pt'),
          wakeWord: Value(item['wake_word'] as String? ?? 'jarvis'),
          alarmSound: Value((item['alarm_sound'] as num?)?.toInt() ?? 0),
          alarmSpacingMs: Value((item['alarm_spacing_ms'] as num?)?.toInt() ?? 10000),
          alarmWizardEnabled: Value(item['alarm_wizard_enabled'] == true),
          sleepTime: Value(item['sleep_time'] as String?),
          wakeTime: Value(item['wake_time'] as String?),
          sleepScheduleEnabled: Value(item['sleep_schedule_enabled'] == true),
          breakfastTime: Value(item['breakfast_time'] as String?),
          lunchTime: Value(item['lunch_time'] as String?),
          dinnerTime: Value(item['dinner_time'] as String?),
          geminiApiKey: Value(item['gemini_api_key'] as String?),
          prohibitedRanges: Value(item['prohibited_ranges'] != null ? json.encode(item['prohibited_ranges']) : null),
          themeMode: Value(item['theme_mode'] as String? ?? 'dark'),
        );
        await _db.into(_db.settings).insert(setting, mode: InsertMode.insertOrReplace);
        totalRestored += 1;
      }
    });

    if (_isConnected()) {
      final response = await _dioClient.post(
        '/restore',
        data: partialBackup,
      );
      if (response.statusCode == 200) {
        if (response.data is Map) {
          final data = response.data as Map;
          return (data['restored_files'] as num).toInt();
        }
        return 1;
      }
      throw Exception('Restauração falhou no dispositivo');
    }

    return totalRestored;
  }

  Future<void> restartDevice() async {
    try {
      await _dioClient.post('/restart');
    } catch (_) {}
  }

  Future<void> syncSettings() async {
    if (!_isConnected()) return;

    try {
      final response = await _dioClient.get('/settings');
      if (response.statusCode == 200 && response.data is Map) {
        final map = response.data as Map<String, dynamic>;
        final current = await getSettings();

        // Convert string ranges to json
        String? rangesJson;
        if (map.containsKey('prohibited_ranges') && map['prohibited_ranges'] is List) {
          rangesJson = json.encode(map['prohibited_ranges']);
        }

        final remoteData = current.copyWith(
          patientName: map['patient_name']?.toString() ?? current.patientName,
          speakerVolume: (map['speaker_volume'] as num?)?.toInt() ?? current.speakerVolume,
          brightness: (map['brightness'] as num?)?.toInt() ?? current.brightness,
          language: map['language']?.toString() ?? current.language,
          wakeWord: map['wake_word']?.toString() ?? current.wakeWord,
          alarmSound: (map['alarm_sound'] as num?)?.toInt() ?? current.alarmSound,
          alarmSpacingMs: (map['alarm_spacing_ms'] as num?)?.toInt() ?? current.alarmSpacingMs,
          alarmWizardEnabled: map['alarm_wizard_enabled'] == true,
          sleepTime: Value(map['sleep_time']?.toString()),
          wakeTime: Value(map['wake_time']?.toString()),
          sleepScheduleEnabled: map['sleep_schedule_enabled'] == true,
          breakfastTime: Value(map['breakfast_time']?.toString()),
          lunchTime: Value(map['lunch_time']?.toString()),
          dinnerTime: Value(map['dinner_time']?.toString()),
          geminiApiKey: Value(map['gemini_api_key']?.toString()),
          prohibitedRanges: Value(rangesJson),
        );

        await _db.update(_db.settings).replace(remoteData);
      }
    } catch (e) {
      debugPrint('Error syncing settings: $e');
    }
  }
}

@Riverpod(keepAlive: true)
SettingsRepository settingsRepository(SettingsRepositoryRef ref) {
  return SettingsRepository(
    ref.watch(databaseProvider),
    ref.watch(dioClientProvider),
    ref,
  );
}

@riverpod
Stream<Setting?> watchSettings(WatchSettingsRef ref) {
  final db = ref.watch(databaseProvider);
  return db.select(db.settings).watchSingleOrNull();
}

@riverpod
class DeviceTimeNotifier extends _$DeviceTimeNotifier {
  @override
  FutureOr<DeviceDateTime?> build() async {
    final isConnected = ref.watch(pairingNotifierProvider).status == ConnectionStatus.connected;
    if (!isConnected) return null;
    return ref.read(settingsRepositoryProvider).fetchDeviceTime();
  }

  Future<void> syncWithPhoneTime() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final now = DateTime.now();
      final deviceTime = DeviceDateTime.fromDateTime(now);
      await ref.read(settingsRepositoryProvider).updateDeviceTime(deviceTime);
      return deviceTime;
    });
  }

  Future<void> setManualDateTime(DateTime selectedDateTime) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final deviceTime = DeviceDateTime.fromDateTime(selectedDateTime);
      await ref.read(settingsRepositoryProvider).updateDeviceTime(deviceTime);
      return deviceTime;
    });
  }

  Future<void> refreshTime() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => ref.read(settingsRepositoryProvider).fetchDeviceTime());
  }
}

@riverpod
Stream<VoiceStatus?> voiceStatusStream(VoiceStatusStreamRef ref) async* {
  final isConnected = ref.watch(pairingNotifierProvider).status == ConnectionStatus.connected;

  if (!isConnected) {
    yield null; // Offline mode yields null status
    return;
  }

  while (true) {
    try {
      final response = await ref.read(dioClientProvider).get('/voice_status');
      if (response.statusCode == 200 && response.data is Map) {
        yield VoiceStatus.fromJson(Map<String, dynamic>.from(response.data as Map));
      }
    } catch (e) {
      yield VoiceStatus(
        state: VoiceState.error,
        connected: false,
        activationCode: '',
        hasCredentials: false,
        wakeWord: 'sophia',
      );
    }
    await Future.delayed(const Duration(seconds: 5));
  }
}

@riverpod
class DeviceResetNotifier extends _$DeviceResetNotifier {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  Future<bool> resetDevicePartitions(Map<String, bool> payload) async {
    state = const AsyncValue.loading();
    var success = false;
    state = await AsyncValue.guard(() async {
      final db = ref.read(databaseProvider);
      
      // Perform local database wipes based on selection
      if (payload['factory'] == true || payload['meds'] == true) {
        await db.delete(db.medications).go();
      }
      if (payload['factory'] == true || payload['alarms'] == true) {
        await db.delete(db.alarms).go();
      }
      if (payload['factory'] == true || payload['reminders'] == true) {
        await db.delete(db.reminders).go();
      }
      if (payload['factory'] == true || payload['history'] == true) {
        await db.delete(db.historyEvents).go();
      }
      if (payload['factory'] == true || payload['logs'] == true) {
        await db.delete(db.systemLogs).go();
      }
      if (payload['factory'] == true || payload['settings'] == true) {
        final repo = ref.read(settingsRepositoryProvider);
        final current = await repo.getSettings();
        final defaults = current.copyWith(
          patientName: 'Paciente',
          speakerVolume: 20,
          brightness: 50,
          language: 'pt',
          wakeWord: 'jarvis',
          alarmSound: 0,
          alarmSpacingMs: 10000,
          alarmWizardEnabled: true,
          sleepTime: const Value(null),
          wakeTime: const Value(null),
          sleepScheduleEnabled: false,
          breakfastTime: const Value(null),
          lunchTime: const Value(null),
          dinnerTime: const Value(null),
          geminiApiKey: const Value(null),
          prohibitedRanges: const Value(null),
          themeMode: 'dark',
        );
        await repo.updateSettings(defaults);
      }

      final isConnected = ref.read(pairingNotifierProvider).status == ConnectionStatus.connected;
      if (isConnected) {
        final response = await ref.read(dioClientProvider).post(
          '/reset',
          data: payload,
        );
        if (response.statusCode != 200) {
          throw Exception('Falha ao resetar partições no dispositivo');
        }
      }
      success = true;

      // Check if reboot is needed based on selected components
      final needsReboot = payload['factory'] == true ||
                          payload['wifi'] == true ||
                          payload['settings'] == true ||
                          payload['xiaozhi'] == true;
      
      if (needsReboot && isConnected) {
        // Trigger restart endpoint
        try {
          await ref.read(dioClientProvider).post('/restart');
        } catch (_) {}
        
        // Wait 8 seconds to allow ESP32 to restart and enter Access Point mode
        await Future.delayed(const Duration(seconds: 8));

        // If Wi-Fi or factory was erased, we lose connection, so wipe IP and redirect
        if (payload['factory'] == true || payload['wifi'] == true) {
          await ref.read(pairingNotifierProvider.notifier).useStandalone();
        }
      } else if ((payload['factory'] == true || payload['wifi'] == true) && !isConnected) {
        await ref.read(pairingNotifierProvider.notifier).useStandalone();
      }
    });
    return success;
  }
}

@riverpod
class SoundSettingsAction extends _$SoundSettingsAction {
  @override
  AsyncValue<void> build() {
    return const AsyncValue.data(null);
  }

  Future<void> saveSound({required int ringtoneIndex, required int repeatIntervalMs}) async {
    state = const AsyncValue.loading();
    try {
      final repository = ref.read(settingsRepositoryProvider);
      await repository.updateSoundSettings(
        ringtoneIndex: ringtoneIndex,
        repeatIntervalMs: repeatIntervalMs,
      );
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> testSoundTone(int index) async {
    state = const AsyncValue.loading();
    try {
      final repository = ref.read(settingsRepositoryProvider);
      await repository.testSound(index);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}
