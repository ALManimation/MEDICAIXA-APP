## 2026-07-01T10:23:00Z

Objective: Implement the alarm deletion logic changes, display ghost alarms in the calendar, and write new tests.

Please perform the following steps:

1. Modify `lib/features/dashboard/presentation/dashboard_notifier.dart`:
   - In the `_updateData` method, modify the ghost alarm reconstruction logic to run on `isToday` (today's date) as well as past dates.
   - Use the following strategy:
     - Change the condition `if (targetZero.isBefore(todayZero)) {` to `if (targetZero.isBefore(todayZero) || isToday) {`.
     - Inside this block, only update the active alarms using `dateEvents` if `targetZero.isBefore(todayZero)` is true (i.e. if it's a past date, missing events mean the alarm was missed). If it's today (`isToday`), perform the existing cleanup that resets statuses from previous days (lines 237-247 of the original file).
     - Keep the ghost alarm reconstruction loop `for (final e in dateEvents)` so that it runs for both past dates and today. This ensures that if an alarm has a history event today but has been deleted from the database, it gets reconstructed as a Ghost Alarm on today's calendar as well.

2. Modify `lib/features/dashboard/presentation/widgets/alarm_card_widget.dart`:
   - Update `_formatFrequency` method. If `alarm.isGhost` is true, return the localized string for 'alarm_removed' (i.e., `t('alarm_removed')` which translates to "Removido"/"Removed").

3. Create a new test file `test/features/dashboard/ghost_alarms_test.dart`:
   - Setup a widget/unit test using Riverpod `ProviderContainer` and an in-memory Drift database `AppDatabase.connect(NativeDatabase.memory())`.
   - Implement tests covering the following scenarios:
     - **Scenario 1**: Create an alarm, mark it taken on a specific date (creating a history event), then delete the alarm using `deleteAlarm`. Verify that when loading the dashboard on that specific date (past date or today), the alarm is reconstructed as a Ghost Alarm (i.e., `alarm.isGhost` is true, status is 'Tomado').
     - **Scenario 2**: In a widget test, render the `AlarmCardWidget` for a Ghost Alarm. Verify it displays the "Excluído" badge, has the gray color theme, lower opacity (0.55), frequency text "Removido", and its tap callback (`onTap`) is null (or click is disabled).
     - **Scenario 3**: Verify that if an alarm is deleted *without* any history events (never taken or missed), it is completely removed and does not show up as a Ghost Alarm on the calendar.
     - **Scenario 4**: Verify that a Ghost Alarm does *not* appear on days of the calendar subsequent to the date of its last recorded status.

4. Run `flutter test` to verify all 216+ tests pass successfully.
5. Run `flutter analyze` to ensure zero static analysis warnings.
6. Write a detailed handoff report when complete and send a message.
