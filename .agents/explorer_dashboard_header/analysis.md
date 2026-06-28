# Analysis: Dashboard Header Reorganization and Collapsible Periods

This report details the findings and architectural recommendations for the Dashboard UI reorganization. The goal is to move the core header components to a fixed top layout and implement collapsible period groups with auto-collapse rules matching the C++ firmware/Web UI behavior.

---

## 1. Current Codebase Exploration

### 1.1 Dashboard Screen Layout
The main dashboard is implemented in:
* **Path**: `lib/features/dashboard/presentation/dashboard_screen.dart`
* **Widget Class**: `DashboardScreen` (extends `ConsumerWidget`)

Currently, the screen utilizes a single scrolling container (`SingleChildScrollView`) wrapping the entire layout (lines 101–285). This causes all header elements (Header Card, Calendar Strip, Health Adherence Banner, and Connection Status) to scroll off-screen as the user scrolls down their daily alarms list.

### 1.2 Location of Key Widgets
Below is the trace of where and how the main header components are currently rendered within the `build()` method of `DashboardScreen`:

1. **Header Card (Greeting + Sync & Action Buttons)**:
   * **Lines**: 108–201
   * **Description**: A `Container` with a dark surface background, rounded bottom corners (`bottomLeft`/`bottomRight` 24dp), and bottom shadows. It dynamically calculates a greeting (Bom dia/Boa tarde/Boa noite) based on the local system time and reads the patient's name from database settings. It also renders the manual sync button, history navigation button, and disconnect button (when connected to a device).
2. **Calendar Strip Widget**:
   * **Line**: 205 (`const CalendarStripWidget()`)
   * **Path**: `lib/features/dashboard/presentation/widgets/calendar_strip_widget.dart`
   * **Description**: A horizontal scrollable list of days representing the week, allowing date navigation.
3. **Health Banner Widget**:
   * **Lines**: 209–212 (`HealthBannerWidget(alarms: state.alarms, currentDate: state.selectedDate)`)
   * **Path**: `lib/features/dashboard/presentation/widgets/health_banner_widget.dart`
   * **Description**: A styled card indicating adherence levels (e.g. "Excelente Adesão", "Atenção", etc.) based on alarm completion rates.
4. **Connection Status Pill**:
   * **Lines**: 216–239
   * **Description**: A small `Row` with a circular status light (green if connected, muted grey if offline) and label text ("MediCaixa conectada" or "Modo Offline").

---

## 2. Alarm Period Fetching & Grouping Analysis

### 2.1 Where Alarms are Fetched
Alarms are reactively watched and updated by `DashboardNotifier` in:
* **Path**: `lib/features/dashboard/presentation/dashboard_notifier.dart`
* **Notifier**: `DashboardNotifier` (annotated with `@riverpod`)

The notifier watches the repository stream and filters active alarms for the selected calendar date in `_updateData` (line 141). The resulting `state.alarms` list is passed to the screen.

### 2.2 Time-Based Grouping (C++ Rules)
Inside the `build()` method of `DashboardScreen` (lines 64–98), active alarms are filtered and placed into four time-based periods. This mirrors the grouping logic in the C++ project's `index.html` (lines 7024–7029):
1. **Sob Demanda (PRN)**:
   * **Condition**: `alarm.isPrn == true`
   * **Behavior**: Displayed in an exclusive top-level section if populated.
2. **Manhã (Morning)**:
   * **Condition**: Effective time is between `00:00` and `11:59` (0 to 719 minutes).
   * **Note**: As mandated by `AGENTS.md` thinking rules, the period from `00:00` to `04:59` (Madrugada) is classified into "Manhã" (consistent with lines 7025–7026 in the C++ code).
3. **Tarde (Afternoon)**:
   * **Condition**: Effective time is between `12:00` and `17:59` (720 to 1079 minutes).
4. **Noite (Night)**:
   * **Condition**: Effective time is between `18:00` and `23:59` (1080 to 1439 minutes).

The effective time calculation includes the original scheduled time + `snoozeMin` (if snooze is active on Today):
```dart
static int _getEffectiveTime(AlarmModel alarm, {required bool isToday}) {
  int mins = alarm.hour * 60 + alarm.minute;
  if (isToday && alarm.snoozeMin > 0) mins += alarm.snoozeMin;
  return mins % 1440;
}
```

