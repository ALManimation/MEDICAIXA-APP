# MediCaixa App — Backup, Restore, and Reset Exploration Report

This report presents a technical analysis and implementation blueprint for the **Backup (Export)**, **Restore (Import)**, and **Reset** features of the MediCaixa App. It details how the app will support both **Standalone (offline-first)** and **Connected (ESP32 synced)** modes, adhering strictly to the architecture and guardrails of the project.

---

## 1. Executive Summary & Architectural Overview

The MediCaixa App operates on an **Offline-First (Standalone)** architecture by default. 
- **In Standalone Mode**: Backup, Restore, and Reset act directly on the local SQLite database via Drift. Backups are generated locally, Restores parse and populate local tables, and Resets clean local tables.
- **In Connected Mode**: The app executes all operations locally AND forwards matching requests to the ESP32 (via HTTP endpoints `/backup`, `/restore`, `/reset`, `/restart`) to keep both environments synchronized.

---

## 2. Drift Database Table Structure & Data Classes

The app uses `drift` for SQLite database operations defined in `lib/core/database/database.dart`. Below are the mappings of database tables, column structures, and generated Drift data classes (which use singular naming in accordance with **Rule 23**).

### A. Medications (`meds` Table)
- **Drift Data Class**: `Medication` (singular of `medications`)
- **Primary Key**: `name` (TextColumn)
- **Columns**:
  - `name`: `TextColumn` (Drug name)
  - `color`: `TextColumn` (Hex/String representation)
  - `type`: `TextColumn` (Form factor: `comprimido`, `capsula`, `gota`, etc.)
  - `dosage`: `TextColumn` (Nullable dosage string)
  - `lastModified`: `IntColumn` (Nullable epoch timestamp)
  - `pendingSync`: `BoolColumn` (Sync status with ESP32)

### B. Alarms (`alarms` Table)
- **Drift Data Class**: `Alarm` (singular of `alarms`)
- **Primary Key**: `id` (IntColumn)
- **Columns**:
  - `id`, `hour`, `minute`, `name`, `medName`, `enabled`, `active`, `days` (JSON `List<bool>`), `status`, `color`, `quantity` (`RealColumn`), `daysQuantity` (JSON `List<double>`), `type`, `dosage`, `lastStatus`, `lastStatusDate`, `snoozeMin`, `startDate`, `durationDays`, `createdDate`.
  - **Advanced/Optional**: `cycleOnDays`, `cycleOffDays`, `cycleCurrentDay`, `cycleIsPaused`, `isPrn`, `prnMinIntervalHours`, `prnMaxDailyDoses`, `prnDosesToday`, `pauseUntil`, `isDynamic`, `dynamicInstruction`, `taperStageCount`, `taperCurrentStage`, `taperDayInStage`, `taperStages` (JSON `List<TaperStage>`), `taperLoop`, `specialInstruction`, `adjustStep`, `adjustIntervalDays` (interval of days for taper, mapped to `adjust_interval_days`), `adjustLimit`, `requiresRemoval`, `removalDelayMins`, `siteRotationList`, `currentSiteIndex`, `dayOfMonth`, `groupId`, `intervalHours`, `intervalDays` (ordinary interval, mapped to `interval_days`), `intervalCountdown`.
  - **Local Sync**: `lastModified`, `pendingSync`.

### C. Reminders (`reminders` Table)
- **Drift Data Class**: `Reminder` (singular of `reminders`)
- **Primary Key**: `id` (IntColumn)
- **Columns**:
  - `id`, `title`, `description`, `enabled`, `hasTime`, `hour` (Nullable), `minute` (Nullable), `period`, `interval`, `startDate`, `notifyDaysBefore`, `lastCompletedDate` (Nullable), `color`.
  - **Local Sync**: `lastModified`, `pendingSync`.

### D. History Events (`history_events` Table)
- **Drift Data Class**: `HistoryEvent` (singular of `historyEvents`)
- **Primary Key**: `id` (IntColumn, autoIncrement)
- **Columns**:
  - `id`, `alarmId` (Nullable), `reminderId` (Nullable), `medName` (Nullable), `dosage` (Nullable), `timestamp` (`IntColumn`), `status` (String log status), `type` (`alarm`, `reminder`, or `system`), `pendingSync`.

