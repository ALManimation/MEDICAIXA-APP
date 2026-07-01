import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart';
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

// Mocking HttpOverrides to intercept Gemini API calls
class MockHttpHeaders implements HttpHeaders {
  final Map<String, List<String>> _headers = {};

  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {
    _headers.putIfAbsent(name, () => []).add(value.toString());
  }

  @override
  List<String>? operator [](String name) => _headers[name];

  @override
  set contentType(ContentType? value) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class MockHttpClientResponse implements HttpClientResponse {
  final String bodyString;
  @override
  final int statusCode;
  @override
  final HttpHeaders headers = MockHttpHeaders();

  MockHttpClientResponse({required this.bodyString, this.statusCode = 200});

  @override
  int get contentLength => bodyString.length;

  @override
  String get reasonPhrase => 'OK';

  @override
  bool get persistentConnection => true;

  @override
  bool get isRedirect => false;

  @override
  List<RedirectInfo> get redirects => const [];

  @override
  List<Cookie> get cookies => const [];

  @override
  X509Certificate? get certificate => null;

  @override
  HttpConnectionInfo? get connectionInfo => null;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    final stream = Stream.value(utf8.encode(bodyString));
    return stream.listen(onData, onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class MockHttpClientRequest implements HttpClientRequest {
  final Uri url;
  final Map<String, String> responses;
  final Function(String url, String body)? onRequest;
  final List<int> _bodyBytes = [];
  @override
  final HttpHeaders headers = MockHttpHeaders();

  MockHttpClientRequest({required this.url, required this.responses, this.onRequest});

  @override
  void add(List<int> data) {
    _bodyBytes.addAll(data);
  }

  @override
  void write(Object? object) {
    if (object != null) {
      _bodyBytes.addAll(utf8.encode(object.toString()));
    }
  }

  @override
  Future addStream(Stream<List<int>> stream) async {
    await for (final data in stream) {
      _bodyBytes.addAll(data);
    }
  }

  @override
  Future flush() => Future.value(null);

  @override
  Future<HttpClientResponse> get done => Future.value(MockHttpClientResponse(bodyString: ''));

  @override
  Future<HttpClientResponse> close() async {
    final bodyString = utf8.decode(_bodyBytes);
    if (onRequest != null) {
      onRequest!(url.toString(), bodyString);
    }

    var responseBody = '{}';
    const statusCode = 200;

    bool matched = false;
    for (final entry in responses.entries) {
      if (url.toString().contains(entry.key) || bodyString.contains(entry.key)) {
        responseBody = entry.value;
        matched = true;
        break;
      }
    }

    if (!matched && responses.containsKey('default')) {
      responseBody = responses['default']!;
    }

    return MockHttpClientResponse(bodyString: responseBody, statusCode: statusCode);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    return null;
  }
}

class MockHttpClient implements HttpClient {
  final Map<String, String> responses;
  final Function(String url, String body)? onRequest;

  MockHttpClient({required this.responses, this.onRequest});

  @override
  Future<HttpClientRequest> postUrl(Uri url) async {
    return MockHttpClientRequest(url: url, responses: responses, onRequest: onRequest);
  }

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    return MockHttpClientRequest(url: url, responses: responses, onRequest: onRequest);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class MockHttpOverrides extends HttpOverrides {
  final Map<String, String> responses;
  final Function(String url, String body)? onRequest;

  MockHttpOverrides({required this.responses, this.onRequest});

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return MockHttpClient(responses: responses, onRequest: onRequest);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late MockDioClient dioClient;
  late MockAlarmApiClient alarmApiClient;
  late ProviderContainer container;
  late SettingsRepository settingsRepo;
  late AlarmRepository alarmRepo;
  late HybridLlmService hybridService;
  late LocalLlmService localService;

  // Mock connectivity state helper
  List<String> mockConnectivityResults = ['wifi'];
  bool shouldConnectivityThrow = false;

  void mockConnectivity(List<String> results) {
    mockConnectivityResults = results;
  }

  setUpAll(() {
    const channel = MethodChannel('dev.fluttercommunity.plus/connectivity');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      if (shouldConnectivityThrow) {
        throw PlatformException(code: 'ERROR', message: 'Failed to check connectivity');
      }
      if (methodCall.method == 'check') {
        return mockConnectivityResults;
      }
      return null;
    });
  });

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
    localService = LocalLlmService();

    // Default connectivity: wifi (has internet)
    mockConnectivityResults = ['wifi'];
    shouldConnectivityThrow = false;
  });

  tearDown(() async {
    HttpOverrides.global = null;
    await db.close();
    container.dispose();
  });

  // Successful mock Gemini JSON structure
  const successGeminiJson = '''
  {
    "candidates": [
      {
        "content": {
          "parts": [
            {
              "text": "{\\"message\\": \\"Olá do Gemini Mock\\", \\"actions\\": []}"
            }
          ]
        }
      }
    ]
  }
  ''';

