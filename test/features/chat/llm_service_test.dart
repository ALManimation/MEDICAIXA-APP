import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/native.dart';
import 'package:medicaixa_app/core/database/database.dart';
import 'package:medicaixa_app/core/network/dio_client.dart';
import 'package:medicaixa_app/core/providers/core_providers.dart';
import 'package:medicaixa_app/features/chat/data/services/local_llm_service.dart';
import 'package:medicaixa_app/features/chat/data/services/hybrid_llm_service.dart';
import 'package:medicaixa_app/features/settings/data/settings_repository.dart';
import 'package:medicaixa_app/features/alarms/data/alarm_repository.dart';
import 'package:medicaixa_app/features/alarms/data/alarm_api_client.dart';

class MockDioClient implements DioClient {
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
  group('LocalLlmService Tests', () {
    final localService = LocalLlmService();

    test('Recognizes "take" commands', () async {
      final response = await localService.generateResponse('tomar alarme 2');
      expect(response.provider, 'local');
      expect(response.actions, hasLength(1));
      expect(response.actions[0].type, 'mark_taken');
      expect(response.actions[0].params['index'], 1);
    });

    test('Recognizes "snooze" commands', () async {
      final response = await localService.generateResponse('adiar alarme 1 por 15 minutos');
      expect(response.provider, 'local');
      expect(response.actions, hasLength(1));
      expect(response.actions[0].type, 'snooze_alarm');
      expect(response.actions[0].params['index'], 0);
      expect(response.actions[0].params['minutes'], 15);
    });

    test('Recognizes "dismiss" commands', () async {
      final response = await localService.generateResponse('cancelar alarme 3');
      expect(response.provider, 'local');
      expect(response.actions, hasLength(1));
      expect(response.actions[0].type, 'toggle_alarm');
      expect(response.actions[0].params['index'], 2);
    });

    test('Recognizes "create alarm" commands', () async {
      final response = await localService.generateResponse('criar novo alarme as 10:30');
      expect(response.provider, 'local');
      expect(response.actions, hasLength(1));
      expect(response.actions[0].type, 'add_alarm');
      expect(response.actions[0].params['hour'], 10);
      expect(response.actions[0].params['minute'], 30);
    });

    test('Recognizes "list alarms" commands', () async {
      final response = await localService.generateResponse('listar meus remedios');
      expect(response.provider, 'local');
      expect(response.actions, hasLength(1));
      expect(response.actions[0].type, 'list_alarms');
    });

    test('Recognizes accented commands (Portuguese accents normalized)', () async {
      final response = await localService.generateResponse('listar meus remédios');
      expect(response.provider, 'local');
      expect(response.actions, hasLength(1));
      expect(response.actions[0].type, 'list_alarms');
    });

    test('Defaults on normal chat conversational text', () async {
      final response = await localService.generateResponse('Olá, tudo bem?');
      expect(response.provider, 'local');
      expect(response.actions, isEmpty);
      expect(response.message, contains('modo offline/local'));
    });
  });

  group('HybridLlmService Fallback Tests', () {
    late AppDatabase db;
    late MockDioClient dioClient;
    late MockAlarmApiClient alarmApiClient;
    late ProviderContainer container;
    late SettingsRepository settingsRepo;
    late AlarmRepository alarmRepo;
    late HybridLlmService hybridService;

    setUp(() async {
      db = AppDatabase.connect(NativeDatabase.memory());
      dioClient = MockDioClient();
      alarmApiClient = MockAlarmApiClient();
      
      container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          dioClientProvider.overrideWithValue(dioClient),
          alarmApiClientProvider.overrideWithValue(alarmApiClient),
        ],
      );
      
      settingsRepo = SettingsRepository(db, dioClient, FakeRef(container));
      alarmRepo = AlarmRepository(db, alarmApiClient, FakeRef(container));
      
      container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          dioClientProvider.overrideWithValue(dioClient),
          alarmApiClientProvider.overrideWithValue(alarmApiClient),
          settingsRepositoryProvider.overrideWithValue(settingsRepo),
          alarmRepositoryProvider.overrideWithValue(alarmRepo),
        ],
      );
      
      hybridService = HybridLlmService(FakeRef(container));
    });

    tearDown(() async {
      await db.close();
      container.dispose();
    });

    test('Falls back to LocalLlmService when Gemini API key is missing', () async {
      final response = await hybridService.generateResponse('tomar alarme 1');
      expect(response.provider, 'local');
      expect(response.actions, hasLength(1));
      expect(response.actions[0].type, 'mark_taken');
      expect(response.actions[0].params['index'], 0);
    });
  });
}
