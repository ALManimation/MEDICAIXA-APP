import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/native.dart';
import 'package:medicaixa_app/core/database/database.dart';
import 'package:medicaixa_app/core/network/dio_client.dart';
import 'package:medicaixa_app/core/providers/core_providers.dart';
import 'package:medicaixa_app/features/pairing/domain/connection_state.dart';
import 'package:medicaixa_app/features/pairing/presentation/pairing_notifier.dart';
import 'package:medicaixa_app/features/settings/presentation/settings_screen.dart';
import 'package:medicaixa_app/features/settings/data/settings_repository.dart';
import 'package:medicaixa_app/features/settings/data/wifi_repository.dart';
import 'package:medicaixa_app/features/settings/data/settings_models.dart';

class MockDioClient implements DioClient {
  Map<String, dynamic> getResponses = {};
  Map<String, dynamic> postResponses = {};

  @override
  String? get baseUrl => 'http://192.168.4.1';

  @override
  bool get isConfigured => true;

  @override
  void setBaseUrl(String url) {}

  @override
  Future<Response<T>> get<T>(String path, {Map<String, dynamic>? queryParameters}) async {
    if (getResponses.containsKey(path)) {
      final data = getResponses[path];
      if (data is Exception) {
        throw data;
      }
      return Response<T>(
        requestOptions: RequestOptions(path: path),
        data: data as T?,
        statusCode: 200,
      );
    }
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      data: null,
      statusCode: 404,
    );
  }

  @override
  Future<Response<T>> post<T>(String path, {dynamic data, Map<String, dynamic>? queryParameters}) async {
    if (postResponses.containsKey(path)) {
      final respData = postResponses[path];
      if (respData is Exception) {
        throw respData;
      }
      return Response<T>(
        requestOptions: RequestOptions(path: path),
        data: respData as T?,
        statusCode: 200,
      );
    }
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      data: 'OK' as T?,
      statusCode: 200,
    );
  }

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
  FakePairingNotifier(this._initialState);
  final ConnectionStateInfo _initialState;
  ConnectionStateInfo? _stateOverride;

  @override
  ConnectionStateInfo build() {
    return _stateOverride ?? _initialState;
  }

  void setConnectionState(ConnectionStateInfo stateInfo) {
    _stateOverride = stateInfo;
    state = stateInfo;
  }

  @override
  Future<void> useStandalone() async {
    state = const ConnectionStateInfo.disconnected();
  }

  @override
  void disconnect() {
    state = const ConnectionStateInfo.disconnected();
  }
}

class FakeDeviceTimeNotifier extends DeviceTimeNotifier {
  FakeDeviceTimeNotifier(this._initialTime);
  final DeviceDateTime _initialTime;

  @override
  FutureOr<DeviceDateTime?> build() {
    return _initialTime;
  }
  
  @override
  Future<void> syncWithPhoneTime() async {}

  @override
  Future<void> setManualDateTime(DateTime selectedDateTime) async {}

  @override
  Future<void> refreshTime() async {}
}

