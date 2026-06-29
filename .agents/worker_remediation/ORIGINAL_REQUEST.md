## 2026-06-28T23:35:44Z
You are a teamwork_preview_worker.
Your working directory is: /Users/almanimation/Downloads/Caixa Remedios/medicaixa_app/.agents/worker_remediation
Your mission is to resolve the findings from the Victory Audit Rejection:

1. **Rule 35 Bypass**:
   In `lib/features/medications/presentation/medication_form_screen.dart`, when deleting a medication in edit mode inside `_delete()`, check if the medication is currently associated with an active alarm in `AlarmRepository`. If it is, display the "Exclusão Bloqueada" warning dialog listing the linked alarms and block the deletion (same logic as in `medications_list_screen.dart`).
   - Import `alarm_repository.dart`.
   - Before deleting, fetch all alarms using `alarmRepo.getAllAlarms()`.
   - Filter alarms where `a.medName == medName || a.name == medName`.
   - If they exist, show the `dialog_delete_blocked_title` dialog, display list of linked alarms, and return early.

2. **Static Analysis & Test Suite fixes**:
   In `test/features/medications/medication_crud_test.dart`:
   - Add `const` to the `Medication(...)` instantiation at lines 71 and 112 to satisfy `prefer_const_constructors`.
   - Replace the deprecated `ProviderScope(parent: container)` at line 144 with `UncontrolledProviderScope(container: container)`.

3. **Verification**:
   - Run `flutter analyze` and ensure it completes with 0 warnings/infos/errors.
   - Run `flutter test` and verify that all 103 tests pass.

MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A Forensic Auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

Please update `.agents/worker_remediation/progress.md` after each step with your current status and timestamp.
When finished, write a handoff.md in your directory and report back.

## 2026-06-28T21:36:42-03:00
You are a worker agent. Your task is to implement the bug fixes and C++ alignment requirements (R1, R2, R3, R4, and R5) in the MediCaixa Flutter app based on the findings from Explorer 1, 2, and 3.

MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A Forensic Auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

Please perform the following edits:

1. Database Layer changes:
- In `lib/features/medications/data/medication_repository.dart`, add:
  ```dart
  Future<Medication?> getMedicationByName(String name) async {
    return await (_db.select(_db.medications)..where((t) => t.name.equals(name))).getSingleOrNull();
  }
  ```
- In `lib/features/alarms/data/alarm_repository.dart`, update `watchAllAlarms()` and `getAllAlarms()` to left outer join the `medications` table on `name == medName` and resolve the alarm's color dynamically:
  ```dart
  Stream<List<AlarmModel>> watchAllAlarms() {
    final query = _db.select(_db.alarms).join([
      leftOuterJoin(_db.medications, _db.medications.name.equalsExp(_db.alarms.medName)),
    ]);
    return query.watch().map((rows) {
      return rows.map((row) {
        final driftAlarm = row.readTable(_db.alarms);
        final medication = row.readTableOrNull(_db.medications);
        final resolvedColor = medication != null ? medication.color : driftAlarm.color;
        return _toModel(driftAlarm).copyWith(color: resolvedColor);
      }).toList();
    });
  }

  Future<List<AlarmModel>> getAllAlarms() async {
    final query = _db.select(_db.alarms).join([
      leftOuterJoin(_db.medications, _db.medications.name.equalsExp(_db.alarms.medName)),
    ]);
    final rows = await query.get();
    return rows.map((row) {
      final driftAlarm = row.readTable(_db.alarms);
      final medication = row.readTableOrNull(_db.medications);
      final resolvedColor = medication != null ? medication.color : driftAlarm.color;
      return _toModel(driftAlarm).copyWith(color: resolvedColor);
    }).toList();
  }
  ```
- In `lib/features/alarms/data/alarm_repository.dart`, update `snoozeAlarm` to copy and save the alarm status as 'SNOOZED':
  ```dart
    final updated = alarm.copyWith(
      status: 'SNOOZED',
      snoozeMin: minutes,
      lastModified: DateTime.now().millisecondsSinceEpoch,
      pendingSync: !_isConnected(),
    );
  ```