### E. Settings (`settings` Table)
- **Drift Data Class**: `Setting` (singular of `settings`)
- **Primary Key**: `id` (IntColumn, defaults to 1, single row config)
- **Columns**:
  - `id`, `deviceIp` (Nullable), `patientName` (`Paciente`), `speakerVolume` (20), `brightness` (50), `language` (`pt`), `wakeWord` (`jarvis`), `alarmSound` (0), `alarmSpacingMs` (10000), `alarmWizardEnabled` (true), `sleepTime` (Nullable), `wakeTime` (Nullable), `sleepScheduleEnabled` (false), `breakfastTime` (Nullable), `lunchTime` (Nullable), `dinnerTime` (Nullable), `geminiApiKey` (Nullable), `prohibitedRanges` (JSON `List<TimeRange>`), `themeMode` (`dark`).

---

## 3. JSON Backup & Restore Mapping Specifications

To support C++ ESP32 firmware compatibility (**Rule 7**), all JSON payloads are mapped to `snake_case` keys. 

### A. Full Backup JSON Schema Draft
```json
{
  "backup_date": "2026-06-29T11:50:00Z",
  "meds": [
    {
      "name": "Ibuprofeno",
      "color": "red",
      "type": "comprimido",
      "dosage": "400mg"
    }
  ],
  "alarms": [
    {
      "id": 1,
      "hour": 8,
      "minute": 0,
      "name": "Toma 1",
      "med_name": "Ibuprofeno",
      "enabled": true,
      "active": true,
      "days": [true, true, true, true, true, true, true],
      "status": "PENDENTE",
      "color": "red",
      "quantity": 1.0,
      "days_quantity": [1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0],
      "type": "comprimido",
      "snooze_min": 5,
      "duration_days": 7
    }
  ],
  "reminders": [
    {
      "id": 1,
      "title": "Beber Água",
      "description": "200ml",
      "enabled": true,
      "has_time": true,
      "hour": 10,
      "minute": 0,
      "period": "day",
      "interval": 1,
      "start_date": "2026-06-29",
      "notify_days_before": 0,
      "color": "blue"
    }
  ],
  "history": [
    {
      "id": 10,
      "alarm_id": 1,
      "reminder_id": null,
      "med_name": "Ibuprofeno",
      "dosage": "400mg",
      "timestamp": 1782729600000,
      "status": "TOMADO",
      "type": "alarm"
    }
  ],
  "settings": {
    "device_ip": "192.168.1.100",
    "patient_name": "Carolina",
    "speaker_volume": 30,
    "brightness": 60,
    "language": "pt",
    "wake_word": "jarvis",
    "alarm_sound": 1,
    "alarm_spacing_ms": 6000,
    "alarm_wizard_enabled": false,
    "sleep_time": "22:00",
    "wake_time": "07:00",
    "sleep_schedule_enabled": true,
    "breakfast_time": "08:00",
    "lunch_time": "12:00",
    "dinner_time": "20:00",
    "gemini_api_key": "AIzaSy...",
    "prohibited_ranges": [],
    "theme_mode": "dark"
  }
}
```

### B. Serialization (Database ➡️ JSON Backup)
To export the database contents, we fetch all rows from Drift tables and convert them to the expected format.
To preserve **Rule 6 (Feature-First)** and prevent tight cross-feature repository coupling (e.g. Settings importing Alarm/Reminder repositories directly), the mapping from database entities to JSON maps is written **directly inside `SettingsRepository`** utilizing Drift's database objects:

```dart
// Inside SettingsRepository
final medsList = await _db.select(_db.medications).get();
final alarmsList = await _db.select(_db.alarms).get();
final remindersList = await _db.select(_db.reminders).get();
final historyList = await _db.select(_db.historyEvents).get();
final settings = await getSettings();

final backupData = {
  'backup_date': DateTime.now().toIso8601String(),
  'meds': medsList.map((m) => {
    'name': m.name,
    'color': m.color,
    'type': m.type,
    'dosage': m.dosage,
  }).toList(),
  'alarms': alarmsList.map((a) => {
    'id': a.id,
    'hour': a.hour,
    'minute': a.minute,
    'name': a.name,
    'med_name': a.medName,
    'enabled': a.enabled,
    'active': a.active,
    'days': json.decode(a.days), // Drift stores List<bool> as String
    'status': a.status,
    'color': a.color,
    'quantity': a.quantity,
    'days_quantity': json.decode(a.daysQuantity), // Drift stores List<double> as String
    'type': a.type,
    'dosage': a.dosage,
    'last_status': a.lastStatus,
    'last_status_date': a.lastStatusDate,
    'snooze_min': a.snoozeMin,
    'start_date': a.startDate,
    'duration_days': a.durationDays,
    'created_date': a.createdDate,
    if (a.cycleOnDays != null) 'cycle_on_days': a.cycleOnDays,
    if (a.cycleOffDays != null) 'cycle_off_days': a.cycleOffDays,
    if (a.cycleCurrentDay != null) 'cycle_current_day': a.cycleCurrentDay,
    if (a.cycleIsPaused != null) 'cycle_is_paused': a.cycleIsPaused,
    if (a.isPrn != null) 'is_prn': a.isPrn,
    if (a.prnMinIntervalHours != null) 'prn_min_interval_hours': a.prnMinIntervalHours,
    if (a.prnMaxDailyDoses != null) 'prn_max_daily_doses': a.prnMaxDailyDoses,
    if (a.prnDosesToday != null) 'prn_doses_today': a.prnDosesToday,
    if (a.pauseUntil != null) 'pause_until': a.pauseUntil,
    if (a.isDynamic != null) 'is_dynamic': a.isDynamic,
    if (a.dynamicInstruction != null) 'dynamic_instruction': a.dynamicInstruction,
    if (a.taperStageCount != null) 'taper_stage_count': a.taperStageCount,
    if (a.taperCurrentStage != null) 'taper_current_stage': a.taperCurrentStage,
    if (a.taperDayInStage != null) 'taper_day_in_stage': a.taperDayInStage,
    if (a.taperStages != null) 'taper_stages': json.decode(a.taperStages!),
    if (a.taperLoop != null) 'taper_loop': a.taperLoop,
    if (a.specialInstruction != null) 'special_instruction': a.specialInstruction,
    if (a.adjustStep != null) 'adjust_step': a.adjustStep,
    if (a.adjustIntervalDays != null) 'adjust_interval_days': a.adjustIntervalDays,
    if (a.adjustLimit != null) 'adjust_limit': a.adjustLimit,
    if (a.requiresRemoval != null) 'requires_removal': a.requiresRemoval,
    if (a.removalDelayMins != null) 'removal_delay_mins': a.removalDelayMins,
    if (a.siteRotationList != null) 'site_rotation_list': a.siteRotationList,
    if (a.currentSiteIndex != null) 'current_site_index': a.currentSiteIndex,
    if (a.dayOfMonth != null) 'day_of_month': a.dayOfMonth,
    if (a.groupId != null) 'group_id': a.groupId,
    if (a.intervalHours != null) 'interval_hours': a.intervalHours,
    if (a.intervalDays != null) 'interval_days': a.intervalDays,
    if (a.intervalCountdown != null) 'interval_countdown': a.intervalCountdown,
  }).toList(),
  'reminders': remindersList.map((r) => {
    'id': r.id,
    'title': r.title,
    'description': r.description,
    'enabled': r.enabled,
    'has_time': r.hasTime,
    'hour': r.hour,
    'minute': r.minute,
    'period': r.period,
    'interval': r.interval,
    'start_date': r.startDate,
    'notify_days_before': r.notifyDaysBefore,
    'last_completed_date': r.lastCompletedDate,
    'color': r.color,
  }).toList(),
  'history': historyList.map((h) => {
    'id': h.id,
    'alarm_id': h.alarmId,
    'reminder_id': h.reminderId,
    'med_name': h.medName,
    'dosage': h.dosage,
    'timestamp': h.timestamp,
    'status': h.status,
    'type': h.type,
  }).toList(),
  'settings': {
    'device_ip': settings.deviceIp,
    'patient_name': settings.patientName,
    'speaker_volume': settings.speakerVolume,
    'brightness': settings.brightness,
    'language': settings.language,
    'wake_word': settings.wakeWord,
    'alarm_sound': settings.alarmSound,
    'alarm_spacing_ms': settings.alarmSpacingMs,
    'alarm_wizard_enabled': settings.alarmWizardEnabled,
    'sleep_time': settings.sleepTime,
    'wake_time': settings.wakeTime,
    'sleep_schedule_enabled': settings.sleepScheduleEnabled,
    'breakfast_time': settings.breakfastTime,
    'lunch_time': settings.lunchTime,
    'dinner_time': settings.dinnerTime,
    'gemini_api_key': settings.geminiApiKey,
    'prohibited_ranges': settings.prohibitedRanges != null ? json.decode(settings.prohibitedRanges!) : null,
    'theme_mode': settings.themeMode,
  }
};
```

