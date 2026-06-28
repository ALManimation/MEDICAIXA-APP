# Adversarial Review & Verification Report — Round 2

## Challenge Summary

**Overall risk assessment**: LOW

All verification targets have been successfully tested, validated, and completed. The codebase is highly robust against the identified edge-cases. Specifically:
1. All 67 unit and widget tests (including reports notifier filtering and widgets robustness) run and pass successfully.
2. The negative percentage clamping in `MedicationPerformanceWidget` is successfully verified at the widget level. Using `(data.percentage / 100.0).clamp(0.0, 1.0)` prevents `FractionallySizedBox` from receiving values outside the [0.0, 1.0] range, eliminating the risk of assertion crashes.
3. DST transition calculations have been verified as correct. Date manipulation uses timezone-independent calendar constructors `DateTime(year, month, day + k)` rather than adding raw `Duration(days: k)` objects, preventing any days skipping or overlapping during daylight savings timezone changes.

---

## Challenges

### [Low] Challenge 1: Negative Percentage Inputs in MedicationPerformanceWidget

- **Assumption challenged**: The percentage value passed to `MedicationPerformanceWidget` is always between 0 and 100.
- **Attack scenario**: If a database error or invalid calculation returns a negative adherence/percentage value (e.g., -50%), `FractionallySizedBox` will receive a negative `widthFactor` and crash the application with an assertion error.
- **Blast radius**: Reports screen UI crashes, preventing the user from viewing any adherence reports.
- **Mitigation**: Successfully mitigated in `medication_performance.dart` line 58 using `(data.percentage / 100.0).clamp(0.0, 1.0)`. This guarantees `widthFactor` is safe even with negative or excessively large percentages.

### [Low] Challenge 2: DST Calendar Shifts & Day Skipping

- **Assumption challenged**: Adding raw Durations (e.g. `Duration(days: 1)`) is safe for calendar date increments.
- **Attack scenario**: Adding exactly 24 hours to a local DateTime across a Daylight Saving Time transition (23-hour or 25-hour day) shifts the hours field away from midnight. Subsequent calculations using midnight extraction could either skip a day or duplicate the same day in the adherence/heatmap graphs.
- **Blast radius**: Distorted daily adherence calculations, skipped calendar days in reports, or incorrect streak computations.
- **Mitigation**: Successfully mitigated in `reports_notifier.dart` by avoiding `Duration(days: 1)` arithmetic. Instead, it uses `DateTime(tempDate.year, tempDate.month, tempDate.day + 1)` which leverages Dart's native local-time calendar normalization, keeping the hour aligned and avoiding skipped days.

---

## Stress Test Results

- **Run complete test suite** → All 67 tests pass successfully → 67 tests executed and passed → **PASS**
- **Negative percentage rendering in MedicationPerformanceWidget** → Render a medication bar with -50% value → Clamped to 0.0 widthFactor; no assertion error/crash → **PASS**
- **Overflow percentage rendering in MedicationPerformanceWidget** → Render a medication bar with 500% value → Clamped to 1.0 widthFactor; no assertion error/crash → **PASS**
- **Empty dataset performance rendering** → Render MedicationPerformanceWidget with empty list → Displays "Nenhum dado por medicamento." correctly without crash → **PASS**
- **Heatmap non-7-multiple week alignment** → Align heatmap cells to week boundaries → Aligned grid cells display correctly without index errors → **PASS**

---

## Unchallenged Areas

- **C++ Firmware integration details** — Out of scope. Physical/simulated ESP32 communication is mocked out in the tests using the Native drift memory database.