---

## 3. Alarm State and Count Identification

To display active and missed counts in the period headers, we must map the alarm statuses for the selected day:
1. **Taken (Tomado)**:
   * `alarm.lastStatusDate == dateFormatted && alarm.lastStatus == 'Tomado'`
2. **Skipped (Não Tomado / Perdido)**:
   * `alarm.lastStatusDate == dateFormatted && alarm.lastStatus == 'Não Tomado'`
3. **Missed (Perdido due to elapsed time)**:
   * Only applicable when the selected date is **Today**.
   * If the current local time has passed the alarm's effective time and the alarm is neither taken nor skipped.
   * *Formula*: `isToday && nowTimeInMins > effectiveTimeInMins && !isTaken && !isSkipped`
4. **Pending (Ativo / Pendente)**:
   * The alarm is scheduled, active (`enabled && active`), and has not yet been taken, skipped, or missed (the time is in the future).
   * *Formula*: `alarm.enabled && alarm.active && !isTaken && !isSkipped && (!isToday || nowTimeInMins <= effectiveTimeInMins)`

### Summary Counts Formula per Group:
* **Active (Pending) Count**: Enabled alarms that are scheduled for the day and are still waiting to be taken (i.e. time has not passed and they are not taken or skipped).
* **Missed Count**: Alarms in the group that were either explicitly skipped (`Não Tomado`) or whose scheduled time has passed today (or in the past) without being taken.

---

## 4. Reorganization and Collapsible Design Recommendations

### 4.1 Scaffold Layout Refactoring
To pin the header elements at the top, we must remove them from the `SingleChildScrollView`. The body of the `Scaffold` should be restructured into a fixed vertical column:

```dart
return Scaffold(
  backgroundColor: AppColors.background,
  body: Column(
    children: [
      // 1. Fixed Header Section (No scroll)
      Container(
        color: AppColors.background, // Or surface depending on theme
        child: Column(
          children: [
            const DashboardHeaderCard(), // Extracted Header Card
            const SizedBox(height: 16),
            const CalendarStripWidget(),
            const SizedBox(height: 16),
            HealthBannerWidget(alarms: state.alarms, currentDate: state.selectedDate),
            const SizedBox(height: 16),
            const ConnectionStatusPill(), // Extracted connection dot + text
            const SizedBox(height: 12),
          ],
        ),
      ),
      
      // 2. Scrollable Body Section
      Expanded(
        child: RefreshIndicator(
          onRefresh: () => notifier.sync(),
          color: AppColors.primary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 100, left: 16, right: 16),
            child: isDesktop
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: _buildAlarmsBody(context, ref, state, morningAlarms, afternoonAlarms, nightAlarms, prnAlarms),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        flex: 1,
                        child: WeeklyRhythmSidebar(),
                      ),
                    ],
                  )
                : _buildAlarmsBody(context, ref, state, morningAlarms, afternoonAlarms, nightAlarms, prnAlarms),
          ),
        ),
      ),
    ],
  ),
);
```

### 4.2 Collapsible Period Headers
Each period group header should be turned into an interactive widget supporting expand/collapse toggles, dynamic chevrons, and badge counts:

```dart
Widget _buildCollapsiblePeriodHeader({
  required String label,
  required IconData icon,
  required Color iconColor,
  required int activeCount,
  required int missedCount,
  required bool isCollapsed,
  required VoidCallback onTap,
}) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(8),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.text,
            ),
          ),
          const SizedBox(width: 8),
          
          // Active Pending Count Badge
          if (activeCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$activeCount',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
          const SizedBox(width: 6),
          
          // Missed Count Badge (in red)
          if (missedCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.missed.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$missedCount perdido${missedCount > 1 ? 's' : ''}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.missed,
                ),
              ),
            ),
            
          const Spacer(),
          
          // Animated Chevron
          AnimatedRotation(
            turns: isCollapsed ? 0.0 : 0.5, // 0.5 turns = 180 deg
            duration: const Duration(milliseconds: 200),
            child: Icon(
              Icons.expand_more_rounded,
              color: AppColors.textMuted,
              size: 22,
            ),
          ),
        ],
      ),
    ),
  );
}
```

