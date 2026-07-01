# Medicaixa App — Code Review Analysis Report

This report presents a thorough investigation of the 14 issues identified in `audit_report.md` across the Medicaixa App Flutter project, aligning recommendations with the guidelines and constraints specified in `.agents/AGENTS.md`.

---

## 1. Critical Severity Issues

### Finding 1.1: `LateInitializationError` due to `late final` Fields in Notifier Classes (Rule 28 Violation)
- **Affected Files**:
  - `lib/features/pairing/presentation/pairing_notifier.dart` (Lines 9, 13)
  - `lib/features/alarms/presentation/wizard/alarm_wizard_notifier.dart` (Lines 36, 40) *(To be deleted under Finding 4.7)*
- **Observation**:
  ```dart
  class PairingNotifier extends _$PairingNotifier {
    late final ConnectionRepository _repo;

    @override
    ConnectionStateInfo build() {
      _repo = ref.watch(connectionRepositoryProvider);
  ```
- **Logical Rationale**: Storing provider or repository references in a `late final` field inside notifier classes and assigning them in `build()` violates **Rule 28** of `AGENTS.md`. In Riverpod, a notifier instance persists while its `build()` method executes multiple times (e.g. during Hot Reload or when a watched dependency changes). Re-running `build()` attempts to re-assign the `late final` class field, triggering a Dart `LateInitializationError` and crashing the application.
- **Proposed Code Change**:
  Refactor `lib/features/pairing/presentation/pairing_notifier.dart` to use a dynamic getter:
  ```dart
  class PairingNotifier extends _$PairingNotifier {
    ConnectionRepository get _repo => ref.read(connectionRepositoryProvider);

    @override
    ConnectionStateInfo build() {
      _autoConnect();
      return ref.watch(deviceConnectionStateProvider);
    }
  ```

---

### Finding 1.2: Medication Deletion Missing Alarm Usage Check in Repository (Rule 35 Violation)
- **Affected Files**:
  - `lib/features/medications/data/medication_repository.dart` (Lines 213–222, 261–266)
  - `lib/features/medications/presentation/medications_list_screen.dart` (Lines 140–142)
  - `lib/features/medications/presentation/medication_form_screen.dart` (Line 144)
- **Observation**:
  `MedicationRepository.deleteMedication` deletes the medication directly from Drift without confirming whether it is associated with any active alarms:
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
- **Logical Rationale**: **Rule 35** states: *"Antes de excluir qualquer medicamento da base de dados, consulte o `AlarmRepository`. Se o medicamento estiver em uso em algum alarme cadastrado, bloqueie a exclusão e alerte o usuário..."* While UI-level validation alerts the user, the database's referential integrity is compromised if medication records are deleted programmatically (e.g., during background synchronization in `syncWithDevice()`), leading to orphaned alarm configurations.
- **Proposed Code Change**:
  In `lib/features/medications/data/medication_repository.dart`, query the alarms table to verify usage before deleting in both `deleteMedication` and `syncWithDevice`:
  ```dart
  // Inside deleteMedication(String name)
  Future<void> deleteMedication(String name) async {
    final activeAlarms = await _db.select(_db.alarms).get();
    final isUsed = activeAlarms.any((alarm) => alarm.medName == name && alarm.enabled);
    if (isUsed) {
      throw Exception('Medicamento está associado a alarmes ativos e não pode ser excluído.');
    }

    if (_isConnected()) {
      try {
        await _apiClient.removeMedication(name);
      } catch (e) {
        debugPrint('Error removing medication on ESP32: $e');
      }
    }
    await (_db.delete(_db.medications)..where((t) => t.name.equals(name))).go();
  }

  // Inside syncWithDevice()
  // Fetch active alarms once before the loop:
  final localAlarms = await _db.select(_db.alarms).get();
  // ...
  // 3. Clean up deleted medications
  for (final local in updatedLocalMeds) {
    if (!remoteMap.containsKey(local.name) && !local.pendingSync) {
      final isUsed = localAlarms.any((alarm) => alarm.medName == local.name && alarm.enabled);
      if (!isUsed) {
        await (_db.delete(_db.medications)..where((t) => t.name.equals(local.name))).go();
      } else {
        debugPrint('Skipping deletion of medication ${local.name} because it is in use by active alarms.');
      }
    }
  }
  ```

