## Review Summary

**Verdict**: REQUEST_CHANGES

The implementation provides a solid structural foundation for native alarm scheduling, critical notifications, and active alarm screens. However, there are critical compile-time and runtime bugs in the native iOS/Android code and DST timezone math that must be resolved before this work can be approved.

---

## Findings

### [Critical] Finding 1: iOS Compilation and Plugin Registration Failure
- **What**: The iOS `AppDelegate.swift` conforms to a non-existent protocol and misses standard plugin registration.
- **Where**: `ios/Runner/AppDelegate.swift` (Lines 6, 17-19)
- **Why**: 
  1. `FlutterImplicitEngineDelegate` and `didInitializeImplicitFlutterEngine` are not present in the Flutter iOS SDK (these are macOS-only concepts). This will fail to compile on iOS.
  2. The required call `GeneratedPluginRegistrant.register(with: self)` is missing from `application(_:didFinishLaunchingWithOptions:)`. Without this, none of the Flutter plugins (like SQLite/Drift, Dio, audioplayers, local notifications) will be registered at runtime on iOS, causing immediate runtime crashes (e.g. `MissingPluginException`).
- **Suggestion**: Change `AppDelegate.swift` back to the standard iOS template, trigger swizzling, and register plugins on launch:
  ```swift
  import Flutter
  import UIKit
  import UserNotifications

  @UIApplicationMain
  @objc class AppDelegate: FlutterAppDelegate {
    override func application(
      _ application: UIApplication,
      didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
      // Trigger swizzling of UNUserNotificationCenter
      _ = UNUserNotificationCenter.swizzleAdd
      
      GeneratedPluginRegistrant.register(with: self)
      return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
  }
  ```

### [Major] Finding 2: Android Wake Lock & Screen-On Timeout Bug
- **What**: Modern Android devices will not keep the screen awake while the active alarm is showing.
- **Where**: `android/app/src/main/kotlin/com/medicaixa/medicaixa_app/MainActivity.kt` (Lines 12-22)
- **Why**: 
  The window flag `WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON` is only added in the `else` block (for API < 27 / Android 8.1). For modern devices (API >= 27), the code calls `setShowWhenLocked(true)` and `setTurnScreenOn(true)` but fails to set the keep-screen-on flag. As a result, the screen will turn on when an alarm triggers but will sleep/turn off shortly after the system timeout (e.g., 15 seconds) while the alarm is still actively ringing, potentially hiding the UI from the user.
- **Suggestion**: Ensure `FLAG_KEEP_SCREEN_ON` is set for all API versions:
  ```kotlin
  override fun onCreate(savedInstanceState: Bundle?) {
      super.onCreate(savedInstanceState)
      
      // Keep screen on for all versions
      window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
      
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
          setShowWhenLocked(true)
          setTurnScreenOn(true)
      } else {
          @Suppress("DEPRECATION")
          window.addFlags(
              WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
              WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
          )
      }
  }
  ```

### [Major] Finding 3: Daylight Saving Time (DST) Timezone Shift Bug
- **What**: Timezone scheduling math uses physical duration instead of calendar days.
- **Where**: `lib/core/services/notification_service.dart` (Line 249)
- **Why**: 
  In `_nextInstanceOfWeekdayTime`, the code increments the date using `scheduledDate.add(const Duration(days: 1))`. Since `Duration(days: 1)` is physically exactly 86,400 seconds (24 hours), it does not account for DST transitions where days can have 23 or 25 hours. When crossing a DST transition boundary, the alarm schedule hour will shift by +/- 1 hour in local time.
- **Suggestion**: Increment the date by advancing the calendar day component in the `TZDateTime` constructor instead of adding a physical 24-hour duration:
  ```dart
  scheduledDate = tz.TZDateTime(
    tz.local,
    scheduledDate.year,
    scheduledDate.month,
    scheduledDate.day + 1,
    scheduledDate.hour,
    scheduledDate.minute,
  );
  ```

### [Minor] Finding 4: Android Custom Sound File Extension Danger
- **What**: Android raw resource sound mapping does not strip extensions.
- **Where**: `lib/core/services/notification_service.dart` (Line 136)
- **Why**: 
  Android raw resource lookups (`RawResourceAndroidNotificationSound`) expect the resource name *without* any file extension (e.g. `alarm_beep` instead of `alarm_beep.wav`). If a custom `soundName` containing an extension (e.g. `custom.wav`) is passed, Android will fail to resolve the resource, failing to play the sound.
- **Suggestion**: Sanitize the sound name for Android by stripping file extensions:
  ```dart
  final String androidSoundName = activeSound.split('.').first;
  // then use RawResourceAndroidNotificationSound(androidSoundName)
  ```

### [Minor] Finding 5: Active Alarm Screen Vibration Leak
- **What**: Haptic vibration loop can leak and run indefinitely if the widget remains mounted but inactive.
- **Where**: `lib/features/alarms/presentation/alarm_active_screen.dart` (Lines 100-108)
- **Why**: 
  The asynchronous loop `_triggerPeriodicVibration()` uses `context.mounted` as its escape condition. If the screen is hidden, preserved in navigation history, or placed in a persistent stack without being fully unmounted, `context.mounted` will remain `true`, causing the phone to vibrate and beep indefinitely.
- **Suggestion**: Use a class-level state boolean like `bool _isRinging = true;` to control the loop:
  ```dart
  // In State class
  bool _isRinging = true;

  @override
  void dispose() {
    _isRinging = false;
    _audioPlayer.dispose();
    ...
  }

  void _triggerPeriodicVibration() {
    Future.doWhile(() async {
      if (!_isRinging || !context.mounted) return false;
      HapticFeedback.vibrate();
      SystemSound.play(SystemSoundType.alert);
      await Future.delayed(const Duration(seconds: 2));
      return _isRinging && context.mounted;
    });
  }
  ```

---

## Verified Claims

- **Analysis and Tests Pass** → verified via `flutter analyze` and `flutter test` → **PASS** (109/109 tests passed successfully, no analysis lint warnings or errors).
- **Sound Assets Exist** → verified via filesystem search → **PASS** (`alarm_beep.wav` exists in `assets/sounds/`, `android/app/src/main/res/raw/`, `ios/Runner/`, and `macos/Runner/`).
- **macOS App Nap Prevention** → verified via checking implementation of `com.medicaixa.app/app_nap` in `macos/Runner/AppDelegate.swift` → **PASS**.

---

## Coverage Gaps

- **App Store Submission Risk** — risk level: **medium** — recommendation: **accept risk with disclosure**. The iOS `UNUserNotificationCenter` swizzling uses key-value coding (`value(forKey: "soundFileName")`) to access private properties of `UNNotificationSound`. This is necessary due to iOS framework limitations on custom critical notification sounds, but poses a small risk of App Store submission rejection.

---

## Unverified Items

- **Physical device background lockscreen overlays** — reason not verified: Physical testing requires actual Apple/Android device deployment, which cannot be automated in this test environment.
