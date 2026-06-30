## 2026-06-29T14:42:50Z
You are the Worker. Working directory: /Users/almanimation/Downloads/Caixa Remedios/medicaixa_app/.agents/teamwork_preview_worker_alarm_notifications/
Read the original request in /Users/almanimation/Downloads/Caixa Remedios/medicaixa_app/ORIGINAL_REQUEST.md.

MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A Forensic Auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

Your objective is to implement the native alarm, sound, and notification integration for Android, iOS, and macOS in the MediCaixa App, ensuring 100% offline autonomy and advanced native configurations in 2026.

Here are the step-by-step tasks:

1. Create the Design Plan Document:
Write a comprehensive engineering design document in `docs/integration_plan.md` outlining the architecture, native APIs, entitlements, and fallback strategy using AVAudioSession. Use the findings and recommendations from Explorer 1, 2, and 3:
- Android: AlarmManager, Importance.max channels, fullScreenIntent, wake locks, boot resiliency via ScheduledNotificationBootReceiver.
- iOS: Critical Alerts entitlement, background audio/fetch modes, AVAudioSession fallback.
- macOS: Time-Sensitive alerts, NSUserNotificationAlertStyle, App Nap prevention.

2. Modify Android Platform Config:
- Update `android/app/src/main/AndroidManifest.xml` to include permissions:
  * `android.permission.USE_FULL_SCREEN_INTENT`
  * `android.permission.SCHEDULE_EXACT_ALARM`
  * `android.permission.USE_EXACT_ALARM`
  * `android.permission.WAKE_LOCK`
  * `android.permission.RECEIVE_BOOT_COMPLETED`
  * `android.permission.POST_NOTIFICATIONS`
  * `android.permission.FOREGROUND_SERVICE`
- Add the `<receiver>` tag for `com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver` inside `<application>`.
- Add `android:showWhenLocked="true"` and `android:turnScreenOn="true"` to `.MainActivity` activity tag.
- Update `android/app/src/main/kotlin/com/medicaixa/medicaixa_app/MainActivity.kt` to set windows flags `setShowWhenLocked(true)` and `setTurnScreenOn(true)` programmatically at creation.

3. Modify iOS Platform Config:
- Update `ios/Runner/Info.plist` to add `UIBackgroundModes` containing `audio` and `fetch`.
- Create `ios/Runner/Runner.entitlements` with the key `com.apple.developer.usernotifications.critical-alerts` set to `true`.

4. Modify macOS Platform Config:
- Update `macos/Runner/Info.plist` to include `NSUserNotificationAlertStyle` with value `alert`.
- Update `macos/Runner/DebugProfile.entitlements` and `Release.entitlements` to include `com.apple.developer.usernotifications.critical-alerts` set to `true`.

5. Swift Integrations:
- Update `ios/Runner/AppDelegate.swift`:
  * Add the swizzling code for `UNUserNotificationCenter` to intercept critical alerts (`interruptionLevel == .critical`) and map the sound to a native critical sound `UNNotificationSound.criticalSoundNamed()`.
  * Set up a Flutter Method Channel `com.medicaixa.app/critical_alarms` (or similar) if needed, or simply swizzle to intercept all critical notifications scheduled by the plugin.
- Modify `macos/Runner/AppDelegate.swift`:
  * Implement Method Channel handler `com.medicaixa.app/app_nap` to start/stop macOS ProcessInfo activity assertions when alarms are active to bypass App Nap.

6. Dart NotificationService and UI Updates:
- Update `lib/core/services/notification_service.dart`:
  * Import `package:audioplayers/audioplayers.dart` if needed.
  * In `init()`, configure Android channel with Importance.max and `audioAttributesUsage: AudioAttributesUsage.alarm`, and enable `requestCriticalPermission: true` on iOS Darwin settings.
  * In `scheduleWeeklyAlarm()`, set Android details to Priority.max, `audioAttributesUsage: AudioAttributesUsage.alarm`. Set iOS Darwin details to `interruptionLevel: InterruptionLevel.critical`. Set macOS Darwin details to `interruptionLevel: InterruptionLevel.timeSensitive`.
  * Implement `configureAudioSessionForPlayback()` helper that sets the global `AudioContext` from `audioplayers` with `AVAudioSessionCategory.playback` on iOS.
- Update `lib/features/alarms/presentation/alarm_active_screen.dart`:
  * Call `NotificationService.instance.configureAudioSessionForPlayback()` before playing sound in `_playAlarmSound()`.
  * Create a fallback beep or use local/remote sounds gracefully.

7. Verification:
- Run `flutter analyze` to verify that code has no static analysis errors.
- Run `flutter test` to verify that all existing tests pass successfully.
- Record the results of these commands in your handoff report.

Write your final status and verification output to `handoff.md` in your directory. Notify the parent orchestrator when complete.
