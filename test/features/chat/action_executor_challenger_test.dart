import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:medicaixa_app/core/database/database.dart';
import 'package:medicaixa_app/core/network/dio_client.dart';
import 'package:medicaixa_app/core/providers/core_providers.dart';
import 'package:medicaixa_app/features/chat/domain/services/action_executor.dart';
import 'package:medicaixa_app/features/chat/domain/services/llm_service.dart';
import 'package:medicaixa_app/features/chat/data/services/llm_providers.dart';
import 'package:medicaixa_app/features/settings/data/settings_repository.dart';
import 'package:medicaixa_app/features/alarms/data/alarm_repository.dart';
import 'package:medicaixa_app/features/alarms/data/alarm_api_client.dart';
import 'package:medicaixa_app/features/alarms/data/alarm_model.dart';
import 'package:medicaixa_app/features/reminders/data/reminder_repository.dart';
import 'package:medicaixa_app/features/reminders/data/reminder_api_client.dart';
import 'package:medicaixa_app/features/reminders/data/reminder_model.dart';
import 'package:medicaixa_app/features/medications/data/medication_repository.dart';
import 'package:medicaixa_app/features/medications/data/medication_api_client.dart';
import 'package:medicaixa_app/features/history/data/history_repository.dart';

class MockDioClient implements DioClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class MockAlarmApiClient implements AlarmApiClient {
  @override
  Future<int> addAlarm(AlarmModel alarm) async => 10;
  @override
  Future<void> updateAlarm(AlarmModel alarm) async {}
  @override
  Future<void> removeAlarm(int id) async {}
  @override
  Future<void> toggleAlarm(int id, bool enabled) async {}
  @override
  Future<void> markTaken(int id, {double? qty}) async {}
  @override
  Future<void> snoozeAlarm(int id, int minutes) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class MockReminderApiClient implements ReminderApiClient {
  @override
  Future<int> addReminder(ReminderModel reminder) async => 20;
  @override
  Future<void> updateReminder(ReminderModel reminder) async {}
  @override
  Future<void> removeReminder(int id) async {}
  @override
  Future<void> toggleReminder(int id, bool enabled) async {}
  @override
  Future<void> completeReminder(int id) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class MockMedicationApiClient implements MedicationApiClient {
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

AlarmsCompanion _toAlarmCompanion(AlarmModel model) {
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
  );
}

RemindersCompanion _toReminderCompanion(ReminderModel model) {
  return RemindersCompanion(
    id: Value(model.id),
    title: Value(model.title),
    description: Value(model.description),
    enabled: Value(model.enabled),
    hasTime: Value(model.hasTime),
    hour: Value(model.hour),
    minute: Value(model.minute),
    period: Value(model.period),
    interval: Value(model.interval),
    startDate: Value(model.startDate),
    notifyDaysBefore: Value(model.notifyDaysBefore),
    lastCompletedDate: Value(model.lastCompletedDate),
    color: Value(model.color),
  );
}

void main() {
  group('ActionExecutor Challenger Unit/Edge-case/Stress Tests', () {
    late AppDatabase db;
    late MockDioClient dioClient;
    late MockAlarmApiClient alarmApiClient;
    late MockReminderApiClient reminderApiClient;
    late MockMedicationApiClient medicationApiClient;
    late ProviderContainer container;
    late SettingsRepository settingsRepo;
    late AlarmRepository alarmRepo;
    late ReminderRepository reminderRepo;
    late MedicationRepository medicationRepo;
    late HistoryRepository historyRepo;
    late ActionExecutor executor;

    setUp(() async {
      db = AppDatabase.connect(NativeDatabase.memory());
      dioClient = MockDioClient();
      alarmApiClient = MockAlarmApiClient();
      reminderApiClient = MockReminderApiClient();
      medicationApiClient = MockMedicationApiClient();

      final preContainer = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          dioClientProvider.overrideWithValue(dioClient),
          alarmApiClientProvider.overrideWithValue(alarmApiClient),
          reminderApiClientProvider.overrideWithValue(reminderApiClient),
          medicationApiClientProvider.overrideWithValue(medicationApiClient),
        ],
      );

      settingsRepo = SettingsRepository(db, dioClient, FakeRef(preContainer));
      alarmRepo = AlarmRepository(db, alarmApiClient, FakeRef(preContainer));
      reminderRepo = ReminderRepository(db, reminderApiClient, FakeRef(preContainer));
      medicationRepo = MedicationRepository(db, medicationApiClient, FakeRef(preContainer));
      historyRepo = HistoryRepository(db);

      container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          dioClientProvider.overrideWithValue(dioClient),
          alarmApiClientProvider.overrideWithValue(alarmApiClient),
          reminderApiClientProvider.overrideWithValue(reminderApiClient),
          medicationApiClientProvider.overrideWithValue(medicationApiClient),
          settingsRepositoryProvider.overrideWithValue(settingsRepo),
          alarmRepositoryProvider.overrideWithValue(alarmRepo),
          reminderRepositoryProvider.overrideWithValue(reminderRepo),
          medicationRepositoryProvider.overrideWithValue(medicationRepo),
          historyRepositoryProvider.overrideWithValue(historyRepo),
        ],
      );

      executor = container.read(actionExecutorProvider);
    });

