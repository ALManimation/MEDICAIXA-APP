# Analysis Report: Dart NotificationService & Cross-Platform Alarm Audio Integration

This report provides the analysis and proposed modifications for the Dart `NotificationService` in the MediCaixa application, detailing the exact integration of high-priority notification channels on Android, Critical Alerts on iOS, and Time-Sensitive notifications on macOS, ensuring compile-safe, platform-conditional execution.

---

## 1. Android: High-Priority Channels and Full-Screen Intent

### Channel Configuration in `init()`
On Android, a channel configured with `Importance.max` is required to display heads-up notifications (banners that slide down). In addition, to support alarm-like behavior that respect system alarm sound volumes and bypass standard do-not-disturb, we set `audioAttributesUsage: AudioAttributesUsage.alarm`.

```dart
// Proposto para init() no Android:
final androidPlugin = _notificationsPlugin
    .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
if (androidPlugin != null) {
  await androidPlugin.requestNotificationsPermission();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'medicaixa_alarms_channel',
    'MediCaixa Alarmes',
    description: 'Canal de notificações para alarmes de medicamentos',
    importance: Importance.max, // Maximum importance
    playSound: true,
    enableVibration: true,
    showBadge: true,
    audioAttributesUsage: AudioAttributesUsage.alarm, // Alarm audio attributes
  );
  await androidPlugin.createNotificationChannel(channel);
}
```

### Zoned Schedule in `scheduleWeeklyAlarm()`
We use `Priority.max` (maximum priority) in `AndroidNotificationDetails` along with `fullScreenIntent: true` to launch the active alarm screen immediately on the lock screen.

```dart
final androidDetails = AndroidNotificationDetails(
  'medicaixa_alarms_channel',
  'MediCaixa Alarmes',
  channelDescription: 'Canal de notificações para alarmes de medicamentos',
  importance: Importance.max,
  priority: Priority.max, // Maximum priority
  sound: soundName != null && soundName.isNotEmpty
      ? RawResourceAndroidNotificationSound(soundName)
      : null,
  playSound: true,
  enableVibration: true,
  fullScreenIntent: true, // Enables fullScreenIntent on Android
  category: AndroidNotificationCategory.alarm,
  audioAttributesUsage: AudioAttributesUsage.alarm,
);
```

---

## 2. iOS: Critical Alerts & Background Audio Playback

### Critical Alerts Setup
For iOS, requesting the critical alert entitlement during initialization is required. We configure `requestCriticalPermission: true` in `DarwinInitializationSettings`.

```dart
const DarwinInitializationSettings initializationSettingsDarwin =
    DarwinInitializationSettings(
  requestAlertPermission: true,
  requestBadgePermission: true,
  requestSoundPermission: true,
  requestCriticalPermission: true, // Request Critical Alert permission on iOS/macOS
);
```

To schedule a critical notification, we must configure `interruptionLevel: InterruptionLevel.critical` in `DarwinNotificationDetails`.

### Addressing `UNNotificationSound.criticalSoundNamed` Native-Side Limitation
The `flutter_local_notifications` package does not expose a direct Dart API for `UNNotificationSound.criticalSoundNamed`. In Objective-C, it maps `sound` to `[UNNotificationSound soundNamed:]`. 
To ensure that critical alerts play with critical bypass characteristics, we propose a Swift swizzle in `ios/Runner/AppDelegate.swift` to intercept scheduled requests with `interruptionLevel == .critical` and map them to critical sound:

```swift
// proposed modification to ios/Runner/AppDelegate.swift
import UserNotifications

extension UNUserNotificationCenter {
    static let swizzleAdd: Void = {
        let originalSelector = #selector(add(_:withCompletionHandler:))
        let swizzledSelector = #selector(swizzled_add(_:withCompletionHandler:))
        
        guard let originalMethod = class_getInstanceMethod(UNUserNotificationCenter.self, originalSelector),
              let swizzledMethod = class_getInstanceMethod(UNUserNotificationCenter.self, swizzledSelector) else {
            return
        }
        method_exchangeImplementations(originalMethod, swizzledMethod)
    }()
    
    @objc func swizzled_add(_ request: UNNotificationRequest, withCompletionHandler completionHandler: ((Error?) -> Void)? = nil) {
        if #available(iOS 15.0, *) {
            if request.content.interruptionLevel == .critical {
                if let soundName = request.content.value(forKey: "sound") as? UNNotificationSound {
                    let soundDesc = soundName.description
                    var fileName: String? = nil
                    if soundDesc.contains(".caf") || soundDesc.contains(".wav") || soundDesc.contains(".aiff") {
                        let pattern = "\"[^\"]+\""
                        if let regex = try? NSRegularExpression(pattern: pattern, options: []),
                           let match = regex.firstMatch(in: soundDesc, options: [], range: NSRange(soundDesc.startIndex..., in: soundDesc)),
                           let range = Range(match.range, in: soundDesc) {
                            fileName = String(soundDesc[range]).replacingOccurrences(of: "\"", with: "")
                        }
                    }
                    
                    let criticalSound: UNNotificationSound
                    if let file = fileName {
                        criticalSound = UNNotificationSound.criticalSoundNamed(UNNotificationSoundName(rawValue: file), withAudioVolume: 1.0)
                    } else {
                        criticalSound = UNNotificationSound.defaultCriticalSound
                    }
                    
                    if let mutableContent = request.content.mutableCopy() as? UNMutableNotificationContent {
                        mutableContent.sound = criticalSound
                        let newRequest = UNNotificationRequest(identifier: request.identifier, content: mutableContent, trigger: request.trigger)
                        self.swizzled_add(newRequest, withCompletionHandler: completionHandler)
                        return
                    }
                }
            }
        }
        self.swizzled_add(request, withCompletionHandler: completionHandler)
    }
}
```
In `application(_:didFinishLaunchingWithOptions:)` in `AppDelegate.swift`, the swizzle is registered via `_ = UNUserNotificationCenter.swizzleAdd`.