---

## 2. High Severity Issues

### Finding 2.1: Manual `isLoading` State Flags Instead of `AsyncValue` (Rule 3 Violation)
- **Affected Files**:
  - `lib/features/dashboard/presentation/dashboard_notifier.dart` (Lines 22, 91, 131, 138, 370)
  - `lib/features/dashboard/presentation/dashboard_screen.dart` (Lines 182, 185, 279, 288)
- **Observation**:
  `DashboardState` defines `final bool isLoading;` as a manual state variable, and `DashboardNotifier` sets `state = state.copyWith(isLoading: true);` before executing operations.
- **Logical Rationale**: This violates **Rule 3**: *"AsyncValue: Use AsyncValue do Riverpod para todos os estados assíncronos. Nunca use flags manuais isLoading ou hasError."*
- **Proposed Code Change**:
  1. Refactor `DashboardNotifier` to extend `AsyncNotifier<DashboardState>` (returning `FutureOr<DashboardState>` in `build()`).
  2. Modify `_performUpdate(DateTime date)` to return a `Future<DashboardState>` representing the computed state.
  3. Inside `build()`, setup the database stream subscriptions and trigger the initial load by returning `_performUpdate(DateTime.now())`:
  ```dart
  @riverpod
  class DashboardNotifier extends _$DashboardNotifier {
    AlarmRepository get _alarmRepo => ref.read(alarmRepositoryProvider);
    ReminderRepository get _reminderRepo => ref.read(reminderRepositoryProvider);
    Timer? _inactivityTimer;

    @override
    FutureOr<DashboardState> build() async {
      final alarmSub = _alarmRepo.watchAllAlarms().listen((_) => refresh());
      final reminderSub = _reminderRepo.watchAllReminders().listen((_) => refresh());
      final historySub = ref.read(historyRepositoryProvider).watchAllHistoryEvents().listen((_) => refresh());

      ref.onDispose(() {
        alarmSub.cancel();
        reminderSub.cancel();
        historySub.cancel();
        _inactivityTimer?.cancel();
      });

      return _performUpdate(DateTime.now());
    }

    Future<void> selectDate(DateTime date) async {
      _resetInactivityTimer(date);
      state = const AsyncLoading();
      state = await AsyncValue.guard(() => _performUpdate(date));
    }

    Future<void> refresh() async {
      final currentDate = state.valueOrNull?.selectedDate ?? DateTime.now();
      state = const AsyncLoading();
      state = await AsyncValue.guard(() => _performUpdate(currentDate));
    }

    Future<void> sync() async {
      state = const AsyncLoading();
      state = await AsyncValue.guard(() async {
        await _alarmRepo.syncWithDevice();
        await _reminderRepo.syncWithDevice();
        return _performUpdate(state.valueOrNull?.selectedDate ?? DateTime.now());
      });
    }

    Future<void> loadSampleData(String jsonContent) async {
      state = const AsyncLoading();
      state = await AsyncValue.guard(() async {
        await _alarmRepo.loadBackupFixture(jsonContent);
        await _reminderRepo.loadBackupFixture(jsonContent);
        return _performUpdate(state.valueOrNull?.selectedDate ?? DateTime.now());
      });
    }
  ```
  4. In `lib/features/dashboard/presentation/dashboard_screen.dart`, consume it cleanly by unwrapping `stateAsync`:
  ```dart
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stateAsync = ref.watch(dashboardNotifierProvider);
    
    // Check loading/error for initial empty state
    if (stateAsync.valueOrNull == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    
    final state = stateAsync.value!;
    // Use stateAsync.isLoading instead of state.isLoading for overlays:
    // line 182: color: stateAsync.isLoading ? AppColors.border : AppColors.textMuted
    // line 185: onPressed: stateAsync.isLoading ? null : () => notifier.sync()
    // line 279: child: stateAsync.isLoading ? ...
    // line 288: opacity: stateAsync.isLoading ? 0.65 : 1.0
  ```

