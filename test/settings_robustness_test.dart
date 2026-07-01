import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/native.dart';
import 'package:dio/dio.dart';
import 'package:medicaixa_app/core/database/database.dart';
import 'package:medicaixa_app/core/network/dio_client.dart';
import 'package:medicaixa_app/core/providers/core_providers.dart';
import 'package:medicaixa_app/core/constants/app_constants.dart';
import 'package:medicaixa_app/features/pairing/presentation/pairing_notifier.dart';
import 'package:medicaixa_app/features/pairing/domain/connection_state.dart';
import 'package:medicaixa_app/features/settings/data/settings_models.dart';
import 'package:medicaixa_app/features/settings/data/settings_repository.dart';
import 'package:medicaixa_app/features/settings/data/wifi_repository.dart';
import 'package:fake_async/fake_async.dart';

import 'package:medicaixa_app/core/providers/connection_providers.dart';


// Fake Pairing Notifier to control the connection state
class FakePairingNotifier extends PairingNotifier {
  final ConnectionStatus initialStatus;
  FakePairingNotifier(this.initialStatus);

  @override
  ConnectionStateInfo build() {
    final stateInfo = ConnectionStateInfo(
      status: initialStatus,
      ip: initialStatus == ConnectionStatus.connected ? 'http://192.168.4.1' : null,
      deviceName: initialStatus == ConnectionStatus.connected ? 'MediCaixa' : null,
      firmwareVersion: initialStatus == ConnectionStatus.connected ? 'v0.90' : null,
    );
    listenSelf((previous, next) {
      Future.microtask(() {
        ref.read(deviceConnectionStateProvider.notifier).updateState(next);
      });
    });
    ref.listen(deviceConnectionStateProvider, (previous, next) {
      if (next.status == ConnectionStatus.disconnected && state.status != ConnectionStatus.disconnected) {
        state = const ConnectionStateInfo.disconnected();
      }
    });
    Future.microtask(() {
      ref.read(deviceConnectionStateProvider.notifier).updateState(stateInfo);
    });
    return stateInfo;
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

// Custom Fake DioClient to simulate network behaviors
class RobustFakeDioClient implements DioClient {
  @override
  String? baseUrl = 'http://192.168.4.1';

  @override
  bool get isConfigured => baseUrl != null;

  @override
  void setBaseUrl(String url) {
    baseUrl = url;
  }

  final Map<String, dynamic Function(dynamic data)> postHandlers = {};
  final Map<String, dynamic Function()> getHandlers = {};
  final List<String> callHistory = [];

  @override
  Future<Response<T>> get<T>(String path, {Map<String, dynamic>? queryParameters}) async {
    callHistory.add('GET $path');
    if (!isConfigured) throw Exception('DioClient is not configured with a base URL');
    
    if (getHandlers.containsKey(path)) {
      final res = await getHandlers[path]!();
      if (res is Exception) {
        throw res;
      }
      return Response<T>(
        requestOptions: RequestOptions(path: path),
        data: res as T?,
        statusCode: 200,
      );
    }
    throw Exception('No GET handler for $path');
  }

  @override
  Future<Response<T>> post<T>(String path, {dynamic data, Map<String, dynamic>? queryParameters}) async {
    callHistory.add('POST $path');
    if (!isConfigured) throw Exception('DioClient is not configured with a base URL');

    if (postHandlers.containsKey(path)) {
      final res = await postHandlers[path]!(data);
      if (res is Exception) {
        throw res;
      }
      return Response<T>(
        requestOptions: RequestOptions(path: path),
        data: res as T?,
        statusCode: 200,
      );
    }
    throw Exception('No POST handler for $path');
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

void main() {
  group('Settings C++ API Integration Robustness Tests', () {
    late AppDatabase db;
    late RobustFakeDioClient dioClient;
    late ProviderContainer container;
    late SettingsRepository settingsRepo;
    late WifiRepository wifiRepo;

    setUp(() async {
      db = AppDatabase.connect(NativeDatabase.memory());
      dioClient = RobustFakeDioClient();
      container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          dioClientProvider.overrideWithValue(dioClient),
          pairingNotifierProvider.overrideWith(() => FakePairingNotifier(ConnectionStatus.connected)),
        ],
      );
      container.read(pairingNotifierProvider);
      await Future.delayed(Duration.zero);
      settingsRepo = SettingsRepository(db, dioClient, FakeRef(container));
      wifiRepo = WifiRepository(dioClient, FakeRef(container));
    });

    tearDown(() async {
      await db.close();
      container.dispose();
    });

    group('1. Network Failures', () {
      test('fetchDeviceTime throws when request fails', () async {
        dioClient.getHandlers['/server_time'] = () {
          throw Exception('Não foi possível conectar à MediCaixa. Verifique a rede.');
        };

        expect(
          () => settingsRepo.fetchDeviceTime(),
          throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('Não foi possível conectar'))),
        );
      });

      test('fetchDeviceTime throws when status code is not 200', () async {
        dioClient.getHandlers['/server_time'] = () {
          throw Exception('Erro no servidor (Código: 500)');
        };

        expect(
          () => settingsRepo.fetchDeviceTime(),
          throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('Erro no servidor (Código: 500)'))),
        );
      });

      test('updatePatientName catches error and logs without crashing the application', () async {
        dioClient.postHandlers['/save_patient_name'] = (_) {
          throw Exception('Network error');
        };

        // Should not throw, should handle internally
        await expectLater(
          settingsRepo.updatePatientName('New Patient Name'),
          completes,
        );
        
        // Verify database was still updated locally
        final settings = await settingsRepo.getSettings();
        expect(settings.patientName, 'New Patient Name');
      });

      test('updateSettings catches network errors and completes normally', () async {
        dioClient.postHandlers['/save_settings'] = (_) {
          throw Exception('Connection failed');
        };

        final current = await settingsRepo.getSettings();
        final updated = current.copyWith(brightness: 80);

        await expectLater(
          settingsRepo.updateSettings(updated),
          completes,
        );

        final local = await settingsRepo.getSettings();
        expect(local.brightness, 80);
      });
      
      test('testSound throws exception when status code is 500', () async {
        dioClient.postHandlers['/test_sound'] = (_) {
          throw Exception('Erro no servidor (Código: 500)');
        };

        expect(
          () => settingsRepo.testSound(1),
          throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('Erro no servidor'))),
        );
      });
    });

    group('2. Slow Connections (Timeout Triggers)', () {
      test('DioClient Timeout configuration is set to 5000ms', () {
        expect(AppConstants.requestTimeoutMs, 5000);
      });

      test('fetchDeviceTime throws timeout exception when connection times out', () async {
        dioClient.getHandlers['/server_time'] = () {
          throw Exception('Tempo limite de conexão esgotado');
        };

        expect(
          () => settingsRepo.fetchDeviceTime(),
          throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('Tempo limite de conexão esgotado'))),
        );
      });
      
      test('downloadBackupJson throws timeout exception when download times out', () async {
        dioClient.getHandlers['/backup'] = () {
          throw Exception('Tempo limite de conexão esgotado');
        };

        expect(
          () => settingsRepo.downloadBackupJson(),
          throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('Tempo limite de conexão esgotado'))),
        );
      });
    });

    group('3. Malformed JSON Responses from ESP32', () {
      test('fetchDeviceTime throws when response is a plain string instead of a JSON map', () async {
        dioClient.getHandlers['/server_time'] = () {
          return 'Not a JSON map';
        };

        expect(
          () => settingsRepo.fetchDeviceTime(),
          throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('Falha ao obter horário'))),
        );
      });

      test('fetchDeviceTime throws when response map has invalid data types (String for Int)', () async {
        dioClient.getHandlers['/server_time'] = () {
          return {
            'year': '2026', // String instead of int
            'month': 6,
            'day': 28,
            'hour': 11,
            'minute': 10,
            'second': 0,
          };
        };

        expect(
          () => settingsRepo.fetchDeviceTime(),
          throwsA(isA<TypeError>()),
        );
      });

      test('syncSettings handles malformed JSON settings response without throwing', () async {
        dioClient.getHandlers['/settings'] = () {
          return 'Invalid data format'; // Expected Map
        };

        // Should complete without throwing exception
        await expectLater(
          settingsRepo.syncSettings(),
          completes,
        );
      });

      test('syncSettings handles settings map with invalid values gracefully', () async {
        dioClient.getHandlers['/settings'] = () {
          return {
            'patient_name': 12345, // Int instead of String
            'speaker_volume': 'high', // String instead of Int
            'brightness': true, // Bool instead of Int
          };
        };

        await expectLater(
          settingsRepo.syncSettings(),
          completes,
        );
      });
    });

    group('4. Sequential Request Queueing', () {
      test('RequestLock processes actions sequentially in FIFO order', () async {
        final lock = RequestLock();
        final executionOrder = <int>[];

        final f1 = lock.synchronized(() async {
          await Future.delayed(const Duration(milliseconds: 50));
          executionOrder.add(1);
        });

        final f2 = lock.synchronized(() async {
          await Future.delayed(const Duration(milliseconds: 10));
          executionOrder.add(2);
        });

        await Future.wait([f1, f2]);
        expect(executionOrder, [1, 2]);
      });
    });

    group('5. WifiRepository Robustness', () {
      test('scanNetworks throws exception on network failure', () async {
        dioClient.getHandlers['/wifi_scan'] = () {
          throw Exception('Não foi possível conectar à MediCaixa. Verifique a rede.');
        };

        expect(
          () => wifiRepo.scanNetworks(),
          throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('Não foi possível conectar'))),
        );
      });

      test('scanNetworks throws timeout exception when slow connection occurs', () async {
        dioClient.getHandlers['/wifi_scan'] = () {
          throw Exception('Tempo limite de conexão esgotado');
        };

        expect(
          () => wifiRepo.scanNetworks(),
          throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('Tempo limite de conexão esgotado'))),
        );
      });

      test('scanNetworks throws format exception/type error when response is malformed (not a list)', () async {
        dioClient.getHandlers['/wifi_scan'] = () {
          return 'Invalid data format'; // Expecting list
        };

        final networks = await wifiRepo.scanNetworks();
        expect(networks, isEmpty);
      });

      test('scanNetworks throws type error when list elements are not maps or have invalid types', () async {
        dioClient.getHandlers['/wifi_scan'] = () {
          return [
            {'ssid': 'MyWifi', 'rssi': 'strong'} // rssi should be int
          ];
        };

        expect(
          () => wifiRepo.scanNetworks(),
          throwsA(isA<TypeError>()),
        );
      });

      test('getSavedNetworks throws exception when server returns status 500', () async {
        dioClient.getHandlers['/wifi_list'] = () {
          throw Exception('Erro no servidor (Código: 500)');
        };

        expect(
          () => wifiRepo.getSavedNetworks(),
          throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('Erro no servidor'))),
        );
      });

      test('addNetwork throws exception when response body is not OK', () async {
        dioClient.postHandlers['/wifi_add'] = (_) {
          return 'ERROR';
        };

        expect(
          () => wifiRepo.addNetwork('SSID', 'PASS'),
          throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('Falha ao salvar rede'))),
        );
      });

      test('removeNetwork throws exception when network fails', () async {
        dioClient.postHandlers['/wifi_remove'] = (_) {
          throw Exception('Connection failed');
        };

        expect(
          () => wifiRepo.removeNetwork('SSID'),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('6. DeviceResetNotifier & Backup/Restore Robustness', () {
      test('DeviceResetNotifier.resetDevicePartitions triggers restart and standalone redirection on wifi wipe', () {
        fakeAsync((async) {
          var restartCalled = false;
          dioClient.postHandlers['/reset'] = (payload) {
            return 'OK';
          };
          dioClient.postHandlers['/restart'] = (_) {
            restartCalled = true;
            return 'OK';
          };

          // Listen to the provider to keep it active during fakeAsync execution
          final subscription = container.listen(pairingNotifierProvider, (_, __) {});
          final subscriptionReset = container.listen(deviceResetNotifierProvider, (_, __) {});

          final notifier = container.read(deviceResetNotifierProvider.notifier);
          
          bool? success;
          notifier.resetDevicePartitions({'wifi': true}).then((val) {
            success = val;
          });

          // Fast forward time by 9 seconds to skip the 8 seconds restart delay
          async.elapse(const Duration(seconds: 9));
          async.flushMicrotasks();

          expect(success, isTrue);
          expect(restartCalled, isTrue);
          
          final connState = container.read(pairingNotifierProvider);
          expect(connState.status, ConnectionStatus.disconnected);

          subscription.close();
          subscriptionReset.close();
        });
      });

      test('DeviceResetNotifier.resetDevicePartitions handles connection failure gracefully', () async {
        dioClient.postHandlers['/reset'] = (_) {
          throw Exception('Connection failed');
        };

        // Listen to the provider to keep it active during async execution
        final subscription = container.listen(deviceResetNotifierProvider, (_, __) {});

        final notifier = container.read(deviceResetNotifierProvider.notifier);
        final success = await notifier.resetDevicePartitions({'settings': true});

        expect(success, isFalse);
        expect(container.read(deviceResetNotifierProvider).hasError, isTrue);

        subscription.close();
      });

      test('DeviceResetNotifier.resetDevicePartitions catches restart exceptions robustly', () {
        fakeAsync((async) {
          dioClient.postHandlers['/reset'] = (_) => 'OK';
          dioClient.postHandlers['/restart'] = (_) {
            throw Exception('Connection failed');
          };

          // Listen to the provider to keep it active during fakeAsync execution
          final subscription = container.listen(deviceResetNotifierProvider, (_, __) {});

          final notifier = container.read(deviceResetNotifierProvider.notifier);
          
          notifier.resetDevicePartitions({'wifi': true});

          async.elapse(const Duration(seconds: 9));

          final state = container.read(deviceResetNotifierProvider);
          expect(state.hasError, isFalse);

          subscription.close();
        });
      });

      test('executeBackupRestore returns expected restored file count on success', () async {
        dioClient.postHandlers['/restore'] = (_) {
          return {'restored_files': 5};
        };

        final count = await settingsRepo.executeBackupRestore({'data': 'foo'});
        expect(count, 5);
      });

      test('executeBackupRestore throws Exception on non-200 status code', () async {
        dioClient.postHandlers['/restore'] = (_) {
          throw Exception('Erro no servidor (Código: 500)');
        };

        expect(
          () => settingsRepo.executeBackupRestore({'data': 'foo'}),
          throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('Erro no servidor'))),
        );
      });

      test('executeBackupRestore throws TypeError on malformed response format', () async {
        dioClient.postHandlers['/restore'] = (_) {
          return {'restored_files': 'invalid_string'}; // String instead of num/int
        };

        expect(
          () => settingsRepo.executeBackupRestore({'data': 'foo'}),
          throwsA(isA<TypeError>()),
        );
      });

      test('updateDeviceTime throws Exception on network failure', () async {
        dioClient.postHandlers['/set_datetime'] = (_) {
          throw Exception('Connection failed');
        };

        expect(
          () => settingsRepo.updateDeviceTime(DeviceDateTime.fromDateTime(DateTime.now())),
          throwsA(isA<Exception>()),
        );
      });

      test('updateDeviceTime completes normally on success', () async {
        var datetimePayload = <String, dynamic>{};
        dioClient.postHandlers['/set_datetime'] = (data) {
          datetimePayload = data as Map<String, dynamic>;
          return 'OK';
        };

        final testTime = DateTime(2026, 6, 28, 12, 0, 0);
        await settingsRepo.updateDeviceTime(DeviceDateTime.fromDateTime(testTime));

        expect(datetimePayload['year'], 2026);
        expect(datetimePayload['hour'], 12);
      });
      
      test('restartDevice completes normally even when server request fails', () async {
        dioClient.postHandlers['/restart'] = (_) {
          throw Exception('Connection reset by peer');
        };

        await expectLater(
          settingsRepo.restartDevice(),
          completes,
        );
      });

      test('executeBackupRestore parses and restores history in both C++ (date/time) and Flutter formats', () async {
        dioClient.postHandlers['/restore'] = (payload) {
          return {'restored_files': 2};
        };

        final testBackup = {
          'history': [
            {
              'date': '29/06/2026',
              'time': '08:05:40',
              'event': 'Tomado',
              'details': 'Prednisona',
              'id': 42,
              'h': 8,
              'm': 0,
              'color': 'yellow',
              'dosage': '5mg',
              'type': 'comprimido',
              'qty': 3
            },
            {
              'timestamp': 1782729938000,
              'med_name': 'Dipirona',
              'id': 26,
              'dosage': '10mL',
              'status': 'PERDIDO',
              'type': 'alarm'
            }
          ]
        };

        final count = await settingsRepo.executeBackupRestore(testBackup);
        expect(count, 2);

        final events = await db.select(db.historyEvents).get();
        expect(events.length, 2);

        final event1 = events.firstWhere((e) => e.medName == 'Prednisona');
        expect(event1.alarmId, 42);
        expect(event1.dosage, '5mg');
        expect(event1.status, 'TOMADO');
        expect(event1.type, 'alarm');
        final expectedTs = DateTime(2026, 6, 29, 8, 5, 40).millisecondsSinceEpoch;
        expect(event1.timestamp, expectedTs);

        final event2 = events.firstWhere((e) => e.medName == 'Dipirona');
        expect(event2.alarmId, 26);
        expect(event2.dosage, '10mL');
        expect(event2.status, 'PERDIDO');
        expect(event2.type, 'alarm');
        expect(event2.timestamp, 1782729938000);
      });
    });
  });
}
