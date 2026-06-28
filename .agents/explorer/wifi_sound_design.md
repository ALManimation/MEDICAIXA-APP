# Technical Design: Wi-Fi & Sound Settings Data Layer

This document details the design of the data layer, repository/service classes, and Riverpod provider structure to integrate Wi-Fi management and sound configurations between the MediCaixa Flutter app and the physical ESP32 box.

---

## 1. Architectural Patterns & Guidelines

1. **Offline-First**: Local SQLite database (Drift) remains the source of truth for the UI whenever applicable. For Wi-Fi, since it's device-bound, state is loaded dynamically from the device when connected.
2. **Serializing Requests**: The ESP32 WebServer has limited DRAM (~270KB). All network requests must go through `DioClient` which utilizes a `RequestLock.synchronized` decorator to prevent concurrent request overhead.
3. **AsyncValue for State Management**: Riverpod `AsyncValue` is used for asynchronous actions and fetches, avoiding manual state flags.
4. **Feature-First Organization**: Wi-Fi-specific files will reside under `lib/features/settings/data/` to keep Settings features co-located.

---

## 2. Wi-Fi Management Architecture

### A. Data Model: `WifiNetwork`
A model representing a Wi-Fi network configuration. It covers both scanned networks (with signal details) and saved networks (SSID list).

```dart
class WifiNetwork {
  final String ssid;
  final int? rssi;
  final int? channel;
  final bool? isOpen;

  const WifiNetwork({
    required this.ssid,
    this.rssi,
    this.channel,
    this.isOpen,
  });

  factory WifiNetwork.fromJson(Map<String, dynamic> json) {
    return WifiNetwork(
      ssid: json['ssid'] as String,
      rssi: json['rssi'] as int?,
      channel: json['channel'] as int?,
      isOpen: json['open'] as bool?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ssid': ssid,
      if (rssi != null) 'rssi': rssi,
      if (channel != null) 'channel': channel,
      if (isOpen != null) 'open': isOpen,
    };
  }
}
```

### B. Repository: `WifiRepository`
Manages communicating with the ESP32 Wi-Fi manager.

```dart
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/providers/core_providers.dart';
import '../../pairing/presentation/pairing_notifier.dart';
import '../../pairing/domain/connection_state.dart';
import 'wifi_network.dart';

part 'wifi_repository.g.dart';

class WifiRepository {
  final DioClient _dioClient;
  final Ref _ref;

  WifiRepository(this._dioClient, this._ref);

  bool _isConnected() {
    final connState = _ref.read(pairingNotifierProvider);
    return connState.status == ConnectionStatus.connected;
  }

  /// Scan available Wi-Fi networks in range
  /// GET /wifi_scan
  /// Returns: List<WifiNetwork> sorted by RSSI descending (strongest first)
  Future<List<WifiNetwork>> scanNetworks() async {
    if (!_isConnected()) {
      throw Exception("O dispositivo MediCaixa está desconectado.");
    }
    
    final response = await _dioClient.get('/wifi_scan');
    if (response.statusCode == 200 && response.data is List) {
      final list = response.data as List;
      final networks = list
          .map((item) => WifiNetwork.fromJson(item as Map<String, dynamic>))
          .toList();
      
      // Sort by RSSI descending (e.g. -40dBm > -85dBm)
      networks.sort((a, b) {
        if (a.rssi == null) return 1;
        if (b.rssi == null) return -1;
        return b.rssi!.compareTo(a.rssi!);
      });
      return networks;
    } else {
      throw Exception("Erro ao escanear redes Wi-Fi (Status: ${response.statusCode})");
    }
  }

  /// List saved networks on the device
  /// GET /wifi_list
  /// Returns: List<WifiNetwork> (contains only SSIDs)
  Future<List<WifiNetwork>> getSavedNetworks() async {
    if (!_isConnected()) {
      throw Exception("O dispositivo MediCaixa está desconectado.");
    }

    final response = await _dioClient.get('/wifi_list');
    if (response.statusCode == 200 && response.data is List) {
      final list = response.data as List;
      return list
          .map((item) => WifiNetwork.fromJson(item as Map<String, dynamic>))
          .toList();
    } else {
      throw Exception("Erro ao obter redes salvas (Status: ${response.statusCode})");
    }
  }

  /// Add network credentials to the device
  /// POST /wifi_add
  /// Payload: {"ssid": "SSID", "password": "PASS"}
  Future<void> addNetwork(String ssid, String password) async {
    if (!_isConnected()) {
      throw Exception("O dispositivo MediCaixa está desconectado.");
    }

    final response = await _dioClient.post(
      '/wifi_add',
      data: {
        'ssid': ssid,
        'password': password,
      },
    );
    
    if (response.statusCode != 200 || response.data?.toString() != 'OK') {
      throw Exception("Falha ao salvar rede Wi-Fi na caixinha.");
    }
  }

  /// Forget/remove saved network credentials
  /// POST /wifi_remove
  /// Payload: {"ssid": "SSID"}
  Future<void> removeNetwork(String ssid) async {
    if (!_isConnected()) {
      throw Exception("O dispositivo MediCaixa está desconectado.");
    }

    final response = await _dioClient.post(
      '/wifi_remove',
      data: {'ssid': ssid},
    );

    if (response.statusCode != 200 || response.data?.toString() != 'OK') {
      throw Exception("Falha ao remover rede Wi-Fi da caixinha.");
    }
  }
}

@Riverpod(keepAlive: true)
WifiRepository wifiRepository(WifiRepositoryRef ref) {
  return WifiRepository(
    ref.watch(dioClientProvider),
    ref,
  );
}
```

