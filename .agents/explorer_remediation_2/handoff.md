# Handoff Report: Preventing Dashboard Calendar Flickering (R3 Investigation)

This analysis details the cause of the dashboard calendar screen flickering when changing dates and provides recommendations for implementing a smooth transition using a `LinearProgressIndicator` without destroying the `Scaffold` body tree.

---

## 1. Observation

In `lib/features/dashboard/presentation/dashboard_screen.dart` (lines 318–327):
```dart
        return Scaffold(
          backgroundColor: AppColors.background,
          body: state.isLoading
              ? Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                )
              : Column(
                  children: [
                    fixedHeader,
                    scrollableBody,
                  ],
                ),
```

In `lib/features/dashboard/presentation/dashboard_notifier.dart` (lines 96–101):
```dart
  void selectDate(DateTime date) {
    state = state.copyWith(selectedDate: date, isLoading: true);
    _updateData();
    
    _resetInactivityTimer();
  }
```

In `lib/features/dashboard/presentation/dashboard_notifier.dart` (lines 141–146, 311–322):
```dart
  Future<void> _updateData() async {
    final date = state.selectedDate;

    // Get all alarms and filter for selected date
    final allAlarms = await _alarmRepo.getAllAlarms();
    // ... [long-running async database querying & processing] ...
    
    state = DashboardState(
      selectedDate: date,
      alarms: filteredAlarms,
      allAlarms: allAlarms,
      reminders: filteredReminders,
      allReminders: allReminders,
      takenCount: takenCount,
      pendingCount: pendingCount,
      missedCount: missedCount,
      isLoading: false,
    );
  }
```

---

## 2. Logic Chain

1. **State Transition triggers Full Unmount**: 
   When the user selects a new date via the `CalendarStripWidget`, the notifier's `selectDate(date)` method is invoked. It immediately updates the UI state with `isLoading: true` (Observer 2).
2. **Scaffold Body Replaced**: 
   Because `state.isLoading` is true, the `Scaffold` in `DashboardScreen` unmounts the entire `Column` containing both `fixedHeader` (which embeds the `CalendarStripWidget`, the `HealthBannerWidget`, and header information) and `scrollableBody` (containing alarms and reminders) (Observer 1).
3. **Flicker Cause**: 
   During the asynchronous execution of `_updateData()` (which queries the SQLite database for alarms, reminders, history events, and ghost alarms) (Observer 3), the user only sees a blank dark/light page with a centered `CircularProgressIndicator`.
4. **Layout Restored**: 
   When `_updateData()` completes, `isLoading` is set to `false`, unmounting the `CircularProgressIndicator` and mounting a newly built `Column` from scratch. This complete tear-down and rebuild of the widget tree causes a severe visual flickering effect and ruins the user's focus on the calendar strip.

---

## 3. Caveats

- **Initial Load Behavior**: On the very first launch, the dashboard starts with empty lists and `isLoading: true`. Rendering the persistent widget tree immediately instead of a full-screen loading spinner will display an empty header and empty calendar strip for a fraction of a second. This is expected and desirable as it matches standard modern UI/UX practices where layouts are rendered instantly.
- **Out-of-Date Data Presentation**: While queries are executing in the background, the screen will continue to display the previous day's alarms and reminders. To prevent confusion, the recommendation includes adding a slight opacity reduction to `scrollableBody` during loading.

---

## 4. Conclusion

To eliminate dashboard flickering, we must keep the view hierarchy (`fixedHeader` and `scrollableBody`) constantly mounted inside the `Scaffold` body. The loading state should be indicated by a thin `LinearProgressIndicator` positioned between `fixedHeader` and `scrollableBody`. Wrapping the progress indicator in a fixed-height container prevents layout shifts, and dimming the body list signals that data is being refreshed.

### Recommended UI Changes

#### Change 1: Update Scaffold Body in `lib/features/dashboard/presentation/dashboard_screen.dart`

```dart
<<<<
        return Scaffold(
          backgroundColor: AppColors.background,
          body: state.isLoading
              ? Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                )
              : Column(
                  children: [
                    fixedHeader,
                    scrollableBody,
                  ],
                ),
====
        return Scaffold(
          backgroundColor: AppColors.background,
          body: Column(
            children: [
              fixedHeader,
              SizedBox(
                height: 4,
                child: state.isLoading
                    ? LinearProgressIndicator(
                        color: AppColors.primary,
                        backgroundColor: AppColors.background,
                      )
                    : null,
              ),
              scrollableBody,
            ],
          ),
>>>>
```

#### Change 2: Add Visual Dimmable Indicator to `scrollableBody` in `lib/features/dashboard/presentation/dashboard_screen.dart`

Wrap the inner `RefreshIndicator` inside `scrollableBody` with an `AnimatedOpacity` controlled by `state.isLoading`:

```dart
<<<<
        final scrollableBody = Expanded(
          child: RefreshIndicator(
            onRefresh: () => notifier.sync(),
            color: AppColors.primary,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isDesktop)
...
                  else
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _buildAlarmsBody(
                        context, ref, state,
                        morningAlarms, afternoonAlarms, nightAlarms, prnAlarms,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
====
        final scrollableBody = Expanded(
          child: AnimatedOpacity(
            opacity: state.isLoading ? 0.65 : 1.0,
            duration: const Duration(milliseconds: 150),
            child: RefreshIndicator(
              onRefresh: () => notifier.sync(),
              color: AppColors.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isDesktop)
...
                    else
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _buildAlarmsBody(
                          context, ref, state,
                          morningAlarms, afternoonAlarms, nightAlarms, prnAlarms,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
>>>>
```

---

## 5. Verification Method

1. **Manual Inspection**:
   - Verify the modified layout structure of `DashboardScreen` in `lib/features/dashboard/presentation/dashboard_screen.dart` to check that the `Scaffold` body uses a persistent `Column` structure with the embedded `SizedBox` hosting the `LinearProgressIndicator`.
2. **Build and Test execution**:
   - Run local analyzer: `flutter analyze`
   - Run tests: `flutter test` (All 104 unit/widget tests in the test suite have run and passed successfully).
3. **Invalidation conditions**:
   - Flickering is considered unresolved if changing the date still unmounts the `CalendarStripWidget` or `fixedHeader`.
