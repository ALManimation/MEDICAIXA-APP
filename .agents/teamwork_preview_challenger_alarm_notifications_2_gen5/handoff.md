# Handoff Report — Native Alarm Integration Challenge Findings

## 1. Observation

I ran verification tests against `lib/core/services/alarm_engine.dart` and `test/zoned_scheduling_dst_test.dart` and observed several critical defects in the native alarm tick loop, midnight boundary management, history logging, and the test suite itself:

### Observation A: Daily Reset Bypasses Missed Status Check
In `lib/core/services/alarm_engine.dart` at lines 135-161, `shouldDelayReset` is calculated:
```dart
                final lastScheduled = tz.TZDateTime(
                  localLocation,
                  year,
                  month,
                  day,
                  a.hour,
                  a.minute,
                );
                final lastEffective = lastScheduled.add(Duration(minutes: a.snoozeMin));
                final windowEnd = lastEffective.add(const Duration(minutes: 10));
                if (localNow.isBefore(windowEnd)) {
                  shouldDelayReset = true;
                }
```
If `shouldDelayReset` is false, it executes the daily reset:
```dart
        if (a.lastStatusDate != null && a.lastStatusDate!.isNotEmpty && a.lastStatusDate != todayStr && !shouldDelayReset) {
          var updated = a.copyWith(
            status: 'PENDENTE',
            snoozeMin: 0,
            lastStatus: '',
            lastStatusDate: '',
            prnDosesToday: a.isPrn == true ? 0 : a.prnDosesToday,
          );
          ...
          await _alarmRepo.updateAlarm(updated);
          ...
          debugPrint("Processed daily tick for alarm '${a.name}' and propagated group status.");
          continue;
        }
```
If the daily tick runs at `00:06` (11 minutes after the alarm scheduled at `23:55`), `shouldDelayReset` is evaluated as `false`. The engine resets `status` to `PENDENTE` and `lastStatus` to `''` and `lastStatusDate` to `''`, followed by a `continue;` statement. This `continue;` statement bypasses the subsequent check at line 430:
```dart
        if (diff > 10) { ... }
```
which would have marked the alarm as missed (`lastStatus = 'Não Tomado'`). 

### Observation B: Missed Alarms Not Written to History
In `lib/core/services/alarm_engine.dart` lines 431-452:
```dart
        if (diff > 10) {
          ...
          final updated = a.copyWith(
            status: 'PENDENTE',
            lastStatus: 'Não Tomado',
            lastStatusDate: bestScheduledDateStr,
            snoozeMin: 0,
          );
          await _alarmRepo.updateAlarm(updated);
          
          debugPrint("Alarm '${a.name}' marked missed (past 10 min window, diff: $diff min).");
          continue;
        }
```
This block only calls `_alarmRepo.updateAlarm(updated)`, which writes to the `alarms` table. In contrast to `AlarmRepository.markSkipped` (which writes to the `historyEvents` table via `historyRepo.addHistoryEvent`), `AlarmEngine._tick()` completely omits writing a history event (status `'PERDIDO'`) for automatically missed alarms.

### Observation C: Duplicate Trigger Loop Bug
In `lib/features/alarms/data/alarm_repository.dart` line 428, `markTaken` updates the database record with today's date:
```dart
    final updated = AlarmModel(
      ...
      status: 'PENDENTE', 
      lastStatus: 'Tomado',
      lastStatusDate: todayStr, // Date of system time (e.g. today)
      ...
    );
```
If the user takes the alarm at `00:02` today (within the active window of `23:55` yesterday to `00:05` today), `lastStatusDate` becomes today's date.
In the subsequent background tick at `00:03` today, the engine finds the closest occurrence:
- Yesterday's occurrence (`28/06/2026 23:55`): `diff = 8 minutes` (selected as closest)
- Today's occurrence (`29/06/2026 23:55`): `diff = -1432 minutes`
Since `bestScheduledDateStr` is `"28/06/2026"` (yesterday) and `a.lastStatusDate` is `"29/06/2026"` (today), they do not match. The skip condition is bypassed, and because `diff` is 8 (within 0 to 10) and `status` is `PENDENTE`, the engine re-triggers the alarm and updates it back to `ATIVO` with `lastStatusDate` set to yesterday's date, causing a duplicate trigger loop.

### Observation D: Overdue Alarm calculation error
In `test/zoned_scheduling_dst_test.dart`, I ran the tests and observed the following failure:
```
  Expected: 'Não Tomado'
    Actual: ''
  test/zoned_scheduling_dst_test.dart:538  expect(updatedAlarm.lastStatus, 'Não Tomado');
```
This test `Daily alarm overdue by more than 12 hours chooses tomorrow as closest and fails to mark today as missed` fails because when the current time is `20:15` and the alarm was scheduled at `08:00` today (12 hours 15 minutes overdue), the engine compares:
- Today's occurrence (08:00 today): `diff = 735 minutes`
- Tomorrow's occurrence (08:00 tomorrow): `diff = -705 minutes`
Since `|-705| < |735|`, the engine selects tomorrow's occurrence as closest, and fails to mark today's alarm as missed.

