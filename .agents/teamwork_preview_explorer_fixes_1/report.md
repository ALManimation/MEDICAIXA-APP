# Exploration Report: Flutter Fixes & Layout Adjustments

## 1. Alarm active screen snooze button dismiss/pop logic

### Observation & Analysis
In `lib/features/alarms/presentation/alarm_active_screen.dart`, the screen is displayed when there are active alarms (alarms with status `'ATIVO'`). 
- **Dismissal Mechanism**: The screen is not popped using `Navigator.pop(context)` under normal use because it is not pushed as a Route. Instead, it is rendered inside a `Stack` overlay in `lib/app.dart` (lines 43-65) using a `Consumer` watching `activeAlarmsProvider`. When the snooze button is clicked, it calls `_snooze` which updates the alarm status in the database to `'SNOOZED'`. This updates the stream, emitting a new list without the snoozed alarm. If the list becomes empty, the `Consumer` in `app.dart` rebuilds and renders `SizedBox.shrink()`, unmounting `AlarmActiveScreen` automatically.
- **Race Condition Bug with Multiple Active Alarms**:
  When multiple alarms are active (e.g. Alarm A and Alarm B):
  1. Clicking "Adiar 10 min" on Alarm A calls `repo.snoozeAlarm` asynchronously.
  2. Before the asynchronous method completes, the database updates, causing the stream in `app.dart` to rebuild `AlarmActiveScreen` with the new list `[Alarm B]`.
  3. `didUpdateWidget` is called. `_currentAlarmIndex` is 0, which is still less than `widget.activeAlarms.length` (1), so it remains 0.
  4. `_snooze` resumes execution and calls `_nextOrDismiss()`.
  5. Inside `_nextOrDismiss()`, it checks `_currentAlarmIndex < widget.activeAlarms.length - 1` (`0 < 0`), which evaluates to `false`.
  6. The `else` block is executed, calling `_audioPlayer.stop()` and cancelling `_timeoutTimer`.
  7. Consequently, the screen continues to display `Alarm B` because the list is not empty, but it remains completely silent and no timeout timer runs.
- **Timeout Bug**:
  Inside `_startTimeoutTimer()`, when the timer expires, it checks `Navigator.canPop(context)` and calls `Navigator.pop(context)`. Since `AlarmActiveScreen` is not a route, this incorrectly pops the underlying page (like the Dashboard) instead of the active screen itself.

### Recommendation & Proposed Fix
1. **Remove `_nextOrDismiss()` from Action Handlers**:
   The action handlers (`_snooze`, `_markTaken`, `_markSkipped`) should only be responsible for executing the repository updates.
2. **Handle Transitions Reactively in `didUpdateWidget`**:
   Rely on `didUpdateWidget` to transition the alarm list and reset state when the list size changes:
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
3. **Remove `Navigator.pop(context)` from Timeout**:
   Remove the `Navigator.pop` call in `_startTimeoutTimer()`. When the timeout occurs, it already updates the alarms in the database, which reactively empties the active alarms list and dismisses the overlay automatically.

---

## 2. Snooze modal RenderFlex overflow

### Observation & Analysis
In `lib/features/alarms/presentation/snooze_modal.dart`, when a user taps on the quantity `TextField` to enter a custom dose, the software keyboard rises, causing a **71 pixels RenderFlex overflow** at the bottom of the modal sheet.
- **Why the Overflow Happens**:
  The modal bottom sheet is shown with `isScrollControlled: true`. The `Padding` widget wraps the `SafeArea` and `SingleChildScrollView` (lines 122-133):
  ```dart
  return Padding(
    padding: EdgeInsets.fromLTRB(
      24,
      16,
      24,
      MediaQuery.of(context).viewInsets.bottom + 32,
    ),
    child: SafeArea(
      child: SingleChildScrollView(
        child: Column(...)
      )
    )
  );
  ```
  Adding `MediaQuery.of(context).viewInsets.bottom` directly to the bottom inset of the outer `Padding` reduces the available height for its child (`SingleChildScrollView`). On a typical screen, the combined height of the content (~524px) + top padding (16px) + keyboard inset (~300px) + bottom padding (32px) equals ~872px. Because `showModalBottomSheet` imposes a maximum height constraint (typically `9/10` of the screen height, e.g., ~720px on an 800px screen), the outer `Padding` widget is constrained and cannot fit, causing a RenderFlex overflow.

### Recommendation & Proposed Fix
To resolve this, the keyboard inset should be placed **inside** the scroll view instead of outside it. This allows the scroll view to expand to the full height allowed by the bottom sheet, and makes the content scrollable when the keyboard overlaps.

**Proposed Widget Structure**:
```dart
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...
              // Content widgets
              ...
              // Keyboard spacing
              SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
            ],
          ),
        ),
      ),
    );
  }
```

---

## 3. Dashboard FAB formatting

### Observation & Analysis
In `lib/features/dashboard/presentation/dashboard_screen.dart`, the `FloatingActionButton` is defined as:
```dart
          floatingActionButton: FloatingActionButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AlarmWizardScreen()),
              );
            },
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: const CircleBorder(),
            tooltip: t('new_alarm_title'),
            child: const Icon(Icons.add_rounded),
          ),
```
- **Finding**: We verified that `shape: const CircleBorder()` is already implemented at line 310 of `dashboard_screen.dart`. No further changes are required.

---

## 4. Calendar Strip chevrons and Weekly Rhythm

### Observation & Analysis
- **Lateral Chevrons**: We investigated `lib/features/dashboard/presentation/widgets/calendar_strip_widget.dart` and `lib/features/dashboard/presentation/dashboard_screen.dart`. No lateral chevrons (left/right navigation arrows) are currently present. The calendar strip is a self-contained horizontal scrolling list controlled by a `ScrollController`.
- **WeeklyRhythmWidget**: The widget exists as a file (`lib/features/dashboard/presentation/widgets/weekly_rhythm_widget.dart`) but is **not imported or used** anywhere in `dashboard_screen.dart`, `app_shell.dart`, or the rest of the app.
- **Database/History Calls**: There are no database or history queries associated with weekly rhythm stats in `dashboard_screen.dart` or `dashboard_notifier.dart`. The only database queries in `dashboard_notifier.dart` are for loading daily alarms/reminders and history events for reconstructing past "ghost alarms" (unrelated to weekly rhythm/adherence stats).

### Recommendation & Proposed Clean-up
1. **Delete Unused File**: Safely delete the unused `lib/features/dashboard/presentation/widgets/weekly_rhythm_widget.dart` file.
2. **Clean up Comment**: Remove the outdated comment in `dashboard_screen.dart` (line 38):
   ```dart
   // Remove this line:
   /// - Desktop sidebar: Weekly Rhythm
   ```