### C. Riverpod State Providers

```dart
/// Triggers Wi-Fi scanning in the background. Auto-disposed to avoid constant CPU scan cycles.
@riverpod
Future<List<WifiNetwork>> wifiScan(WifiScanRef ref) async {
  final repository = ref.watch(wifiRepositoryProvider);
  return repository.scanNetworks();
}

/// Fetches saved networks list.
@riverpod
Future<List<WifiNetwork>> savedWifiNetworks(SavedWifiNetworksRef ref) async {
  final repository = ref.watch(wifiRepositoryProvider);
  return repository.getSavedNetworks();
}

/// Mutator for Wi-Fi configurations (Add, Remove)
@riverpod
class WifiActionNotifier extends _$WifiActionNotifier {
  @override
  AsyncValue<void> build() {
    return const AsyncValue.data(null);
  }

  Future<bool> addNetwork(String ssid, String password) async {
    state = const AsyncValue.loading();
    try {
      final repository = ref.read(wifiRepositoryProvider);
      await repository.addNetwork(ssid, password);
      state = const AsyncValue.data(null);
      
      // Invalidate providers to trigger automatic UI refreshes
      ref.invalidate(savedWifiNetworksProvider);
      ref.invalidate(wifiScanProvider);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> removeNetwork(String ssid) async {
    state = const AsyncValue.loading();
    try {
      final repository = ref.read(wifiRepositoryProvider);
      await repository.removeNetwork(ssid);
      state = const AsyncValue.data(null);
      
      // Invalidate providers to trigger automatic UI refreshes
      ref.invalidate(savedWifiNetworksProvider);
      ref.invalidate(wifiScanProvider);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}
```

---

## 3. Sound Settings & Test Sound Architecture

### A. Sound Config Enums

```dart
/// Maps C++ alarmSound indices to UI values
enum RingtoneType {
  gentile(0, 'Gentil'),
  alerta(1, 'Alerta'),
  melodia(2, 'Melodia'),
  urgente(3, 'Urgente'),
  musical(4, 'Musical');

  final int index;
  final String label;

  const RingtoneType(this.index, this.label);

  static RingtoneType fromIndex(int index) {
    return RingtoneType.values.firstWhere(
      (r) => r.index == index,
      orElse: () => RingtoneType.alerta,
    );
  }
}

/// Maps repeat intervals to alarmSpacingMs
enum AlarmSpacingInterval {
  oneSecond(1000, '1s'),
  threeSeconds(3000, '3s'),
  sixSeconds(6000, '6s'),
  tenSeconds(10000, '10s');

  final int ms;
  final String label;

  const AlarmSpacingInterval(this.ms, this.label);

  static AlarmSpacingInterval fromMs(int ms) {
    return AlarmSpacingInterval.values.firstWhere(
      (i) => i.ms == ms,
      orElse: () => AlarmSpacingInterval.tenSeconds,
    );
  }
}
```

### B. Sound Methods Design in `SettingsRepository`

Add these methods to the existing `SettingsRepository` in `lib/features/settings/data/settings_repository.dart`:

```dart
  /// Updates sound configurations (Ringtone Index and Spacing Interval)
  /// Saves locally to Drift DB and sends payload to POST /save_settings if connected.
  Future<void> updateSoundSettings({
    int? ringtoneIndex,
    int? repeatIntervalMs,
  }) async {
    final current = await getSettings();
    final updated = current.copyWith(
      alarmSound: ringtoneIndex ?? current.alarmSound,
      alarmSpacingMs: repeatIntervalMs ?? current.alarmSpacingMs,
    );

    // 1. Save locally to Drift SQLite (Offline-First compliance)
    await _db.update(_db.settings).replace(updated);

    // 2. If paired and connected, propagate changes to the hardware
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
        debugPrint("Error sending updated sound settings to ESP32: $e");
      }
    }
  }

  /// Triggers a test sound buzzer tone on the physical device
  /// POST /test_sound
  /// Payload: {"index": index}
  Future<void> testSound(int index) async {
    if (!_isConnected()) {
      throw Exception("O dispositivo MediCaixa está desconectado.");
    }

    final response = await _dioClient.post(
      '/test_sound',
      data: {'index': index},
    );
    
    if (response.statusCode != 200 || response.data?.toString() != 'OK') {
      throw Exception("Falha ao emitir som de teste no dispositivo.");
    }
  }
```

### C. State Watcher and Actions Providers

To listen to setting changes dynamically in UI, we declare a Riverpod watcher provider:

```dart
/// Emits updates to settings from Drift SQLite DB in real time.
@riverpod
Stream<Setting?> watchSettings(WatchSettingsRef ref) {
  final db = ref.watch(databaseProvider);
  return db.select(db.settings).watchSingleOrNull();
}

/// Mutator state notifier for Settings / Sound interactions
@riverpod
class SoundSettingsAction extends _$SoundSettingsAction {
  @override
  AsyncValue<void> build() {
    return const Value(null);
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
```
