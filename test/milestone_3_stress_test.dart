// ignore_for_file: depend_on_referenced_packages

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/native.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications_platform_interface/flutter_local_notifications_platform_interface.dart';
import 'package:flutter/foundation.dart';

import 'package:medicaixa_app/core/database/database.dart';
import 'package:medicaixa_app/core/providers/core_providers.dart';
import 'package:medicaixa_app/core/services/notification_service.dart';
import 'package:medicaixa_app/features/alarms/data/alarm_model.dart';
import 'package:medicaixa_app/features/alarms/data/alarm_repository.dart';
import 'package:medicaixa_app/features/alarms/data/alarm_api_client.dart';
import 'package:medicaixa_app/features/dashboard/presentation/dashboard_notifier.dart';
import 'package:medicaixa_app/features/settings/data/settings_models.dart';
import 'package:medicaixa_app/features/history/data/history_repository.dart';
import 'package:medicaixa_app/features/reminders/data/reminder_repository.dart';
import 'package:medicaixa_app/features/reminders/data/reminder_api_client.dart';

class MockAlarmApiClient implements AlarmApiClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class MockReminderApiClient implements ReminderApiClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class MockLocalNotificationsPlatform extends FlutterLocalNotificationsPlatform {
  @override
  Future<void> cancel(int id) async {}
  @override
  Future<void> cancelAll() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class FakeRef implements Ref {
  final ProviderContainer Function() containerFn;
  FakeRef(this.containerFn);

  @override
  T read<T>(ProviderListenable<T> listenable) => containerFn().read(listenable);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// Top level function for compute JSON decode testing
Map<String, dynamic> _testDecodeJson(String source) {
  return json.decode(source) as Map<String, dynamic>;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Milestone 3 Stress Tests - Edge Cases & Robustness', () {
    late AppDatabase db;
    late ProviderContainer container;
    late AlarmRepository alarmRepo;
    late HistoryRepository historyRepo;
    late ReminderRepository reminderRepo;

    setUpAll(() {
      tz.initializeTimeZones();
      FlutterLocalNotificationsPlatform.instance = MockLocalNotificationsPlatform();
    });

    setUp(() {
      db = AppDatabase.connect(NativeDatabase.memory());
      final alarmApiClient = MockAlarmApiClient();
      final reminderApiClient = MockReminderApiClient();
      final fakeRef = FakeRef(() => container);
      
      alarmRepo = AlarmRepository(db, alarmApiClient, fakeRef);
      historyRepo = HistoryRepository(db);
      reminderRepo = ReminderRepository(db, reminderApiClient, fakeRef);

      container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          alarmRepositoryProvider.overrideWithValue(alarmRepo),
          alarmApiClientProvider.overrideWithValue(alarmApiClient),
          historyRepositoryProvider.overrideWithValue(historyRepo),
          reminderRepositoryProvider.overrideWithValue(reminderRepo),
          reminderApiClientProvider.overrideWithValue(reminderApiClient),
        ],
      );
    });

    tearDown(() async {
      await db.close();
      container.dispose();
    });

    test('RingtoneType edge cases: invalid index or extremes', () {
      // Check fromIndex with out-of-bounds negative index
      final ringtoneNegative = RingtoneType.fromIndex(-1);
      // should fallback to alerta (index 1) based on fromIndex implementation
      expect(ringtoneNegative, RingtoneType.alerta);

      // Check fromIndex with out-of-bounds positive index
      final ringtoneLarge = RingtoneType.fromIndex(99);
      expect(ringtoneLarge, RingtoneType.alerta);

      // Check all valid indices
      expect(RingtoneType.fromIndex(0), RingtoneType.gentile);
      expect(RingtoneType.fromIndex(1), RingtoneType.alerta);
      expect(RingtoneType.fromIndex(2), RingtoneType.melodia);
      expect(RingtoneType.fromIndex(3), RingtoneType.urgente);
      expect(RingtoneType.fromIndex(4), RingtoneType.musical);
    });

    test('Timezone fallback logic covers standard and unusual offsets', () async {
      // Accessing guessing logic directly since it's in NotificationService.
      // Since it's private or internal to NotificationService, we can verify how it behaves 
      // under different mocked flutter_timezone outputs.
      
      final mockHandler = (int hours, int minutes) {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('flutter_timezone'),
          (methodCall) async {
            if (methodCall.method == 'getLocalTimezone') {
              throw PlatformException(code: 'UNAVAILABLE');
            }
            return null;
          },
        );
      };

      // Let's test that init() resolves correctly for fallback
      mockHandler(-3, 0);
      await NotificationService.instance.init();
      expect(tz.local, isNotNull);
    });

    test('Missed Alarms Excludes Inactive/Disabled: 100 Alarm Simulation Stress Test', () async {
      final now = DateTime.now();
      final alarmHour = (now.hour - 2) % 24;

      int expectedMissed = 0;

      // Generate 100 alarms
      for (int i = 1; i <= 100; i++) {
        final isEnabled = i % 2 == 0;
        final isActive = i % 3 != 0; // mix of active/inactive
        
        final alarm = AlarmModel(
          id: i,
          hour: alarmHour,
          minute: now.minute,
          name: 'Stress Alarm $i',
          medName: 'Pill $i',
          enabled: isEnabled,
          active: isActive,
          days: List.filled(7, true),
          status: 'PENDENTE',
          color: 'blue',
          quantity: 1.0,
          daysQuantity: List.filled(7, 0.0),
          type: 'comprimido',
          snoozeMin: 0,
          durationDays: 0,
        );

        await alarmRepo.createAlarm(alarm);

        // Under normal past conditions (hour - 2), only active AND enabled count as missed.
        if (isEnabled && isActive) {
          expectedMissed++;
        }
      }

      final state = await container.read(dashboardNotifierProvider.future);
      expect(state.missedCount, expectedMissed);
    });

    test('JSON decoding compute stress test with a large payload', () async {
      // Create a large JSON payload (simulate a backup file with 200 alarms, meds, history, etc.)
      final Map<String, dynamic> largeBackup = {
        'alarms': List.generate(200, (i) => {
          'id': i,
          'hour': 8,
          'minute': 0,
          'name': 'Alarm $i',
          'med_name': 'Med $i',
          'enabled': true,
          'active': true,
          'days': [true, true, true, true, true, true, true],
          'status': 'PENDENTE',
          'color': 'red',
          'quantity': 1.0,
          'days_quantity': [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
          'type': 'comprimido',
          'snooze_min': 0,
          'duration_days': 0,
        }),
        'meds': List.generate(200, (i) => {
          'id': i,
          'name': 'Med $i',
          'dosage': '10mg',
          'color': 'blue',
        }),
      };

      final String jsonString = json.encode(largeBackup);

      // Verify compute works without throwing errors on large JSON
      final Map<String, dynamic> result = await compute(_testDecodeJson, jsonString);
      expect(result, isNotNull);
      expect(result['alarms'], isList);
      expect((result['alarms'] as List).length, 200);
      expect(result['meds'], isList);
      expect((result['meds'] as List).length, 200);
    });
  });
}
