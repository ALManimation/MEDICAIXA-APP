# R5 Analysis: Color Synchronization and Expansion

## 1. Observation
We observed the following regarding the 15 hardware-defined colors in the codebase:
- `lib/core/constants/app_colors.dart` correctly defines 15 colors inside `AppColors.alarmColors` (lines 106-122).
- `lib/features/medications/presentation/medication_form_screen.dart` defines a local inline list of 11 colors (lines 323-335).
- `lib/features/reminders/presentation/reminder_form_screen.dart` defines a local inline list of 9 colors (lines 485-495).
- `lib/features/alarms/presentation/wizard/steps/wizard_step_options.dart` (alternative step) defines a local inline list of 10 colors (lines 34-45).
- `lib/features/alarms/presentation/wizard/steps/step_1_name.dart` (active step) defines a local inline list of 9 colors (lines 496-506).
- `lib/features/alarms/presentation/wizard/steps/step_7_summary.dart` maps only 9 color names in its natural language translator (lines 16-19).
- `lib/features/alarms/data/alarm_repository.dart` selects raw alarms directly from `_db.alarms` in `watchAllAlarms` and `getAllAlarms` (lines 172-181) without any join operation.
- `lib/features/medications/data/medication_repository.dart` lacks a method to fetch a single medication by its name.

---

## 2. Logic Chain
To synchronize and expand colors across medications, alarms, and reminders according to R5:
1. **Color Expansion**: Since `AppColors.alarmColors` is the single source of truth for the 15 colors, we must replace the local hardcoded lists in `medication_form_screen.dart`, `reminder_form_screen.dart`, `wizard_step_options.dart`, `step_1_name.dart`, and `step_7_summary.dart` with `AppColors.alarmColors.keys` (or entries) to display all 15 colors.
2. **Pre-selection in Wizard**: By adding a helper `getMedicationByName(String name)` in `MedicationRepository`, the wizard steps (`step_1_name.dart` and `wizard_step_medication.dart`) can dynamically query the database for a matching saved medication and auto-select its color when the medication name is typed or selected.
3. **Saving Color Propagation**: To guarantee the color is synced to the hardware, the wizard notifiers (`wizard_notifier.dart` and `alarm_wizard_notifier.dart`) must also look up the saved medication name at save-time and propagate its color to the `AlarmModel` right before database insertion/update.
4. **Color Inheritance (Left Outer Join)**: When a medication's color is modified, the alarm should inherit the new color without manual editing. Performing a `leftOuterJoin` on the medications table in `watchAllAlarms()` and `getAllAlarms()` allows us to resolve the alarm color using the joined medication color dynamically, falling back to the alarm's own stored color if the medication is not found.

---

## 3. Caveats
- If multiple alarms share the same medication name, they will all inherit the medication's color when fetched, even if they had distinct colors stored originally in the `alarms` table. This aligns with the requirement of central color inheritance.
- If a medication is deleted, the alarm will fall back to its own color stored in the database.

---

## 4. Conclusion
We proposed the following modifications for R5:

### 4.1. Add `getMedicationByName` in `lib/features/medications/data/medication_repository.dart`
```dart
  Future<Medication?> getMedicationByName(String name) async {
    return await (_db.select(_db.medications)..where((t) => t.name.equals(name))).getSingleOrNull();
  }
```

### 4.2. Update Left Outer Join in `lib/features/alarms/data/alarm_repository.dart`
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

### 4.3. Expand Colors in `lib/features/medications/presentation/medication_form_screen.dart`
```dart
  Widget _buildColorPicker() {
    final colors = AppColors.alarmColors.entries.map((entry) => {
      'id': entry.key,
      'color': entry.value,
    }).toList();
    
    // Checkmark contrast check
    // color: ['white', 'yellow', 'gold', 'chartreuse'].contains(c['id']) ? Colors.black : Colors.white
```

### 4.4. Expand Colors in `lib/features/reminders/presentation/reminder_form_screen.dart`
```dart
  Widget _buildColorPicker() {
    final colors = AppColors.alarmColors.entries.map((entry) => {
      'id': entry.key,
      'color': entry.value,
    }).toList();
    
    // Checkmark contrast check
    // color: ['white', 'yellow', 'gold', 'chartreuse'].contains(c['id']) ? Colors.black : Colors.white
```