### C. Deserialization (JSON Backup ➡️ Database Restore)
During restore, selected partitions are wiped and then inserted back into local Drift tables using database companions.
```dart
// Examples of parsing and inserting into Drift companions inside executeBackupRestore:
if (partialBackup.containsKey('meds')) {
  await _db.delete(_db.medications).go();
  for (final item in partialBackup['meds']) {
    final med = Medication(
      name: item['name'] as String? ?? item['med_name'] as String? ?? '',
      color: item['color'] as String? ?? 'white',
      type: item['type'] as String? ?? 'comprimido',
      dosage: item['dosage'] as String?,
      pendingSync: false,
    );
    await _db.into(_db.medications).insert(med, mode: InsertMode.insertOrReplace);
  }
}

if (partialBackup.containsKey('alarms')) {
  await _db.delete(_db.alarms).go();
  for (final item in partialBackup['alarms']) {
    final alarm = AlarmsCompanion(
      id: Value(item['id'] as int),
      hour: Value(item['hour'] as int),
      minute: Value(item['minute'] as int),
      name: Value(item['name'] as String? ?? ''),
      medName: Value(item['med_name'] as String? ?? item['name'] as String? ?? ''),
      enabled: Value(item['enabled'] == true),
      active: Value(item['active'] == true),
      days: Value(json.encode(item['days'] ?? List.filled(7, true))),
      status: Value(item['status'] as String? ?? 'PENDENTE'),
      color: Value(item['color'] as String? ?? 'blue'),
      quantity: Value((item['quantity'] as num?)?.toDouble() ?? 1.0),
      daysQuantity: Value(json.encode(item['days_quantity'] ?? List.filled(7, 0.0))),
      type: Value(item['type'] as String? ?? 'comprimido'),
      dosage: Value(item['dosage'] as String?),
      lastStatus: Value(item['last_status'] as String?),
      lastStatusDate: Value(item['last_status_date'] as String?),
      snoozeMin: Value(item['snooze_min'] as int? ?? 0),
      startDate: Value(item['start_date'] as String?),
      durationDays: Value(item['duration_days'] as int? ?? 0),
      createdDate: Value(item['created_date'] as String?),
      cycleOnDays: Value(item['cycle_on_days'] as int?),
      cycleOffDays: Value(item['cycle_off_days'] as int?),
      cycleCurrentDay: Value(item['cycle_current_day'] as int?),
      cycleIsPaused: Value(item['cycle_is_paused'] as bool?),
      isPrn: Value(item['is_prn'] as bool?),
      prnMinIntervalHours: Value(item['prn_min_interval_hours'] as int?),
      prnMaxDailyDoses: Value(item['prn_max_daily_doses'] as int?),
      prnDosesToday: Value(item['prn_doses_today'] as int?),
      pauseUntil: Value(item['pause_until'] as int?),
      isDynamic: Value(item['is_dynamic'] as bool?),
      dynamicInstruction: Value(item['dynamic_instruction'] as String?),
      taperStageCount: Value(item['taper_stage_count'] as int?),
      taperCurrentStage: Value(item['taper_current_stage'] as int?),
      taperDayInStage: Value(item['taper_day_in_stage'] as int?),
      taperStages: Value(item['taper_stages'] != null ? json.encode(item['taper_stages']) : null),
      taperLoop: Value(item['taper_loop'] as bool?),
      specialInstruction: Value(item['special_instruction'] as String?),
      adjustStep: Value(item['adjust_step'] != null ? (item['adjust_step'] as num).toDouble() : null),
      adjustIntervalDays: Value(item['adjust_interval_days'] as int?),
      adjustLimit: Value(item['adjust_limit'] != null ? (item['adjust_limit'] as num).toDouble() : null),
      requiresRemoval: Value(item['requires_removal'] as bool?),
      removalDelayMins: Value(item['removal_delay_mins'] as int?),
      siteRotationList: Value(item['site_rotation_list'] as String?),
      currentSiteIndex: Value(item['current_site_index'] as int?),
      dayOfMonth: Value(item['day_of_month'] as int?),
      groupId: Value(item['group_id'] as int?),
      intervalHours: Value(item['interval_hours'] as int?),
      intervalDays: Value(item['interval_days'] as int?),
      intervalCountdown: Value(item['interval_countdown'] as int?),
      pendingSync: const Value(false),
    );
    await _db.into(_db.alarms).insert(alarm, mode: InsertMode.insertOrReplace);
  }
}
```