---

## 3. Medium Severity Issues

### Finding 3.2: Layer Violations (Presentation-to-Data Bleeding)
- **Affected Files**:
  - `lib/features/pairing/presentation/pairing_notifier.dart`
  - `lib/features/alarms/data/alarm_repository.dart` (Line 25)
  - `lib/features/medications/data/medication_repository.dart` (Line 90)
  - `lib/features/reminders/data/reminder_repository.dart` (Line 25)
  - `lib/features/settings/data/settings_repository.dart` (Lines 23, 689, 721, 803, 832, 835)
  - `lib/features/settings/data/wifi_repository.dart` (Line 50)
- **Observation**: Repositories directly import and watch `pairingNotifierProvider` from the presentation layer to evaluate connection states.
- **Logical Rationale**: This violates clean architecture boundary directions, making data layer logic tightly coupled to presentation state management.
- **Proposed Code Change**:
  Create `lib/core/providers/connection_state_provider.dart`:
  ```dart
  import 'package:riverpod_annotation/riverpod_annotation.dart';
  import '../../features/pairing/domain/connection_state.dart';
  import '../../features/pairing/data/connection_repository.dart';

  part 'connection_state_provider.g.dart';

  @Riverpod(keepAlive: true)
  class DeviceConnectionState extends _$DeviceConnectionState {
    @override
    ConnectionStateInfo build() {
      return const ConnectionStateInfo.disconnected();
    }

    void updateState(ConnectionStateInfo newState) {
      state = newState;
    }

    Future<void> useStandalone() async {
      await ref.read(connectionRepositoryProvider).saveDeviceIp(null);
      state = const ConnectionStateInfo.disconnected();
    }

    Future<void> disconnect() async {
      await ref.read(connectionRepositoryProvider).saveDeviceIp(null);
      state = const ConnectionStateInfo.disconnected();
    }
  }
  ```
  Refactor all repositories and related background providers to read `deviceConnectionStateProvider` instead of `pairingNotifierProvider`. For example, in `alarm_repository.dart`:
  ```dart
  import '../../../core/providers/connection_state_provider.dart';

  bool _isConnected() {
    final connState = _ref.read(deviceConnectionStateProvider);
    return connState.status == ConnectionStatus.connected;
  }
  ```
  In `PairingNotifier` (`pairing_notifier.dart`), modify state transitions to update `deviceConnectionStateProvider` and watch it as its backing state:
  ```dart
  @override
  ConnectionStateInfo build() {
    _repo = ref.watch(connectionRepositoryProvider);
    _autoConnect();
    return ref.watch(deviceConnectionStateProvider);
  }

  void _updateState(ConnectionStateInfo newState) {
    ref.read(deviceConnectionStateProvider.notifier).updateState(newState);
  }
  ```

---

### Finding 3.3: Dashboard Inactivity Timer Memory Leak
- **Affected File**:
  - `lib/features/dashboard/presentation/dashboard_notifier.dart` (Lines 65, 124, 75–79)
- **Observation**: `_inactivityTimer` is not cancelled when `DashboardNotifier` is disposed.
- **Logical Rationale**: Leaving an active timer in the event loop causes memory leaks and can attempt to mutate state on a disposed notifier.
- **Proposed Code Change**:
  Add `_inactivityTimer?.cancel();` inside `ref.onDispose` of `DashboardNotifier`:
  ```dart
  ref.onDispose(() {
    alarmSub.cancel();
    reminderSub.cancel();
    historySub.cancel();
    _inactivityTimer?.cancel(); // Cancel timer on dispose
  });
  ```

---

### Finding 3.4: Sound Dropdown Option 0 Label Mismatch (C++ Inconsistency)
- **Affected Files**:
  - `lib/features/settings/presentation/settings_screen.dart` (Line 787)
  - `lib/core/services/notification_service.dart` (Line 145)
  - `lib/features/alarms/presentation/alarm_active_screen.dart` (Line 172)
