# Medicaixa Flutter Application — Code Review Audit Report

This report presents the findings of a comprehensive codebase audit of the Medicaixa Flutter application. The audit was conducted across four major domains: background AlarmEngine logic, Drift database configurations and repositories, Riverpod state management, and Feature-First clean architecture consistency.

The issues identified have been categorized by severity (Critical, High, Medium, Low), referencing exact file paths, line numbers, and concrete recommendations for fixes.

---

## Executive Summary

- **Total Issues Identified**: 14
- **Critical Severity**: 2
- **High Severity**: 1
- **Medium Severity**: 4
- **Low Severity**: 7

Key concerns center around potential runtime crashes on Hot Reload due to `late final` variables (violating Rule 28), repository-level violations of data integrity rules (violating Rule 35 on medication deletions), manual state flags in place of `AsyncValue` (violating Rule 3), and architectural bleeding (data layer components importing presentation layer code).

---

## 1. Critical Severity Issues

### Finding 1.1: `LateInitializationError` due to `late final` Fields in Notifier Classes (Rule 28 Violation)
- **Files & Line Numbers**:
  - `lib/features/alarms/presentation/wizard/alarm_wizard_notifier.dart` (Lines 36, 40)
  - `lib/features/pairing/presentation/pairing_notifier.dart` (Lines 9, 13)
- **Code Quote** (`alarm_wizard_notifier.dart`):
  ```dart
  class AlarmWizardNotifier extends _$AlarmWizardNotifier {
    late final AlarmRepository _repository;

    @override
    WizardState build() {
      _repository = ref.watch(alarmRepositoryProvider);
  ```
- **Description**: Storing provider or repository references in a `late final` field inside notifier classes and assigning them in `build()` violates **Rule 28** of `AGENTS.md`. In Riverpod, a notifier instance persists while its `build()` method executes multiple times (e.g. during Hot Reload or when a watched dependency changes). Re-running `build()` attempts to re-assign the `late final` class field, triggering a Dart `LateInitializationError` and crashing the application.
- **Concrete Recommendation**:
  Remove the `late final` field and expose the dependency via a dynamic getter that performs a `ref.read` dynamically:
  ```dart
  class AlarmWizardNotifier extends _$AlarmWizardNotifier {
    AlarmRepository get _repository => ref.read(alarmRepositoryProvider);

    @override
    WizardState build() {
      return const WizardState.initial();
    }
  }
  ```

### Finding 1.2: Medication Deletion Missing Alarm Usage Check in Repository (Rule 35 Violation)
- **Files & Line Numbers**:
  - `lib/features/medications/data/medication_repository.dart` (Lines 213–222, 261–266)
  - `lib/features/medications/presentation/medications_list_screen.dart` (Lines 140–142)
  - `lib/features/medications/presentation/medication_form_screen.dart` (Line 144)
- **Code Quote** (`medication_repository.dart`):
  ```dart
  Future<void> deleteMedication(String name) async {
    if (_isConnected()) {
      try {
        await _apiClient.removeMedication(name);
      } catch (e) {
        debugPrint('Error removing medication on ESP32: $e');
      }
    }
    await (_db.delete(_db.medications)..where((t) => t.name.equals(name))).go();
  }
  ```
- **Description**: **Rule 35** states: *"Antes de excluir qualquer medicamento da base de dados, consulte o `AlarmRepository`. Se o medicamento estiver em uso em algum alarme cadastrado, bloqueie a exclusão e alerte o usuário..."*
  While the UI screens include check logic, the repository tier itself deletes the medication records directly from SQLite via Drift without verifying active alarm dependencies. If a medication is deleted programmatically (e.g. during device-to-local synchronization or other sync mechanisms), the database's referential integrity is compromised, leading to orphaned alarm configurations.
- **Concrete Recommendation**:
  Query the `alarms` table or inject the `AlarmRepository` inside `MedicationRepository.deleteMedication` (and during deletion loops in `syncWithDevice`) to confirm the medication is not linked to any active alarms. Throw an exception or return a structured warning to block deletion.
  ```dart
  final activeAlarms = await _db.select(_db.alarms).get();
  final isUsed = activeAlarms.any((alarm) => alarm.medName == name && alarm.enabled);
  if (isUsed) {
    throw Exception('Medicamento está associado a alarmes ativos e não pode ser excluído.');
  }
  ```

---

## 2. High Severity Issues

### Finding 2.1: Manual `isLoading` State Flags Instead of `AsyncValue` (Rule 3 Violation)
- **File & Line Numbers**:
  - `lib/features/dashboard/presentation/dashboard_notifier.dart` (Lines 22, 91, 131, 138, 370)
- **Code Quote**:
  ```dart
  final bool isLoading;
  // ...
  state = state.copyWith(isLoading: true);
  ```
