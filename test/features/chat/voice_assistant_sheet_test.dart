import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medicaixa_app/features/chat/domain/services/llm_service.dart';
import 'package:medicaixa_app/features/chat/data/services/voice_service.dart';
import 'package:medicaixa_app/features/chat/domain/services/action_executor.dart';
import 'package:medicaixa_app/features/chat/data/services/llm_providers.dart';
import 'package:medicaixa_app/features/chat/data/services/voice_providers.dart';
import 'package:medicaixa_app/features/chat/presentation/widgets/voice_assistant_sheet.dart';

class MockLlmService implements LlmService {
  LlmResponse? mockResponse;
  bool shouldThrow = false;
  String? lastPrompt;
  List<Map<String, dynamic>>? lastHistory;

  @override
  Future<LlmResponse> generateResponse(
    String message, {
    List<Map<String, dynamic>>? history,
    Map<String, dynamic>? systemContext,
  }) async {
    lastPrompt = message;
    lastHistory = history;
    await Future.delayed(const Duration(milliseconds: 50));
    if (shouldThrow) {
      throw Exception('Mock LLM error');
    }
    return mockResponse ?? LlmResponse(
      message: 'Olá, sou a assistente. Entendido.',
      actions: [],
      provider: 'local',
    );
  }
}

class MockVoiceService implements VoiceService {
  bool isListeningValue = false;
  String? lastSpokenText;
  String? lastFeedbackTone;
  Function(String text)? onResultCallback;
  Function(bool isListening)? onListeningStatusChangedCallback;
  int stopListeningCallCount = 0;
  int stopSpeakingCallCount = 0;

  @override
  bool get isListening => isListeningValue;

  @override
  Future<bool> initializeSTT() async => true;

  @override
  Future<void> startListening({
    required Function(String text) onResult,
    required Function(bool isListening) onListeningStatusChanged,
  }) async {
    isListeningValue = true;
    onResultCallback = onResult;
    onListeningStatusChangedCallback = onListeningStatusChanged;
    onListeningStatusChanged(true);
  }

  @override
  Future<void> stopListening() async {
    stopListeningCallCount++;
    isListeningValue = false;
  }

  @override
  Future<void> speak(String text) async {
    lastSpokenText = text;
  }

  @override
  Future<void> stopSpeaking() async {
    stopSpeakingCallCount++;
    lastSpokenText = null;
  }

  @override
  Future<void> playFeedbackTone(String type) async {
    lastFeedbackTone = type;
  }

  @override
  Future<void> setLocale(String locale) async {}

  @override
  Future<void> setRate(double rate) async {}