- **Observation**: The option 0 in the settings sound dropdown is labeled "Beep", but resolves to and plays `alarm_gentile.wav`.
- **Logical Rationale**: This causes a labeling mismatch. Parity with the C++ Web UI (`index.html` line 2840) must be maintained, where index 0 is labeled "Gentil" (Gentle).
- **Proposed Code Change**:
  In `settings_screen.dart` line 787, rename "Beep" to "Gentil":
  ```dart
  DropdownMenuItem(value: 0, child: Text('Gentil', style: TextStyle(color: AppColors.text))),
  ```

---

### Finding 3.5: Disabled Alarms Erroneously Counted as Missed (Rule 54 Violation)
- **Affected File**:
  - `lib/features/dashboard/presentation/dashboard_screen.dart` (Lines 402–427 inside `_getMissedCountForSection`)
- **Observation**:
  `_getMissedCountForSection` does not verify if alarms are enabled or active before marking them as missed.
- **Logical Rationale**: Missed counts must only represent active and scheduled alarms. Disabled alarms should not contribute to the "Missed" total. However, we must allow `isGhost` alarms (historical instances of deleted alarms) to be evaluated.
- **Proposed Code Change**:
  Add a guard condition at the top of the evaluation loop in `_getMissedCountForSection` in `dashboard_screen.dart`:
  ```dart
  for (final alarm in alarms) {
    if (!alarm.isGhost && (!alarm.enabled || !alarm.active)) {
      continue;
    }
    final isTakenToday = alarm.lastStatusDate == dateFormatted && alarm.lastStatus == 'Tomado';
    // ...
  ```

---

## 4. Low Severity Issues

### Finding 4.1: Custom Model `copyWith` Null Value Limitation (Rule 37 Context)
- **Affected Files**:
  - `lib/features/alarms/data/alarm_repository.dart` (Lines 949–1059)
  - `lib/features/reminders/data/reminder_repository.dart` (Lines 406–441)
- **Observation**: Extension `copyWith` methods use `value ?? this.value` fallbacks, making it impossible to pass `null` to clear fields.
- **Logical Rationale**: This adds implementation complexity (requiring empty strings to reset values) and runs counter to Drift's mapping behaviors (Rule 37).
- **Proposed Code Change**:
  Refactor `copyWith` extensions to use a sentinel Object parameter or a lightweight `Option` helper:
  ```dart
  extension AlarmModelCopyWith on AlarmModel {
    AlarmModel copyWith({
      int? id,
      // ...
      Object? lastStatusDate = const Object(), // Sentinel default
      // ...
    }) {
      return AlarmModel(
        id: id ?? this.id,
        // ...
        lastStatusDate: lastStatusDate == const Object() ? this.lastStatusDate : lastStatusDate as String?,
        // ...
      );
    }
  }
  ```

---

### Finding 4.2: Duplicate Compressed ANVISA Database Loading (Rule 27 Context)
- **Affected Files**:
  - `lib/features/medications/data/medication_repository.dart` (Line 161)
  - `lib/features/alarms/data/medication_search_service.dart` (Line 51)
- **Observation**: Both files load the gzipped database, decompress, and parse it separately in memory. `MedicationRepository` has a custom search function that is not fully compliant with Rule 27's relevance ordering.
- **Logical Rationale**: Duplicate database decompression wastes CPU and memory resources on mobile/desktop platforms.
- **Proposed Code Change**:
  1. Refactor `MedicationSearchService` to return `MedicationModel` objects instead of `MedicationAnvisa`, so that it includes the category and instruction parameters.
  2. Completely remove the `loadDatabase()` and `search(...)` functions from `MedicationRepository`.
  3. In `wizard_step_medication.dart`, fetch results via the unified `searchMedicationsProvider` which reads from `MedicationSearchService`.

---

### Finding 4.3: Synchronous Backup JSON Decoding on UI Thread
- **Affected File**:
  - `lib/features/settings/presentation/settings_screen.dart` (Line 244)
