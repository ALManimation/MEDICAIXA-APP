import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:medicaixa_app/core/database/database.dart';
import 'package:medicaixa_app/features/reminders/data/reminder_model.dart';
import 'package:medicaixa_app/features/reminders/data/reminder_repository.dart';
import 'package:medicaixa_app/features/reminders/data/reminder_api_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  FakeReminderRepository(AppDatabase db) : super(
    db,
    MockReminderApiClient(),
    FakeRef(),
  );

  bool completeCalled = false;
  int? completedId;
  bool deleteCalled = false;
  int? deletedId;

  @override
  Future<void> completeReminder(int id) async {
    completeCalled = true;
    completedId = id;
  }

  @override
  Future<void> deleteReminder(int id) async {
    deleteCalled = true;
    deletedId = id;
  }
}

void main() {
  group('ReminderActionModal Widget Tests', () {
    late AppDatabase db;
    late FakeReminderRepository fakeRepository;
    late ReminderModel pendingReminder;
    late ReminderModel completedReminder;

    setUp(() {
      db = AppDatabase.connect(NativeDatabase.memory());
      fakeRepository = FakeReminderRepository(db);
      
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

      final day = DateTime.now().day.toString().padLeft(2, '0');
      final month = DateTime.now().month.toString().padLeft(2, '0');
      final year = DateTime.now().year;
      final todayFormatted = '$day/$month/$year';

      completedReminder = ReminderModel(
        id: 43,
        title: 'Tomar Vitamina C',
        description: 'Vitamina C efervescente',
        enabled: true,
        hasTime: true,
        hour: 10,
        minute: 0,
        period: 'day',
        interval: 1,
        startDate: '2026-06-28',
        notifyDaysBefore: 0,
        color: 'red',
        lastCompletedDate: todayFormatted,
      );
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('Verify ReminderActionModal displays title, description and "Marcar como Feito" button when pending', (WidgetTester tester) async {
      bool refreshCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    ReminderActionModal.show(
                      context,
                      reminder: pendingReminder,
                      repository: fakeRepository,
                      onRefresh: () => refreshCalled = true,
                    );
                  },
                  child: const Text('Show Modal'),
                );
              },
            ),
          ),
        ),
      );

      // Open the modal
      await tester.tap(find.text('Show Modal'));
      await tester.pumpAndSettle();

      // Verify title and description
      expect(find.text('Gerenciar Lembrete'), findsOneWidget);
      expect(find.text('Tomar Vitamina D'), findsOneWidget);
      expect(find.text('Tomar com água mineral'), findsOneWidget);

      // Verify "Marcar como Feito" button is visible
      final doneButton = find.text('Marcar como Feito');
      expect(doneButton, findsOneWidget);
      expect(find.text('Concluído hoje'), findsNothing);

      // Click "Marcar como Feito"
      await tester.tap(doneButton);
      await tester.pumpAndSettle();

      // Verify actions
      expect(fakeRepository.completeCalled, isTrue);
      expect(fakeRepository.completedId, equals(42));
      expect(refreshCalled, isTrue);

      // Verify modal is closed
      expect(find.text('Gerenciar Lembrete'), findsNothing);
    });

    testWidgets('Verify ReminderActionModal displays "Concluído hoje" text when already completed', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    ReminderActionModal.show(
                      context,
                      reminder: completedReminder,
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
      );

      // Open the modal
      await tester.tap(find.text('Show Modal'));
      await tester.pumpAndSettle();

      // Verify title and description
      expect(find.text('Tomar Vitamina C'), findsOneWidget);
      expect(find.text('Vitamina C efervescente'), findsOneWidget);

      // Verify "Concluído hoje" text is visible and button is NOT
      expect(find.text('Concluído hoje'), findsOneWidget);
      expect(find.text('Marcar como Feito'), findsNothing);
    });

    testWidgets('Verify Editar button closes modal', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    ReminderActionModal.show(
                      context,
                      reminder: pendingReminder,
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
      );

      await tester.tap(find.text('Show Modal'));
      await tester.pumpAndSettle();

      // Click "Editar"
      await tester.tap(find.text('Editar'));
      await tester.pumpAndSettle();

      // Verify modal is closed (due to pop)
      expect(find.text('Gerenciar Lembrete'), findsNothing);
    });

    testWidgets('Verify Excluir button shows dialog and can delete reminder', (WidgetTester tester) async {
      bool refreshCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    ReminderActionModal.show(
                      context,
                      reminder: pendingReminder,
                      repository: fakeRepository,
                      onRefresh: () => refreshCalled = true,
                    );
                  },
                  child: const Text('Show Modal'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Modal'));
      await tester.pumpAndSettle();

      // Click "Excluir"
      await tester.tap(find.text('Excluir'));
      await tester.pumpAndSettle();

      // Verify confirmation dialog is displayed
      expect(find.text('Excluir Lembrete'), findsWidgets); // Both title in modal and dialog title
      expect(find.text('Tem certeza que deseja excluir "Tomar Vitamina D"?'), findsOneWidget);

      // Cancel the exclusion
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      // Repository should not be called yet
      expect(fakeRepository.deleteCalled, isFalse);

      // Open exclusion dialog again
      await tester.tap(find.text('Excluir'));
      await tester.pumpAndSettle();

      // Confirm exclusion
      await tester.tap(find.text('Excluir').last);
      await tester.pumpAndSettle();

      // Verify repository delete call, refresh callback, and modal closure
      expect(fakeRepository.deleteCalled, isTrue);
      expect(fakeRepository.deletedId, equals(42));
      expect(refreshCalled, isTrue);
      expect(find.text('Gerenciar Lembrete'), findsNothing);
    });
  });
}
