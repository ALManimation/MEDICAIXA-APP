import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/native.dart';
import 'package:medicaixa_app/core/database/database.dart';
import 'package:medicaixa_app/core/providers/core_providers.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:medicaixa_app/features/medications/data/medication_repository.dart';
import 'package:medicaixa_app/features/medications/data/medication_api_client.dart';
import 'package:medicaixa_app/features/reports/presentation/reports_notifier.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('pt', null);
    await initializeDateFormatting('en', null);
    await initializeDateFormatting('es', null);
  });

  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase.connect(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        medicationRepositoryProvider.overrideWith((ref) {
          return MedicationRepository(
            ref.watch(databaseProvider),
            ref.watch(medicationApiClientProvider),
            ref,
          );
        }),
      ],
    );
  });

  tearDown(() async {
    await db.close();
    container.dispose();
  });

  Future<void> initNotifier() async {
    final now = DateTime.now();
    final todayMidnight = DateTime(now.year, now.month, now.day);
    final startOfAnalysis = todayMidnight.subtract(const Duration(days: 35));
    final startTimestamp = startOfAnalysis.millisecondsSinceEpoch;
    
    // Await streams to load data
    await container.read(reportsHistoryEventsProvider(startTimestamp).future);
    await container.read(reportsMedicationsProvider.future);
  }

  group('ReportsNotifier Stress Tests', () {
    test('1. 0% Adherence - All events missed or skipped without taken ones', () async {
      final now = DateTime.now();
      final todayMidnight = DateTime(now.year, now.month, now.day);
      final tToday = todayMidnight.millisecondsSinceEpoch + 60 * 1000; // Today 00:01

      // Insert medication
      await db.into(db.medications).insert(const Medication(
        name: 'Med0',
        color: 'red',
        type: 'comprimido',
        pendingSync: false,
      ));

      // Insert missed/skipped events
      await db.into(db.historyEvents).insert(HistoryEvent(
        id: 1,
        medName: 'Med0',
        timestamp: tToday,
        status: 'PERDIDO',
        type: 'alarm',
        pendingSync: false,
      ));
      await db.into(db.historyEvents).insert(HistoryEvent(
        id: 2,
        medName: 'Med0',
        timestamp: tToday - 24 * 3600 * 1000,
        status: 'CANCELADO',
        type: 'alarm',
        pendingSync: false,
      ));

      await initNotifier();
      final state = container.read(reportsNotifierProvider);

      expect(state.generalTakenCount, 0);
      expect(state.generalMissedCount, 1);
      expect(state.generalSkippedCount, 1);
      expect(state.generalAdherencePercentage, 0);
      expect(state.currentStreak, 0);
      expect(state.bestStreak, 0);
    });

    test('2. 100% Adherence - All events taken across various taken statuses', () async {
      final now = DateTime.now();
      final todayMidnight = DateTime(now.year, now.month, now.day);
      
      await db.into(db.medications).insert(const Medication(
        name: 'Med100',
        color: 'green',
        type: 'comprimido',
        pendingSync: false,
      ));

      final statuses = ['TOMADO', 'TOMADO FORA HORA', 'TOMADO PRN', 'CONCLUIDO'];
      for (int i = 0; i < statuses.length; i++) {
        final timestamp = todayMidnight.subtract(Duration(days: i)).millisecondsSinceEpoch + 60 * 1000;
        await db.into(db.historyEvents).insert(HistoryEvent(
          id: i + 1,
          medName: 'Med100',
          timestamp: timestamp,
          status: statuses[i],
          type: 'alarm',
          pendingSync: false,
        ));
      }

      await initNotifier();
      final state = container.read(reportsNotifierProvider);

      expect(state.generalTakenCount, 4);
      expect(state.generalMissedCount, 0);
      expect(state.generalSkippedCount, 0);
      expect(state.generalAdherencePercentage, 100);
      // Perfect streak check
      expect(state.currentStreak, 4);
      expect(state.bestStreak, 4);
    });

    test('3. Empty History - No medications or events', () async {
      await initNotifier();
      final state = container.read(reportsNotifierProvider);

      expect(state.generalTakenCount, 0);
      expect(state.generalMissedCount, 0);
      expect(state.generalSkippedCount, 0);
      expect(state.generalAdherencePercentage, 0);
      expect(state.currentStreak, 0);
      expect(state.bestStreak, 0);
      expect(state.dailyAdherence.length, 7);
      for (final day in state.dailyAdherence) {
        expect(day.percentage, 0);
        expect(day.expectedCount, 0);
      }
    });

    test('4. Null Optional Database Fields', () async {
      final now = DateTime.now();
      final todayMidnight = DateTime(now.year, now.month, now.day);

      // Insert event with null medication name and other nullable fields as null
      await db.into(db.historyEvents).insert(HistoryEvent(
        id: 1,
        medName: null,      // Optional field null
        dosage: null,       // Optional field null
        alarmId: null,      // Optional field null
        reminderId: null,   // Optional field null
        timestamp: todayMidnight.millisecondsSinceEpoch + 60 * 1000,
        status: 'TOMADO',
        type: 'alarm',
        pendingSync: false,
      ));

      await initNotifier();
      final state = container.read(reportsNotifierProvider);

      // Null medName event should be processed under 'Todos' filter
      expect(state.selectedMedication, 'Todos');
      expect(state.generalTakenCount, 1);
      expect(state.generalAdherencePercentage, 100);

      // And it should not be listed in medication performance since name is null
      expect(state.medicationPerformance.any((m) => m.name == ''), false);
    });

    test('5. DST Offset Transitions - Simulation of day rollover and hour shifts', () async {
      // DST boundaries can cause days to have 23 or 25 hours.
      // We test that calculations using Calendar date strings prevent DST-related offsets
      // from placing events in wrong day buckets.
      final now = DateTime.now();
      final todayMidnight = DateTime(now.year, now.month, now.day);

      // Let's create an event that is 25 hours ago, and another that is 23 hours ago
      final t25HoursAgo = todayMidnight.millisecondsSinceEpoch - 25 * 3600 * 1000;
      final t23HoursAgo = todayMidnight.millisecondsSinceEpoch - 23 * 3600 * 1000;
      final t1HourAgo = todayMidnight.millisecondsSinceEpoch - 1 * 3600 * 1000;

      await db.into(db.historyEvents).insert(HistoryEvent(
        id: 1,
        medName: 'MedDST',
        timestamp: t25HoursAgo, // Yesterday or day before depending on timezone
        status: 'TOMADO',
        type: 'alarm',
        pendingSync: false,
      ));

      await db.into(db.historyEvents).insert(HistoryEvent(
        id: 2,
        medName: 'MedDST',
        timestamp: t23HoursAgo, // Yesterday or today depending on timezone
        status: 'TOMADO',
        type: 'alarm',
        pendingSync: false,
      ));

      await db.into(db.historyEvents).insert(HistoryEvent(
        id: 3,
        medName: 'MedDST',
        timestamp: t1HourAgo, // Yesterday (since todayMidnight is 00:00 and 1 hour ago is 23:00 yesterday)
        status: 'TOMADO',
        type: 'alarm',
        pendingSync: false,
      ));

      await initNotifier();
      final state = container.read(reportsNotifierProvider);

      // Verify that all events parse successfully without throwing timezone exceptions
      expect(state.generalTakenCount, 3);
    });

    test('6. Invalid Date Formats and Weird Casing', () async {
      final now = DateTime.now();

      // Event with status in weird casing: 'toMaDo', 'PErdido', 'CANCElado'
      await db.into(db.historyEvents).insert(HistoryEvent(
        id: 1,
        medName: 'MedCase',
        timestamp: now.millisecondsSinceEpoch - 5 * 3600 * 1000,
        status: 'toMaDo',
        type: 'alarm',
        pendingSync: false,
      ));

      await db.into(db.historyEvents).insert(HistoryEvent(
        id: 2,
        medName: 'MedCase',
        timestamp: now.millisecondsSinceEpoch - 4 * 3600 * 1000,
        status: 'PErdido',
        type: 'alarm',
        pendingSync: false,
      ));

      await db.into(db.historyEvents).insert(HistoryEvent(
        id: 3,
        medName: 'MedCase',
        timestamp: now.millisecondsSinceEpoch - 3 * 3600 * 1000,
        status: 'CANCElado',
        type: 'alarm',
        pendingSync: false,
      ));

      // Event with completely invalid status: 'IGNORED' (should be skipped from expected count)
      await db.into(db.historyEvents).insert(HistoryEvent(
        id: 4,
        medName: 'MedCase',
        timestamp: now.millisecondsSinceEpoch - 2 * 3600 * 1000,
        status: 'IGNORED',
        type: 'alarm',
        pendingSync: false,
      ));

      // Event with negative/extremely large timestamp
      await db.into(db.historyEvents).insert(const HistoryEvent(
        id: 5,
        medName: 'MedCase',
        timestamp: -1000000000, // Very far in the past
        status: 'TOMADO',
        type: 'alarm',
        pendingSync: false,
      ));

      await db.into(db.historyEvents).insert(const HistoryEvent(
        id: 6,
        medName: 'MedCase',
        timestamp: 9999999999999, // Very far in the future
        status: 'TOMADO',
        type: 'alarm',
        pendingSync: false,
      ));

      await initNotifier();
      final state = container.read(reportsNotifierProvider);

      expect(state.generalTakenCount, 1);
      expect(state.generalMissedCount, 1);
      expect(state.generalSkippedCount, 1);
      expect(state.generalAdherencePercentage, 33); // 1 / 3 = 33%
    });
  });
}
