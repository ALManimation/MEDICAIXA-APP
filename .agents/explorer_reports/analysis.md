# ReportsScreen Analysis & Implementation Plan

This report contains a read-only investigation, design, and plan for implementing the new `ReportsScreen` and the associated database queries, ensuring alignment with the existing C++ web UI.

---

## 1. Codebase Paths & Structural Mapping

Below are the mapped paths for the components related to this milestone:

*   **Drift Database Definition**: `lib/core/database/database.dart` (defines tables, migrations, and database schema)
*   **Existing History Repository**: `lib/features/history/data/history_repository.dart` (handles data fetching and persistence of history events and system logs)
*   **Existing History Presentation**: `lib/features/history/presentation/history_screen.dart` (currently displays raw events and system logs tabs)
*   **Shell Navigation Structure**: `lib/core/presentation/app_shell.dart` (defines `AppShell` with the bottom navigation bar and desktop sidebar rails)
*   **Dashboard / Home Screen**: `lib/features/dashboard/presentation/dashboard_screen.dart` (contains the top header, summary icons, and navigation button to "Histórico & Logs")
*   **C++ Reference File**: `../Versoes/08.90 C++ Xiaozhi/littlefs_data/www/index.html` (contains HTML elements and complete JavaScript logic for statistics calculations and DOM drawing starting around line 3010 and 12300 respectively)

---

## 2. Database Columns & Data Types

The table `HistoryEvents` in `lib/core/database/database.dart` defines the schema for all historical events. It is defined as:

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

### Event Mappings & Statuses:
*   **type == 'alarm'**: Triggered by alarms (medication reminders).
    *   `TOMADO` (Regular scheduled dose taken on time)
    *   `TOMADO FORA HORA` (Scheduled dose taken late - delay > 10 minutes)
    *   `TOMADO PRN` (As-needed / sob demanda dose taken)
    *   `PERDIDO` (Missed dose or skipped/canceled dose)
    *   `SNOOZED` (Snoozed alarm - transient state, typically excluded from adherence calculations)
*   **type == 'reminder'**: Triggered by general reminders.
    *   `CONCLUIDO` (General reminder completed/checked off)
*   **type == 'system'**: Triggered by system-wide automation.
    *   `Ajuste Progressivo`, `Ciclo Pausa`, `Ciclo Retomado`, `Ciclo Reiniciado`, `Desmame Concluido`, `Desmame Etapa` (Events related to gradual dose adjustments, ON/OFF cycles, and weaning/titration stages)

For the calculation of adherence and compliance metrics, we filter history events to **`type == 'alarm'`** and categorize them as:
*   **Taken**: `status == 'TOMADO' || status == 'TOMADO FORA HORA' || status == 'TOMADO PRN'`
*   **Missed**: `status == 'PERDIDO'`
*   **Skipped/Canceled**: `status == 'CANCELADO'` (Currently, `markSkipped()` writes `status: 'PERDIDO'` in Flutter, but to match the C++ capability, any future event with `CANCELADO` or similar status should be counted as skipped/canceled).

---

## 3. Detailed Logic & Formulas for Reports

The C++ Web UI (`index.html`) implements metrics by looking back in time. For all metrics except the Monthly Heatmap, the current active **Medication Filter** (if set) is applied first.

Let $H_{alarm}$ be the set of alarm history events (where `type == 'alarm'`) filtered by the active medication (if selected).

### 3.1 Adherence General (Donut Chart)
*   **Time Window**: Last 7 days.
    $$sevenAgo = \text{midnight today} - 7 \text{ days}$$
    $$H_{recent} = \{e \in H_{alarm} \mid e.timestamp \ge sevenAgo\}$$
*   **Formula**:
    *   $T = |\{e \in H_{recent} \mid e.status \in \{\text{'TOMADO'}, \text{'TOMADO FORA HORA'}, \text{'TOMADO PRN'}\}\}|$ (Taken count)
    *   $M = |\{e \in H_{recent} \mid e.status = \text{'PERDIDO'}\}|$ (Missed count)
    *   $S = |\{e \in H_{recent} \mid e.status = \text{'CANCELADO'}\}|$ (Skipped count, defaults to 0)
    *   $Total = T + M + S$
    *   $$Adherence \% = \begin{cases} 0 & \text{if } Total = 0 \\ \text{round}\left(\frac{T}{Total} \times 100\right) & \text{if } Total > 0 \end{cases}$$
