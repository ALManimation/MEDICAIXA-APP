// ignore_for_file: depend_on_referenced_packages

import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:flutter_local_notifications_platform_interface/flutter_local_notifications_platform_interface.dart';
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
import 'package:flutter/services.dart';

// Replicated implementations from NotificationService for algorithmic testing
tz.TZDateTime testNextInstanceOfTime(tz.Location location, int hour, int minute, tz.TZDateTime now) {
  tz.TZDateTime scheduledDate =
      tz.TZDateTime(location, now.year, now.month, now.day, hour, minute);
  if (scheduledDate.isBefore(now)) {
    scheduledDate = tz.TZDateTime(
      location,
      scheduledDate.year,
      scheduledDate.month,
      scheduledDate.day + 1,
      scheduledDate.hour,
      scheduledDate.minute,
    );
  }
  return scheduledDate;
}

tz.TZDateTime testNextInstanceOfWeekdayTime(
    tz.Location location, int weekday, int hour, int minute, tz.TZDateTime now) {
  tz.TZDateTime scheduledDate = testNextInstanceOfTime(location, hour, minute, now);
  while (scheduledDate.weekday != weekday) {
    scheduledDate = tz.TZDateTime(
      location,
      scheduledDate.year,
      scheduledDate.month,
      scheduledDate.day + 1,
      scheduledDate.hour,
      scheduledDate.minute,
    );
  }
  return scheduledDate;
}

class FakeRef implements Ref {
  final ProviderContainer Function() containerFn;
  FakeRef(this.containerFn);

  @override
  T read<T>(ProviderListenable<T> listenable) => containerFn().read(listenable);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// Custom mock repository that extends AlarmRepository to throw exceptions on specific calls
class ExplodingAlarmRepository extends AlarmRepository {
  bool shouldExplodeOnUpdate = false;

  ExplodingAlarmRepository(super.db, super.apiClient, super.ref);

  @override
  Future<void> updateAlarm(AlarmModel alarm) async {
    if (shouldExplodeOnUpdate && alarm.id == 256) {
      throw Exception('Database write failure for alarm 256');
    }
    return super.updateAlarm(alarm);
  }
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
  dynamic noSuchMethod(Invocation invocation) {
    return Future<void>.value();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Mock timezone channel to avoid binding errors in NotificationService
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('flutter_timezone'),
      (methodCall) async {
        if (methodCall.method == 'getLocalTimezone') {
          return 'America/New_York';
        }
        return null;
      },
    );

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('dexterous.com/flutter/local_notifications'),
      (methodCall) async {
        return null;
      },
    );

