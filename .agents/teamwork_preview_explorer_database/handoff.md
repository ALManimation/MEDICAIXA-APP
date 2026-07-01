# Codebase Audit Report: Drift Database, Repositories, and Serialization

This handoff report summarizes the codebase audit performed on the Drift database configurations, repositories, serialization logic, platform-specific initializations, and copyWith behaviors.

---

## 1. Observations

### Finding A: Medication Deletion Lacks Safeguard in Repository (Violates Rule 35)
* **File Path**: `lib/features/medications/data/medication_repository.dart`
* **Lines**: 213–222, 261–266
* **Code observed**:
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
  ```dart
  // 3. Clean up deleted medications
  for (final local in updatedLocalMeds) {
    if (!remoteMap.containsKey(local.name) && !local.pendingSync) {
      await (_db.delete(_db.medications)..where((t) => t.name.equals(local.name))).go();
    }
  }
  ```
* **Description**: Rule 35 states: *"Antes de excluir qualquer medicamento da base de dados, consulte o `AlarmRepository`. Se o medicamento estiver em uso em algum alarme cadastrado, bloqueie a exclusão e alerte o usuário listando os alarmes impeditivos."* While the UI screens (`medications_list_screen.dart` and `medication_form_screen.dart`) check if the medication is in use, the repository functions do not verify linked alarms before deletion, leading to potential integrity issues during synchronization or programmatic deletion from elsewhere.

---

### Finding B: Custom Model copyWith Methods Prevent Setting Null Values (Rules 37 & 23 Context)
* **File Paths**:
  1. `lib/features/alarms/data/alarm_repository.dart` (Lines 949–1059)
  2. `lib/features/reminders/data/reminder_repository.dart` (Lines 406–441)
* **Code observed**:
  ```dart
  extension AlarmModelCopyWith on AlarmModel {
    AlarmModel copyWith({
      ...
      String? dosage,
      String? lastStatus,
      String? lastStatusDate,
      ...
    }) {
      return AlarmModel(
        ...
        dosage: dosage ?? this.dosage,
        lastStatus: lastStatus ?? this.lastStatus,
        lastStatusDate: lastStatusDate ?? this.lastStatusDate,
        ...
      );
    }
  }
  ```
* **Description**: In these extensions, nullable fields such as `dosage`, `lastStatus`, and `lastStatusDate` use standard `value ?? this.value` fallbacks. If a developer needs to explicitly set a value to `null` (e.g. clearing `lastStatusDate` when resetting status), the copyWith method ignores the `null` and keeps the old value.
* **Workarounds in code**: To bypass this, files like `lib/core/services/alarm_engine.dart` (line 177–178) pass empty strings `''` instead of `null` and have to perform redundant checks:
  ```dart
  if (a.lastStatusDate != null && a.lastStatusDate!.isNotEmpty)
  ```

---

### Finding C: Unused Legacy Wizard Code (Dead Code)
* **File Paths**:
  - `lib/features/alarms/presentation/wizard/alarm_wizard_notifier.dart` (and generated `.g.dart` file)
  - `lib/features/alarms/presentation/wizard/steps/wizard_step_dosage.dart`
  - `lib/features/alarms/presentation/wizard/steps/wizard_step_medication.dart`
  - `lib/features/alarms/presentation/wizard/steps/wizard_step_options.dart`
  - `lib/features/alarms/presentation/wizard/steps/wizard_step_schedule.dart`
* **Description**: The wizard layout `alarm_wizard_screen.dart` is imported to use `wizard_notifier.dart` along with steps `step_1_name.dart` to `step_7_summary.dart`. The aforementioned `alarm_wizard_notifier.dart` and its `wizard_step_` files are dead code and are only imported by one another.

---

