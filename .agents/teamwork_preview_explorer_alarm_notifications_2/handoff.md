# Handoff Report — iOS/macOS Native Alarm and Sound Integration

## 1. Observation
The following file structures and properties were directly observed in the codebase:

*   **iOS Manifest**: `ios/Runner/Info.plist` does not contain the `UIBackgroundModes` key, which is required for background audio and background fetch operations.
*   **macOS Entitlements**: `macos/Runner/DebugProfile.entitlements` and `macos/Runner/Release.entitlements` lack critical notification permission keys. No entitlements file exists under `ios/Runner/`.
*   **Notification Service**: `lib/core/services/notification_service.dart` initializes notifications using:
    ```dart
    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    ```
    This lacks the `requestCriticalPermission: true` setting necessary for requesting Critical Alerts on Apple platforms.
*   **Plugin Source Code**: Analysis of the cached `flutter_local_notifications` package source (`/Users/almanimation/.pub-cache/hosted/pub.dev/flutter_local_notifications-18.0.1/ios/Classes/FlutterLocalNotificationsPlugin.m:685`) showed:
    ```objective-c
    content.sound = [UNNotificationSound soundNamed:platformSpecifics[SOUND]];
    ```
    There are no calls to `[UNNotificationSound criticalSoundNamed:withAudioVolume:]` in the iOS implementation of the plugin, meaning `flutter_local_notifications` cannot natively bypass the silent switch for critical alerts.
*   **Ringing UI**: `lib/features/alarms/presentation/alarm_active_screen.dart` attempts to play sound from a remote URL (`https://actions.google.com/sounds/v1/alarms/digital_watch_alarm_long.ogg`) and does not configure the background audio context on `AudioPlayer`.

---

## 2. Logic Chain
1. **Background Modes Requirement**: To allow the app to play alarm audio when in the background or when the device is locked, the `UIBackgroundModes` key must be configured in `Info.plist` with values `audio` and `fetch`.
2. **Critical Alerts Entitlement**: Critical Alerts on iOS/macOS require the `com.apple.developer.usernotifications.critical-alerts` entitlement to bypass Do Not Disturb (DND) and the physical silent switch. This must be declared in the app's entitlements profile.
3. **Plugin Limitation Workaround**: Because `flutter_local_notifications` does not call the Apple critical sound API, true critical notifications must be scheduled using a custom Swift Method Channel in `AppDelegate.swift` which direct-calls `UNNotificationSound.criticalSoundNamed()`.
4. **Audio Session Configuration**: The `audioplayers` fallback player must use the `playback` category with speaker output options (configured as a `Set` to prevent compilation errors) to allow sound to play during background execution.
5. **macOS App Nap Prevention**: macOS App Nap will throttle the background execution of the app when hidden. Bypassing this requires the macOS Swift Runner to call `ProcessInfo.processInfo.beginActivity` during active alarm sequences.

---

## 3. Caveats
*   **Developer Portal Configuration**: Applying the Critical Alerts entitlement (`com.apple.developer.usernotifications.critical-alerts`) requires explicit approval from Apple on the Developer Console. The entitlement will not work on production builds without this.
*   **Audio Assets Requirement**: Local audio files (e.g. `alarm.caf`) must be manually added to Xcode target main bundles to be readable by the OS `UNUserNotificationCenter`.

---

## 4. Conclusion
The proposed design in `analysis.md` provides a complete, robust roadmap for enabling native iOS/macOS alarm notifications, background sound playback, and App Nap bypasses, fully addressing all platform constraints for the MediCaixa App.

---

## 5. Verification Method
1. **Dart Compilation Check**:
   Run `flutter analyze` inside the workspace directory to verify that all proposed Dart adjustments (e.g., in `NotificationService` and `AlarmActiveScreen`) pass static analysis.
2. **Permissions Prompt Verification**:
   Build the app on a simulator or device and verify that the system requests "Critical Alerts" permissions on first launch.
3. **File Inspections**:
   Ensure `ios/Runner/Info.plist` and entitlements files contain the exact keys detailed in `analysis.md`.
