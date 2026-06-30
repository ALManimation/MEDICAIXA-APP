// ignore_for_file: depend_on_referenced_packages

import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medicaixa_app/core/services/notification_service.dart';
import 'package:medicaixa_app/features/alarms/presentation/alarm_active_screen.dart';
import 'package:medicaixa_app/features/alarms/data/alarm_model.dart';
import 'package:medicaixa_app/features/alarms/data/alarm_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_local_notifications_platform_interface/flutter_local_notifications_platform_interface.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:audioplayers_platform_interface/audioplayers_platform_interface.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:drift/native.dart';
import 'package:medicaixa_app/core/database/database.dart';
import 'package:medicaixa_app/core/providers/core_providers.dart';

class MockAlarmRepository implements AlarmRepository {
  final List<int> takenAlarms = [];
  final List<int> skippedAlarms = [];
  final Map<int, int> snoozedAlarms = {};

  @override
  Future<void> markTaken(int alarmId, {double? customQty}) async {
    takenAlarms.add(alarmId);
  }

  @override
  Future<void> markSkipped(int alarmId) async {
    skippedAlarms.add(alarmId);
  }

  @override
  Future<void> snoozeAlarm(int alarmId, int minutes) async {
    snoozedAlarms[alarmId] = minutes;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockLocalNotificationsPlatform extends FlutterLocalNotificationsPlatform {
  final bool shouldThrow;
  MockLocalNotificationsPlatform({this.shouldThrow = false});

  Future<bool?> initialize(
    InitializationSettings initializationSettings, {
    onDidReceiveNotificationResponse,
    onDidReceiveBackgroundNotificationResponse,
  }) async {
    if (shouldThrow) {
      throw PlatformException(code: 'INIT_ERROR', message: 'Failed to initialize plugin');
    }
    return true;
  }

  Future<void> zonedSchedule(
    int id,
    String? title,
    String? body,
    tz.TZDateTime scheduledDate,
    NotificationDetails notificationDetails, {
    required AndroidScheduleMode androidScheduleMode,
    required UILocalNotificationDateInterpretation uiLocalNotificationDateInterpretation,
    DateTimeComponents? matchDateTimeComponents,
    String? payload,
  }) async {
    if (shouldThrow) {
      throw PlatformException(code: 'SCHEDULE_ERROR', message: 'Failed to schedule notification');
    }
  }

  @override
  Future<void> cancel(int id) async {}

  @override
  Future<void> cancelAll() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class MockAudioplayersPlatform extends AudioplayersPlatformInterface {
  final _eventController = StreamController<AudioEvent>.broadcast();

  @override
  Future<void> create(String playerId) async {
    // Return normally to avoid unhandled asynchronous exceptions during initialization
  }

  @override
  Stream<AudioEvent> getEventStream(String playerId) {
    return _eventController.stream;
  }

  @override
  Future<void> setSourceUrl(String playerId, String url, {bool? isLocal, String? mimeType}) async {
    // Send the prepared event synchronously to resolve the wait future before throwing the simulated exception
    _eventController.add(
      const AudioEvent(
        eventType: AudioEventType.prepared,
        isPrepared: true,
      ),
    );
    throw Exception('Simulated audio platform error');
  }

  @override
  Future<int?> getCurrentPosition(String playerId) async {
    return 0;
  }

  @override
  Future<void> stop(String playerId) async {}

  @override
  Future<void> dispose(String playerId) async {
    await _eventController.close();
  }

  @override
  Future<void> release(String playerId) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw Exception('Simulated audio platform error');
  }
}

class MockGlobalAudioplayersPlatform extends GlobalAudioplayersPlatformInterface {
  @override
  Future<void> init() async {}

  @override
  Future<void> setGlobalAudioContext(AudioContext context) async {}

  @override
  Stream<GlobalAudioEvent> getGlobalEventStream() {
    return const Stream.empty();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NotificationService Robustness Tests', () {
    late NotificationService service;

    setUp(() {
      service = NotificationService.instance;
      // Setup mock method call handler for timezone
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('flutter_timezone'),
        (message) async {
          if (message.method == 'getLocalTimezone') {
            return 'America/Sao_Paulo';
          }
          return null;
        },
      );
    });

    test('NotificationService handles initialization and timezone gracefully', () async {
      FlutterLocalNotificationsPlatform.instance = MockLocalNotificationsPlatform();
      expect(service.init(), completes);
    });

    test('NotificationService scheduling weekly alarms is exception-safe', () async {
      FlutterLocalNotificationsPlatform.instance = MockLocalNotificationsPlatform(shouldThrow: true);
      // Weekly scheduling has internal try-catch and should NOT throw
      expect(
        () => service.scheduleWeeklyAlarm(
          id: 1,
          hour: 8,
          minute: 0,
          title: 'Test',
          body: 'Test Body',
          days: [false, true, false, false, false, false, false], // Mon active
        ),
        returnsNormally,
      );
    });

    test('Daily/Once scheduling is exception-safe', () async {
      FlutterLocalNotificationsPlatform.instance = MockLocalNotificationsPlatform(shouldThrow: true);
      // Daily/Once scheduling is now exception-safe and should NOT throw
      expect(
        () => service.scheduleWeeklyAlarm(
          id: 1,
          hour: 8,
          minute: 0,
          title: 'Test',
          body: 'Test Body',
          days: List.filled(7, false), // Daily fallback path
        ),
        returnsNormally,
      );
    });
  });

