import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/native.dart';
import 'package:intl/intl.dart';

import 'package:medicaixa_app/core/database/database.dart';
import 'package:medicaixa_app/core/network/dio_client.dart';
import 'package:medicaixa_app/core/providers/core_providers.dart';
import 'package:medicaixa_app/core/localization/app_localizations.dart';
import 'package:medicaixa_app/features/pairing/domain/connection_state.dart';
import 'package:medicaixa_app/features/pairing/presentation/pairing_notifier.dart';
import 'package:medicaixa_app/features/settings/presentation/settings_screen.dart';
import 'package:medicaixa_app/features/settings/data/settings_repository.dart';
import 'package:medicaixa_app/features/settings/data/wifi_repository.dart';

class MockDioClient implements DioClient {
  @override
  String? get baseUrl => 'http://192.168.4.1';
  @override
  bool get isConfigured => true;
  @override
  void setBaseUrl(String url) {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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

class FakePairingNotifier extends PairingNotifier {
  @override
  ConnectionStateInfo build() {
    return const ConnectionStateInfo.disconnected();
  }
}

void main() {
  group('AppLocalizations & Date Formatting Tests', () {
    test('loadTestStrings decodes and parses JSON structure correctly', () {
      const testJson = '''
      {
        "web": {
          "title": "MediCaixa Web App",
          "welcome_message": "Hello %s, welcome!",
          "unread_notifications": "You have %d new messages."
        },
        "lcd": {
          "status": "Online"
        }
      }
      ''';

      AppLocalizations.loadTestStrings(testJson);

      expect(t('title'), equals('MediCaixa Web App'));
      expect(t('status'), equals('Online'));
      expect(t('welcome_message', ['John']), equals('Hello John, welcome!'));
      expect(t('unread_notifications', [5]), equals('You have 5 new messages.'));
      expect(t('non_existent_key'), equals('non_existent_key'));
    });

    test('Locale-specific date formatting is correctly initialized and localized', () {
      final date = DateTime(2026, 6, 28); // Sunday

      // Portuguese
      expect(DateFormat('EEEE', 'pt').format(date).toLowerCase(), contains('domingo'));
      // English
      expect(DateFormat('EEEE', 'en').format(date).toLowerCase(), contains('sunday'));
      // Spanish
      expect(DateFormat('EEEE', 'es').format(date).toLowerCase(), contains('domingo'));
    });
  });

  group('Widget Language Switching Integration Tests', () {
    late AppDatabase db;
    late MockDioClient dioClient;
    late String ptContent;
    late String enContent;
    late String esContent;

    setUpAll(() async {
      ptContent = File('assets/lang/pt.json').readAsStringSync();
      enContent = File('assets/lang/en.json').readAsStringSync();
      esContent = File('assets/lang/es.json').readAsStringSync();
    });

    setUp(() async {
      db = AppDatabase.connect(NativeDatabase.memory());
      dioClient = MockDioClient();

      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          dioClientProvider.overrideWithValue(dioClient),
        ],
      );
      final settingsRepo = SettingsRepository(db, dioClient, FakeRef(container));
      await settingsRepo.getSettings(); // Seed default settings row in db

      // Mock Asset Bundle to load translations dynamically during widget testing
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler(
        'flutter/assets',
        (ByteData? message) async {
          final key = utf8.decode(message!.buffer.asUint8List());
          String response = '';
          if (key.contains('pt.json')) {
            response = ptContent;
          } else if (key.contains('en.json')) {
            response = enContent;
          } else if (key.contains('es.json')) {
            response = esContent;
          } else {
            return null;
          }
          return ByteData.view(Uint8List.fromList(utf8.encode(response)).buffer);
        },
      );
    });

    tearDown(() async {
      await db.close();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler(
        'flutter/assets',
        null,
      );
      await Future.delayed(const Duration(seconds: 2));
    });

    testWidgets('Switching language in Settings updates texts dynamically', (WidgetTester tester) async {
      // Set test viewport size as per Rule 56
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;

      // Force load PT initially
      await AppLocalizations.load('pt');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            dioClientProvider.overrideWithValue(dioClient),
            pairingNotifierProvider.overrideWith(() => FakePairingNotifier()),
            voiceStatusStreamProvider.overrideWith((ref) => const Stream.empty()),
            wifiScanProvider.overrideWith((ref) => Future.value([])),
            savedWifiNetworksProvider.overrideWith((ref) => Future.value([])),
          ],
          child: const MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 1. Verify default/initial language is Portuguese
      expect(find.text('Ajustes Locais'), findsOneWidget);
      expect(find.text('Ajustes da Caixinha'), findsOneWidget);

      // 2. Open dropdown and Select English
      final dropdown = find.text('🇧🇷 Português');
      expect(dropdown, findsOneWidget);
      await tester.tap(dropdown);
      await tester.pumpAndSettle();

      final englishItem = find.text('🇺🇸 English').last;
      await tester.tap(englishItem);
      await tester.pumpAndSettle();

      // Verify the UI updated to English
      expect(find.text('Local Settings'), findsOneWidget);
      expect(find.text('Box Settings'), findsOneWidget);

      // 3. Open dropdown and Select Spanish
      final dropdownEng = find.text('🇺🇸 English');
      expect(dropdownEng, findsOneWidget);
      await tester.tap(dropdownEng);
      await tester.pumpAndSettle();

      final spanishItem = find.text('🇪🇸 Español').last;
      await tester.tap(spanishItem);
      await tester.pumpAndSettle();

      // Verify the UI updated to Spanish
      expect(find.text('Ajustes locales'), findsOneWidget);
      expect(find.text('Ajustes de la caja'), findsOneWidget);

      // 4. Open dropdown and Select Portuguese back
      final dropdownEsp = find.text('🇪🇸 Español');
      expect(dropdownEsp, findsOneWidget);
      await tester.tap(dropdownEsp);
      await tester.pumpAndSettle();

      final portugueseItem = find.text('🇧🇷 Português').last;
      await tester.tap(portugueseItem);
      await tester.pumpAndSettle();

      // Verify the UI updated back to Portuguese
      expect(find.text('Ajustes Locais'), findsOneWidget);
      expect(find.text('Ajustes da Caixinha'), findsOneWidget);

      // Close DB and settle query streams inside the test
      await db.close();
      await tester.pump(const Duration(seconds: 2));

      // Reset tester viewport size
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();

      await tester.pump(const Duration(seconds: 5));
    });
  });
}
