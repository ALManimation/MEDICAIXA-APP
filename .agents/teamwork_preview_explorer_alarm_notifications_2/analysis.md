# iOS and macOS Native Alarm and Sound Integration Analysis

## 1. Executive Summary
This analysis outlines the architecture, configuration, and implementation requirements for native alarm notifications and background sound playback on iOS and macOS for the MediCaixa App. 

Key findings show that while the `flutter_local_notifications` plugin supports scheduling notifications and requests basic permissions, it lacks direct support for native iOS/macOS Critical Alert sounds (bypassing DND/mute switch). To resolve this, the app requires:
1. **Critical Alerts Entitlement Setup**: Declaring the entitlement and requesting it in initialization.
2. **Custom Swift Bridge (Method Channel)**: Direct scheduling using `UNUserNotificationCenter` in Swift to call `UNNotificationSound.criticalSoundNamed(_:withAudioVolume:)`.
3. **Background Audio Session Fallback**: Configuring `AVAudioSession` category to `.playback` using the `audioplayers` package when the app is active in foreground/background.
4. **Local Sound Assets**: Moving away from external URL playback to local assets.

---

## 2. Identified Files to Modify
The following configuration and source files must be modified to support advanced alarm, background audio, and notification features on iOS and macOS:

| File Path | Description | Required Changes |
|---|---|---|
| `ios/Runner/Info.plist` | iOS App Manifest | Add `UIBackgroundModes` (`audio` and `fetch`) to allow background audio session playing. |
| `ios/Runner/Runner.entitlements` | iOS Entitlements (New File) | Add the `com.apple.developer.usernotifications.critical-alerts` key to support Critical Alerts. |
| `macos/Runner/Info.plist` | macOS App Manifest | Add `NSUserNotificationAlertStyle` with value `alert` to ensure notifications persist. |
| `macos/Runner/DebugProfile.entitlements` | macOS Debug Entitlements | Add the `com.apple.developer.usernotifications.critical-alerts` key. |
| `macos/Runner/Release.entitlements` | macOS Release Entitlements | Add the `com.apple.developer.usernotifications.critical-alerts` key. |
| `lib/core/services/notification_service.dart` | Notification Service (Dart) | Enable `requestCriticalPermission: true` on iOS and `InterruptionLevel.critical` for alarm events. |
| `lib/features/alarms/presentation/alarm_active_screen.dart` | Alarm Ringing UI (Dart) | Configure `_audioPlayer` using `setAudioContext` (playback category) and play from local assets instead of remote URLs. |
| `pubspec.yaml` | Flutter Project Configuration | Bundle local alarm sound assets (e.g., `assets/sounds/alarm.mp3`). |

---

## 3. iOS Integration Requirements

### A. Critical Alerts & Permissions
Critical alerts require authorization from Apple (`com.apple.developer.usernotifications.critical-alerts`). Once approved:
1. Create `ios/Runner/Runner.entitlements` and populate it:
   ```xml
   <?xml version="1.0" encoding="UTF-8"?>
   <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
   <plist version="1.0">
   <dict>
       <key>com.apple.developer.usernotifications.critical-alerts</key>
       <true/>
   </dict>
   </plist>
   ```
2. Configure Xcode project build settings to map this file:
   `CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements`
3. Request critical alert permission in Dart:
   ```dart
   const DarwinInitializationSettings initializationSettingsDarwin =
       DarwinInitializationSettings(
     requestAlertPermission: true,
     requestBadgePermission: true,
     requestSoundPermission: true,
     requestCriticalPermission: true, // Crucial for Critical Alerts
   );
   ```

### B. Background Modes (Audio & Fetch)
Add `UIBackgroundModes` to `ios/Runner/Info.plist`:
```xml
<key>UIBackgroundModes</key>
<array>
	<string>audio</string>
	<string>fetch</string>
</array>
```
*   `audio`: Allows the app to continue playing sound in the background via `AVAudioSession` when the screen is locked or the app is closed.
*   `fetch`: Wakes up the app periodically to sync alarm states or fetch updates from the local ESP32 device.

