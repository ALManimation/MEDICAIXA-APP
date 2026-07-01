# Codebase Audit Analysis — 14 Identified Issues

This report provides a detailed analysis of the 14 issues identified in `audit_report.md`, mapping them to their root causes and recommending precise, step-by-step code changes and refactoring strategies. All recommendations align with the coding standards and architectural requirements of `AGENTS.md`.

---

## Executive Summary of Issues

| ID | Issue Description | Severity | Affected Files | Relevant AGENTS.md Rule |
| :--- | :--- | :--- | :--- | :--- |
| **1.1** | `LateInitializationError` on hot reload due to `late final` references | Critical | `alarm_wizard_notifier.dart`, `pairing_notifier.dart` | **Rule 28** |
| **1.2** | Medication deletion missing alarm usage validation in Repository | Critical | `medication_repository.dart`, `medications_list_screen.dart`, `medication_form_screen.dart` | **Rule 35** |
| **2.1** | Manual `isLoading` state flags in place of Riverpod `AsyncValue` | High | `dashboard_notifier.dart` | **Rule 3** |
| **3.2** | Layer Violations (Presentation imports inside Data Repositories) | Medium | All repositories, `pairing_notifier.dart` | Clean Architecture Boundaries |
| **3.3** | Dashboard inactivity timer memory leak on notifier disposal | Medium | `dashboard_notifier.dart` | Resource Lifecycle |
| **3.4** | Sound Dropdown Option 0 "Beep" vs "Gentil/Gentle" label mismatch | Medium | `settings_screen.dart`, `notification_service.dart`, `alarm_active_screen.dart` | C++ Web UI Parity |
| **3.5** | Disabled alarms erroneously counted as missed on Dashboard | Medium | `dashboard_screen.dart` | **Rule 54** |
| **4.1** | Custom model `copyWith` does not support explicit null values | Low | `alarm_repository.dart`, `reminder_repository.dart` | **Rule 37** Context |
| **4.2** | Duplicated loading/decompression of ANVISA database | Low | `medication_repository.dart`, `medication_search_service.dart` | **Rule 27** Context |
| **4.3** | Synchronous backup JSON decoding blocking the UI thread | Low | `settings_screen.dart` | UI Responsiveness |
| **4.4** | Inefficient widget rebuilds in `AlarmCardWidget` | Low | `alarm_card_widget.dart` | Rebuild Optimization |
| **4.5** | Timezone initialization failure defaults to UTC (causes offset shifts) | Low | `alarm_engine.dart`, `notification_service.dart` | Correct Alarm Timing |
| **4.6** | Non-idiomatic manual `AsyncValue` state wraps in synchronous notifiers | Low | `settings_repository.dart`, `wifi_repository.dart` | Riverpod Standards |
| **4.7** | Dead code / unused legacy wizard files | Low | Wizard directory files | Code Hygiene |

---

## Detailed Analyses & Actionable Recommendations

### Finding 1.1: `LateInitializationError` due to `late final` Fields in Notifier Classes (Rule 28 Violation)
- **Problem**: In Riverpod, Notifiers persist across rebuilds and hot reloads, but their `build()` method is executed again. Re-assigning a `late final` field inside `build()` throws a runtime `LateInitializationError`.
- **Affected Files**:
  - `lib/features/alarms/presentation/wizard/alarm_wizard_notifier.dart` (Lines 36, 40)
  - `lib/features/pairing/presentation/pairing_notifier.dart` (Lines 9, 13)
- **Proposed Changes**:
  - **PairingNotifier**:
    Remove `late final ConnectionRepository _repo;` and replace with a dynamic getter reading from `ref`:
    ```dart
    // BEFORE
    class PairingNotifier extends _$PairingNotifier {
      late final ConnectionRepository _repo;
      @override
      ConnectionStateInfo build() {
        _repo = ref.watch(connectionRepositoryProvider);
        _autoConnect();
        return const ConnectionStateInfo.disconnected();
      }
    }

    // AFTER
    class PairingNotifier extends _$PairingNotifier {
      ConnectionRepository get _repo => ref.read(connectionRepositoryProvider);
      @override
      ConnectionStateInfo build() {
        _autoConnect();
        return const ConnectionStateInfo.disconnected();
      }
    }
    ```
  - **AlarmWizardNotifier** (if kept, though it is dead code):
    Similarly replace `late final AlarmRepository _repository;` with a getter:
    ```dart
    AlarmRepository get _repository => ref.read(alarmRepositoryProvider);
    ```

