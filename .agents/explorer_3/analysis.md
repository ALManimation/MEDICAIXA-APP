# Medicaixa App Codebase Audit & Proposed Fixes

This document presents a comprehensive, read-only analysis of the 14 issues identified in `audit_report.md` along with detailed, step-by-step recommendations and proposed code modifications to address each issue while complying with the rules and constraints defined in `AGENTS.md`.

---

## 1. Critical Severity Issues

### Finding 1.1: `LateInitializationError` due to `late final` Fields in Notifier Classes (Rule 28 Violation)
- **Affected Files**:
  - `lib/features/alarms/presentation/wizard/alarm_wizard_notifier.dart` (Lines 36, 40)
  - `lib/features/pairing/presentation/pairing_notifier.dart` (Lines 9, 13)
- **Analysis**:
  Defining `late final` fields in Notifier classes and assigning them inside the `build()` method causes a `LateInitializationError` if `build()` executes more than once (e.g., on Hot Reload or watched dependency change). Since `build()` is responsible for (re)initializing state, class-level fields must not be marked `final` or assigned repeatedly.
- **Rule Reference**: **Rule 28** ("Nunca armazene Providers em variáveis `late final` dentro de Notifiers... Use getters dinâmicos...").
- **Proposed Fix Details**:
  Remove the `late final` fields from both classes and define dynamic getters to retrieve the providers.

#### Proposed Changes for `lib/features/pairing/presentation/pairing_notifier.dart`:
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
  ...
}

// AFTER
class PairingNotifier extends _$PairingNotifier {
  ConnectionRepository get _repo => ref.read(connectionRepositoryProvider);

  @override
  ConnectionStateInfo build() {
    _autoConnect();
    return const ConnectionStateInfo.disconnected();
  }
  ...
}
```

#### Proposed Changes for `lib/features/alarms/presentation/wizard/alarm_wizard_notifier.dart` (if kept, see Finding 4.7):
```dart
// BEFORE
class AlarmWizardNotifier extends _$AlarmWizardNotifier {
  late final AlarmRepository _repository;

  @override
  WizardState build() {
    _repository = ref.watch(alarmRepositoryProvider);
    ...
  }
}

// AFTER
class AlarmWizardNotifier extends _$AlarmWizardNotifier {
  AlarmRepository get _repository => ref.read(alarmRepositoryProvider);

  @override
  WizardState build() {
    ...
  }
}
```

---

### Finding 1.2: Medication Deletion Missing Alarm Usage Check in Repository (Rule 35 Violation)
- **Affected Files**:
  - `lib/features/medications/data/medication_repository.dart` (Lines 213–222, 261–266)
  - `lib/features/medications/presentation/medications_list_screen.dart` (Lines 140–142)
  - `lib/features/medications/presentation/medication_form_screen.dart` (Line 144)
- **Analysis**:
  While the presentation screens (`MedicationFormScreen` and `MedicationsListScreen`) perform validation before initiating deletion, `MedicationRepository` itself executes direct SQLite delete actions without verifying if the medication is currently referenced by any registered alarms. If deletions are triggered programmatically (e.g. during sync loops in `syncWithDevice()`), referential integrity is bypassed.
- **Rule Reference**: **Rule 35** ("Antes de excluir qualquer medicamento da base de dados, consulte o `AlarmRepository`. Se o medicamento estiver em uso em algum alarme cadastrado, bloqueie a exclusão...").
- **Proposed Fix Details**:
  Update `MedicationRepository.deleteMedication` to query the `alarms` table and throw an exception if the medication is in use. Update `syncWithDevice` to run the same query and skip deletion if referenced.

#### Proposed Changes for `lib/features/medications/data/medication_repository.dart`:
```dart
// BEFORE (deleteMedication)
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

