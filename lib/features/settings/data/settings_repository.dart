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
    if (!_isConnected()) throw Exception('Dispositivo offline');
    final response = await _dioClient.get('/backup');
    if (response.statusCode == 200) {
      if (response.data is Map) {
        return jsonEncode(response.data);
      }
      return response.data.toString();
    }
    throw Exception('Falha ao baixar backup');
  }

  Future<int> executeBackupRestore(Map<String, dynamic> partialBackup) async {
    if (!_isConnected()) throw Exception('Dispositivo offline');
    final response = await _dioClient.post(
      '/restore',
      data: partialBackup,
    );
    if (response.statusCode == 200) {
      if (response.data is Map) {
        final data = response.data as Map;
        return (data['restored_files'] as num?)?.toInt() ?? 0;
      }
      return 1;
    }
    throw Exception('Restauração falhou no dispositivo');
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
      final response = await ref.read(dioClientProvider).post(
        '/reset',
        data: payload,
      );
      if (response.statusCode != 200) {
        throw Exception('Falha ao resetar partições no dispositivo');
      }
      success = true;

      // Check if reboot is needed based on selected components
      final needsReboot = payload['factory'] == true ||
                          payload['wifi'] == true ||
                          payload['settings'] == true ||
                          payload['xiaozhi'] == true;
      
      if (needsReboot) {
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