---

### Finding 1.2: Medication Deletion Missing Alarm Usage Check in Repository (Rule 35 Violation)
- **Problem**: `MedicationRepository.deleteMedication` deletes a medication record from Drift SQLite directly, risking referential integrity issues (orphaned alarms) if deleted programmatically or during synchronization loops.
- **Affected Files**:
  - `lib/features/medications/data/medication_repository.dart` (Lines 213–222, 261–266)
- **Proposed Changes**:
  Add an explicit validation querying the `alarms` table inside both `deleteMedication` and the `syncWithDevice` cleanup loop:
  ```dart
  // In MedicationRepository:
  Future<void> deleteMedication(String name) async {
    final activeAlarms = await (_db.select(_db.alarms)
          ..where((t) => t.medName.equals(name) | t.name.equals(name)))
        .get();
    if (activeAlarms.isNotEmpty) {
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

  // In syncWithDevice():
  // 3. Clean up deleted medications
  for (final local in updatedLocalMeds) {
    if (!remoteMap.containsKey(local.name) && !local.pendingSync) {
      final linkedAlarms = await (_db.select(_db.alarms)
            ..where((t) => t.medName.equals(local.name) | t.name.equals(local.name)))
          .get();
      if (linkedAlarms.isEmpty) {
        await (_db.delete(_db.medications)..where((t) => t.name.equals(local.name))).go();
      }
    }
  }
  ```

---

### Finding 2.1: Manual `isLoading` State Flags Instead of `AsyncValue` (Rule 3 Violation)
- **Problem**: `DashboardNotifier` utilizes a manual `bool isLoading` state flag on `DashboardState`, adding boilerplate loading state management and violating Rule 3.
- **Affected Files**:
  - `lib/features/dashboard/presentation/dashboard_notifier.dart`
- **Proposed Changes**:
  - Remove the `isLoading` property from the `DashboardState` class constructor and `copyWith`.
  - Change `DashboardNotifier` to extend `AsyncNotifier<DashboardState>` (returning `FutureOr<DashboardState>` inside `build()`):
  ```dart
  @riverpod
  class DashboardNotifier extends _$DashboardNotifier {
    AlarmRepository get _alarmRepo => ref.read(alarmRepositoryProvider);
    ReminderRepository get _reminderRepo => ref.read(reminderRepositoryProvider);
    Timer? _inactivityTimer;

    @override
    FutureOr<DashboardState> build() async {
      final alarmSub = _alarmRepo.watchAllAlarms().listen((_) => _updateData());
      final reminderSub = _reminderRepo.watchAllReminders().listen((_) => _updateData());
      final historySub = ref.read(historyRepositoryProvider).watchAllHistoryEvents().listen((_) => _updateData());

      ref.onDispose(() {
        alarmSub.cancel();
        reminderSub.cancel();
        historySub.cancel();
        _inactivityTimer?.cancel();
      });

      return _fetchData(DateTime.now());
    }

    Future<DashboardState> _fetchData(DateTime date) async {
      // Computes and returns the state (alarms, reminders, calculations)
      // This is the logic extracted from _performUpdate
    }

    Future<void> _updateData() async {
      state = await AsyncValue.guard(() async {
        final currentDate = state.valueOrNull?.selectedDate ?? DateTime.now();
        return _fetchData(currentDate);
      });
    }

    // Methods like selectDate, resetToToday, sync, loadSampleData update "state = AsyncValue.data(newState)" or trigger _updateData().
  }
  ```
  - In `dashboard_screen.dart`, watch the provider as an `AsyncValue` and safely extract the state:
  ```dart
  final stateAsync = ref.watch(dashboardNotifierProvider);
  final state = stateAsync.valueOrNull;
  if (state == null) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
  // The rest of the build method runs exactly as-is since 'state' has the exact same properties.
  // Replace 'state.isLoading' checks with 'stateAsync.isLoading'.
  ```

