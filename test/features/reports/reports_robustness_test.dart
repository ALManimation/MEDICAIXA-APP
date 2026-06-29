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

  Future<void> insertMedication(String name, String color) async {
    final med = Medication(
      name: name,
      color: color,
      type: 'comprimido',
      pendingSync: false,
    );
    await db.into(db.medications).insert(med);
  }

  Future<void> insertHistoryEvent({
    required int id,
    required String medName,
    required int timestamp,
    required String status,
  }) async {
    await db.into(db.historyEvents).insert(HistoryEvent(
      id: id,
      medName: medName,
      timestamp: timestamp,
      status: status,
      type: 'alarm',
      pendingSync: false,
    ));
  }

  Future<void> initNotifier() async {
    final now = DateTime.now();
    final todayMidnight = DateTime(now.year, now.month, now.day);
    final startOfAnalysis = todayMidnight.subtract(const Duration(days: 35));
    final startTimestamp = startOfAnalysis.millisecondsSinceEpoch;
    
    // Await streams to load data
    await container.read(reportsHistoryEventsProvider(startTimestamp).future);
    await container.read(reportsMedicationsProvider.future);
  }

  group('ReportsNotifier Robustness Tests', () {
    test('1. Zero Alarms / Empty Database', () async {
      await initNotifier();
      final state = container.read(reportsNotifierProvider);

      expect(state.generalTakenCount, 0);
      expect(state.generalMissedCount, 0);
      expect(state.generalSkippedCount, 0);
      expect(state.generalAdherencePercentage, 0);
      expect(state.currentStreak, 0);
      expect(state.bestStreak, 0);
      expect(state.last14DaysDots.length, 14);
      for (final dot in state.last14DaysDots) {
        expect(dot, DotStatus.grayEmpty);
      }
      expect(state.heatmapCells.isNotEmpty, true);
      for (final cell in state.heatmapCells) {
        expect(cell.expectedCount, 0);
        expect(cell.level, HeatmapLevel.level0);
      }
    });

    test('2. Streak Calculations - Skipping Empty Days and Resetting on Misses', () async {
      await insertMedication('Med1', 'blue');
      final now = DateTime.now();
      final todayMidnight = DateTime(now.year, now.month, now.day);

      // Create history events:
      // Day 0 (Today): Taken
      // Day -1 (Yesterday): Empty (No Alarms)
      // Day -2 (2 Days Ago): Taken
      // Day -3 (3 Days Ago): Taken
      // Day -4 (4 Days Ago): Missed (Resets Streak here)
      // Day -5 (5 Days Ago): Taken
      // Day -6 (6 Days Ago): Taken
      // Day -7 (7 Days Ago): Taken
      
      final tToday = todayMidnight.millisecondsSinceEpoch + 60 * 1000; // Today 00:01
      final t2DaysAgo = todayMidnight.subtract(const Duration(days: 2)).millisecondsSinceEpoch + 8 * 3600 * 1000;
      final t3DaysAgo = todayMidnight.subtract(const Duration(days: 3)).millisecondsSinceEpoch + 8 * 3600 * 1000;
      final t4DaysAgo = todayMidnight.subtract(const Duration(days: 4)).millisecondsSinceEpoch + 8 * 3600 * 1000;
      final t5DaysAgo = todayMidnight.subtract(const Duration(days: 5)).millisecondsSinceEpoch + 8 * 3600 * 1000;
      final t6DaysAgo = todayMidnight.subtract(const Duration(days: 6)).millisecondsSinceEpoch + 8 * 3600 * 1000;
      final t7DaysAgo = todayMidnight.subtract(const Duration(days: 7)).millisecondsSinceEpoch + 8 * 3600 * 1000;

      await insertHistoryEvent(id: 1, medName: 'Med1', timestamp: tToday, status: 'TOMADO');
      // Day -1 is empty
      await insertHistoryEvent(id: 2, medName: 'Med1', timestamp: t2DaysAgo, status: 'TOMADO');
      await insertHistoryEvent(id: 3, medName: 'Med1', timestamp: t3DaysAgo, status: 'TOMADO');
      await insertHistoryEvent(id: 4, medName: 'Med1', timestamp: t4DaysAgo, status: 'PERDIDO'); // Miss
      await insertHistoryEvent(id: 5, medName: 'Med1', timestamp: t5DaysAgo, status: 'TOMADO');
      await insertHistoryEvent(id: 6, medName: 'Med1', timestamp: t6DaysAgo, status: 'TOMADO');
      await insertHistoryEvent(id: 7, medName: 'Med1', timestamp: t7DaysAgo, status: 'TOMADO');

      await initNotifier();
      final state = container.read(reportsNotifierProvider);

      // Verify current streak:
      // Today (Day 0) is taken -> 1
      // Yesterday (Day -1) is empty -> skipped, streak remains 1
      // Day -2 is taken -> 2
      // Day -3 is taken -> 3
      // Day -4 is missed -> reset! Loop breaks!
      // So current streak = 3
      expect(state.currentStreak, 3);

      // Verify best streak:
      // Day -7 to -5 is taken -> streak of 3
      // Day -4 is missed -> reset
      // Day -3 to -2 is taken -> streak of 2
      // Day -1 is empty -> skip
      // Day 0 is taken -> streak of 3 (including Day -2, Day -3, and Day 0)
      // Best streak should be 3
      expect(state.bestStreak, 3);
    });

    test('3. Long Streaks (14 and 30 Days)', () async {
      await insertMedication('Med1', 'green');
      final now = DateTime.now();
      final todayMidnight = DateTime(now.year, now.month, now.day);

      // Create a perfect streak for the last 30 days
      for (int i = 0; i < 30; i++) {
        final timestamp = todayMidnight.subtract(Duration(days: i)).millisecondsSinceEpoch + 10 * 3600 * 1000;
        await insertHistoryEvent(id: i + 1, medName: 'Med1', timestamp: timestamp, status: 'TOMADO');
      }

      await initNotifier();
      final state = container.read(reportsNotifierProvider);

      expect(state.currentStreak, 30);
      expect(state.bestStreak, 30);
      expect(state.last14DaysDots.length, 14);
      for (final dot in state.last14DaysDots) {
        expect(dot, DotStatus.fullGreen);
      }
    });

    test('4. Date Parsing and Boundary Times (Midnight Crossover)', () async {
      await insertMedication('Med1', 'blue');
      final now = DateTime.now();
      final todayMidnight = DateTime(now.year, now.month, now.day);
      final yesterdayMidnight = todayMidnight.subtract(const Duration(days: 1));

      // Event 1: Yesterday 00:01 (Just after midnight)
      final t1 = yesterdayMidnight.millisecondsSinceEpoch + 60 * 1000; // 00:01
      // Event 2: Yesterday 23:59 (Just before midnight)
      final t2 = yesterdayMidnight.millisecondsSinceEpoch + 24 * 3600 * 1000 - 60 * 1000; // 23:59
      // Event 3: Day before yesterday 23:59 (Just before yesterday's midnight)
      final t3 = yesterdayMidnight.millisecondsSinceEpoch - 60 * 1000; // Day before yesterday 23:59

      await insertHistoryEvent(id: 1, medName: 'Med1', timestamp: t1, status: 'TOMADO');
      await insertHistoryEvent(id: 2, medName: 'Med1', timestamp: t2, status: 'TOMADO');
      await insertHistoryEvent(id: 3, medName: 'Med1', timestamp: t3, status: 'PERDIDO');

      await initNotifier();
      final state = container.read(reportsNotifierProvider);

      // Verify dailyAdherence grouping
      // state.dailyAdherence is size 7 (from 6 days ago to today)
      // Index 6 is Today. Index 5 is Yesterday. Index 4 is 2 days ago.
      expect(state.dailyAdherence[5].expectedCount, 2); // t1 and t2 should both be yesterday
      expect(state.dailyAdherence[4].expectedCount, 1); // t3 should be 2 days ago
      expect(state.dailyAdherence[5].percentage, 100);
      expect(state.dailyAdherence[4].percentage, 0);
    });

    test('5. Memory Leak and Asynchronous Listeners', () async {
      // Simulate multiple creations and disposals of the notifier/container
      for (int i = 0; i < 5; i++) {
        final localContainer = ProviderContainer(
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
        
        final now = DateTime.now();
        final startOfAnalysis = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 35));
        
        // Read streams
        await localContainer.read(reportsHistoryEventsProvider(startOfAnalysis.millisecondsSinceEpoch).future);
        await localContainer.read(reportsMedicationsProvider.future);
        
        // Read state to initialize notifier
        final state = localContainer.read(reportsNotifierProvider);
        expect(state.generalTakenCount, 0);

        // Dispose container immediately to check that no async leak occurs
        localContainer.dispose();
      }
    });
  });
}
