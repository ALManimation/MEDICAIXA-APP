# Handoff Report

## 1. Observation

- **`lib/features/alarms/presentation/alarm_active_screen.dart`**:
  - `context.mounted` check-gates are completely robust. For instance, in the async haptic feedback/system sound playback loop (lines 112–128):
    ```dart
    Future.doWhile(() async {
      if (!context.mounted) return false;
      ...
      await Future.delayed(const Duration(seconds: 2));
      if (!context.mounted) return false;
      return context.mounted;
    });
    ```
    And in repository operation handlers (lines 151–179):
    ```dart
    if (alarm.isDynamic == true) {
      customQty = await DynamicDoseDialog.show(context, alarm);
      if (!context.mounted) return;
      if (customQty == null) return; // User cancelled
    }
    await repo.markTaken(alarm.id, customQty: customQty);
    if (!context.mounted) return;
    ref.invalidate(dashboardNotifierProvider);
    _nextOrDismiss();
    ```

- **`lib/core/services/alarm_engine.dart`**:
  - In `_tick()` (lines 437–440):
    ```dart
    // Do not mark missed if it was never triggered for this occurrence
    if (a.lastStatusDate == null || a.lastStatusDate!.isEmpty) {
      // New alarm never run, skip marking missed to let it run next time
      continue;
    }
    ```
  - In `_tick()` (lines 362–411) the closest occurrence absolute difference logic:
    ```dart
    final diffForOffset = localNow.difference(effectiveScheduled).inMinutes;

    if (bestDiff == null || diffForOffset.abs() < bestDiff.abs()) {
      bestDiff = diffForOffset;
      bestScheduledDate = scheduledDate;
    }
    ```

- **`lib/features/alarms/data/alarm_repository.dart`**:
  - In `updateAlarm` (lines 294–344), when rebuilding the updated model, the `intervalDays` and `intervalCountdown` fields are entirely omitted:
    ```dart
    final updatedModel = AlarmModel(
      id: alarm.id,
      hour: alarm.hour,
      minute: alarm.minute,
      name: alarm.name,
      medName: alarm.medName,
      enabled: alarm.enabled,
      active: alarm.active,
      days: alarm.days,
      status: alarm.status,
      color: alarm.color,
      quantity: alarm.quantity,
      daysQuantity: alarm.daysQuantity,
      type: alarm.type,
      dosage: alarm.dosage,
      lastStatus: alarm.lastStatus,
      lastStatusDate: alarm.lastStatusDate,
      snoozeMin: alarm.snoozeMin,
      startDate: alarm.startDate,
      durationDays: alarm.durationDays,
      createdDate: alarm.createdDate,
      cycleOnDays: alarm.cycleOnDays,
      cycleOffDays: alarm.cycleOffDays,
      cycleCurrentDay: alarm.cycleCurrentDay,
      cycleIsPaused: alarm.cycleIsPaused,
      isPrn: alarm.isPrn,
      prnMinIntervalHours: alarm.prnMinIntervalHours,
      prnMaxDailyDoses: alarm.prnMaxDailyDoses,
      prnDosesToday: alarm.prnDosesToday,
      pauseUntil: alarm.pauseUntil,
      isDynamic: alarm.isDynamic,
      dynamicInstruction: alarm.dynamicInstruction,
      taperStageCount: alarm.taperStageCount,
      taperCurrentStage: alarm.taperCurrentStage,
      taperDayInStage: alarm.taperDayInStage,
      taperStages: alarm.taperStages,
      taperLoop: alarm.taperLoop,
      specialInstruction: alarm.specialInstruction,
      adjustStep: alarm.adjustStep,
      adjustIntervalDays: alarm.adjustIntervalDays,
      adjustLimit: alarm.adjustLimit,
      requiresRemoval: alarm.requiresRemoval,
      removalDelayMins: alarm.removalDelayMins,
      siteRotationList: alarm.siteRotationList,
      currentSiteIndex: alarm.currentSiteIndex,
      dayOfMonth: alarm.dayOfMonth,
      groupId: alarm.groupId,
      intervalHours: alarm.intervalHours,
      lastModified: DateTime.now().millisecondsSinceEpoch,
      pendingSync: isPending,
    );
    ```