### AVAudioSession Initialization
To configure the system-wide audio session category to `playback` when an alarm sound plays (essential for background play and silent bypass fallback), we leverage the global `AudioContext` from `audioplayers`:

```dart
  /// Configures the iOS audio session for background playback and critical alert audio playback.
  Future<void> configureAudioSessionForPlayback() async {
    if (kIsWeb) return;
    if (Platform.isIOS) {
      try {
        final audioScope = AudioPlayer.global;
        final audioContext = AudioContext(
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
            options: {
              AVAudioSessionOptions.mixWithOthers,
              AVAudioSessionOptions.duckOthers,
            },
          ),
          android: const AudioContextAndroid(
            stayAwake: true,
            contentType: AndroidContentType.music,
            usageType: AndroidUsageType.alarm,
            audioFocus: AndroidAudioFocus.gainTransient,
          ),
        );
        await audioScope.setAudioContext(audioContext);
        debugPrint('AVAudioSession initialized in playback mode for iOS.');
      } catch (e) {
        debugPrint('Error configuring AVAudioSession: $e');
      }
    }
  }
```

---

## 3. macOS: Time-Sensitive Notifications Support

macOS 12.0+ supports Time-Sensitive notifications. To enable this, we schedule the macOS notification with `interruptionLevel: InterruptionLevel.timeSensitive` in `DarwinNotificationDetails` for macOS:

```dart
    final macOSDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
      presentBadge: true,
      presentBanner: true,
      presentList: true,
      sound: soundName != null && soundName.isNotEmpty ? '$soundName.caf' : null,
      categoryIdentifier: 'medicaixa_alarm_category',
      interruptionLevel: InterruptionLevel.timeSensitive, // macOS Time-Sensitive Alert
    );
```

---

## 4. Platform-Conditional Safety and Compile-Safe Implementation

- **Compile Safety**: We utilize standard platform enums and models (`DarwinNotificationDetails`, `InterruptionLevel`, `Importance`, `Priority`, `AudioContextIOS`, `AVAudioSessionCategory`, etc.) which are declared in `flutter_local_notifications` and `audioplayers` for all target platforms, eliminating any compile-time exceptions or target-specific conditional compilation imports.
- **Runtime safety**: Standard runtime platform checks (`kIsWeb`, `Platform.isAndroid`, `Platform.isIOS`) ensure that setup code specific to particular operating systems (like requesting android permissions or setting iOS `AVAudioSession` properties) are guarded and safely skipped on unsupported environments.

---

## 5. Proposed Modifications to `lib/core/services/notification_service.dart`

Below is the complete proposed code modification for `lib/core/services/notification_service.dart`.

```dart
<<<<
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
====
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:audioplayers/audioplayers.dart';

class NotificationService {
>>>>
```

