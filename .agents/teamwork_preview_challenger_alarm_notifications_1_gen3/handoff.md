# Handoff Report — Native Alarm Integration

This report presents the findings of the empirical challenge of the native alarm integration, notification scheduling correctness, exception safety, and offline resilience.

---

## 1. Observation

During static code review, test suite execution (`flutter test`), and analysis of local behavior, the following observations were recorded:

### Observation A: Notification ID Partitioning Collision
In `lib/core/services/notification_service.dart`:
* Line 181: Daily/once alarm notifications are scheduled using the alarm's base database `id` as the notification ID:
  ```dart
  await _notificationsPlugin.zonedSchedule(
    id, // Single notification
    ...
  );
  ```
* Line 208: Weekly day-specific notifications are scheduled using an ID computed as `notificationId = id * 10 + dayIndex`:
  ```dart
  final notificationId = id * 10 + dayIndex;
  await _notificationsPlugin.zonedSchedule(
    notificationId,
    ...
  );
  ```
* In `AGENTS.md` Rule 12, it is specified that synchronized server alarms use database IDs in the range `0-255`, whereas local offline alarms use IDs starting at `256`.
* If a synced alarm has database ID `25` (e.g., synchronized from server) and schedules a Saturday notification (`dayIndex = 6`), its Saturday `notificationId` evaluates to:
  $$\text{notificationId} = 25 \times 10 + 6 = 256$$
* If a local alarm has database ID `256` (daily/once), its notification ID evaluates to:
  $$\text{notificationId} = 256$$
* Both schedule intents target the exact same notification ID `256` in `FlutterLocalNotificationsPlugin`, resulting in one overwriting the other.

### Observation B: AVAudioSession Assertion Failure on iOS
In `lib/core/services/notification_service.dart`:
* Lines 285-293: The `configureAudioSessionForPlayback` method attempts to configure the iOS audio context as follows:
  ```dart
  iOS: AudioContextIOS(
    category: AVAudioSessionCategory.playback,
    options: {
      AVAudioSessionOptions.defaultToSpeaker,
      AVAudioSessionOptions.mixWithOthers,
    },
  )
  ```
* Running `flutter test` reports the following assertion error in the logs:
  ```
  Error configuring AudioContext: 'package:audioplayers_platform_interface/src/api/audio_context.dart': Failed assertion: line 223 pos 13: 'category == AVAudioSessionCategory.playAndRecord ||
                  !options.contains(AVAudioSessionOptions.defaultToSpeaker)': You can set the option `defaultToSpeaker` explicitly only if the audio session category is `playAndRecord`.
  ```
* This causes the iOS audio configuration setup to throw, rendering the custom audio context configuration inoperable on iOS platforms.

### Observation C: State Disposal and Async Gap `setState` Crashes
In `lib/features/alarms/presentation/alarm_active_screen.dart`:
* Action handlers `_markTaken()`, `_markSkipped()`, and `_snooze()` contain asynchronous operations:
  * Line 155: `customQty = await DynamicDoseDialog.show(context, alarm);`
  * Line 158: `await repo.markTaken(alarm.id, customQty: customQty);`
  * Line 165: `await repo.markSkipped(alarm.id);`
  * Line 172: `await repo.snoozeAlarm(alarm.id, minutes);`
* None of these action flows check `if (!mounted) return;` or `if (!context.mounted) return;` after their respective `await` statements.
* All three of these flows call `_nextOrDismiss();` which performs a `setState(...)` call:
  ```dart
  void _nextOrDismiss() {
    if (_currentAlarmIndex < widget.activeAlarms.length - 1) {
      setState(() {
        _currentAlarmIndex++;
      });
    } ...
  }
  ```
* If the widget is popped/dismissed during the async database/network call (or during the dialog prompt), calling `setState` will trigger a `StateError` (`setState() called after dispose()`), crashing the screen state.

### Observation D: Vibration/Sound Fallback Residual Playback
In `lib/features/alarms/presentation/alarm_active_screen.dart`:
* Lines 111-128: The periodic vibration loop runs in a `Future.doWhile` loop:
  ```dart
  Future.doWhile(() async {
    if (!mounted) return false;
    try { await HapticFeedback.vibrate(); } catch (e) { ... }
    try { await SystemSound.play(SystemSoundType.alert); } catch (e) { ... }
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return false;
    return context.mounted;
  });
  ```
* There are no check-gates for `mounted` between the three successive awaited calls (`HapticFeedback.vibrate()`, `SystemSound.play()`, and `Future.delayed()`).
* If the user taps "MARCAR COMO TOMADO" and dismisses the screen while the loop is awaiting `HapticFeedback.vibrate()`, the execution still continues to play the alert sound (`SystemSound.play`) and delay for 2 seconds before checking `!mounted` and terminating. This results in residual audio alert playback after screen dismissal.

### Observation E: Loop Interruption on Exception in `AlarmEngine`
In `lib/core/services/alarm_engine.dart`:
* The foreground ticker `_tick()` processes a list of alarms inside a `for (final a in alarms)` loop starting at line 112.
* Several database writes are performed inside the loop, including:
  ```dart
  await _alarmRepo.updateAlarm(updated);
  ```
