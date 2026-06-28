## 2026-06-28T15:29:12Z

You are the Worker subagent for the ReportsScreen milestone.
Your task is to implement the new ReportsScreen featuring CustomPainter charts, bottom navigation tab replacements, Drift SQLite database calculations, and comprehensive unit tests.

### Reference Documents:
- Plan: `/Users/almanimation/Downloads/Caixa Remedios/medicaixa_app/.agents/orchestrator/plan.md`
- Codebase analysis: `/Users/almanimation/Downloads/Caixa Remedios/medicaixa_app/.agents/explorer_reports/analysis.md`
- C++ JavaScript reference calculations: `/Users/almanimation/Downloads/Caixa Remedios/Versoes/08.90 C++ Xiaozhi/littlefs_data/www/index.html` (specifically lines 12400 to 12900)

### Codebase Scope:
1. **Drift Queries & Optimization**:
   - In `lib/features/history/data/history_repository.dart`, add `watchAlarmHistoryEventsSince(int startTimestamp)` to retrieve only history events where `type == 'alarm'` and `timestamp >= startTimestamp`, ordered by `timestamp` desc.
   - Alternatively, add this optimization in a reports-specific repository if it is cleaner.

2. **Reports Notifier (`lib/features/reports/presentation/reports_notifier.dart`)**:
   - Implement `ReportsNotifier` as a Riverpod notifier (`@riverpod`).
   - Listen/watch the alarm history events from `watchAlarmHistoryEventsSince` starting 35 days ago (to account for monthly heatmap week padding).
   - Maintain state containing: active medication filter (selected medication name or 'Todos'), and the computed metrics.
   - **Adherence General (last 7 days)**:
     - Expected total = taken + missed + skipped.
     - Taken = status is `TOMADO`, `TOMADO FORA HORA`, `TOMADO PRN` or `CONCLUIDO`.
     - Missed = status is `PERDIDO`.
     - Skipped = status is `CANCELADO` (or similar skipped status if any).
     - Calculate rounded percentage: `round((taken / expected) * 100)` or 0 if expected is 0.
   - **Daily Adherence (last 7 days)**:
     - Group events by day in local time timezone (use `DD/MM/YYYY` format to format date from event timestamp, matching C++).
     - For each of the last 7 days (including today), compute percentage.
   - **Streak (last 30 days)**:
     - Group events by day for the last 30 days.
     - Start from today (index 0) backwards: if day has no alarms (`taken + missed == 0`), skip it (does not break streak). If day has taken > 0 and missed == 0, increment current streak. If day has missed > 0, check if it is index 0 (today) with missed == 0 (no miss today doesn't break streak yet). Else, stop counting (broken).
     - Compute best historical streak by scanning chronologically and finding the longest consecutive segment of days with taken > 0 and missed == 0 (ignoring empty days).
   - **14-day Grid**:
     - Status for each of the last 14 days: Full Green (taken > 0 and missed == 0), Partial Orange (taken > 0 and missed > 0), Red Miss (taken == 0 and missed > 0), Gray/Empty (taken == 0 and missed == 0).
   - **Period Distribution (last 7 days)**:
     - Group recent events by hour of the timestamp: Morning (00:00-11:59), Afternoon (12:00-17:59), Night (18:00-23:59).
     - For each period, calculate taken / total.
   - **Per Medication Performance (last 7 days)**:
     - Calculate taken / expected for each medication active in the history events, including its registered color (resolve color from meds list).
   - **Monthly Heatmap (last 30 days)**:
     - Generate a 5-week grid. Let start date be `now - 30 days` aligned back to Sunday. Let end date be today aligned forward to Saturday.
     - For each cell, calculate adherence percentage and assign Level 0 (no data), Level 1 (<25%), Level 2 (25-49%), Level 3 (50-74%), Level 4 (75-99%), Level 5 (100%). Mark cells in the future as Future, and today as Today.

3. **CustomPainter Charts (`lib/features/reports/presentation/widgets/`)**:
   - Implement `CustomPainter` widgets to draw the Donut Chart, Daily Bars, Streak Dots grid, Period Distribution, and Monthly Heatmap.
   - Donut Chart: draw arc segments using `Canvas.drawArc` with correct angles and colors (Taken: `#10b981`, Missed: `#ef4444`, Skipped: `#f59e0b`).
   - Daily Bars: draw tracks and vertical filled columns with rounded corners (`RRect`).
   - Period Distribution: draw vertical columns with rounded corners.
   - Monthly Heatmap: draw calendar cells styled as a grid. (Using standard widgets with a grid layout or custom painters is allowed, but the cells must have clean styling and colors matching the requirements).

4. **ReportsScreen (`lib/features/reports/presentation/reports_screen.dart`)**:
   - Layout scrollable view containing the 6 visual metrics cards.
   - Footer: sticky filter chips bar with a horizontal list of chips for "Todos" and each registered medication. Clicking updates the filter and recalculates metrics.
   - When filtering by a specific medication, the "Por Medicamento" progress bars card must be hidden.

5. **Shell Navigation & Dashboard Updates**:
   - In `lib/core/presentation/app_shell.dart`, import `ReportsScreen` and replace `HistoryScreen` with `ReportsScreen` in the `_screens` registry list (third tab).
   - In `lib/features/dashboard/presentation/dashboard_screen.dart`, ensure that tapping the "Histórico & Logs" icon still pushes `HistoryScreen` onto the Navigator stack so that users can view raw event history/logs.

6. **Unit Testing (`test/features/reports/reports_test.dart`)**:
   - Write tests validating the calculations for adherence, streaks (checking empty days skipping), period grouping, and correct database/state integration.

7. **Static Verification**:
   - Run `dart run build_runner build --delete-conflicting-outputs` if you make any changes requiring code generation.
   - Run `flutter analyze` and fix all static errors.
   - Run `flutter test` and verify that all tests pass.

### Crucial Constraints:
- DO NOT use `const` with `AppColors.xxx` (Rule 22). Icon, TextStyle, BorderSide, etc. referencing `AppColors.xxx` must NOT be const.
- Use `context.mounted` in asynchronous callbacks (Rule 32).
- Use package imports for all new imports.
- Maintain Offline-First support: fall back to Drift SQLite cache if physical ESP32 box is not connected.
- Table classes in Drift: class for table `HistoryEvents` is `HistoryEvent`, table `Settings` is `Setting`, etc. No `Data` suffix.
- Keep C++ formatting for dates: Brazilian format `DD/MM/YYYY`.
