import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart';
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
  group('ActionExecutor Unit Tests', () {
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

    test('mark_taken action: marks active alarm as taken with customQty', () async {
      final alarm1 = AlarmModel(
        id: 1,
        hour: 8,
        minute: 0,
        name: 'Medicamento A',
        medName: 'Medicamento A',
        enabled: true,
        active: true,
        days: List.filled(7, true),
        status: 'PENDENTE',
        color: 'blue',
        quantity: 1.0,
        daysQuantity: List.filled(7, 0.0),
        type: 'comprimido',
        snoozeMin: 10,
        durationDays: 0,
      );

      final alarm2 = AlarmModel(
        id: 2,
        hour: 12,
        minute: 0,
        name: 'Medicamento B',
        medName: 'Medicamento B',
        enabled: true,
        active: true,
        days: List.filled(7, true),
        status: 'ATIVO',
        color: 'red',
        quantity: 2.0,
        daysQuantity: List.filled(7, 0.0),
        type: 'comprimido',
        snoozeMin: 10,
        durationDays: 0,
      );

      await db.into(db.alarms).insert(_toAlarmCompanion(alarm1));
      await db.into(db.alarms).insert(_toAlarmCompanion(alarm2));

      final action = LlmAction(
        type: 'mark_taken',
        params: {'index': 0, 'quantity': 1.5},
      );

      await executor.execute([action]);

      final updatedAlarms = await alarmRepo.getAllAlarms();
      final updatedAlarm2 = updatedAlarms.firstWhere((a) => a.id == 2);
      expect(updatedAlarm2.lastStatus, 'Tomado');

      final historyEvents = await historyRepo.getAllHistoryEvents();
      expect(historyEvents, hasLength(1));
      expect(historyEvents.first.alarmId, 2);
      expect(historyEvents.first.medName, 'Medicamento B');
      expect(historyEvents.first.status, startsWith('TOMADO'));
    });

    test('snooze_alarm action: snoozes alarm', () async {
      final alarm = AlarmModel(
        id: 5,
        hour: 9,
        minute: 0,
        name: 'Paracetamol',
        medName: 'Paracetamol',
        enabled: true,
        active: true,
        days: List.filled(7, true),
        status: 'ATIVO',
        color: 'green',
        quantity: 1.0,
        daysQuantity: List.filled(7, 0.0),
        type: 'comprimido',
        snoozeMin: 10,
        durationDays: 0,
      );

      await db.into(db.alarms).insert(_toAlarmCompanion(alarm));

      final action = LlmAction(
        type: 'snooze_alarm',
        params: {'index': 0, 'minutes': 15},
      );

      await executor.execute([action]);

      final updatedAlarms = await alarmRepo.getAllAlarms();
      final updated = updatedAlarms.firstWhere((a) => a.id == 5);
      expect(updated.status, 'SNOOZED');
      expect(updated.snoozeMin, 15);
    });

    test('toggle_alarm action: enables/disables alarm', () async {
      final alarm = AlarmModel(
        id: 7,
        hour: 15,
        minute: 0,
        name: 'Vitamina C',
        medName: 'Vitamina C',
        enabled: true,
        active: true,
        days: List.filled(7, true),
        status: 'PENDENTE',
        color: 'orange',
        quantity: 1.0,
        daysQuantity: List.filled(7, 0.0),
        type: 'comprimido',
        snoozeMin: 10,
        durationDays: 0,
      );

      await db.into(db.alarms).insert(_toAlarmCompanion(alarm));

      await executor.execute([
        LlmAction(type: 'toggle_alarm', params: {'index': 0, 'enabled': false})
      ]);

      var updated = (await alarmRepo.getAllAlarms()).firstWhere((a) => a.id == 7);
      expect(updated.enabled, false);

      await executor.execute([
        LlmAction(type: 'toggle_alarm', params: {'index': 0, 'enabled': true})
      ]);

      updated = (await alarmRepo.getAllAlarms()).firstWhere((a) => a.id == 7);
      expect(updated.enabled, true);
    });

    test('remove_alarm action: deletes alarm', () async {
      final alarm = AlarmModel(
        id: 9,
        hour: 22,
        minute: 0,
        name: 'Melatonina',
        medName: 'Melatonina',
        enabled: true,
        active: true,
        days: List.filled(7, true),
        status: 'PENDENTE',
        color: 'purple',
        quantity: 1.0,
        daysQuantity: List.filled(7, 0.0),
        type: 'comprimido',
        snoozeMin: 10,
        durationDays: 0,
      );

      await db.into(db.alarms).insert(_toAlarmCompanion(alarm));

      await executor.execute([
        LlmAction(type: 'remove_alarm', params: {'index': 0})
      ]);

      final allAlarms = await alarmRepo.getAllAlarms();
      expect(allAlarms.any((a) => a.id == 9), false);
    });

    test('add_alarm action: creates individual alarms for multiple times (Rule 31)', () async {
      final action = LlmAction(
        type: 'add_alarm',
        params: {
          'name': 'Aspirina',
          'med_name': 'Aspirina',
          'times': ['08:00', '20:00'],
          'quantity': 1.0,
          'days': [0, 1, 2, 3, 4, 5, 6],
          'color': 'blue',
          'type': 'comprimido',
          'dosage': '100mg',
          'start_date': '2026-07-01',
          'duration_days': 5,
        },
      );

      await executor.execute([action]);

      final allAlarms = await alarmRepo.getAllAlarms();
      expect(allAlarms, hasLength(2));

      final a1 = allAlarms.firstWhere((a) => a.hour == 8);
      expect(a1.medName, 'Aspirina');
      expect(a1.quantity, 1.0);
      expect(a1.dosage, '100mg');
      expect(a1.startDate, '2026-07-01');
      expect(a1.durationDays, 5);

      final a2 = allAlarms.firstWhere((a) => a.hour == 20);
      expect(a2.medName, 'Aspirina');
      expect(a2.quantity, 1.0);
      expect(a2.dosage, '100mg');
      expect(a2.startDate, '2026-07-01');
      expect(a2.durationDays, 5);
    });

    test('add_alarm action: splits multiple times inside string parameter (Rule 31)', () async {
      final action = LlmAction(
        type: 'add_alarm',
        params: {
          'name': 'Ibuprofeno',
          'time': '07:00, 15:00 and 23:00',
          'quantity': 1.5,
          'days': [1, 2, 3, 4, 5],
          'color': 'yellow',
        },
      );

      await executor.execute([action]);

      final allAlarms = await alarmRepo.getAllAlarms();
      expect(allAlarms, hasLength(3));

      expect(allAlarms.any((a) => a.hour == 7 && a.minute == 0), true);
      expect(allAlarms.any((a) => a.hour == 15 && a.minute == 0), true);
      expect(allAlarms.any((a) => a.hour == 23 && a.minute == 0), true);

      final alarm = allAlarms.first;
      expect(alarm.medName, 'Ibuprofeno');
      expect(alarm.quantity, 1.5);
      expect(alarm.days, [false, true, true, true, true, true, false]);
    });

    test('update_alarm action: updates alarm properties', () async {
      final alarm = AlarmModel(
        id: 11,
        hour: 6,
        minute: 0,
        name: 'Antialergico',
        medName: 'Antialergico',
        enabled: true,
        active: true,
        days: List.filled(7, true),
        status: 'PENDENTE',
        color: 'red',
        quantity: 1.0,
        daysQuantity: List.filled(7, 0.0),
        type: 'comprimido',
        snoozeMin: 10,
        durationDays: 0,
      );

      await db.into(db.alarms).insert(_toAlarmCompanion(alarm));

      final action = LlmAction(
        type: 'update_alarm',
        params: {
          'index': 0,
          'hour': 7,
          'minute': 30,
          'quantity': 2.0,
          'color': 'purple',
          'dosage': '10mg',
        },
      );

      await executor.execute([action]);

      final updated = (await alarmRepo.getAllAlarms()).firstWhere((a) => a.id == 11);
      expect(updated.hour, 7);
      expect(updated.minute, 30);
      expect(updated.quantity, 2.0);
      expect(updated.color, 'purple');
      expect(updated.dosage, '10mg');
    });

    test('add_reminder action: creates a new reminder', () async {
      final action = LlmAction(
        type: 'add_reminder',
        params: {
          'title': 'Comprar remedios',
          'description': 'Ir a farmacia comprar aspirina',
          'hour': 18,
          'minute': 30,
          'period': 'week',
          'interval': 2,
          'start_date': '2026-07-02',
          'notify_days_before': 1,
          'color': 'green',
        },
      );

      await executor.execute([action]);

      final allReminders = await reminderRepo.getAllReminders();
      expect(allReminders, hasLength(1));

      final r = allReminders.first;
      expect(r.title, 'Comprar remedios');
      expect(r.description, 'Ir a farmacia comprar aspirina');
      expect(r.hasTime, true);
      expect(r.hour, 18);
      expect(r.minute, 30);
      expect(r.period, 'week');
      expect(r.interval, 2);
      expect(r.startDate, '2026-07-02');
      expect(r.notifyDaysBefore, 1);
      expect(r.color, 'green');
    });

    test('complete_reminder action: marks active reminder as completed', () async {
      final todayStr = "${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}";
      final reminder = ReminderModel(
        id: 15,
        title: 'Medir Glicose',
        description: 'Medir em jejum',
        enabled: true,
        hasTime: true,
        hour: 7,
        minute: 0,
        period: 'day',
        interval: 1,
        startDate: todayStr,
        notifyDaysBefore: 0,
        color: 'red',
      );

      await db.into(db.reminders).insert(_toReminderCompanion(reminder));

      final action = LlmAction(
        type: 'complete_reminder',
        params: {'index': 0},
      );

      await executor.execute([action]);

      final allReminders = await reminderRepo.getAllReminders();
      final updated = allReminders.firstWhere((r) => r.id == 15);
      
      final expectedDateStr = "${DateTime.now().day.toString().padLeft(2, '0')}/${DateTime.now().month.toString().padLeft(2, '0')}/${DateTime.now().year}";
      expect(updated.lastCompletedDate, expectedDateStr);

      final historyEvents = await historyRepo.getAllHistoryEvents();
      expect(historyEvents, hasLength(1));
      expect(historyEvents.first.reminderId, 15);
      expect(historyEvents.first.status, 'CONCLUIDO');
    });
  });
}
