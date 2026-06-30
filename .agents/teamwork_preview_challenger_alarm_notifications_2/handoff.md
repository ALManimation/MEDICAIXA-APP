# Handoff Report — 2026-06-29T14:51:00Z

This handoff report summarizes the findings of the empirical evaluation of `NotificationService` and `AndroidManifest.xml` in the `medicaixa_app` repository.

## 1. Observation

- **Notification ID Generation Logic**:
  File: `lib/core/services/notification_service.dart`, lines 198-200:
  ```dart
  final scheduleTime = _nextInstanceOfWeekdayTime(isoWeekday, hour, minute, now);
  final notificationId = id * 10 + dayIndex;

  await _notificationsPlugin.zonedSchedule(
    notificationId,
  ```
  File: `lib/core/services/notification_service.dart`, lines 174-175:
  ```dart
  await _notificationsPlugin.zonedSchedule(
    id, // Single notification
  ```

- **Day-of-Week Indexing**:
  File: `lib/core/services/notification_service.dart`, lines 192-195:
  ```dart
  for (int dayIndex = 0; dayIndex < 7; dayIndex++) {
    if (days[dayIndex]) {
      // Convert days index (0=Sun, 1=Mon, ..., 6=Sat) to timezone ISO weekday (1=Mon, ..., 7=Sun)
      final int isoWeekday = dayIndex == 0 ? 7 : dayIndex; 
  ```

- **Timezone Initialization**:
  File: `lib/core/services/notification_service.dart`, lines 77-87:
  ```dart
  Future<void> _configureLocalTimeZone() async {
    tz.initializeTimeZones();
    try {
      final timezoneInfo = await FlutterTimezone.getLocalTimezone();
      final String timeZoneName = timezoneInfo.identifier;
      tz.setLocalLocation(tz.getLocation(timeZoneName));
      debugPrint('Local timezone configured to: $timeZoneName');
    } catch (e) {
      debugPrint('Could not get local timezone: $e. Falling back to UTC.');
      tz.setLocalLocation(tz.UTC);
    }
  }
  ```

- **Boot Receiver Tags**:
  File: `android/app/src/main/AndroidManifest.xml`, lines 9 and 47-55:
  ```xml
  <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
  ...
  <receiver android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver"
      android:exported="true">
      <intent-filter>
          <action android:name="android.intent.action.BOOT_COMPLETED"/>
          <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
          <action android:name="android.intent.action.QUICKBOOT_POWERON" />
          <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
      </intent-filter>
  </receiver>
  ```

- **Next Instance Time Increments**:
  File: `lib/core/services/notification_service.dart`, lines 236-243:
  ```dart
  tz.TZDateTime _nextInstanceOfTime(int hour, int minute, tz.TZDateTime now) {
    tz.TZDateTime scheduledDate =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }
  ```

- **Test Execution**:
  Command executed: `flutter test`
  Output summary: `All tests passed!` (109 tests passed).

---

## 2. Logic Chain

1. **Notification ID Collision**:
   - The weekly day-specific notification ID is calculated as `notificationId = id * 10 + dayIndex`.
   - The daily/once notification ID is calculated as `id`.
   - If Alarm A has `id = 12`, its weekly IDs are `120` to `126`.
   - If Alarm B has `id = 120`, its daily ID is `120`.
   - Because `12 * 10 + 0 = 120`, the Sunday notification of Alarm A and the daily notification of Alarm B share the exact same ID `120`.
   - Therefore, scheduling one will overwrite or cancel the other in the native alarm scheduler.

2. **Concurrency Risk in Initialization**:
   - `init()` checks `if (_initialized) return;` and then runs asynchronous setup code (e.g. `await _configureLocalTimeZone()`).
   - If multiple schedule/cancel calls are made in quick succession, they will check `_initialized` (which is still false) and run the native initialization simultaneously.
   - This can cause native resource locks or crashes.

3. **Android 13+ Exact Alarm Permission**:
   - `AndroidScheduleMode.alarmClock` is used for scheduling.
   - On Android 13+ (SDK 33+), exact alarms require explicit user/system permission.
   - If the permission is missing, calling `zonedSchedule` will throw a `PlatformException` (derived from `SecurityException`).
   - Since `scheduleWeeklyAlarm` does not contain `try-catch` blocks, this will crash the calling thread (e.g., when adding/saving an alarm).

4. **DST Wall-Clock Drift**:
   - `scheduledDate.add(const Duration(days: 1))` increments the time by exactly 24 hours (86,400 seconds).
   - During a DST boundary crossover, local time will shift by 1 hour (day length is 23 or 25 hours).
   - Adding 24 hours UTC will result in the alarm firing at the incorrect local wall-clock time (shifted by 1 hour).

---

## 3. Caveats

- **Timezone Fallback**: If `FlutterTimezone.getLocalTimezone()` fails, the service falls back to UTC. While this prevents crashes, it shifts alarm schedules by the timezone offset.
- **Darwin Custom Sounds**: macOS and iOS notifications expect custom sounds in specific formats (e.g. `.caf`, `.wav`). The code formats the suffix (`.caf` / `.wav`), but the presence of actual audio files in the native bundle cannot be verified statically.

---

## 4. Conclusion

The time zone configuration, day-of-week indexing, and AndroidManifest boot receivers are implemented correctly according to library APIs. However, the system suffers from **high-risk architectural issues**:
1. **Notification ID collision** between weekly day-specific and daily/once alarms.
2. **Missing async initialization locks** which could trigger concurrent initializations.
3. **Missing try-catch guard** for exact alarm permission constraints on Android 13+.
4. **DST-unsafe day increments** using absolute `Duration(days: 1)`.

All existing unit/widget tests (109 total) pass, but no tests currently cover these edge cases.

---

## 5. Verification Method

- **Test Execution**: Run `flutter test` in the root folder to verify that existing test suites pass.
- **Manual Code Inspection**:
  - Inspect `lib/core/services/notification_service.dart` to verify the ID generation mapping (`id * 10 + dayIndex`) and the duration-based date increments.
  - Inspect `android/app/src/main/AndroidManifest.xml` to verify receiver tags.
- **Invalidation Condition**: The findings in this report are invalidated if it is proven that the database IDs (`id`) are constrained in a way that prevents overlaps between values (e.g., IDs are generated from disjoint ranges), or if the system does not target Android 13+ devices.