- **Description**: `DashboardNotifier` tracks asynchronous data states using a manual `bool isLoading` flag on the `DashboardState` data class. This violates **Rule 3**: *"AsyncValue: Use AsyncValue do Riverpod para todos os estados assíncronos. Nunca use flags manuais isLoading ou hasError."* It introduces manual flag-flipping boilerplates and bypasses Riverpod's compiler-enforced pattern matching for async states.
- **Concrete Recommendation**:
  Refactor `DashboardNotifier` to extend `AsyncNotifier<DashboardState>` (returning `FutureOr<DashboardState>` inside `build()`). Let the Riverpod framework handle loading/error transitions natively. In UI widgets, consume the state using `state.when(...)` or `state.maybeWhen(...)`.

---

## 3. Medium Severity Issues

### Finding 3.1: Disabled Alarms Erroneously Counted as Missed (Rule 54 Violation)
- **File & Line Numbers**:
  - `lib/features/dashboard/presentation/dashboard_screen.dart` (Lines 402–427 inside `_getMissedCountForSection`)
- **Description**: **Rule 54** specifies that dashboard period sections (Morning, Afternoon, Night) must count missed doses. However, the logic inside `_getMissedCountForSection` does not check if the alarm is actually active or enabled (`alarm.enabled || alarm.active`), resulting in disabled alarms being counted as "Missed/Perdido" once their scheduled time has passed for the day.
- **Concrete Recommendation**:
  Add an active status check at the top of the evaluation loop in `_getMissedCountForSection`:
  ```dart
  for (final alarm in alarms) {
    if (!alarm.enabled || !alarm.active) {
      continue;
    }
    // ... rest of the missed logic ...
  }
  ```

### Finding 3.2: Layer Violations (Presentation-to-Data Bleeding)
- **Files & Line Numbers**:
  - `lib/features/alarms/data/alarm_repository.dart` (Lines 23, 57)
  - `lib/features/settings/data/settings_repository.dart` (Lines 9, 23)
  - `lib/features/reminders/data/reminder_repository.dart` (Lines 14, 35)
  - `lib/features/medications/data/medication_repository.dart` (Line 9)
  - `lib/features/wifi/data/wifi_repository.dart` (Lines 9, 37)
- **Code Quote** (`alarm_repository.dart`):
  ```dart
  import '../../pairing/presentation/pairing_notifier.dart';
  // ...
  final connState = _ref.read(pairingNotifierProvider);
  ```
- **Description**: Data repositories (which belong in the `data` layer) directly import and read `pairingNotifierProvider` (which resides in the `presentation` layer). This violates clean architecture boundary directions, making data layer logic tightly coupled to presentation state management.
- **Concrete Recommendation**:
  Extract the connection state logic into a core-level provider (e.g. `deviceConnectionStateProvider` in `lib/core/providers/connection_state_provider.dart`), and let the pairing notifier update it. Repositories should only import and read this core provider.

### Finding 3.3: Dashboard Inactivity Timer Memory Leak
- **File & Line Numbers**:
  - `lib/features/dashboard/presentation/dashboard_notifier.dart` (Lines 65, 124, 75–79)
- **Description**: The dashboard schedules a 3-minute timer (`_inactivityTimer`) when users navigate to past/future days to reset the view to "today". While the timer is cancelled during subsequent date changes, it is **not** cancelled when the `DashboardNotifier` provider itself is disposed (e.g. when navigating away from the dashboard). This leaves an active timer in the event loop that will leak memory and trigger state updates on a disposed notifier when it fires.
- **Concrete Recommendation**:
  Cancel the timer inside the `ref.onDispose` callback of the notifier:
  ```dart
  ref.onDispose(() {
    alarmSub.cancel();
    reminderSub.cancel();
    historySub.cancel();
    _inactivityTimer?.cancel(); // Cancel the timer
  });
  ```

### Finding 3.4: Sound Dropdown Option 0 Label Mismatch (C++ Inconsistency)
- **Files & Line Numbers**:
  - `lib/features/settings/presentation/settings_screen.dart` (Line 787)
  - `lib/core/services/notification_service.dart` (Line 145)
  - `lib/features/alarms/presentation/alarm_active_screen.dart` (Line 172)
- **Description**: In `settings_screen.dart`, dropdown option 0 is labeled "Beep". However, in `NotificationService` and `alarm_active_screen.dart`, selecting index 0 resolves to `alarm_gentile` and plays `alarm_gentile.wav`. This creates a labeling mismatch. In the original C++ Web UI (`index.html` line 2840), index 0 is correctly labeled "Gentil" (Gentle).
- **Concrete Recommendation**:
  Rename dropdown option 0 in `settings_screen.dart` from "Beep" to "Gentil" or "Gentle" to maintain parity with the actual sound played and the C++ project.

---

## 4. Low Severity Issues

### Finding 4.1: Custom Model `copyWith` Null Value Limitation (Rule 37 Context)
- **Files**:
  - `lib/features/alarms/data/alarm_repository.dart` (Lines 949–1059)
  - `lib/features/reminders/data/reminder_repository.dart` (Lines 406–441)
