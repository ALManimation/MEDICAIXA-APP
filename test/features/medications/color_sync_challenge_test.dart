import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/native.dart';
import 'package:medicaixa_app/core/database/database.dart';
import 'package:medicaixa_app/features/medications/data/medication_repository.dart';
import 'package:medicaixa_app/features/medications/data/medication_api_client.dart';
import 'package:medicaixa_app/features/alarms/data/alarm_repository.dart';
import 'package:medicaixa_app/features/alarms/data/alarm_api_client.dart';
import 'package:medicaixa_app/features/alarms/data/alarm_model.dart';
import 'package:medicaixa_app/features/alarms/presentation/wizard/wizard_notifier.dart';
import 'package:medicaixa_app/core/providers/core_providers.dart';

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
  group('Bidirectional Medication Color Synchronization Tests', () {
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
      await db.close();
      container.dispose();
    });

    test('Updating medication color propagates to alarms table and is correctly resolved', () async {
      // 1. Create a medication
      const med = Medication(
        name: 'Ibuprofeno',
        color: 'blue',
        type: 'comprimido',
        dosage: '400mg',
        pendingSync: false,
      );
      await medRepository.createMedication(med);

      // Verify the medication was inserted with blue color
      final medsList = await medRepository.getAllMedications();
      expect(medsList.first.color, equals('blue'));

      // 2. Create an alarm linked to Ibuprofeno
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
        color: 'blue', // Match the medication initial color
        quantity: 1.0,
        daysQuantity: List.filled(7, 0.0),
        type: 'comprimido',
        snoozeMin: 0,
        durationDays: 0,
      );
      await alarmRepository.createAlarm(alarm);

      // Verify the alarm is created and resolved to blue
      var alarms = await alarmRepository.getAllAlarms();
      expect(alarms.first.color, equals('blue'));

      // Also check the underlying database table row for the alarm directly
      var dbAlarms = await db.select(db.alarms).get();
      expect(dbAlarms.first.color, equals('blue'));

      // 3. Update the medication color to red in the repository
      final updatedMed = med.copyWith(color: 'red');
      await medRepository.updateMedication('Ibuprofeno', updatedMed);

      // 4. Verify propagation to the database alarms table row
      dbAlarms = await db.select(db.alarms).get();
      expect(dbAlarms.first.color, equals('red'), reason: 'Color did not propagate to the alarms database table row');

      // 5. Verify that watchAllAlarms and getAllAlarms retrieve the updated color
      alarms = await alarmRepository.getAllAlarms();
      expect(alarms.first.color, equals('red'), reason: 'getAllAlarms did not retrieve the updated medication color');

      final streamAlarms = await alarmRepository.watchAllAlarms().first;
      expect(streamAlarms.first.color, equals('red'), reason: 'watchAllAlarms did not retrieve the updated medication color');
    });

    test('Alarms resolve color using Medication table join, and fall back to alarm color if deleted', () async {
      // 1. Create a medication 'Paracetamol' with color 'yellow'
      const med = Medication(
        name: 'Paracetamol',
        color: 'yellow',
        type: 'comprimido',
        dosage: '500mg',
        pendingSync: false,
      );
      await medRepository.createMedication(med);

      // 2. Create an alarm for 'Paracetamol' but explicitly set its stored color to 'white'
      final alarm = AlarmModel(
        id: 2,
        hour: 10,
        minute: 0,
        name: 'Paracetamol',
        medName: 'Paracetamol',
        enabled: true,
        active: true,
        days: List.filled(7, true),
        status: 'PENDENTE',
        color: 'white', // Stored color is white
        quantity: 1.0,
        daysQuantity: List.filled(7, 0.0),
        type: 'comprimido',
        snoozeMin: 0,
        durationDays: 0,
      );
      await alarmRepository.createAlarm(alarm);

      // 3. Verify that getAllAlarms resolves the color to 'yellow' (from Medication table)
      var alarms = await alarmRepository.getAllAlarms();
      expect(alarms.first.color, equals('yellow'), reason: 'Alarm color was not resolved from the Medications table');

      // Verify direct database row still stores 'white' (or is updated on creation? Wait, on wizard creation it updates color, but let's check)
      final dbAlarms = await db.select(db.alarms).get();
      expect(dbAlarms.first.color, equals('white'), reason: 'Underlying DB row color was not white');

      // 4. Delete the medication 'Paracetamol'
      await medRepository.deleteMedication('Paracetamol');

      // 5. Verify that getAllAlarms now falls back to the stored color 'white'
      alarms = await alarmRepository.getAllAlarms();
      expect(alarms.first.color, equals('white'), reason: 'Alarm did not fall back to its stored color after medication deletion');
    });
   group('Wizard State and Notifier Save Color Synchronization', () {
      test('Wizard saves alarm and medication with synchronized color', () async {
        // We will simulate saving an alarm in the wizard and verify that the medication is created with the same color
        // and that the alarm has that color.
        final container = ProviderContainer(
          overrides: [
            databaseProvider.overrideWithValue(db),
            medicationApiClientProvider.overrideWithValue(MockMedicationApiClient()),
            alarmApiClientProvider.overrideWithValue(MockAlarmApiClient()),
          ],
        );
        addTearDown(container.dispose);

        // Access repositories
        final alarmRepo = container.read(alarmRepositoryProvider);
        final medRepo = container.read(medicationRepositoryProvider);

        // We will use the wizard notifier
        final wizardNotifier = container.read(wizardNotifierProvider.notifier);

        // Fill in step 1 & 7 options
        wizardNotifier.updateState((s) => s.copyWith(
          name: 'Novalgina',
          type: 'comprimido',
          color: 'purple',
          step: 7,
          customTimes: ['08:00'],
        ));

        // Save
        await wizardNotifier.saveAlarm();

        // Verify medication created
        final med = await medRepo.getMedicationByName('Novalgina');
        expect(med, isNotNull);
        expect(med!.color, equals('purple'));

        // Verify alarm created and has color purple
        final alarms = await alarmRepo.getAllAlarms();
        expect(alarms.length, equals(1));
        expect(alarms.first.medName, equals('Novalgina'));
        expect(alarms.first.color, equals('purple'));
      });
    });
  });
}
