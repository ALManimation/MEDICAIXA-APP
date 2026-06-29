import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/native.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:medicaixa_app/core/database/database.dart';
import 'package:medicaixa_app/core/providers/core_providers.dart';
import 'package:medicaixa_app/features/alarms/data/alarm_model.dart';
import 'package:medicaixa_app/features/dashboard/presentation/dashboard_notifier.dart';
import 'package:medicaixa_app/features/dashboard/presentation/dashboard_screen.dart';
import 'package:medicaixa_app/features/medications/presentation/medications_list_screen.dart';
import 'package:medicaixa_app/features/pairing/domain/connection_state.dart';
import 'package:medicaixa_app/features/pairing/presentation/pairing_notifier.dart';
import 'package:drift/drift.dart' hide Column;

class FakePairingNotifier extends PairingNotifier {
  FakePairingNotifier(this._initialState);
  final ConnectionStateInfo _initialState;

  @override
  ConnectionStateInfo build() {
    return _initialState;
  }
}

class FakeDashboardNotifier extends DashboardNotifier {
  final DashboardState _initialState;

  FakeDashboardNotifier(this._initialState);

  @override
  DashboardState build() {
    return _initialState;
  }

  @override
  void selectDate(DateTime date) {
    state = state.copyWith(selectedDate: date);
  }

  @override
  void refresh() {}

  @override
  void resetToToday() {
    state = state.copyWith(selectedDate: DateTime.now());
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
    try {
      await db.close();
    } catch (_) {}
  });

  group('Dashboard responsive layout tests', () {
    testWidgets('Dashboard renders GridView on wide screens (width >= 800)', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final alarm = AlarmModel(
        id: 1,
        hour: 8,
        minute: 0,
        name: 'Test Med',
        medName: 'Test Med',
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
        isLoading: false,
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

      // Expect to find GridView on wide screens
      expect(find.byType(GridView), findsOneWidget);

      await db.close();
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('Dashboard does not render GridView on narrow screens (width < 800)', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final alarm = AlarmModel(
        id: 1,
        hour: 8,
        minute: 0,
        name: 'Test Med',
        medName: 'Test Med',
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
        isLoading: false,
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

      // Expect to find Column instead of GridView on narrow screens
      expect(find.byType(GridView), findsNothing);

      await db.close();
      await tester.pump(const Duration(seconds: 2));
    });
  });

  group('Medications list responsive layout tests', () {
    testWidgets('Medications screen renders GridView on wide screens (width >= 800)', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Insert a mock medication to verify list is not empty
      await db.into(db.medications).insert(
        MedicationsCompanion.insert(
          name: 'Paracetamol',
          color: 'blue',
          type: 'comprimido',
          dosage: const Value('500mg'),
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
          ],
          child: const MaterialApp(
            home: MedicationsListScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Expect to find GridView on wide screens
      expect(find.byType(GridView), findsOneWidget);
      expect(find.text('Paracetamol'), findsOneWidget);

      await db.close();
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('Medications screen does not render GridView on narrow screens (width < 800)', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Insert a mock medication
      await db.into(db.medications).insert(
        MedicationsCompanion.insert(
          name: 'Paracetamol',
          color: 'blue',
          type: 'comprimido',
          dosage: const Value('500mg'),
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
          ],
          child: const MaterialApp(
            home: MedicationsListScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Expect to find ListView instead of GridView on narrow screens
      expect(find.byType(GridView), findsNothing);
      expect(find.byType(ListView), findsOneWidget);
      expect(find.text('Paracetamol'), findsOneWidget);

      await db.close();
      await tester.pump(const Duration(seconds: 2));
    });
  });
}