  @override
  Future<void> setPitch(double pitch) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class MockActionExecutor implements ActionExecutor {
  List<LlmAction>? lastExecutedActions;

  @override
  Future<void> execute(List<LlmAction> actions) async {
    lastExecutedActions = actions;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  late MockLlmService mockLlmService;
  late MockVoiceService mockVoiceService;
  late MockActionExecutor mockActionExecutor;

  setUp(() {
    mockLlmService = MockLlmService();
    mockVoiceService = MockVoiceService();
    mockActionExecutor = MockActionExecutor();
  });

  Widget createTestWidget() {
    return ProviderScope(
      overrides: [
        hybridLlmServiceProvider.overrideWithValue(mockLlmService),
        voiceServiceProvider.overrideWithValue(mockVoiceService),
        actionExecutorProvider.overrideWithValue(mockActionExecutor),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => VoiceAssistantSheet.show(context),
              child: const Text('Abrir Assistente'),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('renders all initial UI elements correctly', (WidgetTester tester) async {
    await tester.pumpWidget(createTestWidget());

    // Open sheet
    await tester.tap(find.text('Abrir Assistente'));
    await tester.pumpAndSettle();

    // Verify title and close button
    expect(find.text('Assistente MediCaixa'), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);

    // Verify welcome message is visible
    expect(
      find.text('Olá! Sou sua assistente. Como posso ajudar com seus medicamentos hoje?'),
      findsOneWidget,
    );

    // Verify text field and buttons
    expect(find.byKey(const ValueKey('chat_text_field')), findsOneWidget);
    expect(find.byKey(const ValueKey('chat_send_button')), findsOneWidget);
    expect(find.byKey(const ValueKey('voice_mic_button')), findsOneWidget);
  });

  testWidgets('handles text submit flow correctly', (WidgetTester tester) async {
    mockLlmService.mockResponse = LlmResponse(
      message: 'Novo alarme criado com sucesso.',
      actions: [LlmAction(type: 'add_alarm', params: {'hour': 8})],
      provider: 'local',
    );

    await tester.pumpWidget(createTestWidget());
    await tester.tap(find.text('Abrir Assistente'));
    await tester.pumpAndSettle();

    // Enter query in text field
    final textField = find.byKey(const ValueKey('chat_text_field'));
    await tester.enterText(textField, 'criar alarme as 8h');
    await tester.pump();

    // Tap Send
    await tester.tap(find.byKey(const ValueKey('chat_send_button')));
    
    // During thinking: should show "Pensando..."
    await tester.pump();
    expect(find.text('Pensando...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Finish processing
    await tester.pumpAndSettle();

    // Verify chat display user message and model response
    expect(find.text('criar alarme as 8h'), findsOneWidget);
    expect(find.text('Novo alarme criado com sucesso.'), findsOneWidget);

    // Verify Actions Executor and Voice TTS were invoked
    expect(mockActionExecutor.lastExecutedActions, isNotNull);
    expect(mockActionExecutor.lastExecutedActions!.first.type, equals('add_alarm'));
    expect(mockVoiceService.lastSpokenText, equals('Novo alarme criado com sucesso.'));
    expect(mockVoiceService.lastFeedbackTone, equals('success'));
  });

  testWidgets('handles voice listening state and transcription flow correctly', (WidgetTester tester) async {
    mockLlmService.mockResponse = LlmResponse(
      message: 'Alarme adiado.',
      actions: [],
      provider: 'local',
    );

    await tester.pumpWidget(createTestWidget());
    await tester.tap(find.text('Abrir Assistente'));
    await tester.pumpAndSettle();

    // Verify wave indicator is NOT showing initially
    expect(find.byType(PulsingWaveIndicator), findsNothing);

    // Tap mic button to start listening
    await tester.tap(find.byKey(const ValueKey('voice_mic_button')));
    await tester.pump();

    // Verify listening state (wave indicator & Ouvindo text)
    expect(find.byType(PulsingWaveIndicator), findsOneWidget);
    expect(find.text('Ouvindo...'), findsOneWidget);
    expect(mockVoiceService.isListening, isTrue);

    // Simulate transcription text during speech
    mockVoiceService.onResultCallback!('adiar alarme');
    await tester.pump();
    expect(find.text('adiar alarme'), findsOneWidget);

    // Tap mic button again to stop listening and trigger LLM processing
    await tester.tap(find.byKey(const ValueKey('voice_mic_button')));
    await tester.pump();

    // Finish processing
    await tester.pumpAndSettle();

    // Verify processing completed
    expect(find.text('adiar alarme'), findsOneWidget);
    expect(find.text('Alarme adiado.'), findsOneWidget);
    expect(mockVoiceService.lastSpokenText, equals('Alarme adiado.'));
  });

  testWidgets('ensures proper cleanup when sheet is closed', (WidgetTester tester) async {
    await tester.pumpWidget(createTestWidget());
    await tester.tap(find.text('Abrir Assistente'));
    await tester.pumpAndSettle();

    // Start listening to have an active session
    await tester.tap(find.byKey(const ValueKey('voice_mic_button')));
    await tester.pump();

    expect(mockVoiceService.stopListeningCallCount, equals(0));
    expect(mockVoiceService.stopSpeakingCallCount, equals(0));

    // Close the sheet via close button
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    // Verify cleanup was invoked
    expect(mockVoiceService.stopListeningCallCount, equals(1));
    expect(mockVoiceService.stopSpeakingCallCount, equals(1));
  });
}
