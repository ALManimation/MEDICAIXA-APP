import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/native.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:medicaixa_app/core/constants/app_colors.dart';
import 'package:medicaixa_app/core/database/database.dart';
import 'package:medicaixa_app/core/providers/core_providers.dart';
import 'package:medicaixa_app/features/alarms/data/alarm_model.dart';
import 'package:medicaixa_app/features/dashboard/presentation/dashboard_notifier.dart';
import 'package:medicaixa_app/features/dashboard/presentation/dashboard_screen.dart';
import 'package:medicaixa_app/features/pairing/domain/connection_state.dart';
import 'package:medicaixa_app/features/pairing/presentation/pairing_notifier.dart';
import 'package:medicaixa_app/features/dashboard/presentation/widgets/health_banner_widget.dart';
import 'package:medicaixa_app/features/dashboard/presentation/widgets/calendar_strip_widget.dart';

import 'package:medicaixa_app/core/providers/connection_providers.dart';

class FakePairingNotifier extends PairingNotifier {
  FakePairingNotifier(this._initialState);
  final ConnectionStateInfo _initialState;

  @override
  ConnectionStateInfo build() {
    listenSelf((previous, next) {
      Future.microtask(() {
        ref.read(deviceConnectionStateProvider.notifier).updateState(next);
      });
    });
    Future.microtask(() {
      ref.read(deviceConnectionStateProvider.notifier).updateState(_initialState);
    });
    return _initialState;
  }
}

class FakeDashboardNotifier extends DashboardNotifier {
  final DashboardState _initialState;

  FakeDashboardNotifier(this._initialState);

  @override
  FutureOr<DashboardState> build() {
    return _initialState;
  }

  @override
  void selectDate(DateTime date) {
    state = AsyncValue.data(state.requireValue.copyWith(selectedDate: date));
  }

  @override
  Future<void> refresh() async {}

  @override
  void resetToToday() {
    state = AsyncValue.data(state.requireValue.copyWith(selectedDate: DateTime.now()));
  }

  @override
  Future<void> sync() async {}
}

