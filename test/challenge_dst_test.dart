// ignore_for_file: depend_on_referenced_packages

import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:medicaixa_app/core/services/alarm_engine.dart';
import 'package:medicaixa_app/core/services/notification_service.dart';
import 'package:medicaixa_app/features/alarms/data/alarm_model.dart';
import 'package:medicaixa_app/features/alarms/data/alarm_repository.dart';
import 'package:medicaixa_app/features/alarms/data/alarm_api_client.dart';
import 'package:medicaixa_app/features/history/data/history_repository.dart';
import 'package:medicaixa_app/core/providers/core_providers.dart';
import 'package:medicaixa_app/core/database/database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/native.dart';
import 'package:flutter_local_notifications_platform_interface/flutter_local_notifications_platform_interface.dart';
import 'package:flutter/services.dart';

class FakeRef implements Ref {
  final ProviderContainer Function() containerFn;
  FakeRef(this.containerFn);

  @override
  T read<T>(ProviderListenable<T> listenable) => containerFn().read(listenable);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockAlarmApiClient implements AlarmApiClient {
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('flutter_timezone'),
      (methodCall) async {
        if (methodCall.method == 'getLocalTimezone') {
          return 'CustomLocation';
        }
        return null;
      },
    );

    FlutterLocalNotificationsPlatform.instance = MockLocalNotificationsPlatform();
    await NotificationService.instance.init();
    tz.initializeTimeZones();
  });

  group('Midnight Wrap & Missed Alarm Bug Verification', () {
    late AppDatabase db;
    late AlarmRepository repository;
    late HistoryRepository historyRepositoryInstance;
    late ProviderContainer container;

    setUp(() {
      db = AppDatabase.connect(NativeDatabase.memory());
      final apiClient = MockAlarmApiClient();
      final fakeRef = FakeRef(() => container);
      repository = AlarmRepository(db, apiClient, fakeRef);
      historyRepositoryInstance = HistoryRepository(db);

      container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          alarmRepositoryProvider.overrideWithValue(repository),
          alarmApiClientProvider.overrideWithValue(apiClient),
          historyRepositoryProvider.overrideWithValue(historyRepositoryInstance),
        ],
      );
    });

    tearDown(() async {
      await db.close();
      container.dispose();
    });

    test('Case 1: Daily tick reset is DELAYED when alarm is within window across midnight boundary', () async {
      // Set local timezone to custom timezone where it's 00:02:00 today.
      final nowUtc = DateTime.now().toUtc();
      final targetLocal = DateTime.utc(nowUtc.year, nowUtc.month, nowUtc.day, 0, 2, 0);
      final offsetMs = targetLocal.difference(nowUtc).inMilliseconds;

      final customTimeZone = tz.TimeZone(offsetMs, isDst: false, abbreviation: 'CUST');
      final customLocation = tz.Location('CustomLocation', [0], [0], [customTimeZone]);
      tz.setLocalLocation(customLocation);

      final localNow = tz.TZDateTime.now(tz.local);
      final yesterday = localNow.subtract(const Duration(days: 1));
      final yesterdayStr = "${yesterday.day.toString().padLeft(2, '0')}/${yesterday.month.toString().padLeft(2, '0')}/${yesterday.year}";

      // Alarm scheduled at 23:55 (yesterday). E.g. 7 minutes ago.
      // E.g. lastStatusDate is yesterdayStr
      final alarm = AlarmModel(
        id: 1,
        hour: 23,
        minute: 55,
        name: 'Midnight Active Alarm',
        medName: 'Med 1',
        enabled: true,
        active: true,
        days: List.filled(7, true),
        status: 'ATIVO',
        color: 'red',
        quantity: 1.0,
        daysQuantity: List.filled(7, 0.0),
        type: 'comprimido',
        snoozeMin: 0,
        durationDays: 0,
        lastStatus: 'Pendente',
        lastStatusDate: yesterdayStr,
      );

      await repository.createAlarm(alarm);

      final engine = container.read(alarmEngineProvider.notifier);
      await engine.triggerTick();

      final dbAlarms = await repository.getAllAlarms();
      final updatedAlarm = dbAlarms.firstWhere((a) => a.id == 256);

      // Verify that daily tick reset was DELAYED (status remains ATIVO, and lastStatusDate remains unchanged)
      expect(updatedAlarm.status, 'ATIVO');
      expect(updatedAlarm.lastStatusDate, yesterdayStr);
    });

    test('Case 2: Daily tick reset runs when window expires, BUT silently bypasses marking the alarm missed (Não Tomado)', () async {
      // Set local timezone to custom timezone where it's 00:06:00 today.
      final nowUtc = DateTime.now().toUtc();
      final targetLocal = DateTime.utc(nowUtc.year, nowUtc.month, nowUtc.day, 0, 6, 0);
      final offsetMs = targetLocal.difference(nowUtc).inMilliseconds;

      final customTimeZone = tz.TimeZone(offsetMs, isDst: false, abbreviation: 'CUST');
      final customLocation = tz.Location('CustomLocation', [0], [0], [customTimeZone]);
      tz.setLocalLocation(customLocation);

      final localNow = tz.TZDateTime.now(tz.local);
      final yesterday = localNow.subtract(const Duration(days: 1));
      final yesterdayStr = "${yesterday.day.toString().padLeft(2, '0')}/${yesterday.month.toString().padLeft(2, '0')}/${yesterday.year}";

      // Alarm scheduled at 23:55 (yesterday). E.g. 11 minutes ago.
      // E.g. lastStatusDate is yesterdayStr
      final alarm = AlarmModel(
        id: 2,
        hour: 23,
        minute: 55,
        name: 'Expired Midnight Alarm',
        medName: 'Med 2',
        enabled: true,
        active: true,
        days: List.filled(7, true),
        status: 'ATIVO',
        color: 'blue',
        quantity: 1.0,
        daysQuantity: List.filled(7, 0.0),
        type: 'comprimido',
        snoozeMin: 0,
        durationDays: 0,
        lastStatus: 'Pendente',
        lastStatusDate: yesterdayStr,
      );

      await repository.createAlarm(alarm);

      final engine = container.read(alarmEngineProvider.notifier);
      await engine.triggerTick();

      final dbAlarms = await repository.getAllAlarms();
      final updatedAlarm = dbAlarms.firstWhere((a) => a.id == 256);

      expect(updatedAlarm.status, 'PENDENTE');
      expect(updatedAlarm.lastStatusDate, yesterdayStr);
      expect(updatedAlarm.lastStatus, 'Não Tomado');
      final historyEvents = await historyRepositoryInstance.getAllHistoryEvents();
      expect(historyEvents.where((e) => e.status == 'PERDIDO').isNotEmpty, isTrue);
    });

    test('Case 3: Standard missed alarm (past 10 min window) does NOT write to the history table', () async {
      // Set local timezone to New York so we have standard time
      tz.setLocalLocation(tz.getLocation('America/New_York'));
      final localNow = tz.TZDateTime.now(tz.local);
      final todayStr = "${localNow.day.toString().padLeft(2, '0')}/${localNow.month.toString().padLeft(2, '0')}/${localNow.year}";

      // Target an occurrence 15 minutes in the past.
      final targetDate = localNow.subtract(const Duration(minutes: 15));

      final alarm = AlarmModel(
        id: 3,
        hour: targetDate.hour,
        minute: targetDate.minute,
        name: 'Standard Expired Alarm',
        medName: 'Med 3',
        enabled: true,
        active: true,
        days: List.filled(7, true),
        status: 'PENDENTE',
        color: 'green',
        quantity: 1.0,
        daysQuantity: List.filled(7, 0.0),
        type: 'comprimido',
        snoozeMin: 0,
        durationDays: 0,
        lastStatus: 'Pendente',
        lastStatusDate: todayStr, // Trigger "never triggered today" check bypass
      );

      await repository.createAlarm(alarm);

      final engine = container.read(alarmEngineProvider.notifier);
      await engine.triggerTick();

      final dbAlarms = await repository.getAllAlarms();
      final updatedAlarm = dbAlarms.firstWhere((a) => a.id == 256);

      // Verify that it was marked missed in alarm model
      expect(updatedAlarm.lastStatus, 'Não Tomado');

      // Verify that a history event was recorded in historyEvents table
      final historyEvents = await historyRepositoryInstance.getAllHistoryEvents();
      expect(historyEvents.where((e) => e.alarmId == 256 && e.status == 'PERDIDO').isNotEmpty, isTrue);
    });

    test('Case 4: Duplicate trigger loop bug when alarm is taken during the active window across midnight', () async {
      // Shift local timezone so localNow is exactly 00:02:00 today.
      final nowUtc = DateTime.now().toUtc();
      final targetLocal = DateTime.utc(nowUtc.year, nowUtc.month, nowUtc.day, 0, 2, 0);
      final offsetMs = targetLocal.difference(nowUtc).inMilliseconds;

      final customTimeZone = tz.TimeZone(offsetMs, isDst: false, abbreviation: 'CUST');
      final customLocation = tz.Location('CustomLocation', [0], [0], [customTimeZone]);
      tz.setLocalLocation(customLocation);

      final localNow = tz.TZDateTime.now(tz.local);
      final yesterday = localNow.subtract(const Duration(days: 1));
      final yesterdayStr = "${yesterday.day.toString().padLeft(2, '0')}/${yesterday.month.toString().padLeft(2, '0')}/${yesterday.year}";

      // Alarm scheduled yesterday at 23:55 (7 minutes ago relative to localNow at 00:02)
      // It is currently ATIVO with lastStatusDate = yesterdayStr (triggered state)
      final alarm = AlarmModel(
        id: 4,
        hour: 23,
        minute: 55,
        name: 'Midnight Taken Alarm',
        medName: 'Med 4',
        enabled: true,
        active: true,
        days: List.filled(7, true),
        status: 'ATIVO',
        color: 'red',
        quantity: 1.0,
        daysQuantity: List.filled(7, 0.0),
        type: 'comprimido',
        snoozeMin: 0,
        durationDays: 0,
        lastStatus: 'Pendente',
        lastStatusDate: yesterdayStr,
      );

      await repository.createAlarm(alarm);

      // Verify that calling markTaken preserves yesterdayStr as lastStatusDate
      await repository.markTaken(256);

      var dbAlarms = await repository.getAllAlarms();
      var updatedAlarm = dbAlarms.firstWhere((a) => a.id == 256);
      expect(updatedAlarm.status, equals('PENDENTE'));
      expect(updatedAlarm.lastStatusDate, equals(yesterdayStr));
      expect(updatedAlarm.lastStatus, equals('Tomado'));

      // Run background engine tick.
      final engine = container.read(alarmEngineProvider.notifier);
      await engine.triggerTick();

      dbAlarms = await repository.getAllAlarms();
      updatedAlarm = dbAlarms.firstWhere((a) => a.id == 256);

      // If the duplicate trigger loop bug is fixed, the status remains PENDENTE
      expect(updatedAlarm.status, equals('PENDENTE'), reason: 'Should not re-trigger an alarm that has already been taken!');
    });
  });
}