### 4.5. Expand Colors in `lib/features/alarms/presentation/wizard/steps/wizard_step_options.dart` (Alternative path)
```dart
  final List<String> _colors = [
    'white', 'red', 'green', 'blue', 'yellow', 'magenta', 'cyan',
    'orange', 'purple', 'pink', 'brown', 'chartreuse', 'teal', 'coral', 'gold'
  ];
```

### 4.6. Pre-select matched color in `lib/features/alarms/presentation/wizard/steps/wizard_step_medication.dart` (Alternative path)
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

### 4.7. Expand colors in `lib/features/alarms/presentation/wizard/steps/step_1_name.dart` (Active path)
```dart
  Widget _buildColorPicker(String selectedColor, Function(String) onSelect) {
    final colors = AppColors.alarmColors;
    ...
```

### 4.8. Pre-select matched color in `lib/features/alarms/presentation/wizard/steps/step_1_name.dart` (Active path)
Inside Autocomplete's `onSelected`:
```dart
            onSelected: (MedicationAnvisa selection) async {
              _selectedFromDropdown = true;
              setState(() {
                _showManualDosageInput = false;
              });
              final medRepo = ref.read(medicationRepositoryProvider);
              final savedMed = await medRepo.getMedicationByName(selection.name);
              notifier.updateState((s) => s.copyWith(
                name: selection.name,
                type: selection.type,
                dosage: selection.dosage,
                color: savedMed?.color ?? s.color,
              ));
            },
```
Inside TextField's `onChanged`:
```dart
                onChanged: (val) async {
                  _selectedFromDropdown = false;
                  final medRepo = ref.read(medicationRepositoryProvider);
                  final savedMed = await medRepo.getMedicationByName(val.trim());
                  notifier.updateState((s) => s.copyWith(
                    name: val,
                    color: savedMed?.color ?? s.color,
                  ));
                },
```

### 4.9. Expand Translate Map in `lib/features/alarms/presentation/wizard/steps/step_7_summary.dart`
```dart
    final colorMap = {
      'white': 'Branco', 'red': 'Vermelho', 'green': 'Verde', 'blue': 'Azul',
      'yellow': 'Amarelo', 'magenta': 'Magenta', 'cyan': 'Ciano', 'orange': 'Laranja',
      'purple': 'Roxo', 'pink': 'Rosa', 'brown': 'Marrom', 'chartreuse': 'Verde-limão',
      'teal': 'Ciano/Verde-azulado', 'coral': 'Coral', 'gold': 'Dourado'
    };
```

### 4.10. Save-time Propagation in `lib/features/alarms/presentation/wizard/wizard_notifier.dart` (Active path)
```dart
  Future<void> saveAlarm() async {
    final repo = ref.read(alarmRepositoryProvider);
    final medRepo = ref.read(medicationRepositoryProvider);
    final isPrn = state.useMode == 'prn';

    final savedMed = await medRepo.getMedicationByName(state.name.trim());
    if (savedMed != null) {
      state = state.copyWith(color: savedMed.color);
    }
    
    if (state.editingAlarmId != null) {
       ...
```

### 4.11. Save-time Propagation in `lib/features/alarms/presentation/wizard/alarm_wizard_notifier.dart` (Alternative path)
```dart
  Future<bool> saveAlarm() async {
    state = state.copyWith(isSaving: true);
    try {
      final medRepo = ref.read(medicationRepositoryProvider);
      final savedMed = await medRepo.getMedicationByName(state.alarm.name);
      final resolvedColor = savedMed?.color ?? state.alarm.color;
      final alarmToSave = state.alarm.copyWith(color: resolvedColor);
      
      await _repository.createAlarm(alarmToSave);
      return true;
      ...
```

---

## 5. Verification Method
1. **Analyze Compilation**: Run `flutter analyze` to ensure there are no static type checking errors or syntax issues.
2. **Unit Tests**: Run `flutter test` to ensure that existing database, repository, or state notifier tests continue to pass.
3. **Database Assertion**: Open the Drift database file and run queries or inspect using widget inspector. Ensure the left outer join yields correct colors in logs.
