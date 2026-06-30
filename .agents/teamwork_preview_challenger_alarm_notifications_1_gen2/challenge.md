## Challenge Summary

**Overall risk assessment**: MEDIUM

## Challenges

### [Medium] Challenge 1: Unmounted context StateError assertion crash

- **Assumption challenged**: Accessing `context.mounted` directly after an asynchronous gap (e.g., `await Future.delayed`) is safe.
- **Attack scenario**: If the user dismisses the `AlarmActiveScreen` (unmounting it) while the periodic vibration loop is waiting on `Future.delayed`, the deferred callback fires and tries to evaluate `context.mounted`. Since the state is already disposed, accessing `context` throws a `StateError` (asserting `This widget has been unmounted, so the State no longer has a context`).
- **Blast radius**: Crashes the application in debug mode and disrupts testing/runtime stability when unmounting the active alarm widget.
- **Mitigation**: Safeguard the context check by inspecting the State's local `mounted` property first before accessing `context`:
  ```dart
  await Future.delayed(const Duration(seconds: 2));
  if (!mounted) return false;
  return context.mounted;
  ```

### [Low] Challenge 2: Asset Availability & Offline Player Errors

- **Assumption challenged**: The local sound asset `assets/sounds/alarm_beep.wav` will always load successfully.
- **Attack scenario**: If the file is missing, corrupted, or cannot be accessed on the filesystem (e.g., path_provider permissions/issues), loading the asset throws a `FlutterError` or `MissingPluginException`.
- **Blast radius**: The local player fails to play audio.
- **Mitigation**: The implementer's robust exception handling successfully catches this crash, falling back to a remote URL source, and then to a periodic haptic feedback & system alert sound loop. Tested and verified that no crash occurs.

### [Medium] Challenge 3: Daily/Once Notification Scheduling Timezone Dependency

- **Assumption challenged**: The timezone database is always initialized, or daily scheduling is exception-safe.
- **Attack scenario**: If timezone resolution fails or local notifications throws during a daily/once alarm schedule (where `days` list is empty), the exception bubbles up and crashes the caller.
- **Blast radius**: Uncaught exceptions during background scheduling will crash the application when configuring daily/once alarms.
- **Mitigation**: Wrap the daily/once scheduling logic inside `scheduleWeeklyAlarm` with a try-catch block (mirroring the weekly schedule loop) or add structural verification of the `days` list.

## Stress Test Results

- **Timezone Resolution Robustness**: Local timezone resolution fails (returns null) → falls back to UTC gracefully → **PASS**
- **Weekly Schedule Exception Safety**: Local notifications throws exception on weekly alarm → exception is caught and logged, caller does not crash → **PASS**
- **Daily/Once Schedule Exception Safety**: Local notifications throws exception on daily/once alarm → exception bubbles up and throws to caller → **FAIL (Vulnerability)**
- **Asset Playback Failure Fallback**: Local sound asset throws `Unable to load asset` → falls back to remote URL source → **PASS**
- **Remote Sound Playback Failure Fallback**: Remote audio playback fails → falls back to periodic haptics & system sounds → **PASS**
- **App Nap Prevention Method Channel Failure**: Prevents App Nap channel throws `UNSUPPORTED` platform exception → exception caught, screen continues to work and triggers fallbacks → **PASS**
- **Widget Unmounting with Active Loop**: Active screen is unmounted while vibration loop is running → throws unmounted context assertion error → **FAIL (Vulnerability)**

## Unchallenged Areas

- **Platform-level background execution restrictions (Android OEM battery savers)** — Out of scope for code-level widget and service unit testing.