    tearDown(() async {
      await db.close();
      container.dispose();
    });

    AlarmModel createBaseAlarm({int id = 1, int hour = 8, String status = 'ATIVO', bool enabled = true}) {
      return AlarmModel(
        id: id,
        hour: hour,
        minute: 0,
        name: 'Remedio $id',
        medName: 'Remedio $id',
        enabled: enabled,
        active: true,
        days: List.filled(7, true),
        status: status,
        color: 'blue',
        quantity: 1.0,
        daysQuantity: List.filled(7, 0.0),
        type: 'comprimido',
        snoozeMin: 10,
        durationDays: 0,
      );
    }

    ReminderModel createBaseReminder({int id = 1, bool enabled = true}) {
      final now = DateTime.now();
      final todayStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
      return ReminderModel(
        id: id,
        title: 'Reminder $id',
        description: 'Desc $id',
        enabled: enabled,
        hasTime: true,
        hour: 8,
        minute: 0,
        period: 'day',
        interval: 1,
        startDate: todayStr,
        notifyDaysBefore: 0,
        color: 'blue',
      );
    }

    group('Edge Cases: Out-of-bounds Indices', () {
      test('mark_taken ignores action if index is out of bounds', () async {
        final alarm = createBaseAlarm(id: 1, status: 'ATIVO');
        await db.into(db.alarms).insert(_toAlarmCompanion(alarm));

        // Index -1 is out of bounds
        await executor.execute([
          LlmAction(type: 'mark_taken', params: {'index': -1})
        ]);

        // Index 1 is out of bounds (only 1 active alarm, so index 0 is valid)
        await executor.execute([
          LlmAction(type: 'mark_taken', params: {'index': 1})
        ]);

        // Verify alarm is still not taken
        final alarms = await alarmRepo.getAllAlarms();
        expect(alarms.first.lastStatus, isNull);

        final history = await historyRepo.getAllHistoryEvents();
        expect(history, isEmpty);
      });

      test('snooze_alarm ignores action if index is out of bounds', () async {
        final alarm = createBaseAlarm(id: 1, status: 'ATIVO');
        await db.into(db.alarms).insert(_toAlarmCompanion(alarm));

        await executor.execute([
          LlmAction(type: 'snooze_alarm', params: {'index': -1, 'minutes': 15})
        ]);

        await executor.execute([
          LlmAction(type: 'snooze_alarm', params: {'index': 5, 'minutes': 15})
        ]);

        final alarms = await alarmRepo.getAllAlarms();
        expect(alarms.first.status, 'ATIVO'); // not changed to SNOOZED
      });

      test('toggle_alarm ignores action if index is out of bounds', () async {
        final alarm = createBaseAlarm(id: 1, enabled: true);
        await db.into(db.alarms).insert(_toAlarmCompanion(alarm));

        await executor.execute([
          LlmAction(type: 'toggle_alarm', params: {'index': -1, 'enabled': false})
        ]);

        await executor.execute([
          LlmAction(type: 'toggle_alarm', params: {'index': 1, 'enabled': false})
        ]);

        final alarms = await alarmRepo.getAllAlarms();
        expect(alarms.first.enabled, true); // remains enabled
      });

      test('remove_alarm ignores action if index is out of bounds', () async {
        final alarm = createBaseAlarm(id: 1);
        await db.into(db.alarms).insert(_toAlarmCompanion(alarm));

        await executor.execute([
          LlmAction(type: 'remove_alarm', params: {'index': -1})
        ]);

        await executor.execute([
          LlmAction(type: 'remove_alarm', params: {'index': 1})
        ]);

        final alarms = await alarmRepo.getAllAlarms();
        expect(alarms, hasLength(1)); // not deleted
      });

      test('complete_reminder ignores action if index is out of bounds', () async {
        final reminder = createBaseReminder(id: 1);
        await db.into(db.reminders).insert(_toReminderCompanion(reminder));

        await executor.execute([
          LlmAction(type: 'complete_reminder', params: {'index': -1})
        ]);

        await executor.execute([
          LlmAction(type: 'complete_reminder', params: {'index': 2})
        ]);

        final reminders = await reminderRepo.getAllReminders();
        expect(reminders.first.lastCompletedDate, isNull);

        final history = await historyRepo.getAllHistoryEvents();
        expect(history, isEmpty);
      });
    });

