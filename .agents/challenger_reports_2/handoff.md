# Handoff Report — Challenger 2 (Testing & Core Verification)

## 1. Observation

1. **Test Commands & Results**:
   Ran the project's verification suite using:
   ```bash
   flutter test test/features/reports/reports_test.dart test/features/reports/reports_robustness_test.dart
   ```
   All tests passed successfully:
   ```
   00:00 +6: All tests passed!
   ```
2. **Error Output (Warnings in Logs)**:
   Observed the following output during test runs:
   ```
   Error loading medications database: Binding has not yet been initialized.
   The "instance" getter on the ServicesBinding binding mixin is only available once that binding has been initialized.
   ```
3. **Code in `reports_notifier.dart`**:
   At line 303:
   ```dart
   final day = todayMidnight.subtract(Duration(days: i));
   ```
   At line 535:
   ```dart
   tempDate = tempDate.add(const Duration(days: 1));
   ```
4. **Code in `medication_repository.dart`**:
   At line 95:
   ```dart
   Future<void> loadDatabase() async {
     ...
     final byteData = await rootBundle.load('assets/medications_db.json.gz');
     ...
   ```

---

## 2. Logic Chain

1. **Verification of Adherence and Streak Correctness**:
   - The test suite verified that streak counting accurately counts active days, skips empty days, and resets on misses.
   - The test `test/features/reports/reports_robustness_test.dart` simulated these scenarios (including 14 and 30-day streaks) and all passed.
2. **Daylight Saving Time (DST) Bug Identification**:
   - The code calculates calendar days by subtracting or adding a fixed `Duration` of 24 hours (`Duration(days: i)` or `Duration(days: 1)`).
   - On days when DST changes, the local day has 23 or 25 hours.
   - Subtracting 24 hours on a 23-hour day goes back to Saturday 23:00, skipping Sunday entirely and duplicating Saturday.
   - Adding 24 hours on a 25-hour day stays on Sunday at 23:00, leading to a duplicate Sunday in the monthly heatmap.
   - Therefore, the calculation of calendar days using `Duration` is vulnerable to DST-induced shifts.

---

## 3. Caveats

- We did not investigate visual UI styling or rendering overflows on the reports screen, as this task was focused on calculation logic, test execution, coverage, and memory/async leaks.
- We did not test real-time timezone switches on a physical device, but verified the logic analytically.

---

## 4. Conclusion

- All unit and robustness tests for the reports feature pass successfully.
- Adherence and streak calculations are correct under standard conditions (handling empty days and resets correctly).
- There are no memory leaks or asynchronous callback issues in the reports notifier since it is managed auto-disposably via Riverpod's declarative `ref.watch` and contains only synchronous event handling.
- **Vulnerability**: A date-shifting and day-skipping vulnerability exists when the user is in a DST-active timezone, caused by using `Duration(days: N)` arithmetic on local `DateTime`s.

---

## 5. Verification Method

To verify the test suite execution and reproduce the findings:
1. Run the test suite:
   ```bash
   flutter test test/features/reports/reports_test.dart test/features/reports/reports_robustness_test.dart
   ```
2. Verify all tests pass.
3. Inspect `test/features/reports/reports_robustness_test.dart` to check edge-case coverage.
4. Inspect the DST vulnerability explanation in `challenge.md`.
