import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/native.dart';
import 'package:medicaixa_app/core/database/database.dart';
import 'package:medicaixa_app/core/network/dio_client.dart';
import 'package:medicaixa_app/core/providers/core_providers.dart';
import 'package:medicaixa_app/features/settings/data/settings_models.dart';
import 'package:medicaixa_app/features/settings/data/settings_repository.dart';
import 'package:medicaixa_app/features/settings/data/wifi_repository.dart';

class MockDioClient implements DioClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class FakeRef implements Ref {
  @override
  final ProviderContainer container;
  FakeRef(this.container);

  @override
  T read<T>(ProviderListenable<T> listenable) => container.read(listenable);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Settings & C++ Box Integration Tests', () {
    late AppDatabase db;
    late MockDioClient dioClient;
    late ProviderContainer container;
    late SettingsRepository settingsRepo;

    setUp(() {
      db = AppDatabase.connect(NativeDatabase.memory());
      dioClient = MockDioClient();
      container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          dioClientProvider.overrideWithValue(dioClient),
        ],
      );
      settingsRepo = SettingsRepository(db, dioClient, FakeRef(container));
    });

    tearDown(() async {
      await db.close();
      container.dispose();
    });

    test('DeviceDateTime serialization and datetime conversion', () {
      final now = DateTime(2026, 6, 28, 11, 10, 51);
      final devTime = DeviceDateTime.fromDateTime(now);

      expect(devTime.year, 2026);
      expect(devTime.month, 6);
      expect(devTime.day, 28);
      expect(devTime.hour, 11);
      expect(devTime.minute, 10);
      expect(devTime.second, 51);

      final backToDt = devTime.toDateTime();
      expect(backToDt, now);

      final json = devTime.toJson();
      expect(json['year'], 2026);
      expect(json['second'], 51);

      final fromJson = DeviceDateTime.fromJson(json);
      expect(fromJson.year, 2026);
      expect(fromJson.second, 51);
    });

    test('VoiceState and VoiceStatus mapping', () {
      final json = {
        'state': 'pensando',
        'connected': true,
        'activation_code': 'ACTIVATION_KEY',
        'has_credentials': true,
        'wake_word': 'jarvis'
      };

      final status = VoiceStatus.fromJson(json);
      expect(status.state, VoiceState.thinking);
      expect(status.state.label, 'Pensando...');
      expect(status.connected, true);
      expect(status.activationCode, 'ACTIVATION_KEY');
      expect(status.hasCredentials, true);
      expect(status.wakeWord, 'jarvis');

      expect(VoiceState.fromString('CONECTANDO'), VoiceState.connecting);
      expect(VoiceState.fromString('ouvindo'), VoiceState.listening);
      expect(VoiceState.fromString('desconhecido'), VoiceState.disconnected);
    });

    test('WifiNetwork serialization', () {
      final json = {
        'ssid': 'MyHomeWifi',
        'rssi': -65,
        'channel': 6,
        'open': false
      };

      final wifi = WifiNetwork.fromJson(json);
      expect(wifi.ssid, 'MyHomeWifi');
      expect(wifi.rssi, -65);
      expect(wifi.channel, 6);
      expect(wifi.isOpen, false);

      final outJson = wifi.toJson();
      expect(outJson['ssid'], 'MyHomeWifi');
      expect(outJson['open'], false);
    });

    test('Sound configuration update locally in SettingsRepository', () async {
      final initial = await settingsRepo.getSettings();
      expect(initial.alarmSound, 0);
      expect(initial.alarmSpacingMs, 10000);

      await settingsRepo.updateSoundSettings(
        ringtoneIndex: 2,
        repeatIntervalMs: 3000,
      );

      final updated = await settingsRepo.getSettings();
      expect(updated.alarmSound, 2);
      expect(updated.alarmSpacingMs, 3000);
    });

    test('themeMode is initialized and updated correctly', () async {
      final initial = await settingsRepo.getSettings();
      expect(initial.themeMode, 'dark');

      final updated = initial.copyWith(themeMode: 'light');
      await settingsRepo.updateSettings(updated);

      final retrieved = await settingsRepo.getSettings();
      expect(retrieved.themeMode, 'light');
    });

    group('RingtoneType & AlarmSpacingInterval mappings', () {
      test('RingtoneType fromIndex', () {
        expect(RingtoneType.fromIndex(0), RingtoneType.gentile);
        expect(RingtoneType.fromIndex(1), RingtoneType.alerta);
        expect(RingtoneType.fromIndex(2), RingtoneType.melodia);
        expect(RingtoneType.fromIndex(3), RingtoneType.urgente);
        expect(RingtoneType.fromIndex(4), RingtoneType.musical);
        expect(RingtoneType.fromIndex(99), RingtoneType.alerta);
      });

      test('AlarmSpacingInterval fromMs', () {
        expect(AlarmSpacingInterval.fromMs(1000), AlarmSpacingInterval.oneSecond);
        expect(AlarmSpacingInterval.fromMs(3000), AlarmSpacingInterval.threeSeconds);
        expect(AlarmSpacingInterval.fromMs(6000), AlarmSpacingInterval.sixSeconds);
        expect(AlarmSpacingInterval.fromMs(10000), AlarmSpacingInterval.tenSeconds);
        expect(AlarmSpacingInterval.fromMs(9999), AlarmSpacingInterval.tenSeconds);
      });
    });
  });
}
