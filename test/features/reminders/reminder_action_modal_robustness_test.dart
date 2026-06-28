import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medicaixa_app/core/database/database.dart';
import 'package:medicaixa_app/core/providers/core_providers.dart';
import 'package:medicaixa_app/features/reminders/data/reminder_model.dart';
import 'package:medicaixa_app/features/reminders/data/reminder_repository.dart';
import 'package:medicaixa_app/features/reminders/data/reminder_api_client.dart';
import 'package:medicaixa_app/features/dashboard/presentation/dashboard_notifier.dart';
import 'package:medicaixa_app/features/reminders/presentation/widgets/reminder_action_modal.dart';

class MockReminderApiClient implements ReminderApiClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class FakeRef implements Ref {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class FakeReminderRepository extends ReminderRepository {
  FakeReminderRepository(AppDatabase db, [Ref? ref]) : super(
    db,
    MockReminderApiClient(),
    ref ?? FakeRef(),
  );

  bool completeCalled = false;
  int? completedId;
  bool deleteCalled = false;
  int? deletedId;

  @override
  Future<void> completeReminder(int id) async {
    completeCalled = true;
    completedId = id;
    await super.completeReminder(id);
  }

  @override
  Future<void> deleteReminder(int id) async {
    deleteCalled = true;
    deletedId = id;
    await super.deleteReminder(id);
  }
}

void main() {
  group('ReminderActionModal Robustness and Adversarial Tests', () {
    late AppDatabase db;
    late FakeReminderRepository fakeRepository;
    late ReminderModel pendingReminder;

    setUp(() {
      db = AppDatabase.connect(NativeDatabase.memory());
      
      pendingReminder = const ReminderModel(
        id: 42,
        title: 'Tomar Vitamina D',
        description: 'Tomar com água mineral',
        enabled: true,
        hasTime: true,
        hour: 9,
        minute: 0,
        period: 'day',
        interval: 1,
        startDate: '2026-06-28',
        notifyDaysBefore: 0,
        color: 'blue',
        lastCompletedDate: null,
      );
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('Verify very long description causes overflow or is captured', (WidgetTester tester) async {
      final List<FlutterErrorDetails> errors = [];
      final oldHandler = FlutterError.onError;
      FlutterError.onError = (FlutterErrorDetails details) {
        errors.add(details);
      };

      fakeRepository = FakeReminderRepository(db);
      bool hasOverflow = false;

      try {
        // Set physical size to a small viewport (typical of older/smaller phones) to test overflow boundaries
        tester.view.physicalSize = const Size(360, 480);
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (context) {
                    return ElevatedButton(
                      onPressed: () {
                        ReminderActionModal.show(
                          context,
                          reminder: ReminderModel(
                            id: 45,
                            title: 'Lembrete com Descrição Gigante',
                            description: 'Esta é uma descrição extremamente longa. ' * 50,
                            enabled: true,
                            hasTime: true,
                            hour: 12,
                            minute: 0,
                            period: 'day',
                            interval: 1,
                            startDate: '2026-06-28',
                            notifyDaysBefore: 0,
                            color: 'blue',
                            lastCompletedDate: null,
                          ),
                          repository: fakeRepository,
                          onRefresh: () {},
                        );
                      },
                      child: const Text('Show Modal'),
                    );
                  },
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Show Modal'));
        await tester.pumpAndSettle();

        // Check if a RenderFlex overflow occurred
        hasOverflow = errors.any((e) => e.toString().contains('A RenderFlex overflowed'));
      } finally {
        FlutterError.onError = oldHandler;
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      }

      // Assert outside of the try-finally block where onError is restored
      expect(hasOverflow, isFalse, reason: 'A very long description should not trigger a RenderFlex overflow since the modal is scrollable');
    });

    testWidgets('Verify ReminderActionModal handles empty description gracefully', (WidgetTester tester) async {
      final emptyDescReminder = pendingReminder.copyWith(description: '');
      fakeRepository = FakeReminderRepository(db);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () {
                      ReminderActionModal.show(
                        context,
                        reminder: emptyDescReminder,
                        repository: fakeRepository,
                        onRefresh: () {},
                      );
                    },
                    child: const Text('Show Modal'),
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Modal'));
      await tester.pumpAndSettle();

      // Verify title is visible
      expect(find.text('Tomar Vitamina D'), findsOneWidget);
      // Verify description Text widget containing the description text is NOT present
      expect(find.text('Tomar com água mineral'), findsNothing);
    });

    testWidgets('Verify ReminderActionModal handles empty title gracefully', (WidgetTester tester) async {
      final emptyTitleReminder = pendingReminder.copyWith(title: '');
      fakeRepository = FakeReminderRepository(db);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () {
                      ReminderActionModal.show(
                        context,
                        reminder: emptyTitleReminder,
                        repository: fakeRepository,
                        onRefresh: () {},
                      );
                    },
                    child: const Text('Show Modal'),
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Modal'));
      await tester.pumpAndSettle();

      // Verify that the title row loads without crashing but displays an empty text
      final textWidget = tester.widget<Text>(find.byWidgetPredicate(
        (widget) => widget is Text && widget.style?.fontSize == 17 && widget.style?.fontWeight == FontWeight.bold
      ));
      expect(textWidget.data, isEmpty);
    });

    test('Verify DashboardNotifier does not automatically react to reminder updates in repository', () async {
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWith((ref) => db),
          reminderRepositoryProvider.overrideWith((ref) => FakeReminderRepository(db, ref)),
        ],
      );
      addTearDown(container.dispose);

      // Listen to the provider to keep it alive during async operations (avoiding auto-dispose)
      final keepAliveLink = container.listen(
        dashboardNotifierProvider,
        (previous, next) {},
      );
      addTearDown(keepAliveLink.close);

      // Trigger initial build and loading
      final notifier = container.read(dashboardNotifierProvider.notifier);
      
      // Let initial async loading complete
      await Future.delayed(Duration.zero);
      
      // Verify initial state
      expect(container.read(dashboardNotifierProvider).reminders.length, 0);

      // Obtain repository
      final repo = container.read(reminderRepositoryProvider);

      // Create a new reminder in the database via repository
      final todayStr = "${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}";
      
      final newReminder = ReminderModel(
        id: 101,
        title: 'Lembrete Reactivo Teste',
        description: 'Desc',
        enabled: true,
        hasTime: false,
        hour: 0,
        minute: 0,
        period: 'day',
        interval: 1,
        startDate: todayStr,
        notifyDaysBefore: 0,
        color: 'blue',
      );
      await repo.createReminder(newReminder);

      // Wait a short moment for database microtasks to flush
      await Future.delayed(const Duration(milliseconds: 100));

      // Verify that DashboardNotifier state remains STALE (still shows 0 reminders)
      // because it does not watch database streams reactively, and `ref.listen` on `reminderRepositoryProvider` is a no-op
      expect(container.read(dashboardNotifierProvider).reminders.length, 0);

      // Now call refresh() manually
      notifier.refresh();
      
      // Dynamically wait for the state to update (polling)
      int retries = 0;
      while (container.read(dashboardNotifierProvider).reminders.isEmpty && retries < 20) {
        await Future.delayed(const Duration(milliseconds: 50));
        retries++;
      }

      // Now the dashboard state updates and shows the new reminder
      expect(container.read(dashboardNotifierProvider).reminders.length, 1);
      expect(container.read(dashboardNotifierProvider).reminders.first.title, 'Lembrete Reactivo Teste');
    });
  });
}