### C. AVAudioSession & Audio Players Fallback
To ensure that sound plays even when the device is set to silent/mute, the active audio player context must be configured to use the `.playback` category before audio starts.

In `lib/features/alarms/presentation/alarm_active_screen.dart`:
```dart
Future<void> _playAlarmSound() async {
  try {
    // 1. Configure the audio session category to playback
    await _audioPlayer.setAudioContext(
      AudioContext(
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
          options: {
            AVAudioSessionOptions.defaultToSpeaker,
            AVAudioSessionOptions.mixWithOthers,
          },
        ),
        android: AudioContextAndroid(
          isSpeakerphoneOn: true,
          stayAwake: true,
          contentType: AndroidContentType.music,
          usageType: AndroidUsageType.alarm,
          audioFocus: AndroidAudioFocus.gainTransientMayDuck,
        ),
      ),
    );

    // 2. Play from local assets rather than external URL
    await _audioPlayer.setReleaseMode(ReleaseMode.loop);
    await _audioPlayer.play(AssetSource('sounds/alarm.mp3'));
  } catch (e) {
    debugPrint('Could not play alarm sound: $e. Using system vibration.');
    _triggerPeriodicVibration();
  }
}
```

### D. Critical Sound Limitation & Solution
Analysis of the `flutter_local_notifications` v18.0.1 source code (`FlutterLocalNotificationsPlugin.m:685`) shows that the plugin only uses `[UNNotificationSound soundNamed:]` when setting notification sounds.
It **does not** call `[UNNotificationSound criticalSoundNamed:withAudioVolume:]`.

#### Proposed Native Swift Solution
To deliver true critical alerts that bypass Do Not Disturb (DND) and the physical mute switch at the OS level, we can implement a lightweight Swift Method Channel in `AppDelegate.swift`:
```swift
import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
    let alarmChannel = FlutterMethodChannel(name: "com.medicaixa.app/critical_alarms",
                                              binaryMessenger: controller.binaryMessenger)
    
    alarmChannel.setMethodCallHandler({
      (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      if call.method == "scheduleCriticalAlarm" {
        self.scheduleCriticalNotification(arguments: call.arguments, result: result)
      } else {
        result(FlutterMethodNotImplemented)
      }
    })
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func scheduleCriticalNotification(arguments: Any?, result: @escaping FlutterResult) {
    guard let args = arguments as? [String: Any],
          let id = args["id"] as? Int,
          let title = args["title"] as? String,
          let body = args["body"] as? String,
          let hour = args["hour"] as? Int,
          let minute = args["minute"] as? Int,
          let soundName = args["soundName"] as? String else {
      result(FlutterMethodError(code: "INVALID_ARGUMENTS", message: "Missing fields", details: nil))
      return
    }

    let content = UNMutableNotificationContent()
    content.title = title
    content.body = body
    
    // Set interruption level to critical (iOS 15+)
    if #available(iOS 15.0, macOS 12.0, *) {
      content.interruptionLevel = .critical
    }
    
    // Set critical sound bypassing mute switch
    content.sound = UNNotificationSound.criticalSoundNamed(UNNotificationSoundName(rawValue: soundName), withAudioVolume: 1.0)
    
    var dateComponents = DateComponents()
    dateComponents.hour = hour
    dateComponents.minute = minute
    
    let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
    let request = UNNotificationRequest(identifier: "medicaixa_critical_alarm_\(id)", content: content, trigger: trigger)
    
    UNUserNotificationCenter.current().add(request) { error in
      if let error = error {
        result(FlutterError(code: "SCHEDULING_FAILED", message: error.localizedDescription, details: nil))
      } else {
        result(true)
      }
    }
  }
}
```

---

## 4. macOS Integration Requirements