- **`test/zoned_scheduling_dst_test.dart`**:
  - Running the added test cases via `flutter test test/zoned_scheduling_dst_test.dart` output:
    ```
    Challenger test - status: PENDENTE, lastStatus: , lastStatusDate:
    ...
    00:00 +10: All tests passed!
    ```

---

## 2. Logic Chain

1. **Closed-App Missed Alarm Vulnerability**:
   - The daily tick resets `lastStatusDate` to `''` when a new day begins.
   - If the app is closed during the trigger window (the 10 minutes surrounding the alarm scheduled time), the alarm is never set to `ATIVO` (which is what sets `lastStatusDate` to today's date).
   - When the app is opened later, `diff` is evaluated. Since the 10-minute window has passed, it enters the `diff > 10` (missed) path.
   - However, because `lastStatusDate` remains `''`, the check `a.lastStatusDate == null || a.lastStatusDate!.isEmpty` is met, which executes `continue;` and skips marking the alarm as missed (`Não Tomado`).
   - Therefore, alarms missed while the app is closed are never recorded as missed in history or database.

2. **12-Hour Rollover Closest Occurrence Loop Vulnerability**:
   - `AlarmEngine` determines the best active occurrence using absolute difference: `diffForOffset.abs() < bestDiff.abs()`.
   - For any daily or consecutive-day alarm, once more than 12 hours pass from the scheduled time, tomorrow's occurrence (e.g., in 11 hours 45 minutes) is mathematically closer than today's occurrence (e.g., 12 hours 15 minutes ago).
   - Consequently, tomorrow's occurrence is chosen as the closest occurrence.
   - Because tomorrow's occurrence is in the future, `diff` is negative and today's missed occurrence is skipped and never marked as missed.

3. **Database Column Deletion Vulnerability**:
   - In `AlarmRepository.updateAlarm`, the newly constructed `updatedModel` does not copy the `intervalDays` and `intervalCountdown` properties from the source `alarm` model.
   - When `_toCompanion(updatedModel)` is called and executed as a database replacement, these columns are written as `null` in Drift.
   - This corrupts the alarm's recurrence settings on any database update.

---

## 3. Caveats

- Timezones: Verification was performed in `America/New_York` and `America/Sao_Paulo` mock environments. Actual hardware synchronization on the ESP32 (which relies on local LAN times) might introduce secondary drift issues if daylight saving transitions are handled differently in C++.
- Standalone / Offline Resilience: Standalone behavior works as expected; however, any database updates performed offline will still trigger database corruption on the `intervalDays` and `intervalCountdown` columns.

---

## 4. Conclusion

- **`alarm_active_screen.dart`**: Verified and found completely exception-safe and context.mounted resilient.
- **`alarm_engine.dart`**: Empirically challenged and confirmed two critical correctness logic flaws (closed-app bypass and 12-hour rollover bypass).
- **`alarm_repository.dart`**: Empirically challenged and confirmed a database corruption flaw on alarm update.
- **Recommendation**: These bugs are critical and block native alarm integration milestone completion. The implementer must address them immediately.

---

## 5. Verification Method

- Run the project's tests with the newly added challenge cases using:
  ```bash
  flutter test test/zoned_scheduling_dst_test.dart
  ```
- File to inspect: `test/zoned_scheduling_dst_test.dart` (specifically tests: `Challenger: Alarm missed while app is closed (lastStatusDate is empty) is NOT marked as missed`, `Challenger: Alternate days interval countdown drifts and gets out of sync when app is closed on active day`, and `Challenger: Daily alarm overdue by more than 12 hours chooses tomorrow as closest and fails to mark today as missed`).
