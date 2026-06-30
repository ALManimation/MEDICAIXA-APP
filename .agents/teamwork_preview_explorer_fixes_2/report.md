# Exploration and Diagnostic Report: Colors & Dashboard Flicker

This report details the findings and proposals regarding color grid alignment, bidirectional color sync, reminder color validation, and dashboard loading flicker in the MediCaixa Flutter application.

---

## 1. Color Grid & Palette Alignment

### Direct Observations & Context
- **Color Map Definition**: In `lib/core/constants/app_colors.dart` (lines 106-122), the official C++ map is defined as `AppColors.alarmColors`, containing exactly 15 color mappings:
  `white`, `red`, `green`, `blue`, `yellow`, `magenta`, `cyan`, `orange`, `purple`, `pink`, `brown`, `chartreuse`, `teal`, `coral`, and `gold`.
- **Inactive/Old Wizard Code**: `lib/features/alarms/presentation/wizard/steps/wizard_step_options.dart` lists all 15 colors in its internal `_colors` array (lines 34-50) and renders them using `AppColors.getAlarmColor`. However, this file is **inactive** and not referenced or integrated anywhere else in the application.
- **Active Wizard Code**: The active alarm wizard is loaded in `lib/features/alarms/presentation/wizard/alarm_wizard_screen.dart` and uses `lib/features/alarms/presentation/wizard/steps/step_1_name.dart`.
- **Active Wizard Colors**: In `step_1_name.dart` (lines 506-517), `_buildColorPicker()` defines a hardcoded local map of only **9 colors**:
  ```dart
  final colors = {
    'blue': const Color(0xFF3B82F6),
    'green': const Color(0xFF10B981),
    'red': const Color(0xFFEF4444),
    'yellow': const Color(0xFFFBBF24),
    'purple': const Color(0xFF8B5CF6),
    'orange': const Color(0xFFF97316),
    'pink': const Color(0xFFEC4899),
    'teal': const Color(0xFF14B8A6),
    'white': const Color(0xFF9CA3AF), // gray circle from C++ UI
  };
  ```
- **Medications Screen**: In `lib/features/medications/presentation/medication_form_screen.dart` (lines 322-371), `_buildColorPicker()` dynamically uses `AppColors.alarmColors.entries.toList()`, showing all 15 colors correctly.

### Proposed Solution
In `lib/features/alarms/presentation/wizard/steps/step_1_name.dart`, refactor `_buildColorPicker` to align with the medication form screen and use the full 15-color palette:
```dart
Widget _buildColorPicker(String selectedColor, Function(String) onSelect) {
  final colors = AppColors.alarmColors.entries.toList();

  return Wrap(
    spacing: 12,
    runSpacing: 12,
    alignment: WrapAlignment.center,
    children: colors.map((entry) {
      final colorId = entry.key;
      final colorVal = entry.value;
      final isSelected = selectedColor == colorId;
      return GestureDetector(
        onTap: () => onSelect(colorId),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: colorVal,
            shape: BoxShape.circle,
            border: isSelected
                ? Border.all(color: Colors.white, width: 3)
                : Border.all(color: Colors.transparent, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
      );
    }).toList(),
  );
}
```

---

## 2. Bidirectional Color Sync

### Direct Observations & Context
- **Persistence Layer**:
  - The `Alarms` table in `lib/core/database/database.dart` (line 19) contains a `TextColumn get color => text()();` column.
  - The `Medications` table (line 152) contains a `TextColumn get color => text()();` column.
  - In `lib/features/alarms/data/alarm_repository.dart` (lines 172-197), the methods `watchAllAlarms()` and `getAllAlarms()` fetch alarms by joining with the `Medications` table:
    ```dart
    final query = _db.select(_db.alarms).join([
      leftOuterJoin(_db.medications, _db.medications.name.equalsExp(_db.alarms.medName)),
    ]);
    // ...
    final resolvedColor = medication != null ? medication.color : driftAlarm.color;
    return _toModel(driftAlarm).copyWith(color: resolvedColor);
    ```
    This ensures that when a medication's color is updated, any linked alarm displays that new color in the UI reactively.
- **Medication Selection**:
  - In the active wizard (`step_1_name.dart`, lines 152-160 and 168-174), choosing an existing medication automatically queries its color from the database and updates the wizard's state:
    ```dart
    final medRepo = ref.read(medicationRepositoryProvider);
    final savedMed = await medRepo.getMedicationByName(selection.name);
    final resolvedColor = savedMed?.color ?? ref.read(wizardNotifierProvider).color;
    // notifier updates state with resolvedColor
    ```
- **Alarms to Medications Update**:
  - In `lib/features/alarms/presentation/wizard/wizard_notifier.dart` (lines 290-320), saving the alarm automatically updates/creates the corresponding medication in the database:
    ```dart
    final savedMed = await medRepo.getMedicationByName(state.name);
    if (savedMed != null) {
      await medRepo.updateMedication(
        savedMed.name,
        savedMed.copyWith(
          color: state.color,
          lastModified: Value(DateTime.now().millisecondsSinceEpoch),
        ),
      );
    } else {
      await medRepo.createMedication(...);
    }
    ```

### GAP Identified
If the user goes directly to the Medications screen (`lib/features/medications/presentation/medication_form_screen.dart`) and changes the color of a medication, the `medications` table is updated. Thanks to the SQL join, the local UI correctly shows the updated color. However, the **`alarms` table database row still contains the old color string**. If a network sync triggers, the alarm color sent to the physical ESP32 device will be the stale color saved in the alarm row, because `AlarmModel.toJson()` serializes the column value.

