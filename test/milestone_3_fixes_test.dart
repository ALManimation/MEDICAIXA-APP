// ignore_for_file: depend_on_referenced_packages

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/native.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications_platform_interface/flutter_local_notifications_platform_interface.dart';

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Milestone 3 Fixes - Sound Labels, Missed Alarms, JSON and Timezones', () {
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

    test('RingtoneType mapping verifies index 0 is labeled Gentil', () {
      final ringtone = RingtoneType.fromIndex(0);
      expect(ringtone, RingtoneType.gentile);
      expect(ringtone.label, 'Gentil');
    });

    test('Timezone initialization fallback handles errors and guesses correctly', () async {
      // Setup mock method channel to throw error for getLocalTimezone
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('flutter_timezone'),
        (methodCall) async {
          if (methodCall.method == 'getLocalTimezone') {
            throw PlatformException(code: 'UNAVAILABLE', message: 'Timezone service not available');
          }
          return null;
        },
      );

      // Verify initializing local timezone doesn't crash and sets a valid local location
      await NotificationService.instance.init();
      expect(tz.local, isNotNull);
      expect(tz.local.name, isNotEmpty);
    });

    test('Disabled/Inactive alarms are excluded from missed count when their hours have passed', () async {
      final now = DateTime.now();
      
      // We will define an alarm whose time has passed (e.g., 2 hours ago)
      final alarmHour = (now.hour - 2) % 24;
      
      // Insert an enabled alarm
      final alarmEnabled = AlarmModel(
        id: 1,
        hour: alarmHour,
        minute: now.minute,
        name: 'Enabled Pill',
        medName: 'Ibuprofeno',
        enabled: true,
        active: true,
        days: List.filled(7, true),
        status: 'PENDENTE',
        color: 'red',
        quantity: 1.0,
        daysQuantity: List.filled(7, 0.0),
        type: 'comprimido',
        snoozeMin: 0,
        durationDays: 0,
      );

      // Insert a disabled alarm
      final alarmDisabled = AlarmModel(
        id: 2,
        hour: alarmHour,
        minute: now.minute,
        name: 'Disabled Pill',
        medName: 'Paracetamol',
        enabled: false,
        active: true,
        days: List.filled(7, true),
        status: 'PENDENTE',
        color: 'blue',
        quantity: 1.0,
        daysQuantity: List.filled(7, 0.0),
        type: 'comprimido',
        snoozeMin: 0,
        durationDays: 0,
      );

      // Insert an inactive alarm
      final alarmInactive = AlarmModel(
        id: 3,
        hour: alarmHour,
        minute: now.minute,
        name: 'Inactive Pill',
        medName: 'Dipirona',
        enabled: true,
        active: false,
        days: List.filled(7, true),
        status: 'PENDENTE',
        color: 'green',
        quantity: 1.0,
        daysQuantity: List.filled(7, 0.0),
        type: 'comprimido',
        snoozeMin: 0,
        durationDays: 0,
      );

      // Save to database
      await alarmRepo.createAlarm(alarmEnabled);
      await alarmRepo.createAlarm(alarmDisabled);
      await alarmRepo.createAlarm(alarmInactive);

      // Await the provider state to complete and get the value
      final state = await container.read(dashboardNotifierProvider.future);
      
      // The enabled alarm should count as missed. The disabled/inactive ones should not.
      // So missedCount should be exactly 1 (from alarmEnabled).
      expect(state.missedCount, 1);
    });
  });
}
