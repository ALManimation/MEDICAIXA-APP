import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:medicaixa_app/core/database/database.dart';
import 'package:medicaixa_app/core/providers/core_providers.dart';
import 'package:medicaixa_app/features/alarms/data/alarm_repository.dart';
import 'package:medicaixa_app/features/alarms/data/alarm_model.dart';
import 'package:medicaixa_app/features/alarms/data/alarm_api_client.dart';
import 'package:medicaixa_app/features/dashboard/presentation/dashboard_notifier.dart';
import 'package:medicaixa_app/features/dashboard/presentation/widgets/alarm_card_widget.dart';
import 'package:medicaixa_app/core/localization/app_localizations.dart';

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

class FakeDashboardNotifier extends DashboardNotifier {
  final DashboardState _initialState;
  FakeDashboardNotifier(this._initialState);

  @override
  DashboardState build() => _initialState;
}

Future<void> _waitForDashboardUpdate(
  ProviderContainer container,
  DateTime expectedDate,
) async {
  await container.read(dashboardNotifierProvider.notifier).refresh();
  await Future.delayed(const Duration(milliseconds: 50)); // Allow UI to settle
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

  test('Scenario 1: Create, mark taken, delete, verify ghost alarm on specific date (today and past)', () async {
    // Keep provider alive
    final keepAliveLink = container.listen(
      dashboardNotifierProvider,
      (previous, next) {},
    );
    addTearDown(keepAliveLink.close);

    final notifier = container.read(dashboardNotifierProvider.notifier);

    // 1. Create a recurrent alarm (active on all days)
    final alarm = AlarmModel(
      id: 0, // Let repository generate ID
      hour: 8,
      minute: 30,
      name: 'Med 12',
      medName: 'Med 12',
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

    final createdAlarms = await repository.getAllAlarms();
    final createdId = createdAlarms.first.id;

    // Get mid-day timestamps to avoid flaky tests
    final now = DateTime.now();
    final todayMid = DateTime(now.year, now.month, now.day, 12, 0, 0);
    final yesterdayMid = todayMid.subtract(const Duration(days: 1));

    // A. TEST FOR PAST DATE
    // Mark taken yesterday by creating a history event
    await db.into(db.historyEvents).insert(
      HistoryEventsCompanion(
        alarmId: Value(createdId),
        medName: const Value('Med 12'),
        dosage: const Value('1 comp.'),
        timestamp: Value(yesterdayMid.millisecondsSinceEpoch),
        status: const Value('TOMADO'),
        type: const Value('alarm'),
      ),
    );

    // Delete the alarm
    await repository.deleteAlarm(createdId);

    // Load dashboard for yesterday and wait for update
    notifier.selectDate(yesterdayMid);
    await _waitForDashboardUpdate(container, yesterdayMid);

    // Verify it is reconstructed as a Ghost Alarm on yesterday
    var state = container.read(dashboardNotifierProvider).requireValue;
    expect(state.alarms.length, 1);
    final ghostPast = state.alarms.first;
    expect(ghostPast.id, createdId);
    expect(ghostPast.isGhost, true);
    expect(ghostPast.lastStatus, 'Tomado');

    // B. TEST FOR TODAY
    // Re-create the alarm so we can mark it taken today
    await repository.createAlarm(alarm);
    
    final createdAlarmsToday = await repository.getAllAlarms();
    final createdIdToday = createdAlarmsToday.first.id;

    // Mark taken today
    await db.into(db.historyEvents).insert(
      HistoryEventsCompanion(
        alarmId: Value(createdIdToday),
        medName: const Value('Med 12'),
        dosage: const Value('1 comp.'),
        timestamp: Value(todayMid.millisecondsSinceEpoch),
        status: const Value('TOMADO'),
        type: const Value('alarm'),
      ),
    );

    // Delete it again
    await repository.deleteAlarm(createdIdToday);

    // Load dashboard for today and wait for update
    notifier.selectDate(todayMid);
    await _waitForDashboardUpdate(container, todayMid);

    // Verify it is reconstructed as a Ghost Alarm on today
    state = container.read(dashboardNotifierProvider).requireValue;
    expect(state.alarms.length, 1);
    final ghostToday = state.alarms.first;
    expect(ghostToday.id, createdIdToday);
    expect(ghostToday.isGhost, true);
    expect(ghostToday.lastStatus, 'Tomado');
  });

  testWidgets('Scenario 2: AlarmCardWidget rendering of Ghost Alarm', (WidgetTester tester) async {
    final ghostAlarm = AlarmModel(
      id: 99,
      hour: 8,
      minute: 0,
      name: 'Remédio Deletado',
      medName: 'Remédio Deletado',
      enabled: false,
      active: false,
      days: List.filled(7, true),
      status: 'TOMADO',
      color: 'grey',
      quantity: 1.0,
      daysQuantity: List.filled(7, 0.0),
      type: 'comprimido',
      dosage: '10mg',
      lastStatus: 'Tomado',
      lastStatusDate: '01/07/2026',
      snoozeMin: 0,
      durationDays: 0,
      isGhost: true,
    );

    final dashboardState = DashboardState(
      selectedDate: DateTime(2026, 7, 1),
      alarms: [ghostAlarm],
      allAlarms: [ghostAlarm],
      reminders: const [],
      allReminders: const [],
      takenCount: 1,
      pendingCount: 0,
      missedCount: 0,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dashboardNotifierProvider.overrideWith(() => FakeDashboardNotifier(dashboardState)),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: AlarmCardWidget(
              alarm: ghostAlarm,
              onMarkTaken: () {},
              onMarkSkipped: () {},
              onToggleEnabled: (_) {},
              onTap: null,
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify it displays the "Excluído" badge
    expect(find.text(t('badge_deleted')), findsOneWidget);

    // Verify lower opacity (0.55)
    final opacityWidget = tester.widget<Opacity>(find.byType(Opacity).first);
    expect(opacityWidget.opacity, 0.55);

    // Verify frequency text "Removido" using precise RichText finder
    final detailsRichText = find.byWidgetPredicate((widget) {
      if (widget is RichText) {
        final textSpan = widget.text as TextSpan;
        return textSpan.toPlainText().contains(t('alarm_removed'));
      }
      return false;
    });
    expect(detailsRichText, findsOneWidget);

    // Verify gray color theme
    final iconWidget = tester.widget<Icon>(find.byType(Icon));
    expect(iconWidget.color, Colors.grey);

    // Verify tap callback (onTap) is null
    final inkWellFinder = find.byType(InkWell);
    expect(inkWellFinder, findsOneWidget);
    final inkWell = tester.widget<InkWell>(inkWellFinder);
    expect(inkWell.onTap, isNull);
  });

  test('Scenario 3: Deleted without history events does not show up as Ghost Alarm', () async {
    final keepAliveLink = container.listen(
      dashboardNotifierProvider,
      (previous, next) {},
    );
    addTearDown(keepAliveLink.close);

    final notifier = container.read(dashboardNotifierProvider.notifier);

    // Create alarm
    final alarm = AlarmModel(
      id: 0,
      hour: 9,
      minute: 0,
      name: 'Never Taken',
      medName: 'Never Taken',
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

    final createdAlarms = await repository.getAllAlarms();
    final createdId = createdAlarms.first.id;

    // Delete it immediately (no history events)
    await repository.deleteAlarm(createdId);

    // Load dashboard
    notifier.refresh();
    await _waitForDashboardUpdate(container, DateTime.now());

    final state = container.read(dashboardNotifierProvider).requireValue;
    expect(state.alarms, isEmpty);
  });

  test('Scenario 4: Ghost Alarm does not appear on days subsequent to last recorded status date', () async {
    final keepAliveLink = container.listen(
      dashboardNotifierProvider,
      (previous, next) {},
    );
    addTearDown(keepAliveLink.close);

    final notifier = container.read(dashboardNotifierProvider.notifier);

    final now = DateTime.now();
    final todayMid = DateTime(now.year, now.month, now.day, 12, 0, 0);
    final yesterdayMid = todayMid.subtract(const Duration(days: 1));
    final tomorrowMid = todayMid.add(const Duration(days: 1));

    // Create and delete alarm with a history event on yesterday
    final alarm = AlarmModel(
      id: 0,
      hour: 10,
      minute: 0,
      name: 'Subsequent test',
      medName: 'Subsequent test',
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

    final createdAlarms = await repository.getAllAlarms();
    final createdId = createdAlarms.first.id;

    await db.into(db.historyEvents).insert(
      HistoryEventsCompanion(
        alarmId: Value(createdId),
        medName: const Value('Subsequent test'),
        dosage: const Value('1 comp.'),
        timestamp: Value(yesterdayMid.millisecondsSinceEpoch),
        status: const Value('TOMADO'),
        type: const Value('alarm'),
      ),
    );

    await repository.deleteAlarm(createdId);

    // 1. Load dashboard on yesterday -> Ghost Alarm should appear
    notifier.selectDate(yesterdayMid);
    await _waitForDashboardUpdate(container, yesterdayMid);
    var state = container.read(dashboardNotifierProvider).requireValue;
    expect(state.alarms.length, 1);
    expect(state.alarms.first.id, createdId);

    // 2. Load dashboard on today -> Ghost Alarm should NOT appear
    notifier.selectDate(todayMid);
    await _waitForDashboardUpdate(container, todayMid);
    state = container.read(dashboardNotifierProvider).requireValue;
    expect(state.alarms, isEmpty);

    // 3. Load dashboard on tomorrow -> Ghost Alarm should NOT appear
    notifier.selectDate(tomorrowMid);
    await _waitForDashboardUpdate(container, tomorrowMid);
    state = container.read(dashboardNotifierProvider).requireValue;
    expect(state.alarms, isEmpty);
  });
}
