## Challenge Summary

**Overall risk assessment**: MEDIUM

## Challenges

### [Medium] Challenge 1: Lack of Alarm-Level Error Isolation in AlarmEngine Day Loop

- **Assumption challenged**: The day loop assumes that database updates, history events, and logging for individual alarms will never fail or throw runtime exceptions.
- **Attack scenario**: During the daily tick (which resets status and runs adjust step, cycle updates, and taper stages), if an update fails (e.g. database constraint error, lock, or disk full) or if a taper stage index lookup throws a `RangeError` (index out of bounds), the exception is not caught inside the loop. It propagates to the outer `try-catch` block of `_tick()`, causing the entire tick to abort immediately.
- **Blast radius**: All subsequent alarms in the same tick will not have their daily status reset or tick-based dosing rules applied, which could lead to missed doses, incorrect dosing adjustments, and incorrect synchronization.
- **Mitigation**: Wrap the processing of each individual alarm in a `try-catch` block inside the loop, logging errors for the failed alarm but allowing the loop to continue processing subsequent alarms.

### [Low] Challenge 2: Redundant Rescheduling and Startup Race Conditions in NotificationService

- **Assumption challenged**: Multiple concurrent initialization requests to `NotificationService.init()` are serialized, and exact alarm scheduling is guaranteed to succeed.
- **Attack scenario**: Concurrent asynchronous initialization calls can race because there is no lock before `_initialized` is set to `true` at the end of the `init()` method. Also, on Android 13+, if exact alarm permissions are not granted, calling `zonedSchedule` throws a `PlatformException` that is unhandled in `scheduleWeeklyAlarm`.
- **Blast radius**: Concurrent initialization can lead to platform-side exceptions or resource locks. Missing exact alarm permission causes the entire schedule/saving flow to fail with uncaught platform exceptions.
- **Mitigation**: Use an asynchronous lock (e.g. `Future` chain or lock flag) during initialization, and wrap `zonedSchedule` calls in try-catch blocks to degrade gracefully if permissions are missing.

## Stress Test Results

- **New York Spring Forward Transition (March 8, 2026)** → Verify that local alarm scheduled at 08:00 remains at 08:00 (instead of shifting to 09:00 as it would if using 1-day Duration) → March 8, 2026 08:00 → March 8, 2026 08:00 → PASS
- **New York Autumn Backward Transition (Nov 1, 2026)** → Verify that local alarm scheduled at 08:00 remains at 08:00 (instead of shifting to 07:00 as it would if using 1-day Duration) → November 1, 2026 08:00 → November 1, 2026 08:00 → PASS
- **Month Roll-over Handling (Oct 31 -> Nov 1)** → Verify that adding 1 day to Oct 31 rolls over to Nov 1 → November 1, 2026 08:00 → November 1, 2026 08:00 → PASS
- **Year Roll-over Handling (Dec 31 -> Jan 1)** → Verify that adding 1 day to Dec 31 rolls over to Jan 1 → January 1, 2027 08:00 → January 1, 2027 08:00 → PASS
- **Day Loop Database Failure Impact** → Simulate a database write failure when processing a single alarm during `_tick()` and verify if subsequent alarms are processed → Alarms are isolated and all successfully updated → The loop terminates immediately on the first failure, leaving subsequent alarms unprocessed → FAIL (Demonstrates the bug successfully)

## Unchallenged Areas

- **Platform-specific audio playback** — AudioPlayer and custom native sound formats (e.g. `.caf`, `.wav`) were not checked on physical devices due to sandbox and emulator restrictions.
