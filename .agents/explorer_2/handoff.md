# Handoff Report — explorer_2

This report provides the details of the investigation conducted on the 14 codebase issues highlighted in `audit_report.md` for the Medicaixa Flutter Application.

---

## 1. Observation
We performed a read-only code audit of the following files:
* `lib/features/alarms/presentation/wizard/alarm_wizard_notifier.dart` (Line 36, 40)
* `lib/features/pairing/presentation/pairing_notifier.dart` (Line 9, 13)
* `lib/features/medications/data/medication_repository.dart` (Lines 90, 213–222, 261–266)
* `lib/features/medications/presentation/medications_list_screen.dart` (Lines 140–142)
* `lib/features/medications/presentation/medication_form_screen.dart` (Line 144)
* `lib/features/dashboard/presentation/dashboard_notifier.dart` (Lines 22, 91, 131, 138, 370)
* `lib/features/alarms/data/alarm_repository.dart` (Line 25, 949–1059)
* `lib/features/settings/data/settings_repository.dart` (Lines 23, 689, 721, 803, 832, 835)
* `lib/features/reminders/data/reminder_repository.dart` (Line 25, 406–441)
* `lib/features/settings/data/wifi_repository.dart` (Line 50)
* `lib/features/dashboard/presentation/dashboard_screen.dart` (Lines 182, 185, 279, 288, 402–427)
* `lib/features/settings/presentation/settings_screen.dart` (Lines 244, 787)
* `lib/core/services/notification_service.dart` (Lines 89-92, 145)
* `lib/features/alarms/presentation/alarm_active_screen.dart` (Line 172)
* `lib/features/alarms/data/medication_search_service.dart` (Line 51)
* `lib/features/dashboard/presentation/widgets/alarm_card_widget.dart` (Line 352)
* `lib/core/services/alarm_engine.dart` (Lines 103–115)

Key violations observed:
1. `late final` variables initialized in notifier `build` methods (e.g., `_repo = ref.watch(connectionRepositoryProvider);` in `PairingNotifier`).
2. Medication deletions from repository bypassing referential dependency checks (violating Rule 35).
3. Presentation layer dependency imports directly in data layer repositories (e.g., `import '../../pairing/presentation/pairing_notifier.dart'`).
4. Manual `isLoading` state flags in notifiers (violating Rule 3).
5. Timers left active on dispose (`_inactivityTimer` in `DashboardNotifier`).
6. Label mismatch for local alarm sound option 0 ("Beep" instead of "Gentil").
7. Missed counts on dashboard including disabled alarms (violating Rule 54).
8. `copyWith` methods not supporting explicit null overrides.
9. Duplicate gzipped ANVISA database decompression and parsing in memory.
10. Synchronous JSON decoding of backups on the main UI thread.
11. Inefficient UI rebuilds in `AlarmCardWidget` due to watching the whole notifier state.
12. Risk of UTC timezone default in case of detection exceptions.
13. Notifiers extending `Notifier` but returning `AsyncValue` manually.
14. Obsolete/dead code wizard step and notifier classes.

---

## 2. Logic Chain
Our step-by-step reasoning from observations to recommended fixes:
1. **Rule 28 Compliance**: `late final` initialization in notifier `build()` throws a runtime crash on Hot Reload because `build()` is executed multiple times on the same instance. Exposing dependencies through dynamic getters that invoke `ref.read` dynamically solves the issue.
2. **Rule 35 Compliance**: Validating medication usage against active alarms at the repository level ensures database referential integrity is preserved during both manual deletes and automated synchronizations.
3. **Clean Architecture Boundary**: Moving connection state tracking to a core-level provider (`DeviceConnectionState` under `lib/core/providers/`) breaks the presentation-to-data bleeding, allowing repositories to read connection states without importing presentation notifiers.
4. **Rule 3 Compliance**: Refactoring `DashboardNotifier` to extend `AsyncNotifier<DashboardState>` lets Riverpod manage lifecycle loading transitions, eliminating manual state flags.
5. **Memory Leak Prevention**: Explicitly cancelling `_inactivityTimer` inside `ref.onDispose` prevents timers from firing on disposed widgets/notifiers.
6. **Buzzer & UI Alignment**: Renaming option 0 to "Gentil" aligns settings screen labels with the actual filename loaded and firmware behavior.
7. **Dashboard Correctness (Rule 54)**: Filtering out inactive or disabled alarms (while keeping ghost alarms) ensures that missed counts accurately represent missed active scheduled doses.
8. **Null Value Fallbacks**: Adopting sentinel `Object` defaults in `copyWith` allows resetting nullable fields to `null` cleanly.
9. **Performance Optimization**: Unifying ANVISA searches under `MedicationSearchService` with a single cache instance eliminates duplicate decompression work.
10. **UI Freeze Prevention**: Shifting heavy backup JSON decoding off the main thread using `compute()` ensures UI remains responsive during restore processes.
11. **Granular Listening**: Using `select` on the provider in `AlarmCardWidget` isolates rebuild triggers to changes in the target field (`selectedDate`).
12. **Region-Specific Fallback**: Falling back to `'America/Sao_Paulo'` on timezone exceptions keeps schedule integrity for the primary user base.
13. **Riverpod Idioms**: Extending `AsyncNotifier<void>` instead of returning manual `AsyncValue` values aligns synchronous action providers with standard practices.
14. **Dead Code Wiping**: Safely deleting the legacy 4-step wizard steps and notifier removes unused code and reduces maintenance overhead.

---

## 3. Caveats
We assume that the ANVISA database `assets/medications_db.json.gz` contains category (`c`) and instruction (`i`) keys. If it does not, they will be parsed as null, which is handled gracefully by `MedicationModel.fromJson` defaults.

---

## 4. Conclusion
The codebase contains several architectural boundaries infractions and Riverpod best-practice deviations that could cause memory leaks, thread blockage, and runtime crashes on reload. Refactoring them according to the step-by-step recommendations detailed in `analysis.md` will resolve all issues, enforce clean feature-first architecture, and guarantee solid runtime performance.

---

## 5. Verification Method
1. **Run Tests**: Execute `flutter test` to ensure compilation and existing tests remain green.
2. **Review Diffs**: Verify proposed refactoring steps in `.agents/explorer_2/analysis.md` to ensure they conform to Dart/Riverpod and `AGENTS.md` guidelines.
3. **Spot Check**: Inspect the renamed dropdown value in `settings_screen.dart` and confirm that it matches `alarm_gentile` file usage in `notification_service.dart`.
