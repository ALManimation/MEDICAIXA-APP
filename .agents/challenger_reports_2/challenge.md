# Adversarial Review Challenge Report — Reports Feature & Calculations

## Challenge Summary

**Overall risk assessment**: MEDIUM (due to Daylight Saving Time calendar vulnerability)

---

## Challenges

### [High] Challenge 1: Daylight Saving Time (DST) Day-Shifting and Skipping Vulnerability

- **Assumption challenged**: That calendar days can be safely calculated by adding or subtracting fixed 24-hour durations (`Duration(days: N)`) on a local `DateTime` instance.
- **Attack scenario**: In timezones where DST is active:
  - **Start of DST (23-hour day)**: Clocks jump forward by 1 hour. A day has only 23 hours. Subtracting `Duration(days: 1)` (24 hours) from Monday at 00:00 local time goes back 24 hours, landing on Saturday at 23:00. This skips Sunday entirely, causing Sunday's stats to be lost and Saturday's stats to be processed twice in `dailyAdherence`.
  - **End of DST (25-hour day)**: Clocks roll back by 1 hour. A day has 25 hours. Adding `Duration(days: 1)` (24 hours) to Sunday at 00:00 local time goes forward 24 hours, landing on Sunday at 23:00. This causes Sunday's statistics to be duplicated and processed twice in the monthly heatmap cells loop.
- **Blast radius**: Daily adherence percentages skip or duplicate days, and streak counts become off-by-one or reset incorrectly due to date mismatches.
- **Mitigation**: Refactor the day subtraction/addition to use calendar-based date arithmetic. Replace:
  ```dart
  todayMidnight.subtract(Duration(days: i))
  ```
  with:
  ```dart
  DateTime(todayMidnight.year, todayMidnight.month, todayMidnight.day - i)
  ```
  And in the heatmap:
  ```dart
  tempDate = tempDate.add(const Duration(days: 1))
  ```
  with:
  ```dart
  tempDate = DateTime(tempDate.year, tempDate.month, tempDate.day + 1)
  ```
  This delegates date math to Dart's built-in calendar engine, which correctly adjusts for local DST transitions.

### [Low] Challenge 2: Uninitialized ServicesBinding in Unit Tests

- **Assumption challenged**: That `MedicationRepository.loadDatabase()` can run during unit test startup without a full Flutter environment.
- **Attack scenario**: During unit tests, the repository calls `rootBundle.load('assets/medications_db.json.gz')` which throws `Binding has not yet been initialized`. While this is caught by a `try-catch` block, it pollutes test logs and means search capabilities cannot be unit tested without a binding.
- **Blast radius**: Test logs contain noisy error output.
- **Mitigation**: Add `TestWidgetsFlutterBinding.ensureInitialized()` at the beginning of the test suite `main()` function, or stub/mock the database loading.

---

## Stress Test Results

A new comprehensive test suite was written in `test/features/reports/reports_robustness_test.dart` and executed successfully.

- **Zero Alarms / Empty Database** → Verify stats are 0%, counts are 0, and streaks are 0 without crashing → **PASS**
- **Streak Calculation with Interspersed Empty Days** → Verify that days with no alarms are skipped (streak is preserved) and not counted as misses → **PASS**
- **Streak Calculation Resets on Misses** → Verify that a missed alarm breaks the active streak and resets it to 0 → **PASS**
- **Long Streaks (14 and 30 Days)** → Verify 14-day and 30-day perfect streaks calculate and cap correctly → **PASS**
- **Midnight Crossover Date Grouping** → Verify events at `00:01` and `23:59` are grouped in the same local day correctly → **PASS**
- **Memory Leak and Asynchronous Listeners** → Verify multiple provider container lifecycles do not leak listeners or throw unhandled async exceptions → **PASS**

---

## Unchallenged Areas

- **C++ Web UI and Firmware synchronization** — out of scope for this reports unit test suite.
