# Handoff Report — AlarmEngine and System Audit

## 1. Observation

During a comprehensive read-only codebase audit of the MediCaixa Flutter application, several discrepancies, logic issues, and rule violations were identified. The details of the audited code and findings are documented below:

### Finding 1: Medication Deletion Safety Check Missing (CRITICAL)
- **Rule Violation**: Rule 35 of `AGENTS.md` ("Impedir Exclusão de Medicamentos em Uso: Antes de excluir qualquer medicamento da base de dados, consulte o `AlarmRepository`. Se o medicamento estiver em uso em algum alarme cadastrado, bloqueie a exclusão e alerte o usuário listando os alarmes impeditivos.") is completely violated.
- **File Paths and Lines**:
  - `lib/features/medications/data/medication_repository.dart` lines 213-222:
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
  - `lib/features/medications/presentation/medications_list_screen.dart` lines 140-142:
    ```dart
    for (final name in _selectedMeds) {
      await medRepo.deleteMedication(name);
    }
    ```
  - `lib/features/medications/presentation/medication_form_screen.dart` line 144:
    ```dart
    await repo.deleteMedication(editMed.name);
    ```

### Finding 2: Inactive/Disabled Alarms Counted as Missed in Dashboard Headers (MEDIUM)
- **Issue**: Under Rule 54 ("Contagem de Alarmes Perdidos em Seções Retráteis..."), sections on the Dashboard show missed count badges. However, the calculation does not verify if the alarm is currently enabled/active, resulting in inactive/disabled alarms being counted as "Missed/Perdido" when their scheduled time has passed.
- **File Path and Lines**:
  - `lib/features/dashboard/presentation/dashboard_screen.dart` lines 402-427 (inside `_getMissedCountForSection`):
    ```dart
    int _getMissedCountForSection(
      List<AlarmModel> alarms,
      DateTime selectedDate,
      bool isToday,
      DateTime now,
      String dateFormatted,
    ) {
      int missedCount = 0;
      for (final alarm in alarms) {
        final isTakenToday = alarm.lastStatusDate == dateFormatted && alarm.lastStatus == 'Tomado';
        if (isTakenToday) {
          continue;
        }
        final isSkippedToday = alarm.lastStatusDate == dateFormatted && alarm.lastStatus == 'Não Tomado';
        if (isSkippedToday) {
          missedCount++;
        } else {
          if (isToday) {
            final alarmTime = DateTime(now.year, now.month, now.day, alarm.hour, alarm.minute);
            final limitTime = alarmTime.add(Duration(minutes: alarm.snoozeMin + 10));
            if (now.isAfter(limitTime)) {
              missedCount++;
            }
          } else {
            final targetZero = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
            final todayZero = DateTime(now.year, now.month, now.day);
            if (targetZero.isBefore(todayZero)) {
              missedCount++;
            }
          }
        }
      }
      return missedCount;
    }
    ```
  There is no check at the beginning of the loop for `!alarm.enabled || !alarm.active`.

### Finding 3: Sound Dropdown Option 0 Label Mismatch (MEDIUM)
- **Issue**: Dropdown option 0 in the settings UI is labeled "Beep" but plays the melody "alarm_gentile" in the player, causing visual and audio inconsistency.
- **File Paths and Lines**:
  - `lib/features/settings/presentation/settings_screen.dart` line 787 (Dropdown item list):
    ```dart
    DropdownMenuItem(value: 0, child: Text('Beep', style: TextStyle(color: AppColors.text))),
    ```
  - `lib/core/services/notification_service.dart` line 145:
    ```dart
    case 0: resolvedSound = 'alarm_gentile'; break;
    ```
  - `lib/features/alarms/presentation/alarm_active_screen.dart` line 172:
    ```dart
    case 0: soundPath = 'sounds/alarm_gentile.wav'; break;
    ```
  - Reference: C++ Web UI `index.html` line 2840 maps option 0 to "Gentil":
    ```html
    <option value="0">Gentil</option>
    ```

### Finding 4: Timezone Initialization Fallback to UTC (LOW)
- **Issue**: In `AlarmEngine`, if `tz.local` fails because the local timezone is not yet set (or fails to initialize), it initiates the setup in background and aborts the current tick. If it fails, it defaults to `tz.UTC` which can trigger the alarm at the wrong local hours (since offset is omitted).
- **File Paths and Lines**:
  - `lib/core/services/alarm_engine.dart` lines 103-115:
    ```dart
    final now = DateTime.now();
    tz.Location localLocation;
    try {
      localLocation = tz.local;
    } catch (_) {
      NotificationService.instance.init().then((_) {
        debugPrint('NotificationService fallback initialization complete.');
      });
      return;
    }
    ```
  - `lib/core/services/notification_service.dart` lines 89-92 (fallback):
    ```dart
    } catch (e) {
      debugPrint('Could not get local timezone: $e. Falling back to UTC.');
      tz.setLocalLocation(tz.UTC);
    }
    ```