### Observation E: Timezone Reset Race Condition in Tests
In `test/zoned_scheduling_dst_test.dart`, when run individually, the test `Regression: Active midnight-wrapped alarm marked as taken...` fails:
```
  Expected: '29/06/2026'
    Actual: '28/06/2026'
```
This is because `NotificationService` is a singleton. When run individually, the first call to `scheduleWeeklyAlarm` inside the tick triggers `NotificationService.init()`, which calls `_configureLocalTimeZone()` and overwrites `tz.local` back to `'America/New_York'`. This breaks the custom shifted timezone configured by the test and fails the test. When run in a group after other tests, the singleton is already initialized, so it returns early and preserves the custom timezone, masking the failure.

---

## 2. Logic Chain

1. **Daily Reset Missed Status Bypass**: Since `shouldDelayReset` checks if the current time is before the window end (Observation A), once the window expires, `shouldDelayReset` becomes `false`. The daily reset runs, updates status to `PENDENTE`, and performs `continue;`. This skips the missed alarm check (`diff > 10`). Therefore, midnight-wrapped alarms that are never taken are silently reset to `PENDENTE` without ever being marked missed.
2. **Missing History Records**: The missed alarm block in the engine (Observation B) only calls `updateAlarm` on the database without calling `addHistoryEvent`. Consequently, no `HistoryEvent` is ever created, making missed doses completely invisible on the reports and adherence screens.
3. **Duplicate Trigger Loop**: If a midnight-wrapped alarm is taken after midnight, `markTaken` sets `lastStatusDate` to today's date (Observation C). However, the engine selects yesterday's occurrence as the closest scheduled date (since it is 7 minutes ago, while today's is 23 hours in the future). Since today's date in `lastStatusDate` does not match yesterday's date, the engine assumes it has not been taken, and because the status is `PENDENTE` and it falls within the 10-minute window, it re-triggers the alarm back to `ATIVO`.
4. **Overdue Alarms**: The closest occurrence loop selects the occurrence with the smallest absolute difference (Observation D). When an alarm is overdue by more than 12 hours, tomorrow's occurrence (which is less than 12 hours away) has a smaller absolute difference than today's (which is more than 12 hours in the past). Thus, tomorrow's occurrence is selected as closest, leaving today's overdue alarm unmarked.
5. **Test Flakiness**: The singleton `NotificationService` resets `tz.local` to the system location upon initialization (Observation E). If a test mocks `tz.local` and then invokes alarm updates, the first invocation initializes `NotificationService` and overwrites `tz.local`, causing subsequent ticks to run in the wrong timezone.

---

## 3. Caveats

- We did not evaluate the behavior of platform-specific code (Java/Kotlin on Android, Swift/ObjC on iOS) when the system clock changes or when timezone is modified at the OS level while the app is in the background.

---

## 4. Conclusion

The native alarm integration has several severe timezone-math, history tracking, and midnight rollover defects:
1. **Midnight-wrapped alarms** that are never taken are silently reset to `PENDENTE` and never marked missed.
2. **Missed alarms** are never recorded in the `historyEvents` database table, skewing reports and adherence tracking.
3. **Taken midnight-wrapped alarms** trigger a duplicate alarm loop immediately after the user takes them shortly after midnight.
4. **Overdue alarms** (over 12 hours past scheduled time) fail to be marked missed due to closest occurrence math preferring tomorrow's occurrence.
5. **Test suite flakiness** exists due to `NotificationService` resetting `tz.local` dynamically.

These defects must be resolved before the milestone can be considered production-ready.

---

## 5. Verification Method

To reproduce these bugs, run the following test commands:
- To run the project's zoned scheduling and DST tests:
  ```bash
  flutter test test/zoned_scheduling_dst_test.dart
  ```
  *(Verify that "Alternate days interval countdown drifts" and "Daily alarm overdue by more than 12 hours" tests fail as expected).*
  
- To verify the timezone race condition in individual tests:
  ```bash
  flutter test test/zoned_scheduling_dst_test.dart --name "Regression: Active midnight-wrapped alarm"
  ```
  *(Verify that this test fails when run individually due to timezone reset).*

- To run the custom challenge tests demonstrating all four cases (including Case 4 Duplicate Trigger):
  ```bash
  flutter test test/challenge_dst_test.dart
  ```
  *(Verify that Case 4 fails due to duplicate triggering).*