*   **UX/Styling**:
    *   Draw donut using a conic gradient: Green (`#10b981`) for Taken proportion, Red (`#ef4444`) for Missed, Orange (`#f59e0b`) for Skipped.
    *   Middle label: display $Adherence \%$ colored by range:
        *   $\ge 80\%$: Green (`#10b981`)
        *   $\ge 50\%$: Yellow/Orange (`#d97706`)
        *   $< 50\%$: Red (`#ef4444`)

### 3.2 Adherence Diária (Daily Bars)
*   **Time Window**: Last 7 days, chronologically from $today - 6 \text{ days}$ to $today$.
*   **For each day** $d$ in the window:
    *   Let $H_d = \{e \in H_{alarm} \mid \text{date}(e) = d\}$ (using Brazilian format `DD/MM/YYYY`)
    *   $T_d = |\{e \in H_d \mid e.status \text{ is taken}\}|$
    *   $E_d = |\{e \in H_d \mid e.status \text{ is taken, missed, or skipped}\}|$ (Expected count)
    *   $$DailyAdherence\%_d = \begin{cases} 0 & \text{if } E_d = 0 \\ \text{round}\left(\frac{T_d}{E_d} \times 100\right) & \text{if } E_d > 0 \end{cases}$$
    *   **Bar Height**: If $E_d = 0$, height is $0\%$. If $E_d > 0$, height is $\max(10, DailyAdherence\%_d)$ (ensure the bar is visible).
    *   **Bar Color**: Transparent if $E_d = 0$, else Green (`#10b981`) if $\ge 80\%$, Orange (`#f59e0b`) if $\ge 50\%$, Red (`#ef4444`) if $< 50\%$.
    *   **Label**: Short day of week name (e.g., 'Dom', 'Seg'). Highlight "Hoje" (today).

### 3.3 Streak / Sequência (Current vs Best)
*   **Time Window**: Last 30 days, from $today$ (index 0) backwards to $today - 29 \text{ days}$ (index 29).
*   **Daily Stats Mapping**: For each day $i \in [0, 29]$:
    *   $taken_i$ = count of taken events on day $i$.
    *   $missed_i$ = count of missed events on day $i$.