### Verified & Fully Compliant Sections
1. **Rule 59 (Apple NativeDatabase Sync Connection)**: Configured correctly in `lib/core/database/database.dart` lines 198–207. Spawns `NativeDatabase(file)` synchronously on iOS and macOS, while using `NativeDatabase.createInBackground(file)` on other platforms.
2. **Rule 8 (Dio Timeout)**: Configured correctly via `AppConstants.requestTimeoutMs` which is set to `5000` (5 seconds) in `lib/core/constants/app_constants.dart` and loaded into `DioClient` BaseOptions.
3. **Rule 9 (Sequential / Serialized Requests)**: Properly managed using a `RequestLock` inside `lib/core/network/dio_client.dart` that synchronizes both `get` and `post` network operations to the ESP32.
4. **Rule 7 & 10 & 11 (Snake_case, Double parsing, Optional fields)**: Checked and fully compliant in `AlarmModel.fromJson` and `AlarmModel.toJson` (`lib/features/alarms/data/alarm_model.dart`), utilizing `(val as num).toDouble()` for the quantity field, `snake_case` keys matching ESP32 expectations, and dynamically stripping inactive options like cycle or PRN fields from the payload.
5. **Rule 23 (Drift Singular Class Names)**: Successfully verified in `lib/core/database/database.g.dart` that generated classes are named in singular (`Alarm`, `Reminder`, `Setting`, `Medication`) and no suffix like `Data` is used.
6. **Rule 27 (Fuzzy Search & Sorting)**: Verified `lib/features/alarms/data/medication_search_service.dart` strictly processes searches on isolates using normalized text, sorts by length first, and maintains the order `Nome > Nome Aproximado > Genérico`.

---

## 2. Logic Chain

1. **Rule 35 Requirement**: Medication deletion must be guarded against being actively used in registered alarms.
2. **Observation on Deletion**: `MedicationRepository.deleteMedication` and `syncWithDevice` directly execute SQLite deletion commands via Drift without querying the `Alarms` table or checking if the medication is referenced.
3. **Conclusion for Finding A**: The repository tier fails to protect referential integrity internally, exposing it to bugs if deletion is initiated programmatically outside the UI screen logic or during device-to-local synchronization.

4. **Observation on copyWith**: Custom model `AlarmModel` and `ReminderModel` classes have copyWith definitions that fall back to `this.dosage` or `this.lastStatus` if the parameter is `null`.
5. **Observation on Workarounds**: In `alarm_engine.dart`, the engine resets status by saving empty strings `''` instead of `null`.
6. **Conclusion for Finding B**: Nullable fields in custom models cannot be cleared to `null` using `copyWith`, forcing the use of empty string workarounds and adding logical noise.

---

## 3. Caveats
No manual testing, builds, or hot restarts were performed, as this is a read-only codebase audit. The analysis assumes that the current behaviors in the repository and model scopes represent all operations touching the SQLite schemas.

---

## 4. Conclusions

| Severity | Issue | Description | Recommendation |
|---|---|---|---|
| **Medium** | Medication deletion lacks database referential check | `deleteMedication` in repository directly deletes rows without checking if alarms link to that medication. | Modify `MedicationRepository.deleteMedication` to query `alarms` (or use DI to check the `AlarmRepository`) and reject/throw if linked alarms exist. |
| **Low** | Custom model copyWith cannot set fields to `null` | Using `dosage ?? this.dosage` ignores explicit `null` updates. | Refactor extensions `AlarmModelCopyWith` and `ReminderModelCopyWith` to support nullable updates (e.g. using sentinel values or wrapping properties inside Drift `Value` objects). |
| **Low** | Unused legacy wizard code | Duplicate wizard classes and step files exist in the alarms feature. | Safely delete the legacy files (`alarm_wizard_notifier.dart` and `wizard_step_*.dart`). |

---

## 5. Verification Method

To verify the findings:
1. **Medication Deletion**:
   - Inspect `lib/features/medications/data/medication_repository.dart` lines 213–222 and 261–266 to confirm the direct SQLite `delete` execution without checking `alarms`.
2. **Custom Model copyWith**:
   - Inspect `lib/features/alarms/data/alarm_repository.dart` line 950 and `lib/features/reminders/data/reminder_repository.dart` line 406. Try to write a unit test executing `model.copyWith(lastStatusDate: null)` and assert it equals `null`—it will fail.
3. **Verification Command**:
   - Run `flutter test` to ensure all existing tests pass after any future cleanups.