```dart
<<<<
  Future<void> init() async {
    if (_initialized) return;

    // 1. Initialize Timezone Database
    await _configureLocalTimeZone();

    // 2. Configure Android Initialization Settings
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // 3. Configure Darwin (iOS / macOS) Initialization Settings
    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    // 4. Combine Initialization Settings
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
      macOS: initializationSettingsDarwin,
    );

    // 5. Initialize the plugin
    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onDidReceiveNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: _onDidReceiveBackgroundNotificationResponse,
    );

    // 6. Request Android permissions if Android 13+
    if (Platform.isAndroid) {
      await _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }

    _initialized = true;
    debugPrint('NotificationService initialized successfully.');
  }
====
  Future<void> init() async {
    if (_initialized) return;

    // 1. Initialize Timezone Database
    await _configureLocalTimeZone();

    // 2. Configure Android Initialization Settings
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // 3. Configure Darwin (iOS / macOS) Initialization Settings
    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      requestCriticalPermission: true, // Request Critical Alert permission for iOS
    );

    // 4. Combine Initialization Settings
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
      macOS: initializationSettingsDarwin,
    );

    // 5. Initialize the plugin
    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onDidReceiveNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: _onDidReceiveBackgroundNotificationResponse,
    );

    // 6. Request Android permissions if Android 13+
    if (Platform.isAndroid) {
      final androidPlugin = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        await androidPlugin.requestNotificationsPermission();

        // Initialize Android notification channel with maximum priority/importance and audio attributes
        const AndroidNotificationChannel channel = AndroidNotificationChannel(
          'medicaixa_alarms_channel',
          'MediCaixa Alarmes',
          description: 'Canal de notificações para alarmes de medicamentos',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          showBadge: true,
          audioAttributesUsage: AudioAttributesUsage.alarm,
        );
        await androidPlugin.createNotificationChannel(channel);
      }
    }

    _initialized = true;
    debugPrint('NotificationService initialized successfully.');
  }
>>>>
```

```dart
<<<<
    final androidDetails = AndroidNotificationDetails(
      'medicaixa_alarms_channel',
      'MediCaixa Alarmes',
      channelDescription: 'Canal de notificações para alarmes de medicamentos',
      importance: Importance.max,
      priority: Priority.high,
      sound: soundName != null && soundName.isNotEmpty
          ? RawResourceAndroidNotificationSound(soundName)
          : null,
      playSound: true,
      enableVibration: true,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
    );

    final darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
      presentBadge: true,
      sound: soundName != null && soundName.isNotEmpty ? '$soundName.caf' : null,
      categoryIdentifier: 'medicaixa_alarm_category',
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );
====
    final androidDetails = AndroidNotificationDetails(
      'medicaixa_alarms_channel',
      'MediCaixa Alarmes',
      channelDescription: 'Canal de notificações para alarmes de medicamentos',
      importance: Importance.max,
      priority: Priority.max, // Maximum priority
      sound: soundName != null && soundName.isNotEmpty
          ? RawResourceAndroidNotificationSound(soundName)
          : null,
      playSound: true,
      enableVibration: true,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
      audioAttributesUsage: AudioAttributesUsage.alarm,
    );

    final iOSDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
      presentBadge: true,
      presentBanner: true,
      presentList: true,
      sound: soundName != null && soundName.isNotEmpty ? '$soundName.caf' : null,
      categoryIdentifier: 'medicaixa_alarm_category',
      interruptionLevel: InterruptionLevel.critical, // Critical Alert for iOS
    );

    final macOSDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
      presentBadge: true,
      presentBanner: true,
      presentList: true,
      sound: soundName != null && soundName.isNotEmpty ? '$soundName.caf' : null,
      categoryIdentifier: 'medicaixa_alarm_category',
      interruptionLevel: InterruptionLevel.timeSensitive, // Time-Sensitive for macOS
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iOSDetails,
      macOS: macOSDetails,
    );
>>>>
```

And add the following helper method inside `NotificationService`:
```dart
  /// Configures the iOS audio session for background playback and critical alert audio playback.
  Future<void> configureAudioSessionForPlayback() async {
    if (kIsWeb) return;
    if (Platform.isIOS) {
      try {
        final audioScope = AudioPlayer.global;
        final audioContext = AudioContext(
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
            options: {
              AVAudioSessionOptions.mixWithOthers,
              AVAudioSessionOptions.duckOthers,
            },
          ),
          android: const AudioContextAndroid(
            stayAwake: true,
            contentType: AndroidContentType.music,
            usageType: AndroidUsageType.alarm,
            audioFocus: AndroidAudioFocus.gainTransient,
          ),
        );
        await audioScope.setAudioContext(audioContext);
        debugPrint('AVAudioSession initialized in playback mode for iOS.');
      } catch (e) {
        debugPrint('Error configuring AVAudioSession: $e');
      }
    }
  }
```

This method must be called in `alarm_active_screen.dart` when the sound starts playing:

```dart
  // Inside lib/features/alarms/presentation/alarm_active_screen.dart
  Future<void> _playAlarmSound() async {
    try {
      // 1. Initialize AVAudioSession in playback mode (.playback)
      await NotificationService.instance.configureAudioSessionForPlayback();

      // 2. Play the sound
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.play(UrlSource(
        'https://actions.google.com/sounds/v1/alarms/digital_watch_alarm_long.ogg',
      ));
    } catch (e) {
      debugPrint('Could not play alarm sound: $e. Using system vibration.');
      _triggerPeriodicVibration();
    }
  }
```