*   **Current Streak**:
    *   Start at index $i = 0$ (today) and count backwards:
        *   $hasAlarms = (taken_i + missed_i) > 0$
        *   If not $hasAlarms$, `continue` (does not break the streak).
        *   If $taken_i > 0$ and $missed_i == 0$, $currentStreak = currentStreak + 1$.
        *   Else if $missed_i > 0$:
            *   If $i == 0$ (today) and $missed_i == 0$, `continue` (an active day in progress with no misses doesn't break the streak).
            *   Otherwise, stop counting (streak is broken).
*   **Best Streak**:
    *   Scan chronologically from oldest to newest ($i = 29$ down to $0$):
        *   $hasAlarms = (taken_i + missed_i) > 0$
        *   If not $hasAlarms$, `continue`.
        *   If $taken_i > 0$ and $missed_i == 0$, $tempStreak = tempStreak + 1$ and $bestStreak = \max(bestStreak, tempStreak)$.
        *   Else, reset $tempStreak = 0$.
    *   After the loop, $bestStreak = \max(bestStreak, currentStreak)$.
*   **14-Dot Grid**:
    *   Show the last 14 days chronologically (left-to-right, index 13 down to 0).
    *   Dot type:
        *   **Full Green**: $taken_i > 0 \text{ and } missed_i == 0$
        *   **Partial Orange**: $taken_i > 0 \text{ and } missed_i > 0$
        *   **Red Miss**: $taken_i == 0 \text{ and } missed_i > 0$
        *   **Gray/Empty**: $taken_i == 0 \text{ and } missed_i == 0$

### 3.4 Period Distribution (Por Horário)
*   **Time Window**: Last 7 days.
*   **Periods**:
    *   Morning: Hour $\in [0, 11]$ (00:00 - 11:59)
    *   Afternoon: Hour $\in [12, 17]$ (12:00 - 17:59)
    *   Night: Hour $\in [18, 23]$ (18:00 - 23:59)
*   **Formula**:
    *   For each period $p \in \{\text{morning}, \text{afternoon}, \text{night}\}$:
        *   Let $H_p$ be the set of recent events falling within period $p$.
        *   $T_p = |\{e \in H_p \mid e.status \text{ is taken}\}|$
        *   $Total_p = |\{e \in H_p \mid e.status \text{ is taken, missed, or skipped}\}|$
        *   $$PeriodAdherence\%_p = \begin{cases} 0 & \text{if } Total_p = 0 \\ \text{round}\left(\frac{T_p}{Total_p} \times 100\right) & \text{if } Total_p > 0 \end{cases}$$
        *   **Bar Height**: $0\%$ if $Total_p = 0$, else $\max(10, PeriodAdherence\%_p)$.
        *   **Bar Color**: Transparent if $Total_p = 0$, else Green if $\ge 80\%$, Orange if $\ge 50\%$, Red if $< 50\%$.
        *   **Label/Icon**:
            *   Morning: Sun icon (`Icons.light_mode_rounded`, `#d97706`)
            *   Afternoon: Horizon/Sunset icon (`Icons.wb_twilight_rounded` or `Icons.wb_sunny_outlined`, `#2563eb`)
            *   Night: Moon icon (`Icons.dark_mode_rounded`, `#4b5563`)

### 3.5 Por Medicamento (Per-Medication)
*   *Note: Hidden if a specific medication filter is active.*
*   **Time Window**: Last 7 days.
*   **Initialize List**: For each unique medication in the active alarms or master database list, create a map record with $taken = 0$, $expected = 0$, and resolve its color.
*   **Accumulate**: For each event $e \in H_{recent}$:
    *   Let $m$ be the resolved lowercase medication name.
    *   If $e.status \text{ is taken} \Rightarrow taken_m = taken_m + 1, expected_m = expected_m + 1$
    *   Else if $e.status \text{ is missed or skipped} \Rightarrow expected_m = expected_m + 1$
*   **Filter**: Keep only records where $expected_m > 0$.
*   **Sort**: Sort descending by $expected_m$ (frequency).
*   **UX/Styling**: Horizontal row list showing:
    *   Medication name.
    *   Horizontal bar track with colored fill. The width is $(taken_m / expected_m) \times 100\%$. The fill color matches the medication's color.
    *   Percentage text: `${pct}%`.

### 3.6 Monthly Heatmap (Mapa Mensal)
*   **Time Window**: Last 30 days.
*   **Grid Calculations**:
    *   Let $startDate$ be $nowMidnight - 30 \text{ days}$. To align the grid to weeks, adjust back to Sunday:
        $$startDate_{aligned} = startDate - startDate.weekday \text{ days}$$
    *   Let $endDate$ be $nowMidnight$. To align the grid to the end of the current week, adjust forward to Saturday:
        $$endDate_{aligned} = endDate + (6 - endDate.weekday) \text{ days}$$
    *   Generate a cell for every day from $startDate_{aligned}$ to $endDate_{aligned}$.
*   **For each cell** (representing day $d$):
    *   $taken_d$ = count of taken events on day $d$.
    *   $total_d$ = count of taken + missed + skipped events on day $d$.
    *   If $d > today$, mark as **Future** (unclickable, gray text).
    *   If $d = today$, mark as **Today** (distinct borders).
    *   Compute $pct_d = total_d > 0 ? \text{round}(\frac{taken_d}{total_d} \times 100) : 0$.
    *   Map to level classes:
        *   $total_d == 0 \Rightarrow$ Level 0 (no data / no expected alarms: dark grey background)
        *   $pct_d == 100\% \Rightarrow$ Level 5 (Bright green: `#22c55e`)
        *   $pct_d \ge 75\% \Rightarrow$ Level 4 (Green: `#16a34a`)
        *   $pct_d \ge 50\% \Rightarrow$ Level 3 (Yellow/Orange: `#ca8a04`)
        *   $pct_d \ge 25\% \Rightarrow$ Level 2 (Dark orange: `#c2410c`)
        *   $pct_d < 25\% \Rightarrow$ Level 1 (Red/Dark red: `#991b1b`)
    *   **Visual Layout**:
        *   Header: Label row with letters: D, S, T, Q, Q, S, S.
        *   Grid: Rows representing weeks. The first element of each row is a label showing the Sunday's date in `DD/MM` format.
        *   Followed by the 7 daily cells showing the day number of the month.
        *   Legend below showing 0% (Red) to 100% (Green) scale and a separate indicator for "Sem dados".

---

## 4. Proposed Database Query Optimizations

Since history events are stored locally and are offline-first, we can optimize the retrieval by querying only relevant events from Drift. 

In `lib/features/history/data/history_repository.dart`, we should add:

```dart
// Fetch only alarm events since a specific timestamp (e.g. 35 days ago to cover heatmap padding)
Stream<List<HistoryEvent>> watchAlarmHistoryEventsSince(int startTimestamp) {
  return (_db.select(_db.historyEvents)
        ..where((t) => t.type.equals('alarm'))
        ..where((t) => t.timestamp.goe(startTimestamp))
        ..orderBy([
          (t) => OrderingTerm(expression: t.timestamp, mode: OrderingMode.desc)
        ]))
      .watch();
}
```

This allows us to watch only the history events needed for reports, preventing needless rebuilds of charts when system log lines are added.

---

## 5. Proposed File Structure

We propose establishing a new feature directory `lib/features/reports/` containing the following structure:

```
lib/features/reports/
├── data/
│   # HistoryRepository from lib/features/history/ can be reused, 
│   # or reports-specific queries can be placed here.
├── presentation/
│   ├── reports_screen.dart            # Main Reports Screen (contains TabBar for "Análise" and "Logs")
│   ├── reports_notifier.dart          # Riverpod notifier to compute metrics and hold filter state
│   └── widgets/
│       ├── medication_filter_bar.dart # Horizontal scrolling medication chip filters
│       ├── general_adherence_card.dart# Donut Chart with Taken/Missed/Skipped legend
│       ├── daily_adherence_card.dart  # 7-day adherence vertical column bar chart
│       ├── streak_card.dart           # Day sequence metric text + 14 dot status horizontal list
│       ├── period_distribution_card.dart # Morning/Afternoon/Night vertical column bar chart
│       ├── medication_performance_card.dart # Horizontal bar performance lists per med
│       └── monthly_heatmap_card.dart  # Aligned 30-day grid calendar heatmap with legend
```

### Design Integration Detail:
Instead of completely removing the events lists and debugging features from the old `HistoryScreen`, we recommend integrating it into the new `ReportsScreen` as the second tab. 
*   **Tab 1: Análise (Charts)**: Displays the medication filter, donut chart, daily bars, streak tracker, period distribution, medication horizontal bars, and the monthly heatmap.
*   **Tab 2: Histórico & Logs (List)**: Hosts the raw database entries and system debug logs with cleanup actions.
This preserves all debugging and log audits while providing a beautiful visual overview.

---

## 6. Shell & Dashboard Integration

To complete the implementation, the following changes are required:

1.  **`lib/core/presentation/app_shell.dart`**:
    *   Import the new `ReportsScreen` from `lib/features/reports/presentation/reports_screen.dart`.
    *   Replace `const HistoryScreen()` with `const ReportsScreen()` in the screen registry list `_screens` (line 26).
    *   Ensure the NavigationRail / BottomNavigationBar labels and icons are fully coordinated.

2.  **`lib/features/dashboard/presentation/dashboard_screen.dart`**:
    *   In the home page top panel under the "Histórico & Logs" tooltip button (line 189), update it to push `ReportsScreen` instead of `HistoryScreen` so that tapping it navigates to the visual reports view (ideally opening directly on Tab 1 or allowing navigation to it).

3.  **Standalone Mode compliance**:
    *   Confirm all data sources fall back gracefully if no physical box connection is active, rendering charts completely using the local Drift SQLite database.
