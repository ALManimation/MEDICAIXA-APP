import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../core/database/database.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/providers/core_providers.dart';
import '../../pairing/presentation/pairing_notifier.dart';
import '../../pairing/domain/connection_state.dart';

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
        debugPrint("Error sending patient name to ESP32: $e");
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

        await _dioClient.post('/save_settings', data: payload);
      } catch (e) {
        debugPrint("Error sending settings to ESP32: $e");
      }
    }
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
      debugPrint("Error syncing settings: $e");
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
