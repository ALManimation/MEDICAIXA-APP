## 2026-06-29T21:20:55Z
You are teamwork_preview_worker. Your working directory is `/Users/almanimation/Downloads/Caixa Remedios/medicaixa_app/.agents/teamwork_preview_worker_fixes_1/`.
Your role is to implement the fixes for Milestones 2, 3, 4, and 5 in the MediCaixa App codebase.

MANDATORY INTEGRITY WARNING:
> DO NOT CHEAT. All implementations must be genuine. DO NOT
> hardcode test results, create dummy/facade implementations, or
> circumvent the intended task. A Forensic Auditor will independently
> verify your work. Integrity violations WILL be detected and your
> work WILL be rejected.

Please execute the following tasks:

### Task 1: Alarm Active Screen Dismiss/Pop & Multi-Alarm Race Condition Fix
File: `lib/features/alarms/presentation/alarm_active_screen.dart`
- Remove the `_nextOrDismiss()` function and its calls inside `_snooze`, `_markTaken`, and `_markSkipped` (so these handlers only call the repository asynchronously).
- Remove the `Navigator.pop(context)` call inside `_startTimeoutTimer()`.
- Add/update `didUpdateWidget` to reactively update `_currentAlarmIndex = 0`, restart the timeout timer, and restart the alarm sound whenever `widget.activeAlarms.length` changes:
  ```dart
  @override
  void didUpdateWidget(covariant AlarmActiveScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.activeAlarms.length != oldWidget.activeAlarms.length) {
      setState(() {
        _currentAlarmIndex = 0;
      });
      _startTimeoutTimer();
      _playAlarmSound();
    }
  }
  ```

### Task 2: Snooze Modal RenderFlex Overflow Fix
File: `lib/features/alarms/presentation/snooze_modal.dart`
- The overflow is caused by adding the keyboard bottom inset to the outer `Padding` widget.
- Modify the outer `Padding` to have a constant padding at the bottom (e.g. `32` or similar, without `MediaQuery.of(context).viewInsets.bottom`).
- Move `MediaQuery.of(context).viewInsets.bottom` inside the `SingleChildScrollView` / `Column` using a `SizedBox(height: MediaQuery.of(context).viewInsets.bottom)` below the content, so the view scrolls and shrinks cleanly when the keyboard appears.

### Task 3: Dashboard FAB shape
File: `lib/features/dashboard/presentation/dashboard_screen.dart`
- Verify that `shape: const CircleBorder()` is applied on the floatingActionButton. If not, add it.

### Task 4: WeeklyRhythmWidget Removal & Calendar Strip cleanup
- Delete the file `lib/features/dashboard/presentation/widgets/weekly_rhythm_widget.dart` completely.
- In `lib/features/dashboard/presentation/dashboard_screen.dart`, remove the comment `/// - Desktop sidebar: Weekly Rhythm` and ensure `WeeklyRhythmWidget` is not referenced or imported.
- In `lib/features/dashboard/presentation/widgets/calendar_strip_widget.dart`, ensure that there are no Positioned chevrons (left/right navigation arrows) over the calendar scroll view. (If any left/right navigation chevrons exist, remove them).

### Task 5: Dashboard Date Swap Flicker & StreamBuilder Optimization
Files: `lib/features/dashboard/presentation/dashboard_notifier.dart`, `lib/features/dashboard/presentation/dashboard_screen.dart`
- In `dashboard_notifier.dart`, modify `selectDate` and `resetToToday` to NOT set `isLoading: true` (only keep `isLoading: true` for the hardware sync call).
- In `dashboard_screen.dart`, remove the inline `StreamBuilder` that watches `db.select(db.settings).watchSingleOrNull()`.
- Replace it by watching the pre-existing Riverpod provider `watchSettingsProvider` (defined in `settings_repository.dart`):
  `final settingsAsync = ref.watch(watchSettingsProvider);`
  Extract values from `settingsAsync.valueOrNull` (like `patientName`, etc.) directly.

### Task 6: Color Grid Expansion (15 Colors)
File: `lib/features/alarms/presentation/wizard/steps/step_1_name.dart`
- Locate `_buildColorPicker`. Refactor it to show all 15 official colors from `AppColors.alarmColors` (instead of the hardcoded 9 colors). You can do this by converting `AppColors.alarmColors.entries.toList()` and iterating over them.

### Task 7: Bidirectional Color Sync
File: `lib/features/medications/data/medication_repository.dart`
- When a medication is created or updated (in `createMedication` and `updateMedication`), search for any alarms in the `alarms` database table that are associated with the medication (where `medName == medication.name`).
- If any matching alarms are found, update their `color` column to match the new medication color, set `pendingSync = true`, and update `lastModified` with the current timestamp in milliseconds, to ensure the new color is synchronized to the physical ESP32 device.

### Task 8: Reminder Colors Defensive Fallback
Files: `lib/features/reminders/data/reminder_model.dart`, `lib/features/reminders/presentation/reminder_form_screen.dart`
- In `reminder_model.dart`, inside `fromJson` parse the incoming color string in lowercase and validate against `AppColors.alarmColors.containsKey`. Fallback to `'blue'` if the color is invalid.
- In `reminder_form_screen.dart`, fallback in `initState` to `'blue'` if the current reminder color is not in the map.

### Task 9: Advanced Notification Perms & Platform Configs
Files: `android/app/src/main/AndroidManifest.xml`, `ios/Runner/Runner.entitlements`, `ios/Runner/Info.plist`, `lib/core/services/notification_service.dart`
- Android Manifest: Add `<uses-permission android:name="android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS"/>`.
- Android Manifest: Ensure exact alarm/fullScreenIntent permissions are configured.
- iOS entitlements / Plist: Verify `com.apple.developer.usernotifications.critical-alerts` is set to `<true/>` in the entitlements, and `UIBackgroundModes` includes `audio` and `fetch` in `Info.plist`.
- macOS entitlements: Verify that `DebugProfile.entitlements` and `Release.entitlements` have networking permissions.
- `notification_service.dart`: Ensure Android notification details set `fullScreenIntent` and max priority. For iOS, configure the audio session category to `.playback` (or configure iOS critical alert audio session correctly) and ensure the iOS details use critical interruption level. Provide document/support for timeSensitive notifications on macOS.

Verify the build and tests pass before completing. Write a detailed handoff.md in your working directory.