  group('Extremely long/short queries & Empty/weird characters', () {
    test('Empty and whitespace-only queries in LocalLlmService', () async {
      final responseEmpty = await localService.generateResponse('');
      expect(responseEmpty.provider, 'local');
      expect(responseEmpty.actions, isEmpty);
      expect(responseEmpty.message, contains('modo offline/local'));

      final responseSpaces = await localService.generateResponse('    \n\t   ');
      expect(responseSpaces.provider, 'local');
      expect(responseSpaces.actions, isEmpty);
    });

    test('Extremely long queries in LocalLlmService', () async {
      final longQuery = 'tomar ' * 1000 + ' alarme 3';
      final response = await localService.generateResponse(longQuery);
      // Even with massive input, it shouldn't crash and should process the regex properly
      expect(response.provider, 'local');
      expect(response.actions, hasLength(1));
      expect(response.actions[0].type, 'mark_taken');
      expect(response.actions[0].params['index'], 2);
    });

    test('Special / Weird characters in LocalLlmService', () async {
      // 1. A query with special characters that should match
      const queryMatch = '📝🤔 Tomar alarme 2!!! [remedio] 💉';
      final responseMatch = await localService.generateResponse(queryMatch);
      expect(responseMatch.provider, 'local');
      expect(responseMatch.actions, hasLength(1));
      expect(responseMatch.actions[0].type, 'mark_taken');
      expect(responseMatch.actions[0].params['index'], 1);

      // 2. A query with totally random symbols that should fallback safely
      const queryFallback = r'@@@ ### $$$ %%% ^^^';
      final responseFallback = await localService.generateResponse(queryFallback);
      expect(responseFallback.provider, 'local');
      expect(responseFallback.actions, isEmpty);
      expect(responseFallback.message, contains('modo offline/local'));
    });
  });

  group('Sudden internet connection drop/recovery simulations', () {
    test('Switches between Gemini and Local on connection drop/recovery', () async {
      // 1. Configure a valid-looking API key so Hybrid service doesn't immediately fallback
      final settings = await settingsRepo.getSettings();
      await settingsRepo.updateSettings(settings.copyWith(
        geminiApiKey: const Value('mock-api-key'),
        patientName: 'João',
      ));

      // Mock Http to return success
      HttpOverrides.global = MockHttpOverrides(
        responses: {'generativelanguage': successGeminiJson},
      );

      // 2. Setup connection: active wifi
      mockConnectivity(['wifi']);

      final response1 = await hybridService.generateResponse('Oi');
      expect(response1.provider, 'gemini');
      expect(response1.message, 'Olá do Gemini Mock');

      // 3. Suddenly simulate internet drop (no connection)
      mockConnectivity(['none']);

      final response2 = await hybridService.generateResponse('Oi');
      expect(response2.provider, 'local');
      expect(response2.message, startsWith('[Modo Offline]'));

      // 4. Simulate recovery (back to wifi)
      mockConnectivity(['wifi']);

      final response3 = await hybridService.generateResponse('Oi');
      expect(response3.provider, 'gemini');
      expect(response3.message, 'Olá do Gemini Mock');
    });

    test('Falls back to Local when connectivity check throws exception', () async {
      final settings = await settingsRepo.getSettings();
      await settingsRepo.updateSettings(settings.copyWith(
        geminiApiKey: const Value('mock-api-key'),
        patientName: 'João',
      ));

      // Connectivity call will crash/throw
      shouldConnectivityThrow = true;

      final response = await hybridService.generateResponse('Oi');
      expect(response.provider, 'local');
      expect(response.message, contains('modo offline/local'));
    });
  });

  group('Multiple sequential and concurrent requests (concurrency test)', () {
    test('Simultaneous calls do not corrupt state or block', () async {
      final settings = await settingsRepo.getSettings();
      await settingsRepo.updateSettings(settings.copyWith(
        geminiApiKey: const Value('mock-api-key'),
        patientName: 'João',
      ));

      HttpOverrides.global = MockHttpOverrides(
        responses: {'generativelanguage': successGeminiJson},
      );

      mockConnectivity(['wifi']);

      // Perform multiple calls concurrently
      final futures = List.generate(
        10,
        (i) => hybridService.generateResponse('Mensagem concorrente $i'),
      );

      final results = await Future.wait(futures);
      for (final result in results) {
        expect(result.provider, 'gemini');
        expect(result.message, 'Olá do Gemini Mock');
      }
    });
  });

  group('Invalid configurations or API key values & Invalid Gemini responses', () {
    test('Fallback to local when API key is empty/null', () async {
      final settings = await settingsRepo.getSettings();
      await settingsRepo.updateSettings(settings.copyWith(
        geminiApiKey: const Value(''),
        patientName: 'João',
      ));

      final response = await hybridService.generateResponse('Oi');
      expect(response.provider, 'local');
      expect(response.message, contains('modo offline/local'));
    });

    test('Fallback to local when Gemini API returns error or invalid key', () async {
      final settings = await settingsRepo.getSettings();
      await settingsRepo.updateSettings(settings.copyWith(
        geminiApiKey: const Value('invalid-key'),
        patientName: 'João',
      ));

      // Mock Http to return HTTP 400 Bad Request
      HttpOverrides.global = MockHttpOverrides(
        responses: {'generativelanguage': '{"error": {"message": "API key not valid"}}'},
      );

      final response = await hybridService.generateResponse('Oi');
      expect(response.provider, 'local');
      expect(response.message, startsWith('[Erro no Gemini - Executando Localmente]'));
    });

    test('Gemini returns malformed JSON - should gracefully parse raw text', () async {
      final settings = await settingsRepo.getSettings();
      await settingsRepo.updateSettings(settings.copyWith(
        geminiApiKey: const Value('mock-api-key'),
        patientName: 'João',
      ));

      // Return plain non-JSON text from Gemini
      const rawTextResponse = '''
      {
        "candidates": [
          {
            "content": {
              "parts": [
                {
                  "text": "Claro, vou te ajudar com isso, mas o formato JSON quebrou!"
                }
              ]
            }
          }
        ]
      }
      ''';

      HttpOverrides.global = MockHttpOverrides(
        responses: {'generativelanguage': rawTextResponse},
      );

      final response = await hybridService.generateResponse('Oi');
      // Provider is gemini, but actions should be empty, and message contains raw response
      expect(response.provider, 'gemini');
      expect(response.actions, isEmpty);
      expect(response.message, contains('JSON quebrou'));
    });
  });
}