- **Description**: Extension-based `copyWith` methods for custom models (`AlarmModel`, `ReminderModel`) use `value ?? this.value` fallbacks. If a developer explicitly passes `null` to clear a nullable field (such as `lastStatusDate` when resetting status), the fallback retains the old value. As a workaround, the code uses empty strings `''`, adding logical complexity.
- **Concrete Recommendation**:
  Refactor `copyWith` to support explicit null overrides, either by using a helper class (like Drift's `Value` wrappers) or sentinel parameters.

### Finding 4.2: Duplicate Compressed ANVISA Database Loading (Rule 27 Context)
- **Files**:
  - `lib/features/medications/data/medication_repository.dart` (Line 161)
  - `lib/features/alarms/data/medication_search_service.dart` (Line 51)
- **Description**: Both modules load and decompress the gzipped ANVISA database `assets/medications_db.json.gz` independently in memory. Loading and decompressing this large database twice wastes memory and CPU. Furthermore, `MedicationRepository` implements a fallback main-thread search that does not comply with Rule 27's search ranking rules (unlike `MedicationSearchService`).
- **Concrete Recommendation**:
  Unify ANVISA search logic under a core-level service (e.g. `AnvisaSearchService`), caching the decompressed DB once and executing Rule 27-compliant search filters using isolates.

### Finding 4.3: Synchronous Backup JSON Decoding on UI Thread
- **File & Line**:
  - `lib/features/settings/presentation/settings_screen.dart` (Line 244)
- **Description**: In `settings_screen.dart`, `json.decode(content)` runs synchronously on the UI thread when restoring a backup file. If the backup contains a long history of logs and alarm events, this blocking operation will freeze the UI.
- **Concrete Recommendation**:
  De-serialize the JSON on a background isolate using Flutter's `compute` utility:
  ```dart
  final Map<String, dynamic> rawMap = await compute(jsonDecode, content) as Map<String, dynamic>;
  ```

### Finding 4.4: Inefficient UI Rebuilds in `AlarmCardWidget`
- **File & Line**:
  - `lib/features/dashboard/presentation/widgets/alarm_card_widget.dart` (Line 352)
- **Description**: `AlarmCardWidget` watches the entire `dashboardNotifierProvider` only to extract the `selectedDate` property. Any update to unrelated properties in `DashboardState` (e.g. `takenCount` updates) will trigger unnecessary rebuilds of the entire card widget.
- **Concrete Recommendation**:
  Use `ref.watch(dashboardNotifierProvider.select((s) => s.selectedDate))` to rebuild the card only when the selected date changes.

### Finding 4.5: Timezone Initialization UTC Fallback Risk
- **Files**:
  - `lib/core/services/alarm_engine.dart` (Lines 103–115)
  - `lib/core/services/notification_service.dart` (Lines 89–92)
- **Description**: If timezone initialization fails or throws an exception, `NotificationService` falls back to setting `tz.UTC` as local. In `AlarmEngine`, this will cause scheduled alarms to trigger at UTC offsets instead of correct local hours, resulting in incorrect alarm timings.
- **Concrete Recommendation**:
  Instead of defaulting to UTC, implement a retry mechanism or alert the user in the UI if timezone bindings fail.

### Finding 4.6: Non-Idiomatic `AsyncValue` Usage in Synchronous Notifiers
- **Files**:
  - `lib/features/settings/data/settings_repository.dart` (DeviceResetNotifier at line 748, SoundSettingsAction at line 843)
  - `lib/features/settings/data/wifi_repository.dart` (WifiActionNotifier at line 170)
- **Description**: These providers extend the synchronous `Notifier` class but manually wrap their state transitions in `AsyncValue` types (`state = const AsyncValue.loading()`, etc.). Standard Riverpod practice is to extend `AsyncNotifier<void>` and return `FutureOr<void>` in `build()`, letting the framework manage lifecycle transitions.
- **Concrete Recommendation**:
  Refactor these classes to extend `AsyncNotifier<void>`.

### Finding 4.7: Dead Code (Unused Legacy Wizard Classes)
- **Files**:
  - `lib/features/alarms/presentation/wizard/alarm_wizard_notifier.dart` (and generated `.g.dart` file)
  - `lib/features/alarms/presentation/wizard/steps/wizard_step_*.dart`
- **Description**: The wizard layout `alarm_wizard_screen.dart` is imported to use `wizard_notifier.dart` along with steps `step_1_name.dart` to `step_7_summary.dart`. The legacy notifier and wizard step files are dead code that only import one another.
- **Concrete Recommendation**:
  Safely delete the obsolete `alarm_wizard_notifier.dart` and `wizard_step_*.dart` files.

---

## 5. Verification Method

To verify these findings and ensure fixes do not introduce regressions:
1. **Compilation and Tests**: Run `flutter test` to verify no existing tests are broken.
2. **LateInitializationError**: Run the application in debug mode and execute a Flutter Hot Reload on screens containing the Pairing or Alarm Wizard notifiers. Verify if a `LateInitializationError` is thrown in the console.
3. **Medication Deletion**: Try to delete a medication that is currently assigned to an active alarm. Verify if the database deletes the row without warnings.
4. **Dashboard Rebuilds**: Add a debug print statement inside `AlarmCardWidget.build`. Toggle a different date or state on the dashboard and check if the card widget rebuilds.