### 4.3 C++ Auto-Collapse Logic Rules
We will reproduce the `index.html` collapse and time rules dynamically in the UI:
1. **For Today (`isToday == true`)**:
   * A period section is automatically collapsed if:
     * **By Time**:
       * `morning` (00:00–11:59): local system time hour >= 12.
       * `afternoon` (12:00–17:59): local system time hour >= 18.
       * `night` (18:00–23:59): never auto-collapses by time.
     * **By Completion**:
       * The period is not empty (`alarms.isNotEmpty`), and **all** enabled/active alarms within it are completed (either taken or missed).
       * *Formula*: `alarms.every((a) => !a.enabled || !a.active || isTaken(a) || isMissed(a))`
   * *Exception*: Empty groups (`alarms.isEmpty`) always show the "Nenhum alarme neste período" card and do not collapse.
2. **For Other Days (`isToday == false`)**:
   * All periods default to **fully expanded** (`isCollapsed = false`).
3. **Manual Overrides**:
   * When the user explicitly taps a header, we write the overridden value to a Riverpod provider state maps (e.g. `Map<String, bool>` mapping period keys to collapse states). This manual choice overrides the automatic logic until the date changes.

```dart
// Riverpod provider to hold manual overrides per selected date
final dashboardCollapseProvider = StateProvider.family<Map<String, bool>, DateTime>((ref, date) {
  return {};
});

// Logic inside build() to determine collapse state for a period
bool getPeriodCollapseState({
  required String period, // 'morning' | 'afternoon' | 'night'
  required List<AlarmModel> periodAlarms,
  required DateTime selectedDate,
  required WidgetRef ref,
}) {
  final now = DateTime.now();
  final isToday = selectedDate.year == now.year &&
                  selectedDate.month == now.month &&
                  selectedDate.day == now.day;

  // Check manual override first
  final overrides = ref.watch(dashboardCollapseProvider(selectedDate));
  if (overrides.containsKey(period)) {
    return overrides[period]!;
  }

  // If no override, apply rules:
  if (!isToday) {
    return false; // Other days are fully expanded
  }

  if (periodAlarms.isEmpty) {
    return false; // Empty sections remain open
  }

  // Rule A: By time
  bool collapsedByTime = false;
  if (period == 'morning' && now.hour >= 12) {
    collapsedByTime = true;
  } else if (period == 'afternoon' && now.hour >= 18) {
    collapsedByTime = true;
  }

  // Rule B: By completion (no pending active alarms)
  final dateFormatted = "${selectedDate.day.toString().padLeft(2, '0')}/${selectedDate.month.toString().padLeft(2, '0')}/${selectedDate.year}";
  bool collapsedByCompletion = periodAlarms.every((alarm) {
    final isTaken = alarm.lastStatusDate == dateFormatted && alarm.lastStatus == 'Tomado';
    final isSkipped = alarm.lastStatusDate == dateFormatted && alarm.lastStatus == 'Não Tomado';
    final alarmTime = DateTime(now.year, now.month, now.day, alarm.hour, alarm.minute);
    final hasPassed = now.isAfter(alarmTime);
    
    // An alarm is completed if it's inactive, taken, skipped, or missed by time.
    return !alarm.enabled || !alarm.active || isTaken || isSkipped || hasPassed;
  });

  return collapsedByTime || collapsedByCompletion;
}
```

---

## 5. Summary Recommendation for Implementation

1. **Scaffold Reorganization**: Modify `dashboard_screen.dart` to split the top fixed items into their own `Column` at the top of the body, wrapping the main scrolling content (reminders, alarm groups, and desktop rhythm sidebars) inside a `SingleChildScrollView` nested in an `Expanded` box.
2. **Keep the Refresh Indicator**: Wrap the `SingleChildScrollView` under the `Expanded` layout with the `RefreshIndicator`. This ensures pulling down on the list refreshes data while keeping the headers fixed.
3. **Period Expansion States**: Add the `dashboardCollapseProvider` family to manage the manual state map and implement the `getPeriodCollapseState` helper in `dashboard_screen.dart`.
4. **Header Refactoring**: Wrap the period titles in `InkWell` to fire manual toggle events. Animate the chevron rotation based on the evaluated boolean state.
5. **Counts rendering**: Render the calculated active pending count and missed count badges in the period headers.