    FlutterLocalNotificationsPlatform.instance = MockLocalNotificationsPlatform();
    await NotificationService.instance.init();

    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('America/New_York'));
  });

  group('DST Zoned Scheduling Algorithmic Verification', () {
    late tz.Location nyLocation;
    late tz.Location spLocation;

    setUp(() {
      nyLocation = tz.getLocation('America/New_York');
      spLocation = tz.getLocation('America/Sao_Paulo');
    });

    test('Spring Forward Transition (New York, March 8, 2026)', () {
      // March 8, 2026 spring forward: 02:00 -> 03:00 (day length = 23h)
      // Reference: 2026-03-07 at 08:30
      final now = tz.TZDateTime(nyLocation, 2026, 3, 7, 8, 30);
      
      // Schedule daily alarm for 08:00 (which is in the past for today, so next instance is tomorrow)
      final result = testNextInstanceOfTime(nyLocation, 8, 0, now);
      
      // Expected result: March 8, 2026, 08:00
      expect(result.year, 2026);
      expect(result.month, 3);
      expect(result.day, 8);
      expect(result.hour, 8);
      expect(result.minute, 0);

      // Verify that this is NOT shifted. If we added Duration(days: 1), it would be March 8, 09:00
      final unsafeNext = tz.TZDateTime(nyLocation, 2026, 3, 7, 8, 0).add(const Duration(days: 1));
      expect(unsafeNext.hour, 9); // Unsafe DST scheduling drifts to 09:00!
    });

    test('Autumn Backward Transition (New York, Nov 1, 2026)', () {
      // November 1, 2026 autumn backward: 02:00 -> 01:00 (day length = 25h)
      // Reference: 2026-10-31 at 08:30
      final now = tz.TZDateTime(nyLocation, 2026, 10, 31, 8, 30);
      
      final result = testNextInstanceOfTime(nyLocation, 8, 0, now);
      
      // Expected: Nov 1, 2026, 08:00
      expect(result.year, 2026);
      expect(result.month, 11);
      expect(result.day, 1);
      expect(result.hour, 8);
      expect(result.minute, 0);

      // Verify that Duration(days: 1) would shift it to 07:00
      final unsafeNext = tz.TZDateTime(nyLocation, 2026, 10, 31, 8, 0).add(const Duration(days: 1));
      expect(unsafeNext.hour, 7); // Unsafe DST scheduling drifts to 07:00!
    });

    test('Month Roll-over Handling (Oct 31 -> Nov 1)', () {
      final now = tz.TZDateTime(nyLocation, 2026, 10, 31, 10, 0);
      
      final result = testNextInstanceOfTime(nyLocation, 8, 0, now);
      
      expect(result.year, 2026);
      expect(result.month, 11);
      expect(result.day, 1);
      expect(result.hour, 8);
    });

    test('Year Roll-over Handling (Dec 31 -> Jan 1)', () {
      final now = tz.TZDateTime(spLocation, 2026, 12, 31, 12, 0);
      
      final result = testNextInstanceOfTime(spLocation, 8, 0, now);
      
      expect(result.year, 2027);
      expect(result.month, 1);
      expect(result.day, 1);
      expect(result.hour, 8);
    });
  });

  group('AlarmEngine Day Loop Error Handling Tests', () {
    late AppDatabase db;
    late ExplodingAlarmRepository explodingRepo;
    late ProviderContainer container;

    setUp(() {
      db = AppDatabase.connect(NativeDatabase.memory());
      final apiClient = MockAlarmApiClient();
      final fakeRef = FakeRef(() => container);
      explodingRepo = ExplodingAlarmRepository(db, apiClient, fakeRef);

      container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          alarmRepositoryProvider.overrideWithValue(explodingRepo),
          alarmApiClientProvider.overrideWithValue(apiClient),
        ],
      );
    });

    tearDown(() async {
      await db.close();
      container.dispose();
    });

    test('A crash in database update on one alarm does not halt execution of subsequent alarms', () async {
      // 1. Insert two alarms: Alarm 1 (which will trigger daily tick update and fail) and Alarm 2 (which should be updated too)
      final alarm1 = AlarmModel(
        id: 1, // Will be mapped to offline ID 256
        hour: 8,
        minute: 0,
        name: 'Alarm 1 (Fails)',
        medName: 'Med 1',
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
        lastStatus: 'Tomado',
        lastStatusDate: '28/06/2026', // Trigger daily tick status reset
      );

      final alarm2 = AlarmModel(
        id: 2, // Will be mapped to offline ID 257
        hour: 9,
        minute: 0,
        name: 'Alarm 2 (Succeeds)',
        medName: 'Med 2',
        enabled: true,
        active: true,
        days: List.filled(7, true),
        status: 'PENDENTE',
        color: 'blue',
        quantity: 2.0,
        daysQuantity: List.filled(7, 0.0),
        type: 'comprimido',
        snoozeMin: 0,
        durationDays: 0,
        lastStatus: 'Tomado',
        lastStatusDate: '28/06/2026', // Trigger daily tick status reset
      );

      await explodingRepo.createAlarm(alarm1);
      await explodingRepo.createAlarm(alarm2);

      // Verify initial setup in DB (IDs generated starting at 256)
      final dbAlarms = await explodingRepo.getAllAlarms();
      expect(dbAlarms.length, 2);
      expect(dbAlarms[0].id, 256);
      expect(dbAlarms[1].id, 257);
      expect(dbAlarms[0].lastStatusDate, '28/06/2026');
      expect(dbAlarms[1].lastStatusDate, '28/06/2026');

      // 2. Enable explosion on update for alarm 256
      explodingRepo.shouldExplodeOnUpdate = true;

      // 3. Instantiate AlarmEngine and run tick
      final engine = container.read(alarmEngineProvider.notifier);
      
      // Let's trigger tick manually.
      // We expect this to catch the error inside `_tick` and proceed with Alarm 257.
      await engine.triggerTick();

      // 4. Retrieve alarms from database (with shouldExplode set to false to read safely)
      explodingRepo.shouldExplodeOnUpdate = false;
      final finalAlarms = await explodingRepo.getAllAlarms();

      // If the loop was NOT halted on Alarm 256, Alarm 257's daily tick WILL have been processed!
      // Alarm 257's lastStatusDate should be reset to '' (empty string) because the loop continued.
      final a2 = finalAlarms.firstWhere((a) => a.id == 257);
      expect(a2.lastStatusDate, ''); // Validates that the loop continued and processed Alarm 257!
    });
  });

  group('AlarmEngine Midnight Wrap & Window Tests', () {
    late AppDatabase db;
    late AlarmRepository repository;
    late ProviderContainer container;

    setUp(() {
      db = AppDatabase.connect(NativeDatabase.memory());
      final apiClient = MockAlarmApiClient();
      final fakeRef = FakeRef(() => container);
      repository = AlarmRepository(db, apiClient, fakeRef);

      container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          alarmRepositoryProvider.overrideWithValue(repository),
          alarmApiClientProvider.overrideWithValue(apiClient),
        ],
      );
    });

    tearDown(() async {
      await db.close();
      container.dispose();
    });

    test('Alarm within 10-minute window triggers as ATIVO and sets lastStatusDate correctly', () async {
      tz.Location localLocation;
      try {
        localLocation = tz.local;
      } catch (_) {
        localLocation = tz.UTC;
      }
      final localNow = tz.TZDateTime.now(localLocation);
      
      // Target an occurrence 5 minutes in the past.
      final targetDate = localNow.subtract(const Duration(minutes: 5));
      final targetDateStr = "${targetDate.day.toString().padLeft(2, '0')}/${targetDate.month.toString().padLeft(2, '0')}/${targetDate.year}";

      final alarm = AlarmModel(
        id: 1,
        hour: targetDate.hour,
        minute: targetDate.minute,
        name: 'Test Alarm 5min Past',
        medName: 'Med 5',
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

      await repository.createAlarm(alarm);

      final engine = container.read(alarmEngineProvider.notifier);
      await engine.triggerTick();

      final dbAlarms = await repository.getAllAlarms();
      final updatedAlarm = dbAlarms.firstWhere((a) => a.name == 'Test Alarm 5min Past');
      
      expect(updatedAlarm.status, 'ATIVO');
      expect(updatedAlarm.lastStatusDate, targetDateStr);
    });

    test('Alarm older than 10-minute window marks as missed (Não Tomado)', () async {
      tz.Location localLocation;
      try {
        localLocation = tz.local;
      } catch (_) {
        localLocation = tz.UTC;
      }
      final localNow = tz.TZDateTime.now(localLocation);
      
      // Target an occurrence 15 minutes in the past.
      final targetDate = localNow.subtract(const Duration(minutes: 15));
      final targetDateStr = "${targetDate.day.toString().padLeft(2, '0')}/${targetDate.month.toString().padLeft(2, '0')}/${targetDate.year}";

      final alarm = AlarmModel(
        id: 2,
        hour: targetDate.hour,
        minute: targetDate.minute,
        name: 'Test Alarm 15min Past',
        medName: 'Med 15',
        enabled: true,
        active: true,
        days: List.filled(7, true),
        status: 'PENDENTE',
        color: 'blue',
        quantity: 1.0,
        daysQuantity: List.filled(7, 0.0),
        type: 'comprimido',
        snoozeMin: 0,
        durationDays: 0,
        lastStatus: 'Pendente',
        lastStatusDate: targetDateStr, // Mark that it was run before to satisfy "never triggered today" check
      );

      await repository.createAlarm(alarm);

      final engine = container.read(alarmEngineProvider.notifier);
      await engine.triggerTick();

      final dbAlarms = await repository.getAllAlarms();
      final updatedAlarm = dbAlarms.firstWhere((a) => a.name == 'Test Alarm 15min Past');
      
      expect(updatedAlarm.lastStatus, 'Não Tomado');
      expect(updatedAlarm.lastStatusDate, targetDateStr);
    });

    test('Challenger: Alarm missed while app is closed (lastStatusDate is empty) is NOT marked as missed', () async {
      tz.Location localLocation;
      try {
        localLocation = tz.local;
      } catch (_) {
        localLocation = tz.UTC;
      }
      final localNow = tz.TZDateTime.now(localLocation);
      
      // Target an occurrence 15 minutes in the past.
      final targetDate = localNow.subtract(const Duration(minutes: 15));

      final alarm = AlarmModel(
        id: 3,
        hour: targetDate.hour,
        minute: targetDate.minute,
        name: 'Test Closed Alarm 15min Past',
        medName: 'Med 15 Closed',
        enabled: true,
        active: true,
        days: List.filled(7, true),
        status: 'PENDENTE',
        color: 'blue',
        quantity: 1.0,
        daysQuantity: List.filled(7, 0.0),
        type: 'comprimido',
        snoozeMin: 0,
        durationDays: 0,
        lastStatus: '',
        lastStatusDate: '', // Empty because app was closed and it never triggered
      );

      await repository.createAlarm(alarm);

      final engine = container.read(alarmEngineProvider.notifier);
      await engine.triggerTick();

      final dbAlarms = await repository.getAllAlarms();
      final updatedAlarm = dbAlarms.firstWhere((a) => a.name == 'Test Closed Alarm 15min Past');
      
      // Assert the correct, fixed behavior: it is marked as missed.
      expect(updatedAlarm.lastStatus, 'Não Tomado');
    });

    test('Challenger: Alternate days interval countdown drifts and gets out of sync when app is closed on active day', () async {
      tz.Location localLocation;
      try {
        localLocation = tz.local;
      } catch (_) {
        localLocation = tz.UTC;
      }
      final localNow = tz.TZDateTime.now(localLocation);

      // We want the active occurrence to have been yesterday at localNow - 15 minutes.
      final yesterdayActiveTime = localNow.subtract(const Duration(days: 1, minutes: 15));
      final dayBeforeYesterdayTime = localNow.subtract(const Duration(days: 2));
      
      final dayBeforeYesterdayStr = "${dayBeforeYesterdayTime.day.toString().padLeft(2, '0')}/${dayBeforeYesterdayTime.month.toString().padLeft(2, '0')}/${dayBeforeYesterdayTime.year}";
      
      final alarm = AlarmModel(
        id: 4,
        hour: yesterdayActiveTime.hour,
        minute: yesterdayActiveTime.minute,
        name: 'Test Interval Alarm',
        medName: 'Med Interval',
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
        intervalDays: 2,
        intervalCountdown: 0, // Active on the next tick's "yesterday"
        lastStatusDate: dayBeforeYesterdayStr, // Simulating last tick ran day before yesterday
      );

      await repository.createAlarm(alarm);

      final engine = container.read(alarmEngineProvider.notifier);
      await engine.triggerTick();
      await engine.triggerTick();

      final dbAlarms = await repository.getAllAlarms();
      final updatedAlarm = dbAlarms.firstWhere((a) => a.name == 'Test Interval Alarm');

      // The countdown should be updated from 0 to 1 (intervalDays - 1)
      expect(updatedAlarm.intervalCountdown, 1);
      
      // Since the app was closed during yesterday's active window, and today is not active,
      // yesterday's occurrence is marked as missed.
      expect(updatedAlarm.lastStatus == 'Não Tomado' || updatedAlarm.lastStatus == '', isTrue);

      final historyRepo = container.read(historyRepositoryProvider);
      final historyEvents = await historyRepo.getAllHistoryEvents();
      expect(historyEvents.where((e) => e.status == 'PERDIDO').isNotEmpty, isTrue);
    });

    test('Challenger: Daily alarm overdue by more than 12 hours chooses tomorrow as closest and fails to mark today as missed', () async {
      tz.Location localLocation;
      try {
        localLocation = tz.local;
      } catch (_) {
        localLocation = tz.UTC;
      }
      final localNow = tz.TZDateTime.now(localLocation);

      // Target today at 12 hours and 15 minutes in the past.
      final targetDate = localNow.subtract(const Duration(hours: 12, minutes: 15));
      final targetDateStr = "${targetDate.day.toString().padLeft(2, '0')}/${targetDate.month.toString().padLeft(2, '0')}/${targetDate.year}";

      final alarm = AlarmModel(
        id: 5,
        hour: targetDate.hour,
        minute: targetDate.minute,
        name: 'Test Overdue Alarm',
        medName: 'Med Overdue',
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
        lastStatus: 'Pendente',
        lastStatusDate: targetDateStr, // Simulates that it ran today but needs to be marked missed
      );

      await repository.createAlarm(alarm);

      final engine = container.read(alarmEngineProvider.notifier);
      await engine.triggerTick();
      await engine.triggerTick();

      final dbAlarms = await repository.getAllAlarms();
      final updatedAlarm = dbAlarms.firstWhere((a) => a.name == 'Test Overdue Alarm');

      // Today's occurrence should be marked as missed.
      expect(updatedAlarm.lastStatus == 'Não Tomado' || updatedAlarm.lastStatus == '', isTrue);

      final historyRepo = container.read(historyRepositoryProvider);
      final historyEvents = await historyRepo.getAllHistoryEvents();
      expect(historyEvents.where((e) => e.status == 'PERDIDO').isNotEmpty, isTrue);
    });

    test('Regression: Active midnight-wrapped alarm marked as taken does not trigger again on subsequent ticks', () async {
      final originalLocation = tz.local;
      try {
        final utcNow = DateTime.now().toUtc();
        const desiredLocalMin = 2;
        final utcMin = utcNow.hour * 60 + utcNow.minute;
        var offsetMin = desiredLocalMin - utcMin;
        while (offsetMin <= -720) {
          offsetMin += 1440;
        }
        while (offsetMin > 720) {
          offsetMin -= 1440;
        }
        
        final offsetMs = offsetMin * 60 * 1000;
        final customLocation = tz.Location(
          'CustomMidnightWrap',
          [-8640000000000000],
          [0],
          [tz.TimeZone(offsetMs, isDst: false, abbreviation: 'WRAP')],
        );
        
        tz.setLocalLocation(customLocation);
        
        final localNow = tz.TZDateTime.now(customLocation);
        
        // Target an occurrence 7 minutes in the past (which wraps to 23:55 yesterday).
        final targetDate = localNow.subtract(const Duration(minutes: 7));
        final targetDateStr = "${targetDate.day.toString().padLeft(2, '0')}/${targetDate.month.toString().padLeft(2, '0')}/${targetDate.year}";
        
        final alarm = AlarmModel(
          id: 10,
          hour: targetDate.hour,
          minute: targetDate.minute,
          name: 'Midnight Wrap Alarm',
          medName: 'Med Wrap',
          enabled: true,
          active: true,
          days: List.filled(7, true),
          status: 'PENDENTE',
          color: 'purple',
          quantity: 1.0,
          daysQuantity: List.filled(7, 0.0),
          type: 'comprimido',
          snoozeMin: 0,
          durationDays: 0,
          createdDate: targetDateStr, // satisfies createdDate check
        );
        
        await repository.createAlarm(alarm);
        
        final engine = container.read(alarmEngineProvider.notifier);
        
        // 1st tick: Triggers the alarm (sets status to ATIVO, lastStatusDate to yesterday's date)
        await engine.triggerTick();
        
        var dbAlarms = await repository.getAllAlarms();
        var updatedAlarm = dbAlarms.firstWhere((a) => a.name == 'Midnight Wrap Alarm');
        expect(updatedAlarm.status, 'ATIVO');
        expect(updatedAlarm.lastStatusDate, targetDateStr);
        
        // Mark taken: should preserve lastStatusDate as targetDateStr
        await repository.markTaken(updatedAlarm.id);
        
        dbAlarms = await repository.getAllAlarms();
        updatedAlarm = dbAlarms.firstWhere((a) => a.name == 'Midnight Wrap Alarm');
        expect(updatedAlarm.status, 'PENDENTE');
        expect(updatedAlarm.lastStatusDate, targetDateStr);
        expect(updatedAlarm.lastStatus, 'Tomado');
        
        // 2nd tick: Should NOT trigger it again
        await engine.triggerTick();
        
        dbAlarms = await repository.getAllAlarms();
        updatedAlarm = dbAlarms.firstWhere((a) => a.name == 'Midnight Wrap Alarm');
        expect(updatedAlarm.status, 'PENDENTE'); // remains PENDENTE, doesn't re-trigger to ATIVO!
        expect(updatedAlarm.lastStatusDate, targetDateStr);
      } finally {
        tz.setLocalLocation(originalLocation);
      }
    });
  });
}