  group('AlarmActiveScreen Robustness Tests', () {
    late MockAlarmRepository mockRepository;
    late AppDatabase db;

    setUp(() {
      mockRepository = MockAlarmRepository();
      db = AppDatabase.connect(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('AlarmActiveScreen handles audio errors and MethodChannel (App Nap) exceptions gracefully', (tester) async {
      // Set the mock audioplayers and global platform to throw exceptions, avoiding any unhandled asynchronous errors
      AudioplayersPlatformInterface.instance = MockAudioplayersPlatform();
      GlobalAudioplayersPlatformInterface.instance = MockGlobalAudioplayersPlatform();

      // Reset preparation timeout to default (30 seconds) to prevent immediate TimeoutExceptions
      AudioPlayer.preparationTimeout = const Duration(seconds: 30);

      // Mock asset loader to throw/fail immediately to prevent rootBundle.load from hanging in testWidgets
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler(
        'flutter/assets',
        (message) async {
          return null; // returning null causes asset load to throw immediately
        },
      );

      // Configure viewport to prevent vertical overflow
      tester.view.physicalSize = const Size(600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Mock App Nap channel to throw exception
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.medicaixa.app/app_nap'),
        (message) async {
          throw PlatformException(code: 'UNSUPPORTED', message: 'App Nap not supported');
        },
      );

      // Track haptic and system sound calls to verify fallback
      int hapticCount = 0;
      int systemSoundCount = 0;

      const platformChannel = MethodChannel('flutter/platform', JSONMethodCodec());
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        platformChannel,
        (message) async {
          if (message.method == 'HapticFeedback.vibrate') {
            hapticCount++;
          }
          if (message.method == 'SystemSound.play') {
            systemSoundCount++;
            // Block the loop forever on the first play call to prevent scheduling Future.delayed
            return Completer<Object?>().future;
          }
          return Future<Object?>.value(null);
        },
      );

      final alarm = AlarmModel(
        id: 10,
        hour: 12,
        minute: 30,
        name: 'Paracetamol',
        medName: 'Paracetamol',
        enabled: true,
        active: true,
        days: List.filled(7, true),
        status: 'PENDENTE',
        color: 'red',
        quantity: 1.0,
        daysQuantity: List.filled(7, 0.0),
        type: 'comprimido',
        snoozeMin: 0,
        durationDays: 0,
      );

      // Build the AlarmActiveScreen in a test environment
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            alarmRepositoryProvider.overrideWithValue(mockRepository),
            databaseProvider.overrideWithValue(db),
          ],
          child: MaterialApp(
            home: AlarmActiveScreen(
              activeAlarms: [alarm],
            ),
          ),
        ),
      );

      // Yield control to the event loop so that unawaited futures inside initState run to completion
      await tester.idle();
      await tester.pump();

      // Verify that the screen did not crash and rendered successfully
      expect(find.text('HORA DO MEDICAMENTO'), findsOneWidget);
      expect(find.text('Paracetamol'), findsOneWidget);

      // Pump to let the periodic vibration loop execute up to the blocking SystemSound.play call
      await tester.pump();

      // Verify that haptic vibration fallback was triggered
      expect(hapticCount, greaterThan(0));
      expect(systemSoundCount, greaterThan(0));

      // Tap on MARK AS TAKEN and verify it invokes repository
      final takenButton = find.byType(ElevatedButton);
      expect(takenButton, findsOneWidget);
      await tester.tap(takenButton);
      await tester.pump();

      expect(mockRepository.takenAlarms.contains(10), true);
    });
  });
}