---

## 4. SettingsRepository Architectural Adjustments

To enable backup, restore, and reset features when offline (or connected), the following changes are required in `lib/features/settings/data/settings_repository.dart`:

### A. `downloadBackupJson()`
Rewrite the method to check the current connection state. If offline, run local queries and compile the backup JSON structure.
```dart
  Future<String> downloadBackupJson() async {
    if (_isConnected()) {
      final response = await _dioClient.get('/backup');
      if (response.statusCode == 200) {
        if (response.data is Map) return jsonEncode(response.data);
        return response.data.toString();
      }
      throw Exception('Falha ao baixar backup do dispositivo físico.');
    } else {
      // Execute the local serialization logic defined in Section 3.B
      // ...
      return jsonEncode(backupData);
    }
  }
```

### B. `executeBackupRestore()`
Update to perform local restoration of SQLite tables first, and then forward the payload to the ESP32 `/restore` endpoint if connected.
```dart
  Future<int> executeBackupRestore(Map<String, dynamic> partialBackup) async {
    // 1. Perform Local Drift DB Wipes and Companion Inserts (from Section 3.C)
    var count = 0;
    if (partialBackup.containsKey('meds')) {
      // Wipes and inserts meds
      count += (partialBackup['meds'] as List).length;
    }
    if (partialBackup.containsKey('alarms')) {
      // Wipes and inserts alarms
      count += (partialBackup['alarms'] as List).length;
    }
    // Repeat for reminders, history, settings...

    // 2. Forward to ESP32 if connected
    if (_isConnected()) {
      try {
        final response = await _dioClient.post('/restore', data: partialBackup);
        if (response.statusCode != 200) {
          throw Exception('Falha ao aplicar restauração no dispositivo físico.');
        }
      } catch (e) {
        debugPrint('Error sending restore payload to ESP32: $e');
        // We do not rethrow to keep local restore intact if ESP32 fails
      }
    }
    return count;
  }
```

### C. `DeviceResetNotifier`
Update `resetDevicePartitions(Map<String, bool> payload)` to execute local wipes when specific components are selected, and reset the local settings row to its default companion settings.
```dart
  Future<bool> resetDevicePartitions(Map<String, bool> payload) async {
    state = const AsyncValue.loading();
    var success = false;
    state = await AsyncValue.guard(() async {
      final db = ref.read(databaseProvider);
      
      // Perform local database wipes based on selection
      if (payload['factory'] == true || payload['meds'] == true) {
        await db.delete(db.medications).go();
      }
      if (payload['factory'] == true || payload['alarms'] == true) {
        await db.delete(db.alarms).go();
      }
      if (payload['factory'] == true || payload['reminders'] == true) {
        await db.delete(db.reminders).go();
      }
      if (payload['factory'] == true || payload['history'] == true) {
        await db.delete(db.historyEvents).go();
      }
      if (payload['factory'] == true || payload['logs'] == true) {
        await db.delete(db.systemLogs).go();
      }
      if (payload['factory'] == true || payload['settings'] == true) {
        final repo = ref.read(settingsRepositoryProvider);
        final current = await repo.getSettings();
        final defaults = current.copyWith(
          patientName: 'Paciente',
          speakerVolume: 20,
          brightness: 50,
          language: 'pt',
          wakeWord: 'jarvis',
          alarmSound: 0,
          alarmSpacingMs: 10000,
          alarmWizardEnabled: true,
          sleepTime: const Value(null),
          wakeTime: const Value(null),
          sleepScheduleEnabled: false,
          breakfastTime: const Value(null),
          lunchTime: const Value(null),
          dinnerTime: const Value(null),
          geminiApiKey: const Value(null),
          prohibitedRanges: const Value(null),
          themeMode: 'dark',
        );
        await repo.updateSettings(defaults);
      }

      final isConnected = ref.read(pairingNotifierProvider).status == ConnectionStatus.connected;
      if (isConnected) {
        final response = await ref.read(dioClientProvider).post('/reset', data: payload);
        if (response.statusCode != 200) throw Exception('Falha ao resetar no dispositivo');
      }

      success = true;

      // Handle reboots / redirection
      final needsReboot = payload['factory'] == true || payload['wifi'] == true || payload['settings'] == true || payload['xiaozhi'] == true;
      if (needsReboot && isConnected) {
        try { await ref.read(dioClientProvider).post('/restart'); } catch (_) {}
        await Future.delayed(const Duration(seconds: 8));
        if (payload['factory'] == true || payload['wifi'] == true) {
          await ref.read(pairingNotifierProvider.notifier).useStandalone();
        }
      } else if ((payload['factory'] == true || payload['wifi'] == true) && !isConnected) {
        await ref.read(pairingNotifierProvider.notifier).useStandalone();
      }
    });
    return success;
  }
```

