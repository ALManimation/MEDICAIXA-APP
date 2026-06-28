import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medicaixa_app/core/database/database.dart';
import 'package:medicaixa_app/features/alarms/data/alarm_repository.dart';
import 'package:medicaixa_app/features/alarms/data/alarm_model.dart';
import 'package:medicaixa_app/core/providers/core_providers.dart';
import 'package:medicaixa_app/features/alarms/data/alarm_api_client.dart';
import 'package:medicaixa_app/features/history/data/history_repository.dart';
import 'package:drift/native.dart';

class MockAlarmApiClient implements AlarmApiClient {
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
  late AppDatabase db;
  late MockAlarmApiClient apiClient;
  late ProviderContainer container;
  late AlarmRepository repository;

  setUp(() {
    db = AppDatabase.connect(NativeDatabase.memory());
    apiClient = MockAlarmApiClient();
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        alarmApiClientProvider.overrideWithValue(apiClient),
      ],
    );
    repository = AlarmRepository(db, apiClient, FakeRef(container));
  });

  tearDown(() async {
    await db.close();
    container.dispose();
  });

  test('PRN Take limits and interval validation', () async {
    // 1. Insert a PRN alarm
    final alarm = AlarmModel(
      id: 1,
      hour: 0,
      minute: 0,
      name: 'PRN Test',
      medName: 'PRN Test',
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
      isPrn: true,
      prnMinIntervalHours: 2, // 2 hours minimum interval
      prnMaxDailyDoses: 2,    // Max 2 doses per day
      prnDosesToday: 0,
    );

    // Save alarme using repository
    await repository.createAlarm(alarm);

    final list = await repository.getAllAlarms();
    final createdId = list.first.id;

    // 2. Take PRN first time -> should succeed
    await repository.takePrn(createdId);
    
    final updatedList = await repository.getAllAlarms();
    expect(updatedList.first.prnDosesToday, 1);
    expect(updatedList.first.lastStatus, 'Tomado PRN');

    // 3. Take PRN second time immediately -> should throw interval exception
    expect(
      () => repository.takePrn(createdId),
      throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('Intervalo mínimo não respeitado'))),
    );
  });

  test('Interval Days creation and countdown check', () async {
    final alarm = AlarmModel(
      id: 2,
      hour: 8,
      minute: 0,
      name: 'Alternating Test',
      medName: 'Alternating Test',
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
      intervalDays: 3, // a cada 3 dias
    );

    await repository.createAlarm(alarm);

    final list = await repository.getAllAlarms();
    final created = list.firstWhere((a) => a.name == 'Alternating Test');

    expect(created.intervalDays, 3);
    expect(created.intervalCountdown, 0); // inicia em 0 para tocar hoje
  });

  test('MarkTaken with custom quantity overrides default quantity', () async {
    final alarm = AlarmModel(
      id: 3,
      hour: 8,
      minute: 0,
      name: 'Custom Qty Test',
      medName: 'Custom Qty Test',
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
    );

    await repository.createAlarm(alarm);

    final list = await repository.getAllAlarms();
    final createdId = list.firstWhere((a) => a.name == 'Custom Qty Test').id;

    // Mark taken with a custom quantity of 3.5 comp.
    await repository.markTaken(createdId, customQty: 3.5);

    // Verify history event dosage has the overridden value
    final historyRepo = container.read(historyRepositoryProvider);
    final historyList = await historyRepo.getAllHistoryEvents();
    final event = historyList.firstWhere((e) => e.alarmId == createdId);

    expect(event.dosage, contains('3.5 comp.'));
  });
}
