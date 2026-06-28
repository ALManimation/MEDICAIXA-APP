# Quality & Adversarial Review Report

---

# PART 1: Quality Review Report

## Review Summary

**Verdict**: REQUEST_CHANGES

The reports feature logic, data stream optimizations, and unit tests have been thoroughly reviewed.
- The compliance calculations and formulas align perfectly with the C++ project specifications (`index.html`).
- The Drift database queries have been correctly optimized, preventing reports rebuilds when system logs or non-alarm logs are added.
- The Drift model naming rules (singular name `HistoryEvent` without `Data` suffix) are followed.
- **Verdict Rationale**: While widget filter interactions are covered in robustness tests, there is a **coverage gap** in the notifier unit tests. No unit test verifies that calling `setFilter` on the `ReportsNotifier` correctly recalculates the state statistics (percentages, daily groupings, and streaks) to isolate only the target medication's history. Thus, `REQUEST_CHANGES` is issued to add this specific test case.

---

## Findings

### [Major] Finding 1: Missing Unit Test Coverage for Notifier Filter Change Handling

- **What**: The unit tests in `reports_test.dart` and `reports_robustness_test.dart` do not assert state changes when calling `setFilter(...)` on the `ReportsNotifier`.
- **Where**: `test/features/reports/reports_test.dart`
- **Why**: The instruction explicitly requires verifying that "Unit tests cover various scenarios (calculating general percentages, daily grouping, streaks with no-alarms days, period grouping, and filter change handling)". Calling `setFilter` and asserting the filtered metrics is crucial to guarantee that in-memory filtering logic works as intended.
- **Suggestion**: Add a new test case in `reports_test.dart` that:
  1. Inserts two different medications (e.g. "Paracetamol" and "Ibuprofeno").
  2. Inserts history events for both medications.
  3. Initializes the notifier (which defaults to 'Todos').
  4. Asserts that the unfiltered metrics contain counts from both.
  5. Calls `setFilter('Paracetamol')`.
  6. Asserts that only "Paracetamol" events are included in the new state calculations.

### [Minor] Finding 2: DST-Unsafe Date Math on `DateTime` Subtraction

- **What**: The use of `todayMidnight.subtract(Duration(days: i))` to generate relative dates in loops is unsafe under Daylight Saving Time (DST) changes.
- **Where**: `lib/features/reports/presentation/reports_notifier.dart` (lines 199, 275, 303, 340, 527, 529)
- **Why**: Subtracting `Duration(days: i)` subtracts exactly `i * 24` hours. During DST boundaries (e.g., transition from/to DST), a calendar day may have 23 or 25 hours. Subtracting 24 hours can result in an hour shift (e.g., landing at 23:00 of the previous day or 01:00 of the same day), causing days to duplicate or be skipped in the daily adherence list.
- **Suggestion**: Use calendar-based date generation instead, e.g.:
  `DateTime(todayMidnight.year, todayMidnight.month, todayMidnight.day - i)`
  This approach is DST-safe because Dart handles month/day overflows/underflows natively at the constructor level.

---

## Verified Claims

- **C++ Spec Alignment (Compliance Formulas)** → verified via independent reading and comparison with `/Users/almanimation/Downloads/Caixa Remedios/Versoes/08.90 C++ Xiaozhi/littlefs_data/www/index.html` → **PASS**
  - *Details*: The daily adherence calculation matches line 12552 (`renderDailyBars`), the streak calculation matches line 12596 (`renderStreak`), and the period distribution matches line 12766 (`renderPeriodDistribution`).
- **Drift Stream Isolation (`watchAlarmHistoryEventsSince`)** → verified via database schema and query stream structure inspection → **PASS**
  - *Details*: `watchAlarmHistoryEventsSince` watches the `HistoryEvents` table but filters `type == 'alarm'`. Since system logs are added to a separate table `SystemLogs` (via `addSystemLog`), log additions do not trigger database updates or stream events on this query.
- **Drift Model Naming Conventions** → verified via project search and inspection of `database.dart` / `database.g.dart` → **PASS**
  - *Details*: Drift uses singular names without a suffix. The `HistoryEvents` table maps to the `HistoryEvent` class, and no occurrences of `HistoryEventData` exist in the code.

---

## Coverage Gaps

- **Notifier `setFilter` validation** — risk level: **Medium** — recommendation: Implement unit test verifying that `setFilter` correctly updates reports state for a selected medication.
- **DST Edge Cases** — risk level: **Low** — recommendation: Update `ReportsNotifier` duration-subtraction logic to use calendar-based date generation.

---

## Unverified Items

- None.

---
---

# PART 2: Adversarial Review Report

## Challenge Summary

**Overall risk assessment**: LOW

The overall structure of the reports business logic is robust and leverages Drift's reactive database streams correctly. The main concerns lie in timezone boundaries and potential DST boundary anomalies.

---

## Challenges

### [Low] Challenge 1: DST Boundary Shifts in Calendar Calculations

- **Assumption challenged**: Calendar days can always be calculated by subtracting multiples of 24-hour durations (`Duration(days: i)`).
- **Attack scenario**: On a DST change day, subtracting 24 hours from midnight might shift the clock back to 23:00 on the prior day. When formatting this via `formatDate(day)` (which displays `DD/MM/YYYY`), the same date string will be processed twice, leading to a duplicated column in `dailyAdherence` or a missed column.
- **Blast radius**: Visual glitch in Daily Adherence bars and Monthly Heatmap on DST transition days.
- **Mitigation**: Replace `DateTime.subtract(Duration(days: i))` with `DateTime(year, month, day - i)`.

---

## Stress Test Results

- **Multiple same-day logs** → Grouping correctly aggregates multiple taken/missed logs on the same day instead of creating multiple day entries → **PASS**
- **Boundary time logs (00:01 and 23:59)** → Logged events exactly at the edge of days are correctly partitioned into their respective local dates → **PASS**
- **Zero alarm days** → Adherence calculations correctly return `0%` and streaks skip these days rather than resetting, matching the C++ specification → **PASS**

---

## Unchallenged Areas

- **Drift SQLite native thread behaviors** — reason not challenged: Standard Flutter-Drift native bindings are out of scope for application logic auditing.
