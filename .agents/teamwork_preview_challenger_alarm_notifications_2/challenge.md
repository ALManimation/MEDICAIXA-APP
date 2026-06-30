# Challenge Report — 2026-06-29T14:50:00Z

## Challenge Summary

**Overall risk assessment**: HIGH

This assessment evaluates the robustness and timing safety of the zoned scheduling in `NotificationService`, timezone initialization, day-of-week indexing, and the structure of boot event receivers in `AndroidManifest.xml`.

---

## Challenges

### [High] Challenge 1: Notification ID Collision

- **Assumption challenged**: Each day-specific weekly alarm notification ID (`alarmId * 10 + dayIndex`) is unique and will not collide with other alarm notification IDs.
- **Attack scenario**: 
  - An alarm with database ID `12` is configured as a weekly recurring alarm (e.g. Sunday to Saturday). The service schedules notifications with IDs: `12 * 10 + dayIndex` (which evaluates to IDs `120`, `121`, `122`, `123`, `124`, `125`, `126`).
  - Another alarm with database ID `120` is configured as a daily or once alarm. It schedules its base notification with ID `120`.
  - The notification for database ID `120` and the Sunday notification for database ID `12` collide on notification ID `120`. This causes one to overwrite the other, resulting in missing alarms or silent cancellations.
- **Blast radius**: High. Notifications for affected alarms will be overwritten and will fail to fire, potentially causing patients to miss crucial medication doses.
- **Mitigation**: Use a collision-free bitwise/mathematical namespace mapping where each alarm ID receives a non-overlapping segment of slots. For example:
  - For daily/once: `notificationId = (alarmId << 3) | 7`
  - For weekly: `notificationId = (alarmId << 3) | dayIndex`
  Since `dayIndex` is in the range `0..6`, all weekly and daily notification IDs will occupy distinct integers.

---

### [Medium] Challenge 2: Lack of Initialization Lock (Race Condition)

- **Assumption challenged**: `NotificationService.init()` is thread-safe and will only initialize the native plugin resources once.
- **Attack scenario**: 
  - Multiple components or rapid sequential events trigger scheduling or cancellation calls (which call `await init()`) concurrently before the first initialization completes (`_initialized = true` is set at the end of `init()`).
  - The native initialization code `_notificationsPlugin.initialize(...)` and `requestNotificationsPermission()` will execute multiple times in parallel, which can cause race conditions, duplicate channel creation, or platform-level exceptions.
- **Blast radius**: Medium. Intermittent initialization failures or duplicate permission prompts under high-frequency scheduling.
- **Mitigation**: Store the initialization future and return it on subsequent calls:
  ```dart
  Future<void>? _initFuture;
  Future<void> init() {
    _initFuture ??= _init();
    return _initFuture!;
  }
  Future<void> _init() async { ... }
  ```

---

### [Medium] Challenge 3: Exact Alarm Permission SecurityException

- **Assumption challenged**: The app can always schedule exact alarms using `AndroidScheduleMode.alarmClock`.
- **Attack scenario**: 
  - On Android 13+ (SDK 33+), the `SCHEDULE_EXACT_ALARM` permission is denied by default unless granted by the user.
  - If the app calls `zonedSchedule` with `AndroidScheduleMode.alarmClock` without checking if it has permission, the OS throws a `java.lang.SecurityException`.
  - Because `zonedSchedule` is not wrapped in a `try-catch` block inside `scheduleWeeklyAlarm`, the exception will propagate and crash the database saving/scheduling workflow.
- **Blast radius**: High. App crash or complete failure to save alarms for users on modern Android devices.
- **Mitigation**: 
  - Wrap the scheduling logic in a `try-catch` block to handle `PlatformException` gracefully.
  - Fall back to an inexact schedule mode (e.g. `AndroidScheduleMode.inexactAllowWhileIdle`) if permission is missing, or prompt the user to grant exact alarm permissions.

---

### [Low] Challenge 4: DST Wall-Clock Shift via Duration Addition

- **Assumption challenged**: Adding a 24-hour duration via `scheduledDate.add(const Duration(days: 1))` is safe for calculating the next instance of weekly alarms.
- **Attack scenario**: 
  - When calculating the next instance of a weekly alarm across a Daylight Saving Time (DST) transition (where the clock shifts forward or backward by 1 hour), adding exactly 24 hours of UTC duration shifts the wall-clock time of the alarm by 1 hour (e.g. from 08:00 AM to 07:00 AM or 09:00 AM).
- **Blast radius**: Medium. Alarms will ring 1 hour early or 1 hour late after a DST transition.
- **Mitigation**: Use component-based addition to preserve wall-clock time when incrementing days:
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

---

## Stress Test Results

- **Timezone Initialization**: Correctly calls `FlutterTimezone.getLocalTimezone()` and obtains the `.identifier` string, complying with Rule 42. Wrapped in a `try-catch` block to handle exceptions, though UTC fallback shifts wall-clock times. → **Pass (with UTC fallback caveat)**
- **Day-of-Week Indexing**: Correctly converts from 0-6 (0=Sun, 1=Mon, ..., 6=Sat) to 1-7 ISO format (1=Mon, 2=Tue, ..., 7=Sun) using `isoWeekday = dayIndex == 0 ? 7 : dayIndex`. The `_nextInstanceOfWeekdayTime` accurately loops to find the correct day. → **Pass**
- **AndroidManifest Boot Event Structure**: 
  - `<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>` is declared.
  - `<receiver>` correctly references `com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver`.
  - Intent filters cover `BOOT_COMPLETED`, `MY_PACKAGE_REPLACED`, and manufacturer-specific quick boot intents (`QUICKBOOT_POWERON`). → **Pass**
- **Test Execution**: `flutter test` executed successfully. All 109 tests passed without any errors. → **Pass**

---

## Unchallenged Areas

- **Audio Session and Speaker Playback** — Native audio driver routing could not be tested on simulated environments and depends on the device hardware state.