// AFTER (deleteMedication)
  Future<void> deleteMedication(String name) async {
    // Check if referenced in alarms
    final activeAlarms = await (_db.select(_db.alarms)..where((t) => t.medName.equals(name))).get();
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

// BEFORE (syncWithDevice - clean up deleted medications)
      // 3. Clean up deleted medications
      for (final local in updatedLocalMeds) {
        if (!remoteMap.containsKey(local.name) && !local.pendingSync) {
          await (_db.delete(_db.medications)..where((t) => t.name.equals(local.name))).go();
        }
      }

// AFTER (syncWithDevice - clean up deleted medications)
      // 3. Clean up deleted medications
      for (final local in updatedLocalMeds) {
        if (!remoteMap.containsKey(local.name) && !local.pendingSync) {
          final activeAlarms = await (_db.select(_db.alarms)..where((t) => t.medName.equals(local.name))).get();
          if (activeAlarms.isEmpty) {
            await (_db.delete(_db.medications)..where((t) => t.name.equals(local.name))).go();
          } else {
            debugPrint('Medication ${local.name} is referenced by active alarms. Skipping deletion during sync.');
          }
        }
      }
```

---

## 2. High Severity Issues

### Finding 2.1: Manual `isLoading` State Flags Instead of `AsyncValue` (Rule 3 Violation)
- **Affected File**:
  - `lib/features/dashboard/presentation/dashboard_notifier.dart` (Lines 22, 91, 131, 138, 370)
  - `lib/features/dashboard/presentation/dashboard_screen.dart` (Lines 182, 185, 279, 288)
- **Analysis**:
  `DashboardNotifier` manages loading state manually using a boolean `isLoading` flag on the `DashboardState` data class. This violates the `AGENTS.md` guardrail of utilizing Riverpod's standard asynchronous wrappers.
- **Rule Reference**: **Rule 3** ("AsyncValue: Use AsyncValue do Riverpod para todos os estados assíncronos. Nunca use flags manuais isLoading ou hasError.").
- **Proposed Fix Details**:
  1. Remove `isLoading` from the `DashboardState` data class.
  2. Refactor `DashboardNotifier` to extend `AsyncNotifier<DashboardState>` and return `FutureOr<DashboardState>` inside `build()`.
  3. Update data refresh/sync methods to set `state = const AsyncLoading()` or wrap operations in `state = await AsyncValue.guard(...)`.
  4. In `DashboardScreen`, watch the notifier as an `AsyncValue` and check `asyncState.isLoading` instead of `state.isLoading`.

#### Proposed Changes for `lib/features/dashboard/presentation/dashboard_notifier.dart`:
```dart
// BEFORE (DashboardState)
class DashboardState {
  final DateTime selectedDate;
  final List<AlarmModel> alarms;
  final List<AlarmModel> allAlarms;
  final List<ReminderModel> reminders;
  final List<ReminderModel> allReminders;
  final int takenCount;
  final int pendingCount;
  final int missedCount;
  final bool isLoading;

  const DashboardState({
    required this.selectedDate,
    required this.alarms,
    required this.allAlarms,
    required this.reminders,
    required this.allReminders,
    required this.takenCount,
    required this.pendingCount,
    required this.missedCount,
    required this.isLoading,
  });
  ...
}

// AFTER (DashboardState)
class DashboardState {
  final DateTime selectedDate;
  final List<AlarmModel> alarms;
  final List<AlarmModel> allAlarms;
  final List<ReminderModel> reminders;
  final List<ReminderModel> allReminders;
  final int takenCount;
  final int pendingCount;
  final int missedCount;

  const DashboardState({
    required this.selectedDate,
    required this.alarms,
    required this.allAlarms,
    required this.reminders,
    required this.allReminders,
    required this.takenCount,
    required this.pendingCount,
    required this.missedCount,
  });

  DashboardState copyWith({
    DateTime? selectedDate,
    List<AlarmModel>? alarms,
    List<AlarmModel>? allAlarms,
    List<ReminderModel>? reminders,
    List<ReminderModel>? allReminders,
    int? takenCount,
    int? pendingCount,
    int? missedCount,
  }) {
    return DashboardState(
      selectedDate: selectedDate ?? this.selectedDate,
      alarms: alarms ?? this.alarms,
      allAlarms: allAlarms ?? this.allAlarms,
      reminders: reminders ?? this.reminders,
      allReminders: allReminders ?? this.allReminders,
      takenCount: takenCount ?? this.takenCount,
      pendingCount: pendingCount ?? this.pendingCount,
      missedCount: missedCount ?? this.missedCount,
    );
  }
}

// BEFORE (DashboardNotifier)
@riverpod
class DashboardNotifier extends _$DashboardNotifier {
  AlarmRepository get _alarmRepo => ref.read(alarmRepositoryProvider);
  ReminderRepository get _reminderRepo => ref.read(reminderRepositoryProvider);
  Timer? _inactivityTimer;

  @override
  DashboardState build() {
    final alarmSub = _alarmRepo.watchAllAlarms().listen((_) => _updateData());
    ...
    return state;
  }
  ...
}

// AFTER (DashboardNotifier)
@riverpod
class DashboardNotifier extends _$DashboardNotifier {
  AlarmRepository get _alarmRepo => ref.read(alarmRepositoryProvider);
  ReminderRepository get _reminderRepo => ref.read(reminderRepositoryProvider);
  Timer? _inactivityTimer;

  @override
  FutureOr<DashboardState> build() async {
    // Watch database streams and reload the notifier reactively
    final alarmSub = _alarmRepo.watchAllAlarms().listen((_) => _updateData());
    final reminderSub = _reminderRepo.watchAllReminders().listen((_) => _updateData());
    final historySub = ref.read(historyRepositoryProvider).watchAllHistoryEvents().listen((_) => _updateData());

    ref.onDispose(() {
      alarmSub.cancel();
      reminderSub.cancel();
      historySub.cancel();
      _inactivityTimer?.cancel();
    });

    return _performUpdate(DateTime.now());
  }

  void selectDate(DateTime date) {
    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncValue.data(current.copyWith(selectedDate: date));
      _updateData();
      _resetInactivityTimer();
    }
  }

  void resetToToday() {
    _inactivityTimer?.cancel();
    _inactivityTimer = null;
    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncValue.data(current.copyWith(selectedDate: DateTime.now()));
      _updateData();
    }
  }

  Future<void> sync() async {
    state = const AsyncValue<DashboardState>.loading().copyWithPrevious(state);
    try {
      await _alarmRepo.syncWithDevice();
      await _reminderRepo.syncWithDevice();
      await _updateData();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> loadSampleData(String jsonContent) async {
    state = const AsyncValue<DashboardState>.loading().copyWithPrevious(state);
    try {
      await _alarmRepo.loadBackupFixture(jsonContent);
      await _reminderRepo.loadBackupFixture(jsonContent);
      await _updateData();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> _updateData() async {
    final current = state.valueOrNull;
    final date = current?.selectedDate ?? DateTime.now();
    try {
      final updated = await _performUpdate(date);
      state = AsyncValue.data(updated);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<DashboardState> _performUpdate(DateTime date) async {
    // ... logic for gathering and filtering alarms, reminders, history ...
    // Note: ensure to ignore disabled alarms here as well (see Finding 3.5)
    return DashboardState(
      selectedDate: date,
      alarms: filteredAlarms,
      allAlarms: allAlarms,
      reminders: filteredReminders,
      allReminders: allReminders,
      takenCount: takenCount,
      pendingCount: pendingCount,
      missedCount: missedCount,
    );
  }
}
```

#### Proposed Changes for `lib/features/dashboard/presentation/dashboard_screen.dart`:
```dart
// In build() method
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(dashboardNotifierProvider);
    final state = asyncState.valueOrNull;
    final isLoading = asyncState.isLoading;

    if (state == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    
    // Replace all references to `state.isLoading` with `isLoading`.
    // Replace selectedDate listener:
    ref.listen<DateTime?>(
      dashboardNotifierProvider.select((s) => s.value?.selectedDate),
      (previous, next) {
        if (next != null) {
          ref.read(dashboardCollapseProvider.notifier).state = const {};
        }
      },
    );
    ...
  }
```

---

## 3. Medium Severity Issues

### Finding 3.2: Layer Violations (Presentation-to-Data Bleeding)
- **Affected Files**:
  - `lib/features/alarms/data/alarm_repository.dart`
  - `lib/features/settings/data/settings_repository.dart`
  - `lib/features/reminders/data/reminder_repository.dart`
  - `lib/features/medications/data/medication_repository.dart`
  - `lib/features/settings/data/wifi_repository.dart`
- **Analysis**:
  Data layer repositories directly import and read `pairingNotifierProvider` from the presentation layer to evaluate connectivity status. This breaks the unidirectional clean architecture boundary.
- **Rule Reference**: Feature-First Clean Architecture separation (data should not import presentation).
- **Proposed Fix Details**:
  1. Define a global connection provider `deviceConnectionStateProvider` in `lib/core/providers/connection_providers.dart` (or domain layer).
  2. Have `PairingNotifier` synchronize its state using `ref.listenSelf` to update the global provider.
  3. Repositories read `deviceConnectionStateProvider` directly.

#### Proposed new file `lib/core/providers/connection_providers.dart`:
```dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../features/pairing/domain/connection_state.dart';

part 'connection_providers.g.dart';

@Riverpod(keepAlive: true)
class DeviceConnectionState extends _$DeviceConnectionState {
  @override
  ConnectionStateInfo build() {
    return const ConnectionStateInfo.disconnected();
  }

  void update(ConnectionStateInfo newState) {
    state = newState;
  }
}
```

#### Proposed changes to `lib/features/pairing/presentation/pairing_notifier.dart` (`build` method):
```dart
  @override
  ConnectionStateInfo build() {
    _autoConnect();
    
    // Synchronize local state with the global domain provider
    ref.listenSelf((previous, next) {
      ref.read(deviceConnectionStateProvider.notifier).update(next);
    });

    return const ConnectionStateInfo.disconnected();
  }
```

#### Proposed changes to `lib/features/alarms/data/alarm_repository.dart`, `lib/features/settings/data/settings_repository.dart`, `lib/features/reminders/data/reminder_repository.dart`, `lib/features/medications/data/medication_repository.dart`, `lib/features/settings/data/wifi_repository.dart`:
Replace the import of `pairing_notifier.dart` with `../../../core/providers/connection_providers.dart` and update the connection checks:
```dart
// BEFORE
import '../../pairing/presentation/pairing_notifier.dart';

  bool _isConnected() {
    final connState = _ref.read(pairingNotifierProvider);
    return connState.status == ConnectionStatus.connected;
  }

// AFTER
import '../../../core/providers/connection_providers.dart';

  bool _isConnected() {
    final connState = _ref.read(deviceConnectionStateProvider);
    return connState.status == ConnectionStatus.connected;
  }
```

---

### Finding 3.3: Dashboard Inactivity Timer Memory Leak
- **Affected File**:
  - `lib/features/dashboard/presentation/dashboard_notifier.dart` (Lines 65, 124, 75–79)
- **Analysis**:
  The inactivity timer scheduled inside `_resetInactivityTimer` is not cancelled when `DashboardNotifier` is disposed.
- **Proposed Fix Details**:
  Add `_inactivityTimer?.cancel();` in the `ref.onDispose` block.
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
- **Affected Files**:
  - `lib/features/settings/presentation/settings_screen.dart` (Line 787)
  - `lib/core/services/notification_service.dart` (Line 145)
  - `lib/features/alarms/presentation/alarm_active_screen.dart` (Line 172)
- **Analysis**:
  Index 0 of local alarm sound plays `alarm_gentile` (.wav), but in the local Settings screen dropdown, index 0 is labeled "Beep". In the original C++ Web UI, index 0 is labeled "Gentil" (Gentle).
- **Proposed Fix Details**:
  Rename "Beep" to "Gentil" in the dropdown items list in `settings_screen.dart`.
```dart
// BEFORE
DropdownMenuItem(value: 0, child: Text('Beep', style: TextStyle(color: AppColors.text))),

// AFTER
DropdownMenuItem(value: 0, child: Text('Gentil', style: TextStyle(color: AppColors.text))),
```

---

### Finding 3.5: Disabled Alarms Erroneously Counted as Missed (Rule 54 Violation)
- **Affected File**:
  - `lib/features/dashboard/presentation/dashboard_screen.dart` (Lines 402–427 inside `_getMissedCountForSection`)
  - `lib/features/dashboard/presentation/dashboard_notifier.dart` (Lines 329–360 inside `_performUpdate`)
- **Analysis**:
  Alarms that are disabled (`!alarm.enabled || !alarm.active`) are incorrectly evaluated inside the "missed" counts when their scheduled hours have passed.
- **Rule Reference**: **Rule 54** ("...as seções de período ... devem exibir a contagem de alarmes programados e, caso haja doses perdidas no dia atual, destacar a quantidade de perdas...").
- **Proposed Fix Details**:
  Insert active status checks at the top of loops in both `_getMissedCountForSection` (dashboard screen) and `_performUpdate` (dashboard notifier).

#### In `lib/features/dashboard/presentation/dashboard_screen.dart`:
```dart
  int _getMissedCountForSection(
    List<AlarmModel> alarms,
    DateTime selectedDate,
    DateTime now,
    String dateFormatted,
  ) {
    int missedCount = 0;
    for (final alarm in alarms) {
      if (!alarm.enabled || !alarm.active) {
        continue; // Skip disabled or inactive alarms
      }
      final isTakenToday = alarm.lastStatusDate == dateFormatted && alarm.lastStatus == 'Tomado';
      ...
```

#### In `lib/features/dashboard/presentation/dashboard_notifier.dart`:
```dart
    for (final alarm in filteredAlarms) {
      if (!alarm.enabled || !alarm.active) {
        continue; // Skip disabled or inactive alarms in calculations
      }
      final isTakenToday = alarm.lastStatusDate == dateFormatted && alarm.lastStatus == 'Tomado';
      ...
```

---

## 4. Low Severity Issues

### Finding 4.1: Custom Model `copyWith` Null Value Limitation (Rule 37 Context)
- **Affected Files**:
  - `lib/features/alarms/data/alarm_repository.dart` (Lines 949–1059)
  - `lib/features/reminders/data/reminder_repository.dart` (Lines 406–441)
- **Analysis**:
  The `copyWith` extensions fallback to `field ?? this.field`. This blocks passing explicit null values, requiring developers to write empty strings as workarounds.
- **Rule Reference**: **Rule 37** ("Nas classes geradas de dados do Drift... os campos opcionais e nulos no copyWith esperam Value<T?>...").
- **Proposed Fix Details**:
  To support explicit nulls cleanly, use a sentinel pattern (default parameters set to a constant `Object` or custom `Sentinel` class) or wrap inputs in an `Option<T>` wrapper.

#### Example Sentinel Implementation in `lib/features/reminders/data/reminder_repository.dart`:
```dart
class Sentinel {
  const Sentinel();
}
const sentinel = Sentinel();

extension ReminderModelCopyWith on ReminderModel {
  ReminderModel copyWith({
    int? id,
    String? title,
    Object? description = sentinel, // default to sentinel
    bool? enabled,
    bool? hasTime,
    int? hour,
    int? minute,
    String? period,
    int? interval,
    Object? startDate = sentinel,
    int? notifyDaysBefore,
    Object? lastCompletedDate = sentinel,
    String? color,
    int? lastModified,
    bool? pendingSync,
  }) {
    return ReminderModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description == sentinel ? this.description : (description as String?),
      enabled: enabled ?? this.enabled,
      hasTime: hasTime ?? this.hasTime,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      period: period ?? this.period,
      interval: interval ?? this.interval,
      startDate: startDate == sentinel ? this.startDate : (startDate as String?),
      notifyDaysBefore: notifyDaysBefore ?? this.notifyDaysBefore,
      lastCompletedDate: lastCompletedDate == sentinel ? this.lastCompletedDate : (lastCompletedDate as String?),
      color: color ?? this.color,
      lastModified: lastModified ?? this.lastModified,
      pendingSync: pendingSync ?? this.pendingSync,
    );
  }
}
```

---

### Finding 4.2: Duplicate Compressed ANVISA Database Loading (Rule 27 Context)
- **Affected Files**:
  - `lib/features/medications/data/medication_repository.dart` (Line 95, 115)
  - `lib/features/alarms/data/medication_search_service.dart`
- **Analysis**:
  `MedicationRepository` and `MedicationSearchService` both decompress and parse the `assets/medications_db.json.gz` asset independently. Additionally, `MedicationRepository`'s search method uses a custom non-Rule 27 search approach.
- **Rule Reference**: **Rule 27** ("Busca e Autocomplete (Fuzzy & Ordenação)... normalizar as strings... relevância (Nome > Nome Aproximado > Genérico)... ordenar priorizando tamanho...").
- **Proposed Fix Details**:
  Remove all asset loading, gzip decompression, parsing isolates, and custom search lists from `MedicationRepository`. Implement the search method by reading `MedicationSearchService` and converting the result.

#### Proposed refactored search method in `lib/features/medications/data/medication_repository.dart`:
```dart
  Future<List<MedicationModel>> search(String query) async {
    final searchService = _ref.read(medicationSearchServiceProvider);
    final results = await searchService.search(query);
    return results.map((m) => MedicationModel(
      name: m.name,
      type: m.type,
      dosage: m.dosage,
      generic: m.generic,
    )).toList();
  }
```
Remove `_parseMedicationsIsolate`, `SearchPayload`, `_levenshteinDistance`, `_searchIsolate`, `_medications`, `_isLoading`, and `loadDatabase()` from `MedicationRepository`. Remove `repo.loadDatabase();` from `medicationRepository` provider definition.

---

### Finding 4.3: Synchronous Backup JSON Decoding on UI Thread
- **Affected File**:
  - `lib/features/settings/presentation/settings_screen.dart` (Line 244)
- **Analysis**:
  Running `json.decode(content)` synchronously on the UI thread when restoring a backup could cause frame drops if the file contains long history logs.
- **Proposed Fix Details**:
  Offload the decode to a background thread using Flutter's `compute` utility:
```dart
// BEFORE
final Map<String, dynamic> rawMap = json.decode(content);

// AFTER
final Map<String, dynamic> rawMap = await compute((String s) => json.decode(s) as Map<String, dynamic>, content);
```

---

### Finding 4.4: Inefficient UI Rebuilds in `AlarmCardWidget`
- **Affected File**:
  - `lib/features/dashboard/presentation/widgets/alarm_card_widget.dart` (Line 352)
- **Analysis**:
  `AlarmCardWidget` watches the entire `dashboardNotifierProvider` to retrieve the `selectedDate`, causing it to rebuild unnecessarily for unrelated changes in the dashboard state.
- **Proposed Fix Details**:
  Utilize Riverpod's `select` on the async value:
```dart
// BEFORE
final selectedDate = ref.watch(dashboardNotifierProvider).selectedDate;

// AFTER
final selectedDate = ref.watch(dashboardNotifierProvider.select((s) => s.value?.selectedDate ?? DateTime.now()));
```

---

### Finding 4.5: Timezone Initialization UTC Fallback Risk
- **Affected Files**:
  - `lib/core/services/notification_service.dart` (Lines 89–92)
  - `lib/core/services/alarm_engine.dart`
- **Analysis**:
  If `FlutterTimezone` fails, falling back to UTC triggers alarms at offset hours.
- **Proposed Fix Details**:
  Implement a timezone-guessing fallback based on the system offset before resorting to UTC.

```dart
// BEFORE (notification_service.dart)
    } catch (e) {
      debugPrint('Could not get local timezone: $e. Falling back to UTC.');
      tz.setLocalLocation(tz.UTC);
    }

// AFTER (notification_service.dart)
    } catch (e) {
      debugPrint('Could not get local timezone: $e. Attempting offset-based fallback.');
      String fallbackZone = 'America/Sao_Paulo'; // Default for Medicaixa App
      final offset = DateTime.now().timeZoneOffset;
      if (offset.inHours == 0) {
        fallbackZone = 'UTC';
      } else if (offset.inHours == 1) {
        fallbackZone = 'Europe/Lisbon';
      }
      try {
        tz.setLocalLocation(tz.getLocation(fallbackZone));
        debugPrint('Fallback timezone configured to: $fallbackZone');
      } catch (_) {
        tz.setLocalLocation(tz.UTC);
      }
    }
```

---

### Finding 4.6: Non-Idiomatic `AsyncValue` Usage in Synchronous Notifiers
- **Affected Files**:
  - `lib/features/settings/data/settings_repository.dart` (DeviceResetNotifier, SoundSettingsAction)
  - `lib/features/settings/data/wifi_repository.dart` (WifiActionNotifier)
- **Analysis**:
  These notifiers extend code-generated `Notifier<AsyncValue<void>>` instead of using `AsyncNotifier<void>` which natively manages the `AsyncValue` wrapping.
- **Proposed Fix Details**:
  Refactor the class declarations and `build` signatures to return `FutureOr<void>` instead of `AsyncValue<void>`.

```dart
// BEFORE (WifiActionNotifier)
@riverpod
class WifiActionNotifier extends _$WifiActionNotifier {
  @override
  AsyncValue<void> build() {
    return const AsyncValue.data(null);
  }
  ...
}

// AFTER (WifiActionNotifier)
@riverpod
class WifiActionNotifier extends _$WifiActionNotifier {
  @override
  FutureOr<void> build() {
    // Returns void
  }
  ...
}
```
(Apply the same change to `DeviceResetNotifier` and `SoundSettingsAction` in `settings_repository.dart`).

---

### Finding 4.7: Dead Code (Unused Legacy Wizard Classes)
- **Affected Files**:
  - `lib/features/alarms/presentation/wizard/alarm_wizard_notifier.dart` (and generated `.g.dart` file)
  - `lib/features/alarms/presentation/wizard/steps/wizard_step_dosage.dart`
  - `lib/features/alarms/presentation/wizard/steps/wizard_step_medication.dart`
  - `lib/features/alarms/presentation/wizard/steps/wizard_step_options.dart`
  - `lib/features/alarms/presentation/wizard/steps/wizard_step_schedule.dart`
- **Analysis**:
  The active alarm creation wizard uses `wizard_notifier.dart` and `steps/step_1_name.dart` to `steps/step_7_summary.dart`. The legacy wizard files are obsolete.
- **Proposed Fix Details**:
  Safely delete `alarm_wizard_notifier.dart`, `alarm_wizard_notifier.g.dart`, and the four `wizard_step_*.dart` step files from the project.