2. UI & Layout changes:
- In `lib/features/alarms/presentation/snooze_modal.dart`:
  - Set `isScrollControlled: true` in `showModalBottomSheet`.
  - Wrap the content Column of `build` in `SafeArea` + `SingleChildScrollView`.
  - Set bottom padding of Padding to `MediaQuery.of(context).viewInsets.bottom + 32`.
- In `lib/features/dashboard/presentation/dashboard_screen.dart`:
  - Remove the loader center widget replacement (do not unmount layout on `state.isLoading`).
  - Keep Scaffold body with a Column containing `fixedHeader` and `scrollableBody`.
  - Display a thin `LinearProgressIndicator` (height 4) when `state.isLoading` is true just under `fixedHeader` (inside a SizedBox of height 4).
  - Wrap `scrollableBody` in an `AnimatedOpacity` with `opacity: state.isLoading ? 0.65 : 1.0` and duration `150` ms.
  - Set `shape: const CircleBorder()` on the `FloatingActionButton`.

3. Color options picker expansions (15 colors):
- In `lib/features/medications/presentation/medication_form_screen.dart`, update `_buildColorPicker` to load all 15 colors from `AppColors.alarmColors.entries`. Adjust contrast icon color (e.g. black for white, yellow, gold, and chartreuse; white for others).
- In `lib/features/reminders/presentation/reminder_form_screen.dart`, update `_buildColorPicker` to load all 15 colors from `AppColors.alarmColors.entries`.
- In `lib/features/alarms/presentation/wizard/steps/wizard_step_options.dart`, expand the `_colors` static list to contain all 15 colors.
- In `lib/features/alarms/presentation/wizard/steps/step_1_name.dart`, update `_buildColorPicker` to map over `AppColors.alarmColors.entries`.
- In `lib/features/alarms/presentation/wizard/steps/step_7_summary.dart`, expand the local `colorMap` translation map to translate all 15 colors.

4. Wizard Pre-selection and Save propagation:
- In `lib/features/alarms/presentation/wizard/steps/wizard_step_medication.dart`, update `_selectMedication` to query medication color from db:
  ```dart
  void _selectMedication(String name, String type, String dosage, String? category, String? instruction) async {
    final notifier = ref.read(alarmWizardNotifierProvider.notifier);
    final medRepo = ref.read(medicationRepositoryProvider);
    final savedMed = await medRepo.getMedicationByName(name);
    final color = savedMed?.color ?? _getColorForCategory(category);
    
    notifier.updateMedication(name, type, dosage, color, instruction);
    if (context.mounted) {
      widget.onNext();
    }
  }
  ```
- In `lib/features/alarms/presentation/wizard/steps/step_1_name.dart`, update `onSelected` and `onChanged` to query matched medication color and update notifier state with it.
- In `lib/features/alarms/presentation/wizard/wizard_notifier.dart` (Active Path), in `saveAlarm()`, add logic to check if a medication matching `state.name` exists. If it exists, update its color to `state.color` in the local DB. If it does not exist, insert a new `Medication` row. Also update the `state` color right before constructing the alarm model to match the medication color if found.
- In `lib/features/alarms/presentation/wizard/alarm_wizard_notifier.dart` (Alternative Path), in `saveAlarm()`, check if a medication matching `state.alarm.name` exists. If it exists, update its color to `state.alarm.color` in the local DB. If not, insert a new `Medication` row. Also construct the alarm to save with the correct medication color.

5. After making the changes:
- Run `dart run build_runner build --delete-conflicting-outputs` (if needed, but note that manually adding methods in classes doesn't require rebuilding unless there is generated code impacted).
- Run `flutter analyze` and ensure there are 0 errors and 0 warnings.
- Run `flutter test` to verify that all tests pass perfectly.
- Write a detailed handoff report to `.agents/worker_remediation/handoff.md`.