    group('Edge Cases: Empty or Malformed JSON Payloads', () {
      test('Empty params handles or falls back gracefully without throwing exceptions', () async {
        // If we pass an empty map, it will use default index 0
        final alarm = createBaseAlarm(id: 1, status: 'ATIVO');
        await db.into(db.alarms).insert(_toAlarmCompanion(alarm));

        await executor.execute([
          LlmAction(type: 'mark_taken', params: {})
        ]);

        final alarms = await alarmRepo.getAllAlarms();
        expect(alarms.first.lastStatus, 'Tomado'); // marked taken because index defaulted to 0
      });

      test('Malformed types in params are caught and do not crash the executor loop', () async {
        final alarm = createBaseAlarm(id: 1, status: 'ATIVO');
        await db.into(db.alarms).insert(_toAlarmCompanion(alarm));

        // Passing string to index where int is expected (will cause cast error)
        // We verify it does not bubble up to crash the application, and subsequent actions still run.
        final validActionRun = createBaseAlarm(id: 2, status: 'ATIVO');
        await db.into(db.alarms).insert(_toAlarmCompanion(validActionRun));

        await executor.execute([
          LlmAction(type: 'mark_taken', params: {'index': 'not_an_int'}),
          LlmAction(type: 'mark_taken', params: {'index': 1, 'quantity': 'not_a_double'}),
          LlmAction(type: 'toggle_alarm', params: {'index': 0, 'enabled': 'not_a_bool'}),
          // A valid action to confirm the loop recovered and executed it
          LlmAction(type: 'snooze_alarm', params: {'index': 0, 'minutes': 12}),
        ]);

        final alarms = await alarmRepo.getAllAlarms();
        // The first alarm (index 0) was successfully snoozed by the last action
        expect(alarms.firstWhere((a) => a.id == 1).status, 'SNOOZED');
        expect(alarms.firstWhere((a) => a.id == 1).snoozeMin, 12);
      });

      test('add_alarm handles invalid days format fallback', () async {
        await executor.execute([
          LlmAction(type: 'add_alarm', params: {
            'name': 'Aspirina',
            'times': ['08:00'],
            'days': 'invalid_days_format', // string instead of list
          })
        ]);

        final alarms = await alarmRepo.getAllAlarms();
        expect(alarms, hasLength(1));
        // Should default to all days (List.filled(7, true))
        expect(alarms.first.days, List.filled(7, true));
      });
    });