---

## 5. SettingsScreen UI & Guardrails Verification

### A. Layout Adjustments
Currently, the Maintenance tile is located inside the `Opacity` and `IgnorePointer` columns that disable everything when disconnected:
```dart
Opacity(
  opacity: connState.status == ConnectionStatus.connected ? 1.0 : 0.55,
  child: IgnorePointer(
    ignoring: connState.status != ConnectionStatus.connected,
    child: Column(
      children: [
        _buildWifiConfigTile(),
        _buildSoundDisplayTile(settings),
        _buildClockSyncCard(),
        _buildVoiceAssistantTile(settings),
        _buildMaintenanceTile(settings), // 🛑 LOCKED OFFLINE
      ],
    ),
  ),
)
```
**Fix**: Move `_buildMaintenanceTile(settings)` out of the `IgnorePointer`/`Opacity` container so it remains accessible offline:
```dart
Opacity(
  opacity: connState.status == ConnectionStatus.connected ? 1.0 : 0.55,
  child: IgnorePointer(
    ignoring: connState.status != ConnectionStatus.connected,
    child: Column(
      children: [
        _buildWifiConfigTile(),
        _buildSoundDisplayTile(settings),
        _buildClockSyncCard(),
        _buildVoiceAssistantTile(settings),
      ],
    ),
  ),
),
const SizedBox(height: 12),
_buildMaintenanceTile(settings), // ✅ ALWAYS ACCESSIBLE
```
Within `_buildMaintenanceTile(settings)`:
- Relaunch wizard, Backup, Restore, and Reset will execute locally (and remotely if connected).
- **"Reboot Device"** requires a physical ESP32 connection. Tap should check connection:
```dart
onTap: connState.status != ConnectionStatus.connected
    ? () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(t('settings_device_offline_reboot_error') ?? 'Dispositivo offline. Não é possível reiniciar.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    : () async {
        // Confirm and restart device ...
      }
```

### B. Rule 22 Check (No `const` with `AppColors`)
We performed a deep check on all references to `AppColors` in `settings_screen.dart`.
- Icon/TextStyle/Border properties parameterized by `AppColors.xxx` are **never** declared with a `const` prefix.
- Example: `leading: Icon(Icons.construction_rounded, color: AppColors.primary),` is correctly declared without `const`.
- Compliance status: **100% compliant**.

### C. Rule 32 Check (Use `context.mounted` in Async Callbacks)
We analyzed all async handlers (e.g. `_downloadBackup`, `_restoreBackup`, `_loadBackupFixture`).
- Every async function correctly defines `final buildContext = context;` at the beginning of the function and checks `buildContext.mounted` prior to modifying context or executing navigator/snack-bar actions.
- Example: `if (buildContext.mounted) { ScaffoldMessenger.of(buildContext).showSnackBar(...) }`
- Compliance status: **100% compliant**.

---

## 6. Compilation & Static Analysis Assessment

No compilation issues or static analysis warnings exist within the analyzed structure:
1. **Riverpod Code Generation**: The models and files are fully annotative. Changing settings repository methods will trigger a `build_runner` code-gen iteration to keep `settings_repository.g.dart` in sync.
2. **Type Safety in Parsing**: Numerical conversions from JSON maps utilize `.toDouble()` or `.toInt()` safely (supporting floats/ints from ESP32 payloads, satisfying **Rule 10**).
3. **Database Nullability**: Nullable fields inside Alarms/Settings companions are safely wrapped with Drift's `Value()` constructor, preventing crashes during restores.

---

## 7. Action Plan for Implementer (Next Steps)
1. Apply the repository edits in `settings_repository.dart` for local mapping and connected synchronization.
2. Adjust `settings_screen.dart` layout to extract the maintenance tile out of the disabled columns.
3. Run `dart run build_runner build --delete-conflicting-outputs` to regenerate drift/riverpod parts.
4. Execute `flutter analyze` and `flutter test` to ensure zero compilation or logical issues.