---

## 2. Logic Chain

1. **Rule 35 compliance check**: Rule 35 states that before deleting a medication from the DB, the system must check `AlarmRepository` and block it if the medication is in use. Investigating `medication_repository.dart` reveals that `deleteMedication` only executes the database query `(_db.delete(_db.medications)..where((t) => t.name.equals(name))).go();` and does not check alarms. Both deleting screens (`medications_list_screen.dart` and `medication_form_screen.dart`) simply call `deleteMedication` directly without consulting the `AlarmRepository`. This leaves a critical gap that leads to inconsistent database references.
2. **Dashboard Missed count check**: In `dashboard_screen.dart`, `_getMissedCountForSection` calculates how many alarms in the period section are missed. Inactive/disabled alarms are still returned by `dashboardNotifierProvider` because `_isAlarmActiveOnDate` only filters by calendar schedule, not by state. When evaluating those alarms in `_getMissedCountForSection`, there is no `!alarm.enabled || !alarm.active` guard. Thus, every disabled alarm is incorrectly counted as missed if it is past its time.
3. **Sound selection mapping check**: The settings page uses dropdown values `0-4` to match settings in the C++ project. Dropdown option 0 is labeled "Beep" in the settings screen code, but maps to `alarm_gentile` in `NotificationService` and `alarm_active_screen.dart` sound player path switch blocks. In the C++ project's `index.html`, index 0 is labeled "Gentil" (Gentle), proving that index 0 is meant to be the Gentle melody, not Beep.
4. **Timezone fallback check**: If `FlutterTimezone.getLocalTimezone()` fails or throws an exception (which can happen under certain emulator/device environments if the package bindings fail), the catch block sets the location to UTC `tz.setLocalLocation(tz.UTC)`. This causes all subsequent calculations in the `AlarmEngine` tick to use UTC time instead of local time, which causes alarms to trigger hours early/late depending on the device's timezone offset.

---

## 3. Caveats

- We did not write or execute any code fixes as we are restricted to a read-only investigation.
- We assumed that `tz.local` is the primary source of timezone location throughout the `AlarmEngine` execution.
- We did not investigate background background tasks (e.g. WorkManager integrations) since background task executors on iOS/Android were out of the immediate scope, though `AlarmEngine` manages the tick logic correctly when the application is running.

---

## 4. Conclusion

1. The medication deletion code has a **Critical** violation of Rule 35. Deletion must be updated to inspect the active alarms, list blocking alarms, and show an warning alert to the user.
2. The Dashboard header badge calculation has a **Medium** bug where disabled alarms are erroneously counted as missed. A check `if (!alarm.enabled || !alarm.active) continue;` must be added at the top of the loop in `_getMissedCountForSection` inside `dashboard_screen.dart`.
3. Dropdown option 0 in the settings UI has a **Medium** labeling mismatch and must be renamed from "Beep" to "Gentil" or "Gentle" to maintain parity with the played file and the C++ project.
4. Timezone config has a **Low** risk of using UTC fallback if initialization fails.

---

## 5. Verification Method

To verify these issues, inspect the following files and sections:
1. **Medication Deletion**:
   - Inspect `lib/features/medications/data/medication_repository.dart` at line 213. Notice the complete absence of a check to `AlarmRepository`.
   - Inspect `lib/features/medications/presentation/medications_list_screen.dart` at lines 138-142. Note the direct execution of deletion.
2. **Dashboard Missed Badge**:
   - Inspect `lib/features/dashboard/presentation/dashboard_screen.dart` at line 402. Confirm that there is no check for `alarm.enabled` or `alarm.active` in `_getMissedCountForSection`.
3. **Sound dropdown label mismatch**:
   - Inspect `lib/features/settings/presentation/settings_screen.dart` at line 787. Verify that option 0 is named `'Beep'`.
   - Inspect `lib/core/services/notification_service.dart` at line 145. Verify that case 0 maps to `'alarm_gentile'`.
4. **To run project tests**:
   - Run `flutter test` to verify that other tests are fully functional and pass.