    group('Rule 31: Add alarms with multiple times (split check)', () {
      test('Splits list of strings into multiple alarms', () async {
        await executor.execute([
          LlmAction(type: 'add_alarm', params: {
            'name': 'Multi1',
            'times': ['06:00', '12:00', '18:00', '00:00']
          })
        ]);

        final alarms = await alarmRepo.getAllAlarms();
        expect(alarms, hasLength(4));
        expect(alarms.any((a) => a.hour == 6 && a.minute == 0), true);
        expect(alarms.any((a) => a.hour == 12 && a.minute == 0), true);
        expect(alarms.any((a) => a.hour == 18 && a.minute == 0), true);
        expect(alarms.any((a) => a.hour == 0 && a.minute == 0), true);
        for (final a in alarms) {
          expect(a.name, 'Multi1');
        }
      });

      test('Splits list of maps into multiple alarms', () async {
        await executor.execute([
          LlmAction(type: 'add_alarm', params: {
            'name': 'MultiMap',
            'times': [
              {'hour': 9, 'minute': 30},
              {'hour': 21, 'minute': 45}
            ]
          })
        ]);

        final alarms = await alarmRepo.getAllAlarms();
        expect(alarms, hasLength(2));
        expect(alarms.any((a) => a.hour == 9 && a.minute == 30), true);
        expect(alarms.any((a) => a.hour == 21 && a.minute == 45), true);
      });

      test('Splits single string with delimiters (comma, semicolon, and) into multiple alarms', () async {
        await executor.execute([
          LlmAction(type: 'add_alarm', params: {
            'name': 'Delimited',
            'times': '07:15, 13:30; 19:45 and 22:00'
          })
        ]);

        final alarms = await alarmRepo.getAllAlarms();
        expect(alarms, hasLength(4));
        expect(alarms.any((a) => a.hour == 7 && a.minute == 15), true);
        expect(alarms.any((a) => a.hour == 13 && a.minute == 30), true);
        expect(alarms.any((a) => a.hour == 19 && a.minute == 45), true);
        expect(alarms.any((a) => a.hour == 22 && a.minute == 0), true);
      });

      test('Splits hour and minute lists into multiple alarms', () async {
        await executor.execute([
          LlmAction(type: 'add_alarm', params: {
            'name': 'ListHM',
            'hour': [8, 14, 20],
            'minute': [15, 30, 45]
          })
        ]);

        final alarms = await alarmRepo.getAllAlarms();
        expect(alarms, hasLength(3));
        expect(alarms.any((a) => a.hour == 8 && a.minute == 15), true);
        expect(alarms.any((a) => a.hour == 14 && a.minute == 30), true);
        expect(alarms.any((a) => a.hour == 20 && a.minute == 45), true);
      });
    });

    group('Rule 46: Verify customQty is correctly passed to markTaken', () {
      test('mark_taken passes quantity parameter correctly', () async {
        final alarm = createBaseAlarm(id: 1, status: 'ATIVO');
        await db.into(db.alarms).insert(_toAlarmCompanion(alarm));

        await executor.execute([
          LlmAction(type: 'mark_taken', params: {'index': 0, 'quantity': 2.5})
        ]);

        final history = await historyRepo.getAllHistoryEvents();
        expect(history, hasLength(1));
        // The dosage formatted should include the quantity 2.5
        expect(history.first.dosage, startsWith('2.5'));
      });

      test('mark_taken passes customQty parameter correctly as a fallback/alternative', () async {
        final alarm = createBaseAlarm(id: 1, status: 'ATIVO');
        await db.into(db.alarms).insert(_toAlarmCompanion(alarm));

        await executor.execute([
          LlmAction(type: 'mark_taken', params: {'index': 0, 'customQty': 4.0})
        ]);

        final history = await historyRepo.getAllHistoryEvents();
        expect(history, hasLength(1));
        expect(history.first.dosage, startsWith('4'));
      });
    });

    group('Invalid Action Types', () {
      test('Invalid action types do not crash and other valid actions continue executing', () async {
        final alarm = createBaseAlarm(id: 1, status: 'ATIVO');
        await db.into(db.alarms).insert(_toAlarmCompanion(alarm));

        await executor.execute([
          LlmAction(type: 'unknown_super_action', params: {'some': 'thing'}),
          LlmAction(type: 'another_invalid_one', params: {}),
          LlmAction(type: 'mark_taken', params: {'index': 0})
        ]);

        final alarms = await alarmRepo.getAllAlarms();
        expect(alarms.first.lastStatus, 'Tomado'); // executed successfully

        final history = await historyRepo.getAllHistoryEvents();
        expect(history, hasLength(1));
      });
    });
  });
}