### Proposed Solution
To ensure absolute bidirectional sync at the database level and prevent stale colors from being synced to the hardware device:
1. When a medication is created or updated in `lib/features/medications/data/medication_repository.dart`, query and update any alarms linked to that medication.
2. In `MedicationRepository.updateMedication` and `createMedication`, perform a database update on the `Alarms` table where `medName` matches the medication name:
   ```dart
   // Inside MedicationRepository:
   Future<void> _syncAlarmsColor(String medName, String newColor) async {
     final alarmsQuery = _db.select(_db.alarms)..where((t) => t.medName.equals(medName));
     final linkedAlarms = await alarmsQuery.get();
     for (final alarm in linkedAlarms) {
       if (alarm.color != newColor) {
         final updatedAlarm = alarm.copyWith(
           color: newColor,
           lastModified: Value(DateTime.now().millisecondsSinceEpoch),
           pendingSync: true, // Mark for sync to push to ESP32
         );
         await _db.update(_db.alarms).replace(updatedAlarm);
       }
     }
   }
   ```
   Execute this helper method at the end of `createMedication` and `updateMedication` to propagate the color change to the alarms, setting their `pendingSync = true` to push to the ESP32.

---

## 3. Reminder Colors

### Direct Observations & Context
- **Screen**: `lib/features/reminders/presentation/reminder_form_screen.dart` (lines 484-533) already uses `AppColors.alarmColors.entries.toList()` to build the color picker options.
- **Model Defaulting**: In `lib/features/reminders/data/reminder_model.dart` (line 52):
  ```dart
  color: json['color'] as String? ?? 'blue',
  ```
  If a sync response or backup contains a color outside of the 15 official ones (e.g. `'grey'`), it won't resolve correctly inside the `AppColors.alarmColors` map and will fall back to `AppColors.primary`.

### Proposed Solution
Use defensive programming to sanitize reminder colors in the model when deserializing JSON. This guarantees that only valid keys of `AppColors.alarmColors` are parsed:
- **`ReminderModel.fromJson` modification**:
  ```dart
  final rawColor = (json['color'] as String? ?? 'blue').toLowerCase();
  final validColor = AppColors.alarmColors.containsKey(rawColor) ? rawColor : 'blue';
  ```
- **`ReminderFormScreen.initState` fallback**:
  ```dart
  _selectedColor = AppColors.alarmColors.containsKey(r.color.toLowerCase())
      ? r.color.toLowerCase()
      : 'blue';
  ```

---

## 4. Dashboard Loading Flicker

### Direct Observations & Context
1. **Unnecessary `isLoading = true` State During Date Swaps**:
   In `lib/features/dashboard/presentation/dashboard_notifier.dart` (lines 96-101 and 105-110):
   ```dart
   void selectDate(DateTime date) {
     state = state.copyWith(selectedDate: date, isLoading: true);
     _updateData();
     ...
   }
   ```
   Setting `isLoading: true` instructs the `DashboardScreen` (lines 286-299) to display a `LinearProgressIndicator` and to transition the opacity of the main scrollable content to `0.65` via `AnimatedOpacity` (which takes 150ms to fade out).
   Since loading local data from SQLite takes under 5ms, the notifier immediately receives the database records and emits a new state with `isLoading: false`, causing the UI to instantly fade back to `1.0` and hide the progress bar. This rapid transition is perceived as a jarring visual "blink" or flicker.
2. **Re-subscription to settingsStream**:
   Inside `DashboardScreen.build()` (lines 58-63):
   ```dart
   final db = ref.watch(databaseProvider);
   final settingsStream = db.select(db.settings).watchSingleOrNull();
   ```
   Every time the dashboard builds (such as when the selected date changes), a brand-new stream instance is created. The `StreamBuilder` consumes this stream, forcing it to unsubscribe from the old stream and subscribe to the new one. During this sub-millisecond transition, the `StreamBuilder` briefly holds no data (`snapshot.data` is null), which can cause temporary layout shifts or text defaultings (e.g., patient name reverting to default string) before the database returns the query results.

### Proposed Solutions
1. **Separate Sync/Local Loading States**:
   Do not trigger `isLoading: true` for local date changes. Keep `isLoading` for device sync only (`sync()` and `loadSampleData()`). Date navigation will perform database queries and update the state atomically without fading out the screen.
   In `DashboardNotifier`:
   ```dart
   void selectDate(DateTime date) {
     state = state.copyWith(selectedDate: date); // Keep isLoading: false
     _updateData();
     _resetInactivityTimer();
   }

   void resetToToday() {
     _inactivityTimer?.cancel();
     _inactivityTimer = null;
     state = state.copyWith(selectedDate: DateTime.now()); // Keep isLoading: false
     _updateData();
   }
   ```
2. **Optimize Settings Watching (Eliminate StreamBuilder)**:
   Avoid creating the settings stream inside the widget's `build()` method. Define a global Riverpod `StreamProvider` for settings:
   ```dart
   // lib/core/providers/core_providers.dart (or new file)
   @riverpod
   Stream<Setting?> watchSettings(WatchSettingsRef ref) {
     final db = ref.watch(databaseProvider);
     return db.select(db.settings).watchSingleOrNull();
   }
   ```
   Then, in `DashboardScreen`, watch this provider and remove the `StreamBuilder` completely:
   ```dart
   // In DashboardScreen:
   final settingsAsync = ref.watch(watchSettingsProvider);
   final patientName = settingsAsync.valueOrNull?.patientName ?? t('tab_patient');
   ```
   This prevents database re-subscriptions, eliminates the stream transition delay, and keeps the widget tree light and stable.