- **Observation**: `json.decode(content)` is called synchronously inside `_restoreBackup()`.
- **Logical Rationale**: Large backup files containing extensive history event lists will block the UI thread during parsing, causing frame drops.
- **Proposed Code Change**:
  In `settings_screen.dart` line 244, parse the backup content asynchronously using Flutter's `compute` utility:
  ```dart
  import 'package:flutter/foundation.dart'; // Ensure compute is imported
  // ...
  final Map<String, dynamic> rawMap = await compute(jsonDecode, content) as Map<String, dynamic>;
  ```

---

### Finding 4.4: Inefficient UI Rebuilds in `AlarmCardWidget`
- **Affected File**:
  - `lib/features/dashboard/presentation/widgets/alarm_card_widget.dart` (Line 352)
- **Observation**: `AlarmCardWidget` watches the entire `dashboardNotifierProvider` only to extract `selectedDate`.
- **Logical Rationale**: Changes to other fields in `DashboardState` (like `takenCount` or lists of other alarms) trigger rebuilds of the entire card widget.
- **Proposed Code Change**:
  Change line 352 in `alarm_card_widget.dart` to select only the `selectedDate` property:
  ```dart
  final selectedDate = ref.watch(
    dashboardNotifierProvider.select((s) => s.valueOrNull?.selectedDate ?? DateTime.now()),
  );
  ```

---

### Finding 4.5: Timezone Initialization UTC Fallback Risk
- **Affected Files**:
  - `lib/core/services/notification_service.dart` (Lines 89–92)
  - `lib/core/services/alarm_engine.dart` (Lines 103–115)
- **Observation**: `NotificationService` falls back to `tz.UTC` if local timezone detection fails.
- **Logical Rationale**: Falling back to UTC results in scheduled notifications triggering at wrong local hours for international users.
- **Proposed Code Change**:
  Fall back to a region-specific timezone (such as `America/Sao_Paulo` representing Brazil) as a smart secondary option before defaulting to UTC:
  ```dart
  } catch (e) {
    debugPrint('Could not get local timezone: $e. Falling back to America/Sao_Paulo.');
    try {
      tz.setLocalLocation(tz.getLocation('America/Sao_Paulo'));
    } catch (_) {
      tz.setLocalLocation(tz.UTC); // Absolute fallback
    }
  }
  ```

---

### Finding 4.6: Non-Idiomatic `AsyncValue` Usage in Synchronous Notifiers
- **Affected Files**:
  - `lib/features/settings/data/settings_repository.dart` (Line 748, Line 843)
  - `lib/features/settings/data/wifi_repository.dart` (Line 170)
- **Observation**: Notifiers extend the synchronous `Notifier` class but manually wrap state transitions in `AsyncValue` types.
- **Logical Rationale**: Standard Riverpod practices dictate using `AsyncNotifier<void>` when managing asynchronous actions.
- **Proposed Code Change**:
  Refactor these notifiers to extend `AsyncNotifier<void>` and return `FutureOr<void>` in `build()`:
  ```dart
  @riverpod
  class WifiActionNotifier extends _$WifiActionNotifier {
    @override
    FutureOr<void> build() {
      return null;
    }
    // ...
  }
  ```

---

### Finding 4.7: Dead Code (Unused Legacy Wizard Classes)
- **Affected Files**:
  - `lib/features/alarms/presentation/wizard/alarm_wizard_notifier.dart` (and generated `.g.dart` file)
  - `lib/features/alarms/presentation/wizard/steps/wizard_step_*.dart`
- **Observation**: These wizard step and notifier files are obsolete and are completely unused by the active `alarm_wizard_screen.dart`.
- **Logical Rationale**: Obsolete files increase the codebase maintenance overhead and bundle size.
- **Proposed Code Change**:
  Delete the following obsolete files:
  - `lib/features/alarms/presentation/wizard/alarm_wizard_notifier.dart`
  - `lib/features/alarms/presentation/wizard/alarm_wizard_notifier.g.dart`
  - `lib/features/alarms/presentation/wizard/steps/wizard_step_medication.dart`
  - `lib/features/alarms/presentation/wizard/steps/wizard_step_dosage.dart`
  - `lib/features/alarms/presentation/wizard/steps/wizard_step_schedule.dart`
  - `lib/features/alarms/presentation/wizard/steps/wizard_step_options.dart`
