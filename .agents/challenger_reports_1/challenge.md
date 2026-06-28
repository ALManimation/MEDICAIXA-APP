# Challenge Report: ReportsScreen UI & Layout Robustness

## Challenge Summary

**Overall risk assessment**: MEDIUM

While the majority of the custom painters and rendering widgets for `ReportsScreen` degrade gracefully and do not crash on extreme inputs, we identified a critical vulnerability in `MedicationPerformanceWidget` where negative percentage values trigger a builder assertion crash. Additionally, visual regressions/overlaps can occur with unbounded percentages or extreme dot counts.

---

## Challenges

### [High] Challenge 1: Negative Percentage Input Crash in MedicationPerformanceWidget

- **Assumption challenged**: Percentage is assumed to be a non-negative number within the `[0, 100]` range.
- **Attack scenario**: If state computations or upstream repository failures yield a negative percentage value, passing this to `MedicationPerformanceWidget` causes a runtime crash during the build phase:
  ```
  Failed assertion: line 3224 pos 15: 'widthFactor == null || widthFactor >= 0.0': is not true.
  ```
- **Blast radius**: Complete crash of the `ReportsScreen` rendering pathway, rendering the reports tab completely inaccessible.
- **Mitigation**: Normalize and clamp the width factor within the range `[0.0, 1.0]` using `clamp`:
  ```dart
  widthFactor: (data.percentage / 100.0).clamp(0.0, 1.0)
  ```

### [Medium] Challenge 2: StreakDotsPainter Overlap & Inverse Drawing

- **Assumption challenged**: The available width is always large enough to fit all dots with positive spacing.
- **Attack scenario**: If a high count of dots is provided (e.g., in wide historical views) or the device width is extremely restricted, the spacing calculation `(size.width - (dotCount * dotDiameter)) / (dotCount - 1)` resolves to a negative value. This causes dots to overlap, and under extreme constraints (where spacing is less than `-dotDiameter`), they paint in reverse order and accumulate off-screen to the left (negative `cx`).
- **Blast radius**: Visual clutter, illegible rendering, and out-of-bounds drawing.
- **Mitigation**: Ensure `spacing` is clamped to at least `0`, and place the dots row in a scrollable horizontal container if the dots total exceeds the available width.

### [Low] Challenge 3: Unbounded Painting in DailyBarPainter & PeriodBarPainter

- **Assumption challenged**: Percentages are always within the `[0, 100]` bounds.
- **Attack scenario**: If the input percentage is greater than `100` (e.g., `500%`), `barHeightFactor` scales past `1.0`. The painter draws a filled rounded rectangle with a height larger than `size.height` and a negative `top` offset, drawing outside the canvas constraints.
- **Blast radius**: Visual bleed-through onto neighboring widgets in the view hierarchy.
- **Mitigation**: Clamp `percentage.toDouble() / 100.0` or the resulting `barHeightFactor` within `[0.0, 1.0]`.

---

## Stress Test Results

| Scenario / Test Case | Expected Behavior | Actual Behavior | Result |
|---|---|---|---|
| `DonutChartPainter` with zero values (`0, 0, 0`) | Safe return, no divide-by-zero crash | Exits early via `total == 0` check | **PASS** |
| `DonutChartPainter` with large values (`1e9`) | Proportional arc calculation without crash | Normal rendering with standard arcs | **PASS** |
| `DailyBarsWidget` with `expectedCount = 0` | Weekday label renders, percentage hidden | Correctly skips drawing bar fill | **PASS** |
| `DailyBarsWidget` with negative percentages | Graceful rendering or clamping | Draws with minimum 10% height | **PASS** |
| `StreakDotsWidget` with empty dots | safe render with no dots | Column and streak labels render, dot row empty | **PASS** |
| `StreakDotsWidget` with 100 dots | Spacing becomes negative but no crash | Paints overlapping dots | **PASS** |
| `PeriodDistributionWidget` with `expected = 0` | Label displays "0/0", track is empty | Correctly displays track and text | **PASS** |
| `MonthlyHeatmapWidget` with empty cells | Returns empty widget safely | Returns `SizedBox.shrink()` | **PASS** |
| `MonthlyHeatmapWidget` with non-7-multiple cells | Renders partial week with padded empty cells | Generates padded weeks using `SizedBox.shrink` | **PASS** |
| `MedicationPerformanceWidget` with negative percentage | Graceful fallback or clamping | Crashes on `FractionallySizedBox` build | **FAIL** |

---

## Unchallenged Areas

- **Drift DB Migration Rules** — Verification focused strictly on the layout, rendering, and standalone functionality of the reports screen rather than underlying DB migration testing.
