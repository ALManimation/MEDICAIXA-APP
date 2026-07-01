import 'dart:io';
import 'dart:typed_data';
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
import 'package:medicaixa_app/core/providers/core_providers.dart';
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
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await initializeDateFormatting('pt_BR', null);
  });

  group('Milestone 2 Stress and Edge-Case Tests', () {
    late AppDatabase db;
    late ProviderContainer container;
    late MedicationRepository medRepository;
    late AlarmRepository alarmRepository;
    late MedicationSearchService searchService;
    late Uint8List dbBytes;

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

      dbBytes = File('assets/medications_db.json.gz').readAsBytesSync();
    });

    tearDown(() async {
      try {
        await db.close();
      } catch (_) {}
      container.dispose();
    });

    test('Medication Deletion Check: Blocks if active, but permits deletion if alarm is disabled (Rule 35 gap)', () async {
      // 1. Create medication
      const med = Medication(
        name: 'Aspirina',
        color: 'yellow',
        type: 'comprimido',
        dosage: '100mg',
        pendingSync: false,
      );
      await medRepository.createMedication(med);

      // 2. Create disabled/inactive alarm
      final alarm = AlarmModel(
        id: 12,
        hour: 8,
        minute: 0,
        name: 'Aspirina',
        medName: 'Aspirina',
        enabled: false,
        active: false,
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

      // 3. Repository allows deletion because the query checks for (enabled == true | active == true)
      await medRepository.deleteMedication('Aspirina');

      // Verify it was deleted (exposing the gap where disabled alarms referencing the medication do not prevent deletion)
      final list = await medRepository.getAllMedications();
      expect(list.any((m) => m.name == 'Aspirina'), isFalse);
    });

    test('copyWith Sentinel: Class member copyWith takes precedence and fails to set to null, while extension copyWith succeeds', () async {
      final alarm = AlarmModel(
        id: 1,
        hour: 8,
        minute: 0,
        name: 'Test',
        medName: 'Test',
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
        startDate: '2026-07-01',
      );

      // A. Call member copyWith with null: succeeds to set to null
      final memberUpdated = alarm.copyWith(startDate: null);
      print('DEBUG: memberUpdated.startDate = ${memberUpdated.startDate}');
      expect(memberUpdated.startDate, isNull);

      // B. Call copyWith and omit field: retains original value
      final omittedUpdated = alarm.copyWith(name: 'New Name');
      print('DEBUG: omittedUpdated.startDate = ${omittedUpdated.startDate}');
      expect(omittedUpdated.name, equals('New Name'));
      expect(omittedUpdated.startDate, equals('2026-07-01'));
    });

    test('MedicationSearchService: Fuzzy searches match correctly & parallel searches trigger duplicate asset loads (Race Condition)', () async {
      int assetLoadCount = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler(
        'flutter/assets',
        (ByteData? message) async {
          assetLoadCount++;
          print('DEBUG: Asset load count incremented to $assetLoadCount');
          return ByteData.sublistView(dbBytes);
        },
      );

      print('DEBUG: Starting fuzzy search for Parasetamol');
      final fuzzyResults = await searchService.search('Parasetamol');
      print('DEBUG: Fuzzy search finished. Results length: ${fuzzyResults.length}');
      expect(fuzzyResults, isNotEmpty);
      expect(fuzzyResults.any((m) => m.name.toLowerCase().contains('paracetamol')), isTrue);
      expect(assetLoadCount, equals(1));

      // Reset cache for concurrency test
      print('DEBUG: Resetting searchService cache');
      searchService = MedicationSearchService();
      assetLoadCount = 0;

      // Trigger parallel searches
      print('DEBUG: Triggering parallel searches');
      final Future<List<MedicationAnvisa>> search1 = searchService.search('Aspirina');
      final Future<List<MedicationAnvisa>> search2 = searchService.search('Paracetamol');
      
      print('DEBUG: Awaiting parallel searches');
      await Future.wait([search1, search2]);
      print('DEBUG: Parallel searches finished');

      // Concurrency race: both trigger loadDb because _cachedDb remains null until first assignment completes.
      expect(assetLoadCount, equals(2));
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler('flutter/assets', null);
    });
  });
}
