# Handoff Report - Explorer 3

## 1. Observation
- Target source file: `lib/core/services/notification_service.dart`.
- The current implementation of `init()` in `lib/core/services/notification_service.dart` does not pre-create notification channels on Android and only requests basic permissions:
  ```dart
  // line 28
  const DarwinInitializationSettings initializationSettingsDarwin =
      DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );
  ```
  ```dart
  // line 50
  if (Platform.isAndroid) {
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }
  ```
- The current implementation of `scheduleWeeklyAlarm()` in `lib/core/services/notification_service.dart` configures basic `AndroidNotificationDetails` and a shared `DarwinNotificationDetails` for iOS and macOS:
  ```dart
  // line 109
  final androidDetails = AndroidNotificationDetails(
    'medicaixa_alarms_channel',
    'MediCaixa Alarmes',
    channelDescription: 'Canal de notificações para alarmes de medicamentos',
    importance: Importance.max,
    priority: Priority.high,
    // ...
  ```
  ```dart
  // line 124
  final darwinDetails = DarwinNotificationDetails(
    presentAlert: true,
    presentSound: true,
    presentBadge: true,
    sound: soundName != null && soundName.isNotEmpty ? '$soundName.caf' : null,
    categoryIdentifier: 'medicaixa_alarm_category',
  );
  ```
- The `flutter_local_notifications` package does not natively expose `UNNotificationSound.criticalSoundNamed` in its Dart API, as observed in `/Users/almanimation/.pub-cache/hosted/pub.dev/flutter_local_notifications-18.0.1/ios/Classes/FlutterLocalNotificationsPlugin.m` line 685:
  ```objc
  content.sound = [UNNotificationSound soundNamed:platformSpecifics[SOUND]];
  ```
- The `audioplayers` package (v6.8.1) exposes a global `AudioScope` configuration API (`AudioPlayer.global.setAudioContext(AudioContext ctx)`), as observed in `/Users/almanimation/.pub-cache/hosted/pub.dev/audioplayers-6.8.1/lib/src/audioplayer.dart` line 21:
  ```dart
  static final global = GlobalAudioScope();
  ```
- The project test command `flutter test` completes successfully with 109 tests passing.

---

## 2. Logic Chain
- **Requirement 1 (Android Channel & Zoned Schedule)**: To ensure max priority/importance, we must pre-create the notification channel during `init()` using `resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel()` with `Importance.max` and `audioAttributesUsage: AudioAttributesUsage.alarm`. In `scheduleWeeklyAlarm()`, we must specify `priority: Priority.max` and `audioAttributesUsage: AudioAttributesUsage.alarm` in `AndroidNotificationDetails` along with the existing `fullScreenIntent: true` to trigger lock screen alerts.
- **Requirement 2 (iOS Critical Alerts)**: To request iOS critical alert permissions, we must configure `requestCriticalPermission: true` inside `DarwinInitializationSettings` in `init()`. When scheduling alarms, we must assign `interruptionLevel: InterruptionLevel.critical` in `DarwinNotificationDetails` for iOS.
- **Requirement 3 (UNNotificationSound.criticalSoundNamed bypass)**: Because `flutter_local_notifications` does not support `UNNotificationSound.criticalSoundNamed` out-of-the-box, we must swizzle `UNUserNotificationCenter`'s `add(_:withCompletionHandler:)` in Swift (`AppDelegate.swift`) to copy and map the notification payload to a critical alert sound whenever the request contains `interruptionLevel == .critical`.
- **Requirement 4 (AVAudioSession Playback Mode)**: In order to initialize `AVAudioSession` in playback mode on iOS when a sound plays (necessary for background audio bypass), we can invoke `AudioPlayer.global.setAudioContext(...)` with category set to `AVAudioSessionCategory.playback`. Exposing this as a helper method `configureAudioSessionForPlayback()` in `NotificationService` allows `alarm_active_screen.dart` to trigger it.
- **Requirement 5 (macOS Time-Sensitive Notifications)**: To support Time-Sensitive alerts on macOS, we configure separate `DarwinNotificationDetails` for macOS with `interruptionLevel: InterruptionLevel.timeSensitive`.
- **Requirement 6 (Platform Conditional & Compile Safety)**: Guarding OS-specific calls using `Platform.isAndroid` and `Platform.isIOS` checks at runtime ensures safety, while referencing standard cross-platform Dart APIs from `flutter_local_notifications` and `audioplayers` ensures compile-safety across all targets.

---

## 3. Caveats
- Bypassing do-not-disturb (DND) and volume levels natively on iOS via `UNNotificationSound.criticalSoundNamed` requires the app to be signed with the *Critical Alerts Entitlement* from Apple. Without it, iOS will reject the critical alert scheduling or fallback to normal alerts.

---

## 4. Conclusion
The proposed changes to `lib/core/services/notification_service.dart` cleanly address all requirements:
1. Initialize the Android notification channel with `Importance.max` and `audioAttributesUsage: AudioAttributesUsage.alarm`.
2. Modify `scheduleWeeklyAlarm` to use `Priority.max` on Android, separate iOS details with `interruptionLevel: InterruptionLevel.critical`, and macOS details with `interruptionLevel: InterruptionLevel.timeSensitive`.
3. Request critical notification permissions on iOS initialization (`requestCriticalPermission: true`).
4. Implement `configureAudioSessionForPlayback()` inside `NotificationService` utilizing `AudioPlayer.global.setAudioContext(...)` to set the playback audio category.
5. Apply a Swift swizzle in `AppDelegate.swift` to handle native mapping of scheduled critical sounds to `UNNotificationSound.criticalSoundNamed(...)`.

---

## 5. Verification Method
- Execute `flutter analyze` to ensure there are no compilation errors or lint issues after code application.
- Execute `flutter test` to verify that all existing tests continue to pass.
- Manually run the application on Android, iOS, or macOS simulators/devices to verify that notifications are scheduled without runtime crashes.