---

### Finding 3.2: Layer Violations (Presentation-to-Data Bleeding)
- **Problem**: Repositories in the `data` layer import `pairing_notifier.dart` from the `presentation` layer to check the connection status, violating clean architecture boundaries.
- **Affected Files**:
  - `lib/features/alarms/data/alarm_repository.dart`
  - `lib/features/settings/data/settings_repository.dart`
  - `lib/features/reminders/data/reminder_repository.dart`
  - `lib/features/medications/data/medication_repository.dart`
  - `lib/features/settings/data/wifi_repository.dart`
- **Proposed Changes**:
  - Create a core provider in `lib/core/providers/connection_state_provider.dart`:
    ```dart
    import 'package:riverpod_annotation/riverpod_annotation.dart';
    import '../../features/pairing/domain/connection_state.dart';

    part 'connection_state_provider.g.dart';

    @Riverpod(keepAlive: true)
    class DeviceConnectionState extends _$DeviceConnectionState {
      @override
      ConnectionStateInfo build() => const ConnectionStateInfo.disconnected();

      void updateState(ConnectionStateInfo newState) {
        state = newState;
      }
    }
    ```
  - In `pairing_notifier.dart`, listen to itself and update the core connection provider:
    ```dart
    @override
    ConnectionStateInfo build() {
      _autoConnect();
      ref.listenSelf((previous, next) {
        ref.read(deviceConnectionStateProvider.notifier).updateState(next);
      });
      return const ConnectionStateInfo.disconnected();
    }
    ```
  - In all repositories, remove imports to `pairing_notifier.dart` and read `deviceConnectionStateProvider` instead:
    ```dart
    // In repositories:
    import '../../../core/providers/connection_state_provider.dart';
    
    bool _isConnected() {
      final connState = _ref.read(deviceConnectionStateProvider);
      return connState.status == ConnectionStatus.connected;
    }
    ```

---

### Finding 3.3: Dashboard Inactivity Timer Memory Leak
- **Problem**: The dashboard `_inactivityTimer` (a 3-minute timer) is scheduled when navigating off-today, but it is not cancelled when `DashboardNotifier` is disposed.
- **Affected Files**:
  - `lib/features/dashboard/presentation/dashboard_notifier.dart`
- **Proposed Changes**:
  Add `_inactivityTimer?.cancel();` to the `ref.onDispose` callback of `DashboardNotifier`:
  ```dart
  ref.onDispose(() {
    alarmSub.cancel();
    reminderSub.cancel();
    historySub.cancel();
    _inactivityTimer?.cancel(); // Cancel timer to prevent leaks
  });
  ```

---

### Finding 3.4: Sound Dropdown Option 0 Label Mismatch (C++ Inconsistency)
- **Problem**: Dropdown option index 0 is labeled "Beep" in the settings UI, but resolves to `alarm_gentile` and plays `alarm_gentile.wav` locally. In the C++ project Web UI (`index.html` line 2840), index 0 is correctly labeled "Gentil" (Gentle).
- **Affected Files**:
  - `lib/features/settings/presentation/settings_screen.dart` (Line 787)
- **Proposed Changes**:
  Change the option label in `settings_screen.dart`:
  ```dart
  // BEFORE
  DropdownMenuItem(value: 0, child: Text('Beep', style: TextStyle(color: AppColors.text))),
  
  // AFTER
  DropdownMenuItem(value: 0, child: Text('Gentil', style: TextStyle(color: AppColors.text))),
  ```

---