### A. Entitlements Configuration
Since macOS applications run in an App Sandbox, update `macos/Runner/DebugProfile.entitlements` and `Release.entitlements` to include both network clients/servers (already present) and the Critical Alerts capability:
```xml
<key>com.apple.developer.usernotifications.critical-alerts</key>
<true/>
```

### B. Persistent Notifications style
By default, macOS notifications fade away after a few seconds. For medical alarms, we need them to behave like modal alerts that require user interaction to dismiss.
In `macos/Runner/Info.plist`, add:
```xml
<key>NSUserNotificationAlertStyle</key>
<string>alert</string>
```

### C. Run Loop Preservation (App Nap Prevention)
macOS uses **App Nap** to freeze applications that are hidden behind other windows or have no visible window. This will cause timers and network sync checks to fail.
To prevent this, the Swift Runner should start a process activity assertion when an alarm is active:
```swift
// In macOS AppDelegate.swift
private var activityToken: NSObjectProtocol?

func disableAppNap() {
    if activityToken == nil {
        activityToken = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiated, .idleSystemSleepDisabled],
            reason: "Playing urgent medicine alarm sound and syncing data"
        )
    }
}

func enableAppNap() {
    if let token = activityToken {
        ProcessInfo.processInfo.endActivity(token)
        activityToken = nil
    }
}
```

---

## 5. Proposed Code and Asset Layout

### Sound Assets Mapping
Sound files must be mapped and loaded natively in the target directories to be accessible by `UNUserNotificationCenter` and `AVAudioSession`:

*   **Flutter Assets**: `assets/sounds/alarm.mp3` (configured in `pubspec.yaml`).
*   **iOS App Bundle**: `ios/Runner/alarm.caf` (add resource to Xcode Runner project target).
*   **macOS App Bundle**: `macos/Runner/alarm.caf` (add resource to Xcode Runner project target).
*   **Android Raw Assets**: `android/app/src/main/res/raw/alarm.mp3`.

---

## 6. Engineering Plan Section: iOS/macOS Integration

The following content is designed to be integrated into `docs/integration_plan.md`:

```markdown
## Platform Integration: iOS & macOS

### 1. Requirements Checklist
- [ ] iOS Background Audio Mode (`UIBackgroundModes: audio`) enabled.
- [ ] iOS Background Fetch Mode (`UIBackgroundModes: fetch`) enabled.
- [ ] iOS Entitlement `com.apple.developer.usernotifications.critical-alerts` requested and mapped via `Runner.entitlements`.
- [ ] macOS Entitlement `com.apple.developer.usernotifications.critical-alerts` enabled in Debug and Release profiles.
- [ ] macOS Notification alert style forced to `alert` via `NSUserNotificationAlertStyle` in `Info.plist`.
- [ ] Alarm sound assets (`alarm.caf`) bundled in iOS and macOS Main App Bundles.

### 2. Notification Initialization and Level Configurations
In `NotificationService` (Dart):
- Enable `requestCriticalPermission: true` on iOS.
- Pass `InterruptionLevel.critical` to `interruptionLevel` inside `DarwinNotificationDetails`.
- Sound filename mapped to `alarm.caf`.

### 3. AVAudioSession Background Audio Fallback Flow
To ensure alarms ring even on silent or background states:
1. When alarm is triggered, Dart invokes `AudioPlayer.setAudioContext` setting the iOS audio session category to `playback` and options to `defaultToSpeaker`.
2. Play the local asset sound on loop.
3. If the app is suspended, the native `UNUserNotificationCenter` triggers the critical alert.
4. When the user taps the notification, the app loads `AlarmActiveScreen` which continues playing the sound via `AudioPlayer` until the user takes action (Tomado, Adiar, Pular).

### 4. macOS Keep-Alive (App Nap Bypass)
To prevent macOS from throttling or pausing alarm timers:
1. Implement a method channel `com.medicaixa.app/app_nap` in Swift.
2. Dart calls `disableAppNap()` when starting active alarm checks or audio playback.
3. Dart calls `enableAppNap()` when all active alarms have been resolved or snoozed.
```
