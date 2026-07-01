import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' show Value;
import 'package:medicaixa_app/core/database/database.dart';
import 'package:medicaixa_app/features/medications/data/medication_repository.dart';
import 'package:medicaixa_app/features/medications/data/medication_api_client.dart';
import 'package:medicaixa_app/features/alarms/data/alarm_repository.dart';
import 'package:medicaixa_app/features/alarms/data/alarm_api_client.dart';
import 'package:medicaixa_app/features/alarms/data/alarm_model.dart';
import 'package:medicaixa_app/core/providers/core_providers.dart';
import 'package:medicaixa_app/core/providers/connection_providers.dart';
import 'package:medicaixa_app/features/pairing/domain/connection_state.dart';
import 'package:medicaixa_app/features/medications/presentation/medications_list_screen.dart';
import 'package:medicaixa_app/features/medications/presentation/medication_form_screen.dart';
import 'package:intl/date_symbol_data_local.dart';

class MockMedicationApiClient implements MedicationApiClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

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
  setUpAll(() async {
    await initializeDateFormatting('pt_BR', null);
  });

  group('Medication CRUD & Rule 35 Deletion Prevention Tests', () {
    late AppDatabase db;
    late ProviderContainer container;
    late MedicationRepository medRepository;
    late AlarmRepository alarmRepository;

    setUp(() {
      db = AppDatabase.connect(NativeDatabase.memory());
      container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          medicationApiClientProvider.overrideWithValue(MockMedicationApiClient()),
          alarmApiClientProvider.overrideWithValue(MockAlarmApiClient()),
        ],
      );
      medRepository = MedicationRepository(db, MockMedicationApiClient(), FakeRef(container));
      alarmRepository = AlarmRepository(db, MockAlarmApiClient(), FakeRef(container));
    });

    tearDown(() async {
      try {
        await db.close();
      } catch (_) {}
      container.dispose();
    });

    test('Create, Update, and Delete Medication without Active Alarms', () async {
      // 1. Create a medication
      const med = Medication(
        name: 'Paracetamol',
        color: 'red',
        type: 'comprimido',
        dosage: '500mg',
        pendingSync: false,
      );
      await medRepository.createMedication(med);

      // Verify insertion
      var list = await medRepository.getAllMedications();
      expect(list.length, equals(1));
      expect(list.first.name, equals('Paracetamol'));
      expect(list.first.dosage, equals('500mg'));

      // 2. Update the medication
      final updatedMed = med.copyWith(dosage: const Value('750mg'));
      await medRepository.updateMedication('Paracetamol', updatedMed);

      // Verify update
      list = await medRepository.getAllMedications();
      expect(list.length, equals(1));
      expect(list.first.dosage, equals('750mg'));

      // 3. Delete the medication
      await medRepository.deleteMedication('Paracetamol');

      // Verify deletion
      list = await medRepository.getAllMedications();
      expect(list, isEmpty);
    });

    test('Verify Rule 35: Exception thrown when deleting medication in use by active/enabled alarm', () async {
      // 1. Create medication
      const med = Medication(
        name: 'Aspirina',
        color: 'yellow',
        type: 'comprimido',
        dosage: '100mg',
        pendingSync: false,
      );
      await medRepository.createMedication(med);

      // 2. Create an active alarm referencing it
      final alarm = AlarmModel(
        id: 10,
        hour: 8,
        minute: 0,
        name: 'Aspirina',
        medName: 'Aspirina',
        enabled: true,
        active: true,
        days: List.filled(7, true),
        status: 'PENDENTE',
        color: 'yellow',
        quantity: 1.0,
        daysQuantity: List.filled(7, 0.0),
        type: 'comprimido',
        snoozeMin: 0,
        durationDays: 0,
      );
      await alarmRepository.createAlarm(alarm);

      // 3. Try to delete medication and expect Exception
      expect(
        () => medRepository.deleteMedication('Aspirina'),
        throwsA(isA<Exception>()),
      );

      // Verify medication is still in DB
      final list = await medRepository.getAllMedications();
      expect(list.any((m) => m.name == 'Aspirina'), isTrue);
    });

    test('Verify Rule 35 during syncWithDevice: medication in use by active/enabled alarm is skipped during cleanup', () async {
      // Set connection state to connected
      container.read(deviceConnectionStateProvider.notifier).updateState(
        const ConnectionStateInfo(
          status: ConnectionStatus.connected,
          ip: '192.168.4.1',
        ),
      );

      // 1. Create medication
      const med = Medication(
        name: 'Dipirona',
        color: 'green',
        type: 'comprimido',
        dosage: '500mg',
        pendingSync: false,
      );
      await medRepository.createMedication(med);

      // 2. Create active alarm referencing Dipirona
      final alarm = AlarmModel(
        id: 11,
        hour: 10,
        minute: 0,
        name: 'Dipirona',
        medName: 'Dipirona',
        enabled: true,
        active: true,
        days: List.filled(7, true),
        status: 'PENDENTE',
        color: 'green',
        quantity: 1.0,
        daysQuantity: List.filled(7, 0.0),
        type: 'comprimido',
        snoozeMin: 0,
        durationDays: 0,
      );
      await alarmRepository.createAlarm(alarm);

      // 3. Run sync cleanup loop
      await medRepository.syncWithDevice();

      // Verify that Dipirona was NOT deleted because of the active alarm check
      final list = await medRepository.getAllMedications();
      expect(list.any((m) => m.name == 'Dipirona'), isTrue);
    });

    testWidgets('Verify Rule 35: Blocking medication deletion if linked to an active alarm', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // 1. Create medication
      const med = Medication(
        name: 'Ibuprofeno',
        color: 'blue',
        type: 'comprimido',
        dosage: '400mg',
        pendingSync: false,
      );
      await medRepository.createMedication(med);

      // 2. Create an alarm linked to the medication (medName or name set to 'Ibuprofeno')
      final alarm = AlarmModel(
        id: 1,
        hour: 8,
        minute: 0,
        name: 'Ibuprofeno',
        medName: 'Ibuprofeno',
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
      await alarmRepository.createAlarm(alarm);

      // 3. Render MedicationsListScreen
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: MedicationsListScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Ibuprofeno is listed
      expect(find.text('Ibuprofeno'), findsOneWidget);

      // 4. Enter selection mode and select Ibuprofeno
      final selectButton = find.text('Selecionar');
      expect(selectButton, findsOneWidget);
      await tester.tap(selectButton);
      await tester.pumpAndSettle();

      final medCard = find.text('Ibuprofeno');
      await tester.tap(medCard);
      await tester.pumpAndSettle();

      // Tap the delete button
      final deleteButton = find.text('Excluir (1)');
      expect(deleteButton, findsOneWidget);
      await tester.tap(deleteButton);
      await tester.pumpAndSettle();

      // 5. Verify that warning dialog is shown (blocked deletion)
      expect(find.text('Não é possível excluir'), findsOneWidget);
      expect(find.textContaining('Não é possível excluir medicamentos em uso'), findsOneWidget);

      // Tap OK on the dialog
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      // Verify the medication was not deleted
      final list = await medRepository.getAllMedications();
      expect(list.any((m) => m.name == 'Ibuprofeno'), isTrue);

      await db.close();
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('Verify Rule 35 in MedicationFormScreen: Blocking medication deletion if linked to an active alarm', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // 1. Create medication
      const med = Medication(
        name: 'Aspirina',
        color: 'yellow',
        type: 'comprimido',
        dosage: '100mg',
        pendingSync: false,
      );
      await medRepository.createMedication(med);

      // 2. Create an alarm linked to the medication
      final alarm = AlarmModel(
        id: 2,
        hour: 9,
        minute: 0,
        name: 'Aspirina',
        medName: 'Aspirina',
        enabled: true,
        active: true,
        days: List.filled(7, true),
        status: 'PENDENTE',
        color: 'yellow',
        quantity: 1.0,
        daysQuantity: List.filled(7, 0.0),
        type: 'comprimido',
        snoozeMin: 0,
        durationDays: 0,
      );
      await alarmRepository.createAlarm(alarm);

      // 3. Render MedicationFormScreen in edit mode
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: MedicationFormScreen(editMedication: med),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Aspirina is displayed in form field
      expect(find.text('Aspirina'), findsOneWidget);

      // 4. Tap the delete button on the form screen
      final deleteBtn = find.byIcon(Icons.delete_rounded);
      expect(deleteBtn, findsOneWidget);
      await tester.tap(deleteBtn);
      await tester.pumpAndSettle();

      // 5. Verify that warning dialog is shown (blocked deletion)
      expect(find.text('Não é possível excluir'), findsOneWidget);
      expect(find.textContaining('Não é possível excluir medicamentos em uso'), findsOneWidget);

      // Tap OK on the dialog
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      // Verify the medication was not deleted
      final list = await medRepository.getAllMedications();
      expect(list.any((m) => m.name == 'Aspirina'), isTrue);

      await db.close();
      await tester.pump(const Duration(seconds: 2));
    });
  });
}