### Finding 3.5: Disabled Alarms Erroneously Counted as Missed (Rule 54 Violation)
- **Problem**: Alarms that are disabled or inactive are counted as missed by `_getMissedCountForSection` on the Dashboard and in the notifier totals after their scheduled times have passed.
- **Affected Files**:
  - `lib/features/dashboard/presentation/dashboard_screen.dart` (Line 402 inside `_getMissedCountForSection`)
  - `lib/features/dashboard/presentation/dashboard_notifier.dart` (inside `_performUpdate` loop)
- **Proposed Changes**:
  - In `dashboard_screen.dart` (`_getMissedCountForSection`):
    ```dart
    for (final alarm in alarms) {
      if (!alarm.enabled || !alarm.active) {
        continue;
      }
      final isTakenToday = alarm.lastStatusDate == dateFormatted && alarm.lastStatus == 'Tomado';
      ...
    }
    ```
  - In `dashboard_notifier.dart` (`_fetchData` / `_performUpdate` loop):
    ```dart
    for (final alarm in filteredAlarms) {
      if (!alarm.enabled || !alarm.active) {
        continue;
      }
      final isTakenToday = alarm.lastStatusDate == dateFormatted && alarm.lastStatus == 'Tomado';
      ...
    }
    ```

---

### Finding 4.1: Custom Model `copyWith` Null Value Limitation (Rule 37 Context)
- **Problem**: Custom `copyWith` extensions for models (`AlarmModel`, `ReminderModel`) use `value ?? this.value` fallbacks, making it impossible to explicitly clear fields (e.g. setting `lastStatusDate` to `null`).
- **Affected Files**:
  - `lib/features/alarms/data/alarm_repository.dart`
  - `lib/features/reminders/data/reminder_repository.dart`
- **Proposed Changes**:
  Use the standard Dart sentinel object pattern to support null override mapping:
  ```dart
  extension AlarmModelCopyWith on AlarmModel {
    AlarmModel copyWith({
      ...
      Object? lastStatusDate = const Object(),
      ...
    }) {
      return AlarmModel(
        ...
        lastStatusDate: lastStatusDate == const Object() ? this.lastStatusDate : (lastStatusDate as String?),
        ...
      );
    }
  }
  ```
  Perform the same refactoring for nullable properties in `ReminderModel`.

---

### Finding 4.2: Duplicate Compressed ANVISA Database Loading (Rule 27 Context)
- **Problem**: Both `MedicationRepository` and `MedicationSearchService` load and decompress the `assets/medications_db.json.gz` file independently, wasting memory and CPU cycles.
- **Affected Files**:
  - `lib/features/medications/data/medication_repository.dart`
  - `lib/features/alarms/data/medication_search_service.dart`
- **Proposed Changes**:
  - Delegate all search and autocomplete logic to the core `MedicationSearchService` (which is already implemented using isolates and follows Rule 27 ranking principles).
  - Remove `loadDatabase()` and `search()` methods and fields from `MedicationRepository`.
  - In components where ANVISA autocomplete is needed, consume `searchMedicationsProvider` from `MedicationSearchService`.

---

### Finding 4.3: Synchronous Backup JSON Decoding on UI Thread
- **Problem**: Restoring backups uses `json.decode(content)` synchronously on the UI thread, blocking the main UI loop when parsing large event/log backup strings.
- **Affected Files**:
  - `lib/features/settings/presentation/settings_screen.dart` (Line 244)
- **Proposed Changes**:
  Utilize Flutter's `compute` utility to parse JSON inside a background isolate:
  ```dart
  // BEFORE
  final Map<String, dynamic> rawMap = json.decode(content);

  // AFTER
  final Map<String, dynamic> rawMap = await compute(
    (str) => json.decode(str) as Map<String, dynamic>,
    content,
  );
  ```

---

### Finding 4.4: Inefficient UI Rebuilds in `AlarmCardWidget`
- **Problem**: `AlarmCardWidget` watches the entire `dashboardNotifierProvider` only to extract `selectedDate`, causing it to rebuild when unrelated fields (e.g. counts, lists) in the dashboard change.
- **Affected Files**:
  - `lib/features/dashboard/presentation/widgets/alarm_card_widget.dart` (Line 352)
