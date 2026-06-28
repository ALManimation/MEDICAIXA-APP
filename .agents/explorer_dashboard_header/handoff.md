# Handoff: Dashboard Header Reorganization and Collapsible Periods

## 1. Observation

Direct observations made in the codebase and reference project:
1. **Dashboard Screen**:
   * File: `lib/features/dashboard/presentation/dashboard_screen.dart`
   * Main structure is built using `SingleChildScrollView` wrapping header card, calendar strip, health banner, connection status pill, and alarm periods (lines 101–285).
   * Grouping is done using effective time slots (lines 64–98) where morning covers `00:00` to `11:59` (accounting for the 00:00–04:59 Madrugada range in morning slot per C++ `index.html` lines 7025–7026).
2. **Dashboard Notifier**:
   * File: `lib/features/dashboard/presentation/dashboard_notifier.dart`
   * Reactive state is mapped into `DashboardState` (lines 13–59) and fetched in `_updateData()` (lines 141–322).
   * The status checks for Today define completed vs missed alarms (lines 278–309).
3. **C++ reference file**:
   * File: `../Versoes/08.90 C++ Xiaozhi/littlefs_data/www/index.html`
   * Auto-collapse rules are managed via `shouldAutoCollapse(period)` (lines 7264–7269):
     * Morning auto-collapses when current hour >= 12.
     * Afternoon auto-collapses when current hour >= 18.
     * Night never auto-collapses by time.
   * Auto-collapse trigger updates on UI load/rendering: `updatePeriodCollapse()` (lines 7317–7326).
   * Manual override is supported with a timeout of 5 minutes: `togglePeriod(period)` (lines 7288–7315).
   * Empty groups never collapse: `if (st.count === 0) { setPeriodCollapsed(period, false); return; }` (line 7321).
4. **App Colors**:
   * File: `lib/core/constants/app_colors.dart`
   * Available color themes include `AppColors.primary`, `AppColors.missed`, `AppColors.text`, `AppColors.textMuted`.

## 2. Logic Chain

1. **Observations 1 & 2** reveal that the entire dashboard screen is inside a single scrollable container. To prevent the header components from scrolling away, we must lift the Header Card, Calendar Strip, Health Banner, and Connection Status outside of the scrollable list.
2. Placing them in a parent `Column` above an `Expanded` scroll view ensures the header is pinned, and nesting the `RefreshIndicator` inside the `Expanded` ensures pulling on the alarms triggers data sync while the header remains static.
3. **Observation 3** provides the exact rules used in the C++ project for collapsing groups: collapsing morning after midday (hour >= 12) and afternoon after evening (hour >= 18).
4. Expanding on the "completion" requirement, we can inspect `AlarmModel` fields (from Observation 2) to check if all active scheduled alarms in a period are finished (taken or missed). If there are no pending active alarms, the period should auto-collapse as well.
5. Using a Riverpod `StateProvider.family<Map<String, bool>, DateTime>` allows tracking manual expand/collapse states (manual override) independently for each date, resolving conflict with the auto-collapse timers and fallback behavior.

## 3. Caveats

* The C++ code implements a 5-minute timer to revert manual expansion overrides. The proposed Flutter design suggests maintaining manual overrides as long as the user stays on that specific date dashboard view to simplify state lifecycle and avoid memory leaks from active timers, but a timer could be added if 100% strict alignment is desired.
* We assume the system timezone and local hour are kept in sync on the device.

## 4. Conclusion

The analysis is complete. We recommend a layout refactoring of `dashboard_screen.dart` to separate fixed headers from scrollable alarm contents, wrapping the headers with collapsible controls (with animated chevron indicators and badges for pending and missed alarm counts), and applying the specified C++ auto-collapse timing and completion logic.

## 5. Verification Method

1. **Static Analysis**: Run `flutter analyze` to ensure no syntax errors.
2. **Unit Tests**: Run `flutter test` to ensure existing repository and notifier tests pass.
3. **Manual verification of header layout**: Once implemented, launch the application and verify that scrolling the alarm cards does not move the greeting card, calendar strip, health banner, or connection status.
4. **Manual verification of auto-collapse**:
   * If today, set system time to 13:00 and confirm the morning period auto-collapses on screen load.
   * If an alarm group has all its alarms marked taken/skipped, confirm the group collapses automatically.
   * Navigate to yesterday or tomorrow, and confirm all period groups are expanded by default.
5. **Manual override check**: Click the period headers to toggle the expand/collapse states, checking that manual overrides correctly disable the automatic logic.