void main() {
  group('Settings UI Adversarial Tests', () {
    late AppDatabase db;
    late MockDioClient dioClient;

    setUp(() async {
      db = AppDatabase.connect(NativeDatabase.memory());
      dioClient = MockDioClient();
      
      // Pre-seed database with default settings row
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          dioClientProvider.overrideWithValue(dioClient),
        ],
      );
      final settingsRepo = SettingsRepository(db, dioClient, FakeRef(container));
      await settingsRepo.getSettings();
    });

    tearDown(() async {
      await db.close();
      await Future.delayed(const Duration(seconds: 2));
    });

    testWidgets('Transitions between connected and standalone states', (WidgetTester tester) async {
      const disconnectedState = ConnectionStateInfo.disconnected();
      
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            dioClientProvider.overrideWithValue(dioClient),
            pairingNotifierProvider.overrideWith(() => FakePairingNotifier(disconnectedState)),
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

      // Warning card is visible
      expect(find.text('Configurações da Caixinha Bloqueadas'), findsOneWidget);

      // Section has opacity 0.55 and IgnorePointer ignoring: true
      final ignorePointerFinder = find.byType(IgnorePointer);
      expect(ignorePointerFinder, findsWidgets);

      final opacityFinder = find.byType(Opacity);
      final opacityWidgets = tester.widgetList<Opacity>(opacityFinder);
      final hasReducedOpacity = opacityWidgets.any((w) => w.opacity == 0.55);
      expect(hasReducedOpacity, isTrue);

      final ignorePointerWidgets = tester.widgetList<IgnorePointer>(ignorePointerFinder);
      final hasIgnoringPointer = ignorePointerWidgets.any((w) => w.ignoring == true);
      expect(hasIgnoringPointer, isTrue);

      // Transition to CONNECTED STATE
      final container = ProviderScope.containerOf(tester.element(find.byType(SettingsScreen)));
      final notifier = container.read(pairingNotifierProvider.notifier) as FakePairingNotifier;
      notifier.setConnectionState(const ConnectionStateInfo(
        status: ConnectionStatus.connected,
        ip: 'http://192.168.4.1',
        deviceName: 'MediCaixa',
        firmwareVersion: 'v0.90',
      ));

      // Re-pump SettingsScreen with the connected notifier state
      await tester.pump();
      await tester.pumpAndSettle();

      // Warning card is NOT visible
      expect(find.text('Configurações da Caixinha Bloqueadas'), findsNothing);

      // Section has opacity 1.0 and IgnorePointer ignoring: false
      final opacityWidgetsConnected = tester.widgetList<Opacity>(opacityFinder);
      final hasFullOpacity = opacityWidgetsConnected.any((w) => w.opacity == 1.0);
      expect(hasFullOpacity, isTrue);

      final ignorePointerWidgetsConnected = tester.widgetList<IgnorePointer>(ignorePointerFinder);
      final hasActivePointer = ignorePointerWidgetsConnected.any((w) => w.ignoring == false);
      expect(hasActivePointer, isTrue);

      // Close DB and settle query streams inside the test
      await db.close();
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('Dialog validations: selective partition resets and uppercase APAGAR match check', (WidgetTester tester) async {
      const connectedState = ConnectionStateInfo(
        status: ConnectionStatus.connected,
        ip: 'http://192.168.4.1',
        deviceName: 'MediCaixa',
        firmwareVersion: 'v0.90',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            dioClientProvider.overrideWithValue(dioClient),
            pairingNotifierProvider.overrideWith(() => FakePairingNotifier(connectedState)),
            voiceStatusStreamProvider.overrideWith((ref) => const Stream.empty()),
            wifiScanProvider.overrideWith((ref) => Future.value([])),
            savedWifiNetworksProvider.overrideWith((ref) => Future.value([])),
            deviceTimeNotifierProvider.overrideWith(() => FakeDeviceTimeNotifier(DeviceDateTime.fromDateTime(DateTime.now()))),
          ],
          child: const MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Expand "Manutenção da Caixinha" tile
      final maintenanceTileFinder = find.text('Manutenção da Caixinha');
      expect(maintenanceTileFinder, findsOneWidget);
      await tester.ensureVisible(maintenanceTileFinder);
      await tester.tap(maintenanceTileFinder);
      await tester.pumpAndSettle();

      // Tap "Reset de Dados" to show reset dialog
      final resetDataFinder = find.text('Reset de Dados');
      expect(resetDataFinder, findsOneWidget);
      await tester.ensureVisible(resetDataFinder);
      await tester.tap(resetDataFinder);
      await tester.pumpAndSettle();

      // Dialog is shown
      expect(find.byType(AlertDialog), findsOneWidget);

      // 1. Check initially that "Confirmar e Apagar" button is disabled (onPressed is null)
      final confirmButtonFinder = find.widgetWithText(ElevatedButton, 'Confirmar e Apagar');
      expect(confirmButtonFinder, findsOneWidget);
      ElevatedButton confirmBtn = tester.widget<ElevatedButton>(confirmButtonFinder);
      expect(confirmBtn.onPressed, isNull);

      // 2. Select 'Alarmes' partition
      final alarmsCheckboxFinder = find.widgetWithText(CheckboxListTile, 'Alarmes');
      expect(alarmsCheckboxFinder, findsOneWidget);
      await tester.ensureVisible(alarmsCheckboxFinder);
      await tester.tap(alarmsCheckboxFinder);
      await tester.pumpAndSettle();

      // Check button remains disabled because confirmation text is empty
      confirmBtn = tester.widget<ElevatedButton>(confirmButtonFinder);
      expect(confirmBtn.onPressed, isNull);

      // 3. Test uppercase 'APAGAR' match check:
      final textFieldFinder = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      );
      expect(textFieldFinder, findsOneWidget);

      // Try typing non-matching text: 'APAGA'
      await tester.enterText(textFieldFinder, 'APAGA');
      await tester.pumpAndSettle();
      confirmBtn = tester.widget<ElevatedButton>(confirmButtonFinder);
      expect(confirmBtn.onPressed, isNull);

      // Try typing lowercase 'apagar' (will be formatted to 'APAGAR' by formatter)
      await tester.enterText(textFieldFinder, 'apagar');
      await tester.pumpAndSettle();

      // Verify uppercase text conversion formatting
      final textField = tester.widget<TextField>(textFieldFinder);
      expect(textField.controller?.text, 'APAGAR');

      // Check button is now enabled (onPressed is not null)
      confirmBtn = tester.widget<ElevatedButton>(confirmButtonFinder);
      expect(confirmBtn.onPressed, isNotNull);

      // 4. Test "RESET DE FÁBRICA (Tudo)" checkbox behavior:
      // Tap factory reset checkbox
      final factoryResetCheckboxFinder = find.widgetWithText(CheckboxListTile, 'RESET DE FÁBRICA (Tudo)');
      expect(factoryResetCheckboxFinder, findsOneWidget);
      await tester.ensureVisible(factoryResetCheckboxFinder);
      await tester.tap(factoryResetCheckboxFinder);
      await tester.pumpAndSettle();

      // Verify that individual partition tiles are now disabled (onChanged is null)
      final alarmsCheckbox = tester.widget<CheckboxListTile>(alarmsCheckboxFinder);
      expect(alarmsCheckbox.onChanged, isNull);

      // Uncheck factory reset to make partitions editable again
      await tester.ensureVisible(factoryResetCheckboxFinder);
      await tester.tap(factoryResetCheckboxFinder);
      await tester.pumpAndSettle();
      final alarmsCheckboxAfter = tester.widget<CheckboxListTile>(alarmsCheckboxFinder);
      expect(alarmsCheckboxAfter.onChanged, isNotNull);

      // Dismiss dialog
      final cancelBtnFinder = find.text('Cancelar');
      await tester.ensureVisible(cancelBtnFinder);
      await tester.tap(cancelBtnFinder);
      await tester.pumpAndSettle();

      // Close DB and settle query streams inside the test
      await db.close();
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('Layout component boundaries: Long patient names and empty SSID lists', (WidgetTester tester) async {
      const connectedState = ConnectionStateInfo(
        status: ConnectionStatus.connected,
        ip: 'http://192.168.4.1',
        deviceName: 'MediCaixa',
        firmwareVersion: 'v0.90',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            dioClientProvider.overrideWithValue(dioClient),
            pairingNotifierProvider.overrideWith(() => FakePairingNotifier(connectedState)),
            voiceStatusStreamProvider.overrideWith((ref) => const Stream.empty()),
            wifiScanProvider.overrideWith((ref) => Future.value([])), // Empty scanned SSIDs
            savedWifiNetworksProvider.overrideWith((ref) => Future.value([])), // Empty saved SSIDs
          ],
          child: const MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Long patient name boundary handling (100 characters)
      final patientNameFieldFinder = find.ancestor(
        of: find.text('Nome do Paciente'),
        matching: find.byType(TextField),
      );
      expect(patientNameFieldFinder, findsOneWidget);

      final longName = 'X' * 100;
      await tester.enterText(patientNameFieldFinder, longName);
      await tester.pumpAndSettle();

      final saveButtonFinder = find.widgetWithText(ElevatedButton, 'Salvar Nome');
      await tester.tap(saveButtonFinder);
      await tester.pumpAndSettle();

      // Verify name saved in Drift local DB correctly
      final settings = await db.select(db.settings).getSingle();
      expect(settings.patientName, longName);

      // 2. Wi-Fi Config Tile empty scanned / saved list handling
      final wifiTileFinder = find.text('Rede Wi-Fi da Caixinha');
      expect(wifiTileFinder, findsOneWidget);
      await tester.ensureVisible(wifiTileFinder);
      await tester.tap(wifiTileFinder);
      await tester.pumpAndSettle();

      // Verify the empty state placeholders are rendered properly
      expect(find.text('Nenhuma rede Wi-Fi salva no dispositivo'), findsOneWidget);
      expect(find.text('Nenhuma rede Wi-Fi encontrada'), findsOneWidget);

      // Close DB and settle query streams inside the test
      await db.close();
      await tester.pump(const Duration(seconds: 2));
    });

    test('Drift database extreme speaker volume and display brightness limits (0 and 100)', () async {
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          dioClientProvider.overrideWithValue(dioClient),
        ],
      );
      final repo = SettingsRepository(db, dioClient, FakeRef(container));

      final initial = await repo.getSettings();

      // Boundary: 0
      final settingsZero = initial.copyWith(speakerVolume: 0, brightness: 0);
      await repo.updateSettings(settingsZero);

      var updated = await repo.getSettings();
      expect(updated.speakerVolume, 0);
      expect(updated.brightness, 0);

      // Boundary: 100
      final settingsHundred = initial.copyWith(speakerVolume: 100, brightness: 100);
      await repo.updateSettings(settingsHundred);

      updated = await repo.getSettings();
      expect(updated.speakerVolume, 100);
      expect(updated.brightness, 100);
    });
  });
}
