# UI/Layout Review Report: ReportsScreen & Widgets

**Verdict**: REQUEST_CHANGES

---

## Review Summary

The Reports module implementation is functional and robust, featuring offline-first riverpod stream query parsing, customized visual representations, and a dual-layout AppShell conforming to the feature requirements. However, the implementation violates **Rule 22** of the project's layout rules (no `const` with `AppColors`) in multiple places. It also presents layout stress-test weaknesses under very narrow device dimensions.

---

## Verified Claims

- **Offline-First Stream-Based Integration**: Verified via `reports_notifier.dart` lines 180–212. The state registers streams from `historyRepositoryProvider` and `medicationRepositoryProvider`. Real data calculations (streaks, daily/period compliance, medication statistics) are evaluated reactively. → **PASS**
- **No Third-Party Chart Packages**: Verified via `pubspec.yaml` and import analysis. No charting dependencies (like `fl_chart`) were added. Custom representation widgets utilize `CustomPainter` or native layouts. → **PASS**
- **Responsiveness**: Verified via `AppShell` lines 66–175. The UI switches between `NavigationRail` + screen content (Desktop) and `BottomNavigationBar` (Mobile) at a threshold width of 800. → **PASS**
- **No `context.mounted` async issues**: Checked all reviewed files. As there are no async context-based logic or handlers inside the reviewed widget components (all are stateless/pure builders), no violations exist. → **PASS**

---

## Findings (Quality Review)

### 🚨 Major Finding 1: Rule 22 Violations (AppColors inside `const`)

- **What**: Several widgets/layouts reference `AppColors.xxx` constants inside `const` constructors or arrays.
- **Where**:
  1. `lib/features/reports/presentation/widgets/streak_dots.dart` line 133:
     ```dart
     const Divider(height: 24, color: AppColors.border),
     ```
  2. `lib/features/reports/presentation/widgets/medication_filter_bar.dart` lines 20–25:
     ```dart
     decoration: const BoxDecoration(
       color: AppColors.surface,
       border: Border(
         top: BorderSide(color: AppColors.border, width: 1),
       ),
     ),
     ```
  3. `lib/core/presentation/app_shell.dart` lines 83–104:
     ```dart
     destinations: const [
       NavigationRailDestination(
         icon: Icon(Icons.dashboard_outlined),
         selectedIcon: Icon(Icons.dashboard_rounded, color: AppColors.primary),
         label: Text('Início'),
       ),
       ...
     ]
     ```
- **Why**: Rule 22 strictly states: *"Widgets that reference AppColors.xxx CANNOT be const. Use Icon(Icons.alarm, color: AppColors.primary) without const. This includes: Icon, TextStyle, BorderSide, Divider, CircularProgressIndicator, and any widget that receives parameters of AppColors."* This is to ensure color swapping or dynamic theme mutations do not cause compile-time frozen values.
- **Suggestion**: Remove the `const` prefix from these widgets/lists.

---

## Challenges (Adversarial / Critic Review)

### ⚠️ Medium Challenge 1: Streak Dots Negative Spacing Risk

- **Assumption Challenged**: The screen layout will always have enough width to accommodate the 14 days of sequence dots in a row.
- **Attack Scenario**: If the user runs the app on a narrow device (e.g. 320 logical pixels) and has a 3-digit streak (e.g. "124 dias"), the left column takes ~120px, the spacer takes 32px, leaving only ~168px or less for the remaining `Expanded` area.
- **Blast Radius**:
  In `streak_dots.dart` lines 19–21:
  ```dart
  final double spacing = dotCount > 1 
      ? (size.width - (dotCount * dotDiameter)) / (dotCount - 1)
      : 0;
  ```
  If `size.width` is less than `dotCount * dotDiameter` (which is 14 * 12 = 168px), `spacing` becomes negative. This causes dots to overlap or render in reverse order, breaking the visualization.
- **Mitigation**: Add a guard constraint `spacing = max(0, spacing)` and consider putting the dot strip in a horizontal scrollable view or reducing dot diameter if width becomes too narrow.

### ℹ️ Low Challenge 2: Monthly Heatmap Grid Boundary Constraint

- **Assumption Challenged**: Heatmap fits all screen dimensions.
- **Attack Scenario**: On screen widths under 274px, the calendar cells (7 days * 32px + 50px date label = 274px minimum) will suffer horizontal layout overflow.
- **Mitigation**: Wrap the calendar grid row in a `SingleChildScrollView` or a layout constraint checking width to guarantee rendering on ultra-small screens.

---

## Coverage Gaps

- **None** — Checked all 9 required files for responsiveness, `CustomPainter` layout bounds, async state lifecycle, and styling rules.

---

## Unverified Items

- **None** — Verified all constraints and ran test suites.
