## Challenge Summary

**Overall risk assessment**: MEDIUM

While the application compiles without warnings (`flutter analyze` shows zero issues) and the existing test suite passes 100% (109 tests run successfully), our adversarial review has identified several edge-case scenarios where the notification scheduling and active alarm alert playback could fail, crash, or fail silently under runtime constraint pressures.

---

## Challenges

### [High] Challenge 1: Android 12+ (SDK 31+) Exact Alarm Permission Crash and Blocked Rescheduling Loop
- **Assumption challenged**: The service assumes calling `zonedSchedule` with `AndroidScheduleMode.alarmClock` will always succeed on Android if general notifications permission is granted.
- **Attack scenario**: On Android 12+, scheduling exact alarms requires user permission (`SCHEDULE_EXACT_ALARM`). If this permission is not granted or is revoked by the user, `zonedSchedule` throws a `PlatformException` (SecurityException). Because there is no error handling inside `NotificationService.scheduleWeeklyAlarm`, this exception propagates.
  
  In `AlarmEngine._rescheduleAllNotifications`, scheduling is performed sequentially inside a `for` loop wrapped in a single global `try-catch` block:
  ```dart
  try {
    await notificationService.cancelAllNotifications();
    for (final alarm in alarms) {
      ...
      await notificationService.scheduleWeeklyAlarm(...);
    }
  } catch (e) {
    debugPrint('Error rescheduling notifications: $e');
  }
  ```
  If any alarm fails to schedule (e.g. the first one in the list), the exception propagates out, the loop terminates immediately, and **all subsequent alarms** will not have their notifications scheduled.
- **Blast radius**: High. A single exception stops the scheduling of all remaining active alarms.
- **Mitigation**:
  1. Wrap the call to `scheduleWeeklyAlarm` inside `AlarmEngine._rescheduleAllNotifications`'s loop body in a separate `try-catch` block, ensuring that an error scheduling one alarm does not cancel the scheduling of the rest.
  2. Implement checking of exact alarm permissions using the platform specific implementation of the notifications plugin or a permission handler before scheduling.
  3. Catch exceptions inside `scheduleWeeklyAlarm` and fall back to `AndroidScheduleMode.exactAllowWhileIdle` or `AndroidScheduleMode.inexactAllowWhileIdle` if the exact alarm clock mode throws a `SecurityException`.

### [Medium] Challenge 2: Asset Sound Playback Failures Coupled with Offline Fallback Pitfalls
- **Assumption challenged**: If the local sound file fails to play, the player will successfully fall back to playing from a remote URL.
- **Attack scenario**: In `AlarmActiveScreen._playAlarmSound()`, if `_audioPlayer.play(AssetSource('sounds/alarm_beep.wav'))` throws an exception, the app catches it and attempts to play:
  `await _audioPlayer.play(UrlSource('https://actions.google.com/sounds/v1/alarms/digital_watch_alarm_long.ogg'))`.
  
  However, MediCaixa is designed to be **offline-first** (functioning standalone without the box/internet). If the device is offline, resolving the remote URL host will throw a network exception or timeout. This exception will propagate out of the inner catch (since it's not wrapped in a nested try-catch) to the outer try-catch, triggering haptics/vibration. While the haptics/vibration loop is a good fallback, there will be a latency before it starts (waiting for the remote attempt to fail), and the alarm will run with zero audio.
- **Blast radius**: Medium. User receives no audio alerts, only vibrations. If haptics/vibration are unsupported or fail, the alarm becomes fully silent.
- **Mitigation**:
  1. Replace the remote URL fallback with a local fallback sound (e.g., standard OS notification/alarm beep sound).
  2. Start the haptics/vibration loop immediately and concurrently with the sound play attempts, rather than waiting for both sound attempts to fail.

### [Medium] Challenge 3: Uncaught Exceptions in Fallback Alert Loop
- **Assumption challenged**: The periodic vibration and beep loop in `_triggerPeriodicVibration()` will execute indefinitely until the active screen is dismissed.
- **Attack scenario**:
  ```dart
  void _triggerPeriodicVibration() {
    Future.doWhile(() async {
      if (!context.mounted) return false;
      HapticFeedback.vibrate();
      SystemSound.play(SystemSoundType.alert);
      await Future.delayed(const Duration(seconds: 2));
      return context.mounted;
    });
  }
  ```
  If the platform does not support haptics (e.g., macOS desktop builds, simulated environments, or custom Android ROMs without vibration motors) or if the system sound channel is not initialized, `HapticFeedback.vibrate()` or `SystemSound.play(...)` may throw a `PlatformException` or `MissingPluginException`. Because the loop body in `Future.doWhile` is not wrapped in a `try-catch`, any thrown exception will crash the future chain, immediately halting the backup vibration loop.
- **Blast radius**: Medium. The fallback alert system will fail silently and permanently stop vibrating or beeping if a single call fails.
- **Mitigation**: Wrap the calls to `HapticFeedback.vibrate()` and `SystemSound.play()` inside the `Future.doWhile` loop in a `try-catch` block so that failures are logged but the periodic loop continues to run.

---

## Stress Test Results

- **Scenario 1: Android 12+ missing Exact Alarm permission**
  - Expected behavior: Application degrades gracefully by requesting permission or falling back to inexact alarms; remaining notifications are scheduled.
  - Actual/Predicted behavior: `zonedSchedule` throws `SecurityException`, which bubbles up, halts the rescheduling loop, and leaves all subsequent alarms unscheduled in the OS.
  - Result: **FAIL**

- **Scenario 2: Playback of local sound asset throws an exception while offline**
  - Expected behavior: Quick fallback to local backup beep or immediate vibration loop start.
  - Actual/Predicted behavior: Player blocks trying to resolve `https://actions.google.com/` remote URL, throws network exception/timeout after a delay, and then falls back to vibration.
  - Result: **FAIL (High Latency & Silent Alarm)**

- **Scenario 3: Vibration loop runs on macOS desktop (unsupported haptics)**
  - Expected behavior: Haptics do nothing; system alert plays periodically.
  - Actual/Predicted behavior: If any method throws a `MissingPluginException` or `PlatformException`, the loop halts entirely and stops alerting.
  - Result: **FAIL (Brittle Fallback)**

- **Scenario 4: Audio session category configuration on macOS Desktop**
  - Expected behavior: Catches platform errors gracefully and uses default desktop audio output.
  - Actual/Predicted behavior: Correct. `AudioPlayer.global.setAudioContext` throws an exception on macOS which is caught and logged, allowing playback to continue gracefully.
  - Result: **PASS**

---

## Unchallenged Areas

- **Platform Native Implementations** — Out of scope. We reviewed Dart/Flutter bindings only; we did not examine the underlying Objective-C/Swift and Java/Kotlin plugin source code.
