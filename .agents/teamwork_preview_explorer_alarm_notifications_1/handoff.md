# Handoff Report — Android Native Alarm & Sound Integration

This handoff report summarizes the analysis and configurations designed for Android's native alarm, sound, and notification integration. All analysis and proposed code structures have been recorded in the local directory's `analysis.md`.

## 1. Observation
* **Current Permissions (`AndroidManifest.xml`)**: The manifest only contains basic network permissions:
  ```xml
  2:     <uses-permission android:name="android.permission.CHANGE_WIFI_MULTICAST_STATE"/>
  3:     <uses-permission android:name="android.permission.ACCESS_WIFI_STATE"/>
  4:     <uses-permission android:name="android.permission.INTERNET"/>
  ```
* **MainActivity (`MainActivity.kt`)**: The main activity class is a default blank skeleton:
  ```kotlin
  5: class MainActivity : FlutterActivity()
  ```
* **Existing Notification Setup (`lib/core/services/notification_service.dart`)**:
  * Line 120 sets `fullScreenIntent: true`, but the project lacks the necessary manifest permission and activity flags for it to function when the device is locked.
  * No runtime permission requests exist in Dart for exact alarms or custom boot configuration.

## 2. Logic Chain
1. **Lock-Screen Launch**: For `AlarmActiveScreen` to render over the lock screen, `fullScreenIntent` must be set to `true` (as in `notification_service.dart`), the manifest must declare `USE_FULL_SCREEN_INTENT`, and the activity must have `showWhenLocked="true"` and `turnScreenOn="true"` properties.
2. **Exact Alarm Timing**: Exact alarms require scheduling through Android's `AlarmManager`. This requires declaring `SCHEDULE_EXACT_ALARM` in the manifest and requesting it at runtime (Android 14+ / API 34). Declaring `USE_EXACT_ALARM` is an alternative for automatic approval on Android 13+ but risks Google Play Store rejection.
3. **Reboot Resiliency**: `AlarmManager` schedules are cleared on reboot. Declaring `RECEIVE_BOOT_COMPLETED` and registering the `ScheduledNotificationBootReceiver` receiver allows `flutter_local_notifications` to automatically restore alarm schedules on device startup.
4. **Wakelocks**: Declaring `WAKE_LOCK` prevents the CPU from returning to sleep before the alarm sound can finish playing and the UI finishes loading.

## 3. Caveats
* **Google Play Policy**: Using `USE_EXACT_ALARM` is heavily audited by Google. For production releases, we recommend declaring only `SCHEDULE_EXACT_ALARM` and using the runtime dialog.
* **Audio files**: Custom sound files must be added in `android/app/src/main/res/raw/` in order to ring with a custom tone on Android. The directory is currently missing.
* **Android 14+ fullScreenIntent changes**: On Android 14+, the fullScreenIntent permission is disabled by default for non-dialer/non-clock apps, requiring the developer/user to verify settings in some OEMs.

## 4. Conclusion
* The manifest modifications, Kotlin-side window flags, Dart permission check helpers, and the design section for the overall `docs/integration_plan.md` have been fully drafted and detailed in `analysis.md`.
* The proposed changes are complete, self-contained, and ready for integration.

## 5. Verification Method
* **Compilation test**: Run `flutter build apk` (or `flutter build macos` / `flutter analyze`) to verify that the manifest structure is valid and the Dart side compiles.
* **Functional Verification**:
  1. Trigger permission request at app start and verify that the user is prompted for notifications and exact alarms.
  2. Schedule an exact alarm, lock the phone, and check if `AlarmActiveScreen` wakes up the device and displays on top of the lock screen.
  3. Reboot the device and verify that scheduled alarms are correctly restored in the system alarm queue (can be verified via `adb shell dumpsys alarm`).
