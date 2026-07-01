import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/native.dart';
import 'package:medicaixa_app/core/database/database.dart';
import 'package:medicaixa_app/features/medications/data/medication_repository.dart';
import 'package:medicaixa_app/features/medications/data/medication_api_client.dart';
import 'package:medicaixa_app/features/alarms/data/alarm_repository.dart';
import 'package:medicaixa_app/features/alarms/data/alarm_api_client.dart';
import 'package:medicaixa_app/features/alarms/data/alarm_model.dart';
import 'package:medicaixa_app/features/alarms/data/medication_search_service.dart';
import 'package:medicaixa_app/features/reminders/data/reminder_model.dart';
import 'package:medicaixa_app/core/providers/core_providers.dart';
import 'package:medicaixa_app/core/providers/connection_providers.dart';
import 'package:medicaixa_app/features/pairing/domain/connection_state.dart';

class MockMedicationApiClient implements MedicationApiClient {
  @override
  Future<List<Medication>> fetchMedications() => Future.value(<Medication>[]);
  @override
  Future<void> addMedication(Medication med) async {}
  @override
  Future<void> updateMedication(String oldName, Medication med) async {}
  @override
  Future<void> removeMedication(String name) async {}
}

class MockAlarmApiClient implements AlarmApiClient {
  @override
  Future<int> addAlarm(AlarmModel alarm) async => alarm.id;
  @override
  Future<void> updateAlarm(AlarmModel alarm) async {}
  @override
  Future<void> removeAlarm(int id) async {}
  @override
  Future<List<AlarmModel>> fetchAlarms() async => [];
  @override
  Future<void> toggleAlarm(int id, bool enabled) async {}
  @override
  Future<void> markTaken(int id, {double? qty}) async {}
  @override
  Future<void> markSkipped(int id) async {}
  @override
  Future<void> takePrn(int id) async {}
  @override
  Future<void> pauseAlarm(int id, int pauseUntilEpoch) async {}
  @override
  Future<void> snoozeAlarm(int id, int minutes) async {}
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
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Milestone 2 Challenger Tests', () {
    late AppDatabase db;
    late ProviderContainer container;
    late MedicationRepository medRepository;
    late AlarmRepository alarmRepository;
    late MedicationSearchService searchService;

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
      searchService = MedicationSearchService();
    });

    tearDown(() async {
      try {
        await db.close();
      } catch (_) {}
      container.dispose();
    });

    group('1. Medication Deletion Check (Rule 35 Edge Cases)', () {
      setUp(() async {
        // Create baseline medication
        const med = Medication(
          name: 'Ibuprofeno',
          color: 'blue',
          type: 'comprimido',
          dosage: '400mg',
          pendingSync: false,
        );
        await medRepository.createMedication(med);
      });

      test('Should block deletion if used by an enabled but inactive alarm', () async {
        final alarm = AlarmModel(
          id: 1,
          hour: 8,
          minute: 0,
          name: 'Ibuprofeno',
          medName: 'Ibuprofeno',
          enabled: true,
          active: false,
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

        await expectLater(
          medRepository.deleteMedication('Ibuprofeno'),
          throwsA(isA<Exception>()),
        );

        final list = await medRepository.getAllMedications();
        expect(list.any((m) => m.name == 'Ibuprofeno'), isTrue);
      });

      test('Should block deletion if used by a disabled but active alarm', () async {
        final alarm = AlarmModel(
          id: 2,
          hour: 8,
          minute: 0,
          name: 'Ibuprofeno',
          medName: 'Ibuprofeno',
          enabled: false,
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

        await expectLater(
          medRepository.deleteMedication('Ibuprofeno'),
          throwsA(isA<Exception>()),
        );

        final list = await medRepository.getAllMedications();
        expect(list.any((m) => m.name == 'Ibuprofeno'), isTrue);
      });

      test('Should allow deletion if used by an alarm that is both disabled AND inactive', () async {
        final alarm = AlarmModel(
          id: 3,
          hour: 8,
          minute: 0,
          name: 'Ibuprofeno',
          medName: 'Ibuprofeno',
          enabled: false,
          active: false,
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

        final alarmsBefore = await db.select(db.alarms).get();
        print('Alarms in DB before delete: ${alarmsBefore.map((a) => 'id=${a.id}, medName=${a.medName}, name=${a.name}, enabled=${a.enabled}, active=${a.active}')}');
        
        final medsBefore = await medRepository.getAllMedications();
        print('Meds in DB before delete: ${medsBefore.map((m) => m.name)}');

        // Deletion should succeed because the alarm is not active/enabled.
        await expectLater(
          medRepository.deleteMedication('Ibuprofeno'),
          completes,
        );

        final medsAfter = await medRepository.getAllMedications();
        print('Meds in DB after delete: ${medsAfter.map((m) => m.name)}');

        expect(medsAfter.any((m) => m.name == 'Ibuprofeno'), isFalse);
      });

      test('syncWithDevice: should retain medication if alarm is active/enabled', () async {
        container.read(deviceConnectionStateProvider.notifier).updateState(
          const ConnectionStateInfo(
            status: ConnectionStatus.connected,
            ip: '192.168.4.1',
          ),
        );

        final alarm = AlarmModel(
          id: 4,
          hour: 8,
          minute: 0,
          name: 'Ibuprofeno',
          medName: 'Ibuprofeno',
          enabled: true,
          active: false,
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

        await medRepository.syncWithDevice();

        final list = await medRepository.getAllMedications();
        expect(list.any((m) => m.name == 'Ibuprofeno'), isTrue);
      });

      test('syncWithDevice: should delete medication if all referencing alarms are disabled and inactive', () async {
        container.read(deviceConnectionStateProvider.notifier).updateState(
          const ConnectionStateInfo(
            status: ConnectionStatus.connected,
            ip: '192.168.4.1',
          ),
        );

        final alarm = AlarmModel(
          id: 5,
          hour: 8,
          minute: 0,
          name: 'Ibuprofeno',
          medName: 'Ibuprofeno',
          enabled: false,
          active: false,
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

        final medsBefore = await medRepository.getAllMedications();
        print('Meds in DB before sync: ${medsBefore.map((m) => m.name)}');

        await medRepository.syncWithDevice();

        final medsAfter = await medRepository.getAllMedications();
        print('Meds in DB after sync: ${medsAfter.map((m) => m.name)}');

        expect(medsAfter.any((m) => m.name == 'Ibuprofeno'), isFalse);
      });
    });

    group('2. copyWith Sentinel Pattern', () {
      test('Should retain original values when parameters are omitted', () {
        final original = AlarmModel(
          id: 42,
          hour: 8,
          minute: 30,
          name: 'Aspirina',
          medName: 'Aspirina',
          enabled: true,
          active: true,
          days: const [true, false, true, false, true, false, true],
          status: 'PENDENTE',
          color: 'red',
          quantity: 2.0,
          daysQuantity: const [0.0, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0],
          type: 'comprimido',
          dosage: '100mg',
          lastStatus: 'TOMADO',
          lastStatusDate: '01/07/2026',
          snoozeMin: 5,
          startDate: '2026-07-01',
          durationDays: 10,
          createdDate: '2026-06-30',
          cycleOnDays: 5,
          specialInstruction: 'Tomar com água',
        );

        final updated = original.copyWith();

        expect(updated.id, original.id);
        expect(updated.hour, original.hour);
        expect(updated.minute, original.minute);
        expect(updated.name, original.name);
        expect(updated.medName, original.medName);
        expect(updated.enabled, original.enabled);
        expect(updated.active, original.active);
        expect(updated.days, original.days);
        expect(updated.status, original.status);
        expect(updated.color, original.color);
        expect(updated.quantity, original.quantity);
        expect(updated.daysQuantity, original.daysQuantity);
        expect(updated.type, original.type);
        expect(updated.dosage, original.dosage);
        expect(updated.lastStatus, original.lastStatus);
        expect(updated.lastStatusDate, original.lastStatusDate);
        expect(updated.snoozeMin, original.snoozeMin);
        expect(updated.startDate, original.startDate);
        expect(updated.durationDays, original.durationDays);
        expect(updated.createdDate, original.createdDate);
        expect(updated.cycleOnDays, original.cycleOnDays);
        expect(updated.specialInstruction, original.specialInstruction);
      });

      test('copyWith Sentinel pattern inside AlarmModel successfully sets nullable fields to null', () {
        final original = AlarmModel(
          id: 42,
          hour: 8,
          minute: 30,
          name: 'Aspirina',
          medName: 'Aspirina',
          enabled: true,
          active: true,
          days: const [true, false, true, false, true, false, true],
          status: 'PENDENTE',
          color: 'red',
          quantity: 2.0,
          daysQuantity: const [0.0, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0],
          type: 'comprimido',
          dosage: '100mg',
          lastStatus: 'TOMADO',
          lastStatusDate: '01/07/2026',
          snoozeMin: 5,
          startDate: '2026-07-01',
          durationDays: 10,
          createdDate: '2026-06-30',
          cycleOnDays: 5,
          specialInstruction: 'Tomar com água',
        );

        final updated = original.copyWith(
          dosage: null,
          lastStatus: null,
          lastStatusDate: null,
          startDate: null,
          createdDate: null,
          cycleOnDays: null,
          specialInstruction: null,
        );

        // Verify nullable fields are indeed null
        expect(updated.dosage, isNull);
        expect(updated.lastStatus, isNull);
        expect(updated.lastStatusDate, isNull);
        expect(updated.startDate, isNull);
        expect(updated.createdDate, isNull);
        expect(updated.cycleOnDays, isNull);
        expect(updated.specialInstruction, isNull);

        // Verify non-nullable fields are retained
        expect(updated.id, original.id);
        expect(updated.hour, original.hour);
        expect(updated.minute, original.minute);
        expect(updated.name, original.name);
        expect(updated.medName, original.medName);
        expect(updated.enabled, original.enabled);
        expect(updated.active, original.active);
        expect(updated.days, original.days);
        expect(updated.status, original.status);
        expect(updated.color, original.color);
        expect(updated.quantity, original.quantity);
        expect(updated.daysQuantity, original.daysQuantity);
        expect(updated.type, original.type);
        expect(updated.snoozeMin, original.snoozeMin);
        expect(updated.durationDays, original.durationDays);
      });

      test('copyWith Sentinel pattern inside ReminderModel successfully sets nullable fields to null', () {
        final original = ReminderModel(
          id: 1,
          title: 'Title',
          description: 'Desc',
          enabled: true,
          hasTime: true,
          hour: 8,
          minute: 30,
          period: 'day',
          interval: 1,
          startDate: '2026-07-01',
          notifyDaysBefore: 1,
          lastCompletedDate: '01/07/2026',
          color: 'blue',
          lastModified: 1234567,
        );

        final updated = original.copyWith(
          hour: null,
          minute: null,
          lastCompletedDate: null,
          lastModified: null,
        );

        // Verify nullable fields are indeed null
        expect(updated.hour, isNull);
        expect(updated.minute, isNull);
        expect(updated.lastCompletedDate, isNull);
        expect(updated.lastModified, isNull);

        // Verify non-nullable fields are retained
        expect(updated.id, original.id);
        expect(updated.title, original.title);
        expect(updated.description, original.description);
        expect(updated.enabled, original.enabled);
        expect(updated.hasTime, original.hasTime);
        expect(updated.period, original.period);
        expect(updated.interval, original.interval);
        expect(updated.startDate, original.startDate);
        expect(updated.notifyDaysBefore, original.notifyDaysBefore);
        expect(updated.color, original.color);
      });

      test('Should update fields when explicit non-null values are passed', () {
        final original = AlarmModel(
          id: 42,
          hour: 8,
          minute: 30,
          name: 'Aspirina',
          medName: 'Aspirina',
          enabled: true,
          active: true,
          days: const [true, false, true, false, true, false, true],
          status: 'PENDENTE',
          color: 'red',
          quantity: 2.0,
          daysQuantity: const [0.0, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0],
          type: 'comprimido',
          snoozeMin: 5,
          durationDays: 10,
        );

        final updated = original.copyWith(
          hour: 12,
          minute: 0,
          enabled: false,
          color: 'blue',
          quantity: 1.5,
          dosage: '500mg',
        );

        expect(updated.hour, 12);
        expect(updated.minute, 0);
        expect(updated.enabled, false);
        expect(updated.color, 'blue');
        expect(updated.quantity, 1.5);
        expect(updated.dosage, '500mg');
        expect(updated.id, original.id);
        expect(updated.name, original.name);
      });
    });

    group('3. MedicationSearchService & Avoid Duplicate DB Loads', () {
      late int mockAssetLoadCount;

      setUp(() {
        mockAssetLoadCount = 0;

        // Mock the rootBundle asset channel to return a mock gzip list
        final list = [
          {'n': 'Aspirina', 't': 'comprimido', 'd': '100mg', 'g': 'ácido acetilsalicílico'},
          {'n': 'Paracetamol', 't': 'comprimido', 'd': '500mg', 'g': 'paracetamol'},
          {'n': 'Dipirona Sódica', 't': 'gota', 'd': '500mg/ml', 'g': 'dipirona'},
          {'n': 'Losartana Potássica', 't': 'comprimido', 'd': '50mg', 'g': 'losartana'},
        ];
        final jsonStr = json.encode(list);
        final jsonBytes = utf8.encode(jsonStr);
        final gzBytes = gzip.encode(jsonBytes);

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler(
          'flutter/assets',
          (ByteData? message) async {
            final String key = utf8.decode(message!.buffer.asUint8List());
            if (key == 'assets/medications_db.json.gz') {
              mockAssetLoadCount++;
              return ByteData.sublistView(Uint8List.fromList(gzBytes));
            }
            return null;
          },
        );
      });

      tearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler(
          'flutter/assets',
          null,
        );
      });

      test('Verify fuzzy search ignores accents, casing, and handles approximations', () async {
        // Query with casing and accents
        final results1 = await searchService.search('Aspirína');
        expect(results1.length, equals(1));
        expect(results1.first.name, equals('Aspirina'));

        // Query with lowercase and generic search
        final results2 = await searchService.search('dipirona');
        expect(results2.length, equals(1));
        expect(results2.first.name, equals('Dipirona Sódica'));

        // Fuzzy match: misspelling of Losartana (missing letters, levenshtein <= 2)
        final results3 = await searchService.search('losartna');
        expect(results3.length, equals(1));
        expect(results3.first.name, equals('Losartana Potássica'));
      });

      test('Verify DB is loaded only once on consecutive calls', () async {
        expect(mockAssetLoadCount, equals(0));

        // First call loads from mock asset
        await searchService.search('Aspirina');
        expect(mockAssetLoadCount, equals(1));

        // Second call should hit the cache and NOT load again
        await searchService.search('Paracetamol');
        expect(mockAssetLoadCount, equals(1));

        // Dosages lookup call should also hit the cache
        final dosages = await searchService.getDosagesForMedication('Dipirona Sódica');
        expect(dosages, contains('500mg/ml'));
        expect(mockAssetLoadCount, equals(1));
      });
    });
  });
}
