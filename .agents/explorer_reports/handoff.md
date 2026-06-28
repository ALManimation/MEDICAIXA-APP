# Handoff Report — ReportsScreen Exploration

This report summarizes the design, queries, and proposed implementation path for the new `ReportsScreen` and its adherence logic.

---

## 1. Observation

*   **Database Schema**: Found in `lib/core/database/database.dart` at line 125:
    ```dart
    class HistoryEvents extends Table {
      IntColumn get id => integer().autoIncrement()();
      IntColumn get alarmId => integer().nullable()();
      IntColumn get reminderId => integer().nullable()();
      TextColumn get medName => text().nullable()();
      TextColumn get dosage => text().nullable()();
      IntColumn get timestamp => integer()();
      TextColumn get status => text()(); // TOMADO, PERDIDO, SNOOZED, CONCLUIDO
      TextColumn get type => text()(); // alarm, reminder, system
      BoolColumn get pendingSync => boolean().withDefault(const Constant(false))();
    }
    ```
*   **Logging Operations**:
    *   In `lib/features/alarms/data/alarm_repository.dart` line 427: `final historyStatus = isLate ? 'TOMADO FORA HORA' : 'TOMADO';`
    *   In `lib/features/alarms/data/alarm_repository.dart` line 875: `status: 'TOMADO PRN',`
    *   In `lib/features/alarms/data/alarm_repository.dart` line 613: `status: 'PERDIDO',` (written when alarm window expires or marked skipped)
    *   In `lib/features/reminders/data/reminder_repository.dart` line 295: `status: 'CONCLUIDO',`
    *   In `lib/core/services/alarm_engine.dart` line 192: `status: 'Ajuste Progressivo', type: 'system'` (and other system actions).
*   **C++ Web UI Calculations**: Located in `../Versoes/08.90 C++ Xiaozhi/littlefs_data/www/index.html` lines 12501–12921. Notable segments:
    *   *Adherence General (Donut)*:
        ```javascript
        logs.forEach(l => {
          if (l.event === 'Tomado') taken++;
          else if (l.event === 'Não Tomado' || l.event === 'Perdido') missed++;
          else if (l.event === 'Cancelado') skipped++;
        });
        ```
    *   *Streak / Sequência*:
        ```javascript
        if (dStat.taken > 0 && dStat.missed === 0) {
          currentStreak++;
        } else {
          if (i === 0 && dStat.missed === 0) { continue; }
          streakBroken = true;
          break;
        }
        ```
    *   *Monthly Heatmap Grid Aligned to Weeks*:
        ```javascript
        const startDate = new Date(nowMidnight.getTime() - 30 * 24 * 3600 * 1000);
        const startDayOfWeek = startDate.getDay(); // 0=Dom
        startDate.setDate(startDate.getDate() - startDayOfWeek);
        ```
*   **Shell Integration & Dashboard Navigation**:
    *   In `lib/core/presentation/app_shell.dart` line 26: `const HistoryScreen(),` (third screen in navigation list).
    *   In `lib/features/dashboard/presentation/dashboard_screen.dart` line 189: `MaterialPageRoute(builder: (_) => const HistoryScreen()),` under the history icon button callback.

---

## 2. Logic Chain

1.  **Metric Isolation**: Adherence statistics only concern medication actions, represented in Drift database table `HistoryEvents` where `type == 'alarm'`. Other types (`reminder` and `system`) must be excluded from calculations to avoid skewed reports.
2.  **Date Resolution**: The app stores alarm `lastStatusDate` as Brazilian-formatted strings `DD/MM/YYYY` (Observation 1, core rule 39). Therefore, database queries or parsing logic in Dart must map and group the `timestamp` field into matching timezone-local days (formatted as `DD/MM/YYYY` in local timezone America/Sao_Paulo).
3.  **Unified Screen Structure**: If we replace `HistoryScreen` with `ReportsScreen`, we will lose the raw logging audit tabs ("Eventos" and "Logs do Sistema") unless we encapsulate them inside a subview or a secondary tab in the new `ReportsScreen`. Thus, the optimal design is a `DefaultTabController` displaying the visual charts on Tab 1 ("Análise") and the raw logs list on Tab 2 ("Histórico & Logs").
4.  **Optimal Query Routing**: To prevent reports from rebuilding when non-alarm (system/reminder) logs are added, we should introduce a dedicated optimized Drift query `watchAlarmHistoryEventsSince(int startTimestamp)` that pre-filters `type == 'alarm'` and limits history scope to the required 35-day timeframe.

---

## 3. Caveats

*   **Offline / Standalone calculations**: The C++ Web UI fetches `/history` directly from the ESP32. In Flutter, the repository synchronizes history data to local SQLite. The logic design assumes that the local database is the source of truth, meaning compliance stats are generated offline without needing a physical connection to the ESP32.
*   **Date formats**: Epoch timestamps in `HistoryEvents` need to be resolved to day strings using the device's local timezone. timezone variations must be handled properly in Dart.

---

## 4. Conclusion

The milestone can be fully realized by:
1.  Creating the folder `lib/features/reports/` with the widgets and state notifier following the proposed feature-first architecture.
2.  Implementing the six specific compliance widgets (Donut, Daily Bars, Streak, Period Distribution, Medication Bars, Heatmap) and the horizontal Medication Filter in Dart using the exact C++ formulas.
3.  Upgrading `AppShell` and `DashboardScreen` to route to `ReportsScreen` instead of `HistoryScreen`.
4.  Structuring `ReportsScreen` with a Tabbed Layout to preserve the raw log viewing and clearing tools.

---

## 5. Verification Method

*   **Code Review**: Verify that the new `ReportsScreen` path is imported in `lib/core/presentation/app_shell.dart` and replaces `HistoryScreen`.
*   **Compilation**: Build the application using:
    ```bash
    flutter analyze
    ```
    Verify that there are no static analyzer or compilation issues.
*   **Test Command**: Execute unit tests using:
    ```bash
    flutter test
    ```
