import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/native.dart';
import 'package:fake_async/fake_async.dart';
import 'package:dio/dio.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:medicaixa_app/core/database/database.dart';
import 'package:medicaixa_app/core/network/dio_client.dart';
import 'package:medicaixa_app/core/providers/core_providers.dart';
import 'package:medicaixa_app/core/providers/connection_providers.dart';
import 'package:medicaixa_app/features/pairing/domain/connection_state.dart';
import 'package:medicaixa_app/features/pairing/presentation/pairing_notifier.dart';
import 'package:medicaixa_app/features/pairing/data/connection_repository.dart';
import 'package:medicaixa_app/features/dashboard/presentation/dashboard_notifier.dart';
import 'package:medicaixa_app/features/dashboard/presentation/widgets/alarm_card_widget.dart';
import 'package:medicaixa_app/features/alarms/data/alarm_model.dart';
import 'package:medicaixa_app/core/localization/app_localizations.dart';

class MockDioClient implements DioClient {
  @override
  String? baseUrl = 'http://192.168.4.1';

  @override
  bool get isConfigured => baseUrl != null;

  @override
  void setBaseUrl(String url) {
    baseUrl = url;
  }

  @override
  Future<Response<T>> get<T>(String path, {Map<String, dynamic>? queryParameters}) async {
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      statusCode: 200,
      data: <String, dynamic>{'firmware_version': 'v0.90'} as T?,
    );
  }

  @override
  Future<Response<T>> post<T>(String path, {dynamic data, Map<String, dynamic>? queryParameters}) async {
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      statusCode: 200,
      data: 'OK' as T?,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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
  setUpAll(() async {
    await initializeDateFormatting('pt_BR', null);
  });

  group('Milestone 1 Challenger Validation Tests', () {
    late AppDatabase db;
    late MockDioClient dioClient;

    setUp(() {
      db = AppDatabase.connect(NativeDatabase.memory());
      dioClient = MockDioClient();
    });

    tearDown(() async {
      await db.close();
    });

    test('1. Hot Reload Safety: PairingNotifier does not throw LateInitializationError on multiple builds', () {
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          dioClientProvider.overrideWithValue(dioClient),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(pairingNotifierProvider.notifier);

      // Call build() multiple times to simulate hot reload on the same instance
      expect(() => notifier.build(), returnsNormally);
      expect(() => notifier.build(), returnsNormally);
    });

    test('2. Memory Leak & Safety: DashboardNotifier inactivity timer cancels on dispose', () {
      fakeAsync((async) {
        final container = ProviderContainer(
          overrides: [
            databaseProvider.overrideWithValue(db),
            dioClientProvider.overrideWithValue(dioClient),
          ],
        );

        final notifier = container.read(dashboardNotifierProvider.notifier);
        
        // Let initial load complete
        async.flushMicrotasks();

        // Select a non-today date to start the inactivity timer (3 minutes)
        final pastDate = DateTime.now().subtract(const Duration(days: 5));
        notifier.selectDate(pastDate);
        async.flushMicrotasks();

        // Now dispose the container (which disposes the notifier and executes onDispose)
        container.dispose();
        async.flushMicrotasks();

        // Advance time by 4 minutes to trigger where the timer would have fired if not cancelled
        async.elapse(const Duration(minutes: 4));

        // If the timer was not cancelled, it would attempt to call resetToToday()
        // which calls state = ... on a disposed notifier, throwing a StateError or bad state.
        // Since we are inside fakeAsync, any uncaught error or execution of timer would be detected or fail the test.
        // We assert no exceptions occurred.
      });
    });

    testWidgets('3. AlarmCardWidget select query correctness', (WidgetTester tester) async {
      // Initialize translation strings using loadTestStrings
      AppLocalizations.loadTestStrings('{"web": {"badge_deleted": "Excluído", "next_site_rotation": "Próximo site: %s", "med_type_tablet_short": "comp"}}');

      final alarm = AlarmModel(
        id: 1,
        hour: 8,
        minute: 0,
        name: 'Medicamento Teste',
        medName: 'Medicamento Teste',
        enabled: true,
        active: true,
        days: const [true, true, true, true, true, true, true],
        status: 'PENDENTE',
        color: 'blue',
        daysQuantity: const [0.0, 1.0, 2.0, 0.0, 0.0, 0.0, 0.0], // Asymmetric quantity
        quantity: 1.0,
        type: 'Comprimido',
        snoozeMin: 0,
        durationDays: 0,
      );

      final date = DateTime(2026, 6, 29); // Monday (weekday = 1, so index wday%7 = 1)
      final state = DashboardState(
        selectedDate: date,
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
            dashboardNotifierProvider.overrideWith(() => FakeDashboardNotifier(state)),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: AlarmCardWidget(
                alarm: alarm,
                onMarkTaken: () {},
                onMarkSkipped: () {},
                onToggleEnabled: (_) {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify that the quantity shown matches index 1 of daysQuantity (which is 1.0)
      // inside the RichText widget details row
      expect(
        find.byWidgetPredicate((widget) => widget is RichText && widget.text.toPlainText().contains('1 comp')),
        findsOneWidget,
      );
    });
  });
}
