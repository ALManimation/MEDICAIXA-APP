import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medicaixa_app/core/constants/app_colors.dart';
import 'package:medicaixa_app/core/localization/app_localizations.dart';
import 'package:medicaixa_app/core/providers/locale_provider.dart';
import 'package:medicaixa_app/core/providers/theme_provider.dart';
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

class FakeThemeNotifier extends AppThemeNotifier {
  final ThemeMode _fakeState = ThemeMode.dark;

  @override
  ThemeMode build() {
    return _fakeState;
  }

  @override
  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    AppColors.setTheme(mode == ThemeMode.dark);
  }
}

class FakeLocaleNotifier extends AppLocale {
  final String _fakeState = 'pt';

  @override
  String build() {
    return _fakeState;
  }

  @override
  Future<void> changeLocale(String languageCode) async {
    state = languageCode;
  }
}

void main() {
  late MockLlmService mockLlmService;
  late MockVoiceService mockVoiceService;
  late MockActionExecutor mockActionExecutor;
  late FakeThemeNotifier fakeThemeNotifier;
  late FakeLocaleNotifier fakeLocaleNotifier;

  setUp(() {
    mockLlmService = MockLlmService();
    mockVoiceService = MockVoiceService();
    mockActionExecutor = MockActionExecutor();
    fakeThemeNotifier = FakeThemeNotifier();
    fakeLocaleNotifier = FakeLocaleNotifier();

    // Ensure localization is loaded with PT as default before each test
    final file = File('assets/lang/pt.json');
    if (file.existsSync()) {
      AppLocalizations.loadTestStrings(file.readAsStringSync());
    }
  });

  Widget createTestWidget({required WidgetRefConsumer builder}) {
    return ProviderScope(
      overrides: [
        hybridLlmServiceProvider.overrideWithValue(mockLlmService),
        voiceServiceProvider.overrideWithValue(mockVoiceService),
        actionExecutorProvider.overrideWithValue(mockActionExecutor),
        appThemeNotifierProvider.overrideWith(() => fakeThemeNotifier),
        appLocaleProvider.overrideWith(() => fakeLocaleNotifier),
      ],
      child: Consumer(
        builder: (context, ref, _) {
          final locale = ref.watch(appLocaleProvider);
          final themeMode = ref.watch(appThemeNotifierProvider);
          return MaterialApp(
            themeMode: themeMode,
            locale: Locale(locale),
            home: Scaffold(
              body: Builder(
                builder: (innerContext) {
                  return Consumer(
                    builder: (context, ref, _) => builder(innerContext, ref),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  testWidgets('rapidly opens and closes sheet while listening, verifying cleanup is safe', (WidgetTester tester) async {
    await tester.pumpWidget(createTestWidget(
      builder: (context, ref) => ElevatedButton(
        onPressed: () => VoiceAssistantSheet.show(context),
        child: const Text('Abrir Assistente'),
      ),
    ));

    // Open sheet
    await tester.tap(find.text('Abrir Assistente'));
    await tester.pumpAndSettle();

    // Tap mic button to start listening
    await tester.tap(find.byKey(const ValueKey('voice_mic_button')));
    await tester.pump();

    expect(mockVoiceService.isListening, isTrue);

    // Close the sheet immediately via close button
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    // Verify cleanup was invoked on the service
    expect(mockVoiceService.stopListeningCallCount, equals(1));
    expect(mockVoiceService.stopSpeakingCallCount, equals(1));

    // Open the sheet again to verify it is clean and functional
    await tester.tap(find.text('Abrir Assistente'));
    await tester.pumpAndSettle();
    expect(find.text('Assistente MediCaixa'), findsOneWidget);

    // Close again
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
  });

  testWidgets('rapidly opens and closes sheet in a loop without delay to ensure safety', (WidgetTester tester) async {
    await tester.pumpWidget(createTestWidget(
      builder: (context, ref) => ElevatedButton(
        onPressed: () => VoiceAssistantSheet.show(context),
        child: const Text('Abrir Assistente'),
      ),
    ));

    for (int i = 0; i < 5; i++) {
      // Tap to open
      await tester.tap(find.text('Abrir Assistente'));
      await tester.pump();

      // Immediately pop the navigator to close the sheet
      final BuildContext context = tester.element(find.byType(ElevatedButton));
      Navigator.pop(context);
      await tester.pump();
    }

    await tester.pumpAndSettle();
    expect(find.text('Assistente MediCaixa'), findsNothing);
  });

  testWidgets('handles long text inputs without UI overflow and scrolls to bottom', (WidgetTester tester) async {
    // Set a viewport size that represents a portrait device but prevents artificial overflows
    tester.view.physicalSize = const Size(500, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    mockLlmService.mockResponse = LlmResponse(
      message: 'Esta é uma resposta da assistente com conteúdo extremamente longo para testar se a bolha do chat consegue quebrar o texto corretamente e rolar a tela sem provocar nenhum aviso de estouro de layout (overflow) na tela do dispositivo. ' * 5,
      actions: [],
      provider: 'local',
    );

    await tester.pumpWidget(createTestWidget(
      builder: (context, ref) => ElevatedButton(
        onPressed: () => VoiceAssistantSheet.show(context),
        child: const Text('Abrir Assistente'),
      ),
    ));

    // Open sheet
    await tester.tap(find.text('Abrir Assistente'));
    await tester.pumpAndSettle();

    // Input very long text
    final longInput = 'Este é um input de teste do usuário com uma mensagem muito grande repetida várias vezes. ' * 10;
    final textField = find.byKey(const ValueKey('chat_text_field'));
    await tester.enterText(textField, longInput);
    await tester.pump();

    // Send the message
    await tester.tap(find.byKey(const ValueKey('chat_send_button')));
    await tester.pump(); // Start LLM processing

    // Verify user message is present in tree before lazy-loading pushes it offstage
    // Trim the text because _submitText() trims input before rendering
    expect(find.text(longInput.trim()), findsOneWidget);

    await tester.pumpAndSettle(); // Finish processing

    // Verify response is present
    expect(find.text(mockLlmService.mockResponse!.message), findsOneWidget);

    // Verify ScrollController has clients and has scrolled downwards from the top (offset > 0)
    final ListView messageList = tester.widget(find.byType(ListView));
    final ScrollController? scrollController = messageList.controller;
    expect(scrollController, isNotNull);
    if (scrollController != null) {
      expect(scrollController.hasClients, isTrue);
      expect(scrollController.offset, greaterThan(0));

      // Force scroll to absolute bottom to verify layout survives without overflow
      scrollController.jumpTo(scrollController.position.maxScrollExtent);
      await tester.pumpAndSettle();
    }
  });

  testWidgets('submitting empty text or spaces is ignored gracefully', (WidgetTester tester) async {
    await tester.pumpWidget(createTestWidget(
      builder: (context, ref) => ElevatedButton(
        onPressed: () => VoiceAssistantSheet.show(context),
        child: const Text('Abrir Assistente'),
      ),
    ));

    // Open sheet
    await tester.tap(find.text('Abrir Assistente'));
    await tester.pumpAndSettle();

    final textField = find.byKey(const ValueKey('chat_text_field'));

    // Submit completely empty text
    await tester.enterText(textField, '');
    await tester.tap(find.byKey(const ValueKey('chat_send_button')));
    await tester.pumpAndSettle();

    expect(mockLlmService.lastPrompt, isNull);

    // Submit text containing only spaces
    await tester.enterText(textField, '     ');
    await tester.tap(find.byKey(const ValueKey('chat_send_button')));
    await tester.pumpAndSettle();

    expect(mockLlmService.lastPrompt, isNull);
  });

  testWidgets('toggles theme and locale while sheet is open without crashes and updates colors/translations', (WidgetTester tester) async {
    await tester.pumpWidget(createTestWidget(
      builder: (context, ref) => ElevatedButton(
        onPressed: () => VoiceAssistantSheet.show(context),
        child: const Text('Abrir Assistente'),
      ),
    ));

    // Open sheet
    await tester.tap(find.text('Abrir Assistente'));
    await tester.pumpAndSettle();

    // Verify initial layout color is dark mode surface color (0xFF1F2937)
    expect(AppColors.surface, equals(const Color(0xFF1F2937)));

    // Verify initial placeholder is in Portuguese
    final textFormField = tester.widget<TextField>(find.byKey(const ValueKey('chat_text_field')));
    expect(textFormField.decoration?.hintText, equals('Digite uma mensagem...'));

    final container = ProviderScope.containerOf(tester.element(find.byType(VoiceAssistantSheet)));

    // 1. Toggle Theme to Light Mode
    await container.read(appThemeNotifierProvider.notifier).setThemeMode(ThemeMode.light);
    await tester.pumpAndSettle();

    // Verify static colors are updated to light mode colors (surface 0xFFFFFFFF)
    expect(AppColors.surface, equals(const Color(0xFFFFFFFF)));

    // 2. Toggle Locale to English
    final enFile = File('assets/lang/en.json');
    if (enFile.existsSync()) {
      AppLocalizations.loadTestStrings(enFile.readAsStringSync());
    }
    await container.read(appLocaleProvider.notifier).changeLocale('en');
    await tester.pumpAndSettle();

    // Verify translation helper returns English string
    expect(AppLocalizations.translate('chat_placeholder'), equals('Type a message...'));

    // 3. Close the sheet and reopen it to ensure theme and translation changes are correctly applied
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    // Open sheet again
    await tester.tap(find.text('Abrir Assistente'));
    await tester.pumpAndSettle();

    // Verify background color is updated to Light Mode color
    final sheetContainer = tester.widget<Container>(find.byType(Container).first);
    final boxDecoration = sheetContainer.decoration as BoxDecoration?;
    expect(boxDecoration?.color, equals(const Color(0xFFFFFFFF)));

    // Verify placeholder text is now English
    final textFormFieldEn = tester.widget<TextField>(find.byKey(const ValueKey('chat_text_field')));
    expect(textFormFieldEn.decoration?.hintText, equals('Type a message...'));

    // 4. Toggle back to Portuguese & Dark Mode
    await container.read(appThemeNotifierProvider.notifier).setThemeMode(ThemeMode.dark);
    final ptFile = File('assets/lang/pt.json');
    if (ptFile.existsSync()) {
      AppLocalizations.loadTestStrings(ptFile.readAsStringSync());
    }
    await container.read(appLocaleProvider.notifier).changeLocale('pt');
    await tester.pumpAndSettle();

    // Close and reopen again to verify reverting changes
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    // Reopen
    await tester.tap(find.text('Abrir Assistente'));
    await tester.pumpAndSettle();

    // Verify reverted to Portuguese and Dark Mode
    final textFormFieldPt = tester.widget<TextField>(find.byKey(const ValueKey('chat_text_field')));
    expect(textFormFieldPt.decoration?.hintText, equals('Digite uma mensagem...'));
    final sheetContainerDark = tester.widget<Container>(find.byType(Container).first);
    final boxDecorationDark = sheetContainerDark.decoration as BoxDecoration?;
    expect(boxDecorationDark?.color, equals(const Color(0xFF1F2937)));
  });
}

typedef WidgetRefConsumer = Widget Function(BuildContext context, WidgetRef ref);