* There is no local `try-catch` enclosing individual iterations of the `for` loop. The only `try-catch` is at the boundary of the `_tick()` method itself (lines 98-416).
* Consequently, if updating the database for one alarm throws an exception (e.g. database locking, serialization issues, or schema violation), the entire loop is aborted. All subsequent alarms scheduled for that tick are skipped.
* This failure mode is validated by `test/zoned_scheduling_dst_test.dart`:
  ```
  00:08 +107: /Users/almanimation/Downloads/Caixa Remedios/medicaixa_app/test/zoned_scheduling_dst_test.dart: AlarmEngine Day Loop Error Handling Tests A crash in database update on one alarm halts execution of subsequent alarms
  ```

---

## 2. Logic Chain

1. **ID Collision**:
   * The formula `id * 10 + dayIndex` operates on the base ID space.
   * If a synced alarm is in the $[0, 255]$ range, its Saturday ID can equal $256$, which is a valid base ID for a local alarm.
   * This overlapping address space guarantees collisions between synced weekly Saturday alarms and local daily/once alarms.
2. **Audio Setup Failure**:
   * The iOS configuration specifies `AVAudioSessionCategory.playback` alongside `AVAudioSessionOptions.defaultToSpeaker`.
   * The `audioplayers` package enforces a strict assertion constraint: `defaultToSpeaker` is only compatible with `playAndRecord`.
   * This assertion error causes the audio session context configuration to fail to apply, meaning the app's alarms will not route to the speaker as intended under silent switch conditions or headphone states on iOS.
3. **Action Crashes**:
   * Action methods await asynchronous operations (database writes/UI Dialogs).
   * Disposal of the screen's state can happen during this async gap.
   * Execution continues unconditionally to `_nextOrDismiss()`, which calls `setState()`.
   * Calling `setState()` on a disposed State object causes a framework runtime exception (`StateError`).
4. **Alarms Loop Interruption**:
   * The loops inside `AlarmEngine._tick()` execute database updates directly.
   * An exception during one database update propagates out of the loop to the outer `_tick()` handler.
   * This immediately breaks the execution, leaving remaining alarms in the queue unprocessed for that tick.

---

## 3. Caveats

* The timezone logic was not fully evaluated on a live device transitioning across DST time boundaries, but was thoroughly verified via timezone DST test scenarios in `test/zoned_scheduling_dst_test.dart` (e.g., spring-forward and autumn-backward transitions) which showed correct next-instance calculation.
* No changes were made to the implementation code to fix these issues, in compliance with the review-only constraint.

---

## 4. Conclusion

The native alarm integration exhibits multiple high-risk correctness and safety vulnerabilities:
1. **Critical ID Collision**: Clashing notification IDs between synced weekly alarms and local daily alarms will cause scheduled OS notifications to overwrite each other.
2. **AVAudioSession Setup Crash**: The audio context configuration always fails on iOS due to an assertion violation in `audioplayers`.
3. **State Disposal StateErrors**: Action handlers lack safety gates check `mounted` after async gaps, leading to runtime crashes when performing `setState` on disposed active screens.
4. **Alarm Ticker Interruption**: A single alarm database update failure halts the entire `AlarmEngine` loop, preventing remaining scheduled alarms from firing.

### Recommendations:
* **ID Resolution**: Modify weekly alarm notification ID calculation to use a safer partitioning scheme (e.g., bitwise shifting: `(id << 3) | dayIndex`, or adding a large offset like `100000 + id * 7 + dayIndex`).
* **AVAudioSession Options**: Change the iOS audio context category to `AVAudioSessionCategory.playAndRecord` to enable `defaultToSpeaker`, or remove `defaultToSpeaker` from the option list if the category is kept as `playback`.
* **Async Gap Safety Checks**: Add `if (!mounted) return;` immediately after every `await` inside action handlers in `alarm_active_screen.dart`.
* **Loop Isolation in AlarmEngine**: Wrap the inner loop logic in `AlarmEngine._tick()` with an individual `try-catch` per alarm iteration, ensuring that a database failure on one alarm does not block others.

---

## 5. Verification Method

To verify these issues, inspect the following:
* **ID Collision**:
  Compare `lib/core/services/notification_service.dart` line 208: `final notificationId = id * 10 + dayIndex;` with Rule 12 (`id > 255` for local offline alarms, `0-255` for synced).
* **Audio Session Crash**:
  Inspect `lib/core/services/notification_service.dart` lines 285-293. Run tests using `flutter test` and check the stdout for `Failed assertion: line 223 ... category == AVAudioSessionCategory.playAndRecord || !options.contains(AVAudioSessionOptions.defaultToSpeaker)`.
* **State Disposal Crash**:
  Inspect `lib/features/alarms/presentation/alarm_active_screen.dart` action handlers `_markTaken` (line 151), `_markSkipped` (line 163), `_snooze` (line 170) to confirm the lack of `mounted` checks before `_nextOrDismiss()`.
* **AlarmEngine loop halt**:
  Inspect `lib/core/services/alarm_engine.dart` line 112. Run the test `A crash in database update on one alarm halts execution of subsequent alarms` in `test/zoned_scheduling_dst_test.dart` to verify the failure propagation behavior.