void main() {
  late AppDatabase db;

  setUpAll(() async {
    await initializeDateFormatting('pt_BR', null);
  });

  setUp(() {
    db = AppDatabase.connect(NativeDatabase.memory());
  });

  tearDown(() async {
    currentDateOverride = () => DateTime.now();
    try {
      await db.close();
    } catch (_) {}
  });

  testWidgets('Dashboard header has fixed elements and correct hierarchy', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    currentDateOverride = () => DateTime(2026, 6, 28, 8, 0); // 8:00 AM (Bom dia)

    final date = DateTime(2026, 6, 28);
    final state = DashboardState(
      selectedDate: date,
      alarms: const [],
      allAlarms: const [],
      reminders: const [],
      allReminders: const [],
      takenCount: 0,
      pendingCount: 0,
      missedCount: 0,

    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          pairingNotifierProvider.overrideWith(() => FakePairingNotifier(const ConnectionStateInfo.disconnected())),
          dashboardNotifierProvider.overrideWith(() => FakeDashboardNotifier(state)),
        ],
        child: const MaterialApp(
          home: DashboardScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Greeting, HealthBanner, CalendarStrip, Connection pill exist in the fixed header area
    expect(find.textContaining('Bom dia, Paciente!'), findsOneWidget);
    expect(find.byType(HealthBannerWidget), findsOneWidget);
    expect(find.byType(CalendarStripWidget), findsOneWidget);
    expect(find.text('Modo Offline'), findsOneWidget);
    
    // Verify scrollable body structure exists
    expect(find.byType(SingleChildScrollView), findsOneWidget);

    await db.close();
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('Period sections can toggle expand/collapse state when tapped', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    currentDateOverride = () => DateTime(2026, 6, 28, 8, 0); // 8:00 AM

    final alarm = AlarmModel(
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
      snoozeMin: 0,
      durationDays: 0,
    );

    final state = DashboardState(
      selectedDate: DateTime(2026, 6, 28),
      alarms: [alarm],
      allAlarms: [alarm],
      reminders: const [],
      allReminders: const [],
      takenCount: 0,
      pendingCount: 1,
      missedCount: 0,

    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          pairingNotifierProvider.overrideWith(() => FakePairingNotifier(const ConnectionStateInfo.disconnected())),
          dashboardNotifierProvider.overrideWith(() => FakeDashboardNotifier(state)),
        ],
        child: const MaterialApp(
          home: DashboardScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Initially open (hour < 12, pending exists)
    expect(find.text('Medicamento A'), findsOneWidget);

    // Tap to collapse
    await tester.tap(find.textContaining('Manhã (1)'));
    await tester.pumpAndSettle();

    // Now hidden
    expect(find.text('Medicamento A'), findsNothing);

    // Tap to expand
    await tester.tap(find.textContaining('Manhã (1)'));
    await tester.pumpAndSettle();

    // Visible again
    expect(find.text('Medicamento A'), findsOneWidget);

    await db.close();
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('Badge count display shows active count and missed counts in red', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    currentDateOverride = () => DateTime(2026, 6, 28, 8, 0); // 8:00 AM

    final alarm = AlarmModel(
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
      snoozeMin: 0,
      durationDays: 0,
      lastStatus: 'Não Tomado',
      lastStatusDate: '28/06/2026',
    );

    final state = DashboardState(
      selectedDate: DateTime(2026, 6, 28),
      alarms: [alarm],
      allAlarms: [alarm],
      reminders: const [],
      allReminders: const [],
      takenCount: 0,
      pendingCount: 0,
      missedCount: 1,

    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          pairingNotifierProvider.overrideWith(() => FakePairingNotifier(const ConnectionStateInfo.disconnected())),
          dashboardNotifierProvider.overrideWith(() => FakeDashboardNotifier(state)),
        ],
        child: const MaterialApp(
          home: DashboardScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Manhã (1) and "• 1 perdido" exist
    expect(find.textContaining('Manhã (1)'), findsOneWidget);
    final missedFinder = find.textContaining('1 perdido');
    expect(missedFinder, findsOneWidget);
    
    final textWidget = tester.widget<Text>(missedFinder);
    expect(textWidget.style?.color, equals(AppColors.missed));

    await db.close();
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('Time-based auto-collapse logic on Today', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    // 1:00 PM (hour 13) -> Morning collapses, Afternoon is expanded
    currentDateOverride = () => DateTime(2026, 6, 28, 13, 0);

    final morningAlarm = AlarmModel(
      id: 1,
      hour: 8,
      minute: 0,
      name: 'Morning Med',
      medName: 'Morning Med',
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

    final afternoonAlarm = AlarmModel(
      id: 2,
      hour: 14,
      minute: 0,
      name: 'Afternoon Med',
      medName: 'Afternoon Med',
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

    final state = DashboardState(
      selectedDate: DateTime(2026, 6, 28),
      alarms: [morningAlarm, afternoonAlarm],
      allAlarms: [morningAlarm, afternoonAlarm],
      reminders: const [],
      allReminders: const [],
      takenCount: 0,
      pendingCount: 1, // Afternoon Med is pending (time is 13:00, alarm is 14:00)
      missedCount: 1,  // Morning Med is missed (time passed 8:00 < 13:00)

    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          pairingNotifierProvider.overrideWith(() => FakePairingNotifier(const ConnectionStateInfo.disconnected())),
          dashboardNotifierProvider.overrideWith(() => FakeDashboardNotifier(state)),
        ],
        child: const MaterialApp(
          home: DashboardScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Morning is collapsed (hour >= 12)
    expect(find.text('Morning Med'), findsNothing);

    // Afternoon is expanded (hour < 18, pending exists)
    expect(find.text('Afternoon Med'), findsOneWidget);

    await db.close();
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('Completion-based auto-collapse logic on Today', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    currentDateOverride = () => DateTime(2026, 6, 28, 8, 0); // 8:00 AM

    final morningAlarm = AlarmModel(
      id: 1,
      hour: 9,
      minute: 0,
      name: 'Morning Med',
      medName: 'Morning Med',
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
      lastStatus: 'Tomado',
      lastStatusDate: '28/06/2026',
    );

    final state = DashboardState(
      selectedDate: DateTime(2026, 6, 28),
      alarms: [morningAlarm],
      allAlarms: [morningAlarm],
      reminders: const [],
      allReminders: const [],
      takenCount: 1,
      pendingCount: 0,
      missedCount: 0,

    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          pairingNotifierProvider.overrideWith(() => FakePairingNotifier(const ConnectionStateInfo.disconnected())),
          dashboardNotifierProvider.overrideWith(() => FakeDashboardNotifier(state)),
        ],
        child: const MaterialApp(
          home: DashboardScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Collapsed because the only alarm in Morning section is Taken (no pending)
    expect(find.text('Morning Med'), findsNothing);

    await db.close();
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('Other days remain fully expanded', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    // Current date is 2026-06-28 13:00 (which would trigger Morning collapse if it was today)
    currentDateOverride = () => DateTime(2026, 6, 28, 13, 0);

    final morningAlarm = AlarmModel(
      id: 1,
      hour: 8,
      minute: 0,
      name: 'Morning Med',
      medName: 'Morning Med',
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

    final state = DashboardState(
      selectedDate: DateTime(2026, 6, 29), // Tomorrow
      alarms: [morningAlarm],
      allAlarms: [morningAlarm],
      reminders: const [],
      allReminders: const [],
      takenCount: 0,
      pendingCount: 1,
      missedCount: 0,

    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          pairingNotifierProvider.overrideWith(() => FakePairingNotifier(const ConnectionStateInfo.disconnected())),
          dashboardNotifierProvider.overrideWith(() => FakeDashboardNotifier(state)),
        ],
        child: const MaterialApp(
          home: DashboardScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Should be fully expanded because selected date is tomorrow (other day)
    expect(find.text('Morning Med'), findsOneWidget);

    await db.close();
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('Switching selected date resets manual collapse states', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    currentDateOverride = () => DateTime(2026, 6, 28, 8, 0); // 8:00 AM

    final alarm = AlarmModel(
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
      snoozeMin: 0,
      durationDays: 0,
    );

    final stateToday = DashboardState(
      selectedDate: DateTime(2026, 6, 28),
      alarms: [alarm],
      allAlarms: [alarm],
      reminders: const [],
      allReminders: const [],
      takenCount: 0,
      pendingCount: 1,
      missedCount: 0,

    );

    final dashboardNotifier = FakeDashboardNotifier(stateToday);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          pairingNotifierProvider.overrideWith(() => FakePairingNotifier(const ConnectionStateInfo.disconnected())),
          dashboardNotifierProvider.overrideWith(() => dashboardNotifier),
        ],
        child: const MaterialApp(
          home: DashboardScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Initially open (hour < 12, pending exists)
    expect(find.text('Medicamento A'), findsOneWidget);

    // Tap to collapse
    await tester.tap(find.textContaining('Manhã (1)'));
    await tester.pumpAndSettle();

    // Now hidden
    expect(find.text('Medicamento A'), findsNothing);

    // Now change date (which fires listener and should clear overrides)
    dashboardNotifier.selectDate(DateTime(2026, 6, 29));
    await tester.pumpAndSettle();

    // The collapse overrides should be cleared, so it goes back to default (expanded for other days)
    expect(find.text('Medicamento A'), findsOneWidget);

    await db.close();
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('Section remains expanded if at least one alarm is pending, even if others are taken', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    currentDateOverride = () => DateTime(2026, 6, 28, 8, 0); // 8:00 AM

    final takenAlarm = AlarmModel(
      id: 1,
      hour: 8,
      minute: 0,
      name: 'Taken Med',
      medName: 'Taken Med',
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
      lastStatus: 'Tomado',
      lastStatusDate: '28/06/2026',
    );

    final pendingAlarm = AlarmModel(
      id: 2,
      hour: 9,
      minute: 0,
      name: 'Pending Med',
      medName: 'Pending Med',
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

    final state = DashboardState(
      selectedDate: DateTime(2026, 6, 28),
      alarms: [takenAlarm, pendingAlarm],
      allAlarms: [takenAlarm, pendingAlarm],
      reminders: const [],
      allReminders: const [],
      takenCount: 1,
      pendingCount: 1,
      missedCount: 0,

    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          pairingNotifierProvider.overrideWith(() => FakePairingNotifier(const ConnectionStateInfo.disconnected())),
          dashboardNotifierProvider.overrideWith(() => FakeDashboardNotifier(state)),
        ],
        child: const MaterialApp(
          home: DashboardScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Both should be visible since section remains expanded
    expect(find.text('Taken Med'), findsOneWidget);
    expect(find.text('Pending Med'), findsOneWidget);

    await db.close();
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('Fixed header elements are not inside SingleChildScrollView', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    currentDateOverride = () => DateTime(2026, 6, 28, 8, 0);

    final state = DashboardState(
      selectedDate: DateTime(2026, 6, 28),
      alarms: const [],
      allAlarms: const [],
      reminders: const [],
      allReminders: const [],
      takenCount: 0,
      pendingCount: 0,
      missedCount: 0,

    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          pairingNotifierProvider.overrideWith(() => FakePairingNotifier(const ConnectionStateInfo.disconnected())),
          dashboardNotifierProvider.overrideWith(() => FakeDashboardNotifier(state)),
        ],
        child: const MaterialApp(
          home: DashboardScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final scrollableFinder = find.byType(SingleChildScrollView);
    expect(scrollableFinder, findsOneWidget);

    // Verify Greeting, HealthBanner, and CalendarStrip are NOT descendants of the scrollable view
    expect(find.descendant(of: scrollableFinder, matching: find.textContaining('Bom dia, Paciente!')), findsNothing);
    expect(find.descendant(of: scrollableFinder, matching: find.byType(HealthBannerWidget)), findsNothing);
    expect(find.descendant(of: scrollableFinder, matching: find.byType(CalendarStripWidget)), findsNothing);

    await db.close();
    await tester.pump(const Duration(seconds: 2));
  });
}
