import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/native.dart';
import 'package:medicaixa_app/core/database/database.dart';
import 'package:medicaixa_app/core/providers/core_providers.dart';
import 'package:medicaixa_app/features/reports/presentation/reports_notifier.dart';
import 'package:intl/date_symbol_data_local.dart';

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
      ],
    );
  });

  tearDown(() async {
    await db.close();
    container.dispose();
  });

  test('ReportsNotifier - Adherence General, Daily, and Streaks calculations', () async {
    // 1. Insert a medication
    const med = Medication(
      name: 'Paracetamol',
      color: 'red',
      type: 'comprimido',
      pendingSync: false,
    );
    await db.into(db.medications).insert(med);

    final now = DateTime.now();
    final todayMidnight = DateTime(now.year, now.month, now.day);

    // Let's create timestamps for the last few days
    final tToday = todayMidnight.millisecondsSinceEpoch + 60 * 1000; // Today 00:01
    final tYesterday = todayMidnight.subtract(const Duration(days: 1)).millisecondsSinceEpoch + 14 * 3600 * 1000; // Yesterday 14:00
    final t2DaysAgo_1 = todayMidnight.subtract(const Duration(days: 2)).millisecondsSinceEpoch + 8 * 3600 * 1000; // 2 Days Ago 08:00
    final t2DaysAgo_2 = todayMidnight.subtract(const Duration(days: 2)).millisecondsSinceEpoch + 20 * 3600 * 1000; // 2 Days Ago 20:00
    final t4DaysAgo_1 = todayMidnight.subtract(const Duration(days: 4)).millisecondsSinceEpoch + 9 * 3600 * 1000; // 4 Days Ago 09:00
    final t4DaysAgo_2 = todayMidnight.subtract(const Duration(days: 4)).millisecondsSinceEpoch + 21 * 3600 * 1000; // 4 Days Ago 21:00
    final t5DaysAgo = todayMidnight.subtract(const Duration(days: 5)).millisecondsSinceEpoch + 10 * 3600 * 1000; // 5 Days Ago 10:00
    final t6DaysAgo = todayMidnight.subtract(const Duration(days: 6)).millisecondsSinceEpoch + 10 * 3600 * 1000; // 6 Days Ago 10:00

    // Insert history events
    // Day 0: Taken
    await db.into(db.historyEvents).insert(HistoryEvent(
      id: 1,
      medName: 'Paracetamol',
      timestamp: tToday,
      status: 'TOMADO',
      type: 'alarm',
      pendingSync: false,
    ));

    // Day -1: Missed
    await db.into(db.historyEvents).insert(HistoryEvent(
      id: 2,
      medName: 'Paracetamol',
      timestamp: tYesterday,
      status: 'PERDIDO',
      type: 'alarm',
      pendingSync: false,
    ));

    // Day -2: Taken 2 events
    await db.into(db.historyEvents).insert(HistoryEvent(
      id: 3,
      medName: 'Paracetamol',
      timestamp: t2DaysAgo_1,
      status: 'TOMADO',
      type: 'alarm',
      pendingSync: false,
    ));
    await db.into(db.historyEvents).insert(HistoryEvent(
      id: 4,
      medName: 'Paracetamol',
      timestamp: t2DaysAgo_2,
      status: 'TOMADO FORA HORA',
      type: 'alarm',
      pendingSync: false,
    ));

    // Day -3: Empty

    // Day -4: Taken 1, Missed 1
    await db.into(db.historyEvents).insert(HistoryEvent(
      id: 5,
      medName: 'Paracetamol',
      timestamp: t4DaysAgo_1,
      status: 'TOMADO',
      type: 'alarm',
      pendingSync: false,
    ));
    await db.into(db.historyEvents).insert(HistoryEvent(
      id: 6,
      medName: 'Paracetamol',
      timestamp: t4DaysAgo_2,
      status: 'PERDIDO',
      type: 'alarm',
      pendingSync: false,
    ));

    // Day -5: Taken
    await db.into(db.historyEvents).insert(HistoryEvent(
      id: 7,
      medName: 'Paracetamol',
      timestamp: t5DaysAgo,
      status: 'TOMADO',
      type: 'alarm',
      pendingSync: false,
    ));

    // Day -6: Taken
    await db.into(db.historyEvents).insert(HistoryEvent(
      id: 8,
      medName: 'Paracetamol',
      timestamp: t6DaysAgo,
      status: 'TOMADO',
      type: 'alarm',
      pendingSync: false,
    ));

    // Await streams to emit their values
    final startOfAnalysis = todayMidnight.subtract(const Duration(days: 35));
    final startTimestamp = startOfAnalysis.millisecondsSinceEpoch;
    await container.read(reportsHistoryEventsProvider(startTimestamp).future);
    await container.read(reportsMedicationsProvider.future);

    // Resolve the notifier state
    final state = container.read(reportsNotifierProvider);

    // Verify general adherence
    // Expected: Today(1) + Yesterday(1) + 2DaysAgo(2) + 4DaysAgo(2) + 5DaysAgo(1) + 6DaysAgo(1) = 8
    // Taken: Today(1) + 2DaysAgo(2) + 4DaysAgo(1) + 5DaysAgo(1) + 6DaysAgo(1) = 6
    // Adherence: (6/8 * 100).round() = 75%
    expect(state.generalTakenCount, 6);
    expect(state.generalMissedCount, 2);
    expect(state.generalAdherencePercentage, 75);

    // Verify daily adherence percentages
    // dailyData is ordered from oldest (Day -6) to newest (Day 0)
    expect(state.dailyAdherence.length, 7);
    expect(state.dailyAdherence[0].percentage, 100); // Day -6
    expect(state.dailyAdherence[1].percentage, 100); // Day -5
    expect(state.dailyAdherence[2].percentage, 50);  // Day -4
    expect(state.dailyAdherence[3].percentage, 0);   // Day -3 (empty)
    expect(state.dailyAdherence[4].percentage, 100); // Day -2
    expect(state.dailyAdherence[5].percentage, 0);   // Day -1
    expect(state.dailyAdherence[6].percentage, 100); // Day 0

    // Verify current and best streaks
    // Current streak: Today is taken > 0 and missed == 0 -> streak 1.
    // Yesterday has missed > 0 -> breaks. So current streak is 1.
    // Best streak:
    // Day -6: 1
    // Day -5: 2
    // Day -4: broken (missed > 0)
    // Day -3: empty (skip)
    // Day -2: 1
    // Day -1: broken
    // Day 0: 1
    // Best streak is 2.
    expect(state.currentStreak, 1);
    expect(state.bestStreak, 2);

    // Verify period distribution
    // Morning (00:00 - 11:59):
    // Today 10:00 (Taken), 2DaysAgo 08:00 (Taken), 4DaysAgo 09:00 (Taken), 5DaysAgo 10:00 (Taken), 6DaysAgo 10:00 (Taken)
    // Expected: 5, Taken: 5 -> 100%
    // Afternoon (12:00 - 17:59):
    // Yesterday 14:00 (Missed)
    // Expected: 1, Taken: 0 -> 0%
    // Night (18:00 - 23:59):
    // 2DaysAgo 20:00 (Taken), 4DaysAgo 21:00 (Missed)
    // Expected: 2, Taken: 1 -> 50%
    expect(state.morningTaken, 5);
    expect(state.morningExpected, 5);
    expect(state.morningPercentage, 100.0);

    expect(state.afternoonTaken, 0);
    expect(state.afternoonExpected, 1);
    expect(state.afternoonPercentage, 0.0);

    expect(state.nightTaken, 1);
    expect(state.nightExpected, 2);
    expect(state.nightPercentage, 50.0);
  });

  test('ReportsNotifier - Filtering by medication updates state and recalculates metrics', () async {
    // 1. Insert two medications
    const med1 = Medication(
      name: 'Paracetamol',
      color: 'red',
      type: 'comprimido',
      pendingSync: false,
    );
    const med2 = Medication(
      name: 'Ibuprofeno',
      color: 'blue',
      type: 'comprimido',
      pendingSync: false,
    );
    await db.into(db.medications).insert(med1);
    await db.into(db.medications).insert(med2);

    final now = DateTime.now();
    final todayMidnight = DateTime(now.year, now.month, now.day);
    final tToday = todayMidnight.millisecondsSinceEpoch + 60 * 1000; // Today 00:01

    // Insert history events:
    // Paracetamol: 1 taken, 0 missed
    await db.into(db.historyEvents).insert(HistoryEvent(
      id: 1,
      medName: 'Paracetamol',
      timestamp: tToday,
      status: 'TOMADO',
      type: 'alarm',
      pendingSync: false,
    ));

    // Ibuprofeno: 1 missed, 0 taken
    await db.into(db.historyEvents).insert(HistoryEvent(
      id: 2,
      medName: 'Ibuprofeno',
      timestamp: tToday,
      status: 'PERDIDO',
      type: 'alarm',
      pendingSync: false,
    ));

    // Await streams to emit
    final startOfAnalysis = DateTime(todayMidnight.year, todayMidnight.month, todayMidnight.day - 35);
    final startTimestamp = startOfAnalysis.millisecondsSinceEpoch;
    await container.read(reportsHistoryEventsProvider(startTimestamp).future);
    await container.read(reportsMedicationsProvider.future);

    final notifier = container.read(reportsNotifierProvider.notifier);

    // Initial state: default filter is "Todos"
    var state = container.read(reportsNotifierProvider);
    expect(state.selectedMedication, 'Todos');
    // Combine both: 1 taken, 1 missed -> total 2, percentage 50%
    expect(state.generalTakenCount, 1);
    expect(state.generalMissedCount, 1);
    expect(state.generalAdherencePercentage, 50);

    // Filter to Paracetamol
    notifier.setFilter('Paracetamol');
    state = container.read(reportsNotifierProvider);
    expect(state.selectedMedication, 'Paracetamol');
    // Only Paracetamol: 1 taken, 0 missed -> total 1, percentage 100%
    expect(state.generalTakenCount, 1);
    expect(state.generalMissedCount, 0);
    expect(state.generalAdherencePercentage, 100);

    // Filter to Ibuprofeno
    notifier.setFilter('Ibuprofeno');
    state = container.read(reportsNotifierProvider);
    expect(state.selectedMedication, 'Ibuprofeno');
    // Only Ibuprofeno: 0 taken, 1 missed -> total 1, percentage 0%
    expect(state.generalTakenCount, 0);
    expect(state.generalMissedCount, 1);
    expect(state.generalAdherencePercentage, 0);
  });
}