- **Proposed Changes**:
  Use `select` to filter and rebuild the widget only on `selectedDate` modifications:
  ```dart
  // BEFORE
  final selectedDate = ref.watch(dashboardNotifierProvider).selectedDate;

  // AFTER
  final selectedDate = ref.watch(
    dashboardNotifierProvider.select((s) => s.valueOrNull?.selectedDate),
  ) ?? DateTime.now();
  ```

---

### Finding 4.5: Timezone Initialization UTC Fallback Risk
- **Problem**: Setting `tz.UTC` on timezone configuration failure causes scheduled alarms to trigger at shifted UTC offsets, causing incorrect timings for users.
- **Affected Files**:
  - `lib/core/services/notification_service.dart` (Lines 89–92)
- **Proposed Changes**:
  In `notification_service.dart`, check for failure and fall back to the project's primary timezone location (`America/Sao_Paulo`) before defaulting to UTC:
  ```dart
  Future<void> _configureLocalTimeZone() async {
    tz.initializeTimeZones();
    try {
      final timezoneInfo = await FlutterTimezone.getLocalTimezone();
      final String timeZoneName = timezoneInfo.identifier;
      tz.setLocalLocation(tz.getLocation(timeZoneName));
      debugPrint('Local timezone configured to: $timeZoneName');
    } catch (e) {
      debugPrint('Could not get local timezone: $e. Trying default Sao Paulo fallback.');
      try {
        tz.setLocalLocation(tz.getLocation('America/Sao_Paulo'));
        debugPrint('Fallback local timezone configured to America/Sao_Paulo');
      } catch (e2) {
        debugPrint('Fallback failed: $e2. Setting UTC.');
        tz.setLocalLocation(tz.UTC);
      }
    }
  }
  ```

---

### Finding 4.6: Non-Idiomatic `AsyncValue` Usage in Synchronous Notifiers
- **Problem**: Providers like `DeviceResetNotifier`, `SoundSettingsAction`, and `WifiActionNotifier` extend synchronous Notifiers but manually configure and wrap their state properties using `AsyncValue`.
- **Affected Files**:
  - `lib/features/settings/data/settings_repository.dart`
  - `lib/features/settings/data/wifi_repository.dart`
- **Proposed Changes**:
  Refactor these notifiers to extend `AsyncNotifier<void>` and return `FutureOr<void>` from `build()`:
  ```dart
  @riverpod
  class WifiActionNotifier extends _$WifiActionNotifier {
    @override
    FutureOr<void> build() {
      // return void / null
    }

    Future<bool> addNetwork(String ssid, String password) async {
      state = const AsyncValue.loading();
      state = await AsyncValue.guard(() async {
        final repository = ref.read(wifiRepositoryProvider);
        await repository.addNetwork(ssid, password);
        ref.invalidate(savedWifiNetworksProvider);
        ref.invalidate(wifiScanProvider);
      });
      return !state.hasError;
    }
  }
  ```

---

### Finding 4.7: Dead Code (Unused Legacy Wizard Classes)
- **Problem**: Legacy wizard notifier and wizard steps are unused. The application instead utilizes `wizard_notifier.dart` and `steps/step_1_name.dart` through `steps/step_7_summary.dart`.
- **Affected Files**:
  - `lib/features/alarms/presentation/wizard/alarm_wizard_notifier.dart` (and generated `.g.dart`)
  - `lib/features/alarms/presentation/wizard/steps/wizard_step_dosage.dart`
  - `lib/features/alarms/presentation/wizard/steps/wizard_step_medication.dart`
  - `lib/features/alarms/presentation/wizard/steps/wizard_step_options.dart`
  - `lib/features/alarms/presentation/wizard/steps/wizard_step_schedule.dart`
- **Proposed Changes**:
  - Mark these 5 files for deletion to clean up the directory and reduce codebase clutter.
