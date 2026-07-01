# Investigation Report: Alarm Deletion, History, and Ghost Alarms

## Executive Summary
This report analyzes the structure of alarm deletion, history tracking, and the concept of "Ghost Alarms" in both the reference C++ project (firmware & Web UI) and the current Dart/Flutter codebase. The Flutter project replicates this logic to provide a consistent offline-first experience, rendering past alarm states even if the parent alarm configuration has been deleted.

---

## 1. C++ Project Investigation Findings

### 1.1. Web Interface (`index.html`)

#### Alarm Deletion
- **Individual Deletion**: Located in `index.html` at line 8243, a single alarm is deleted by making a POST request to `/remove` with the index of the alarm:
  ```javascript
  function remove(i) { 
    if (confirm('Tem certeza?')) { 
      fetch('/remove', { method: 'POST', body: JSON.stringify({ index: i }) })
        .then(() => loadAlarms()); 
    } 
  }
  ```
- **Group Deletion**: Located in `index.html` at line 7881, group deletion prompts the user, sorts the alarm group indices in descending order (to avoid invalidating prior indices), and sends sequential POST requests to `/remove` for each index:
  ```javascript
  function deleteAlarmGroup(groupId) {
    const group = getGroupAlarms(groupId);
    if (group.length === 0) return;
    const msg = (t('group_delete_confirm') || 'Excluir todos os %d alarmes deste grupo?').replace('%d', group.length);
    if (!confirm(msg)) return;
    const sorted = group.sort((a, b) => b.originalIndex - a.originalIndex);
    let chain = Promise.resolve();
    sorted.forEach(a => {
      chain = chain.then(() =>
        fetch('/remove', { method: 'POST', body: JSON.stringify({ index: a.originalIndex }) }).then(r => r.text())
      );
    });
    chain.then(() => { lastAlarmData = null; loadAlarms(); loadMeds(); });
  }
  ```

#### Ghost Alarm Logic & History Loading
- When rendering past calendar dates (`if (!isToday)`), the web interface requests historical data via `/history?t=...` (mapped to `/littlefs/data/history.json` on the ESP32 filesystem) at line 6985:
  ```javascript
  // For non-today days, use history to determine status + ghost alarms
  if (!isToday) {
    const calDateISO = selectedCalDate || getLocalDateStr(filterDate);
    filtered.forEach(x => {
      const logStatus = getLogStatusForAlarm(x, calDateISO);
      x._calStatus = logStatus;
    });

    // Ghost alarms: history entries that do not correspond to any current alarm ID
    const histEntries = getHistoryEntriesForDate(calDateISO);
    const currentIds = new Set(filtered.map(x => x.id).filter(id => typeof id === 'number'));
    const ghostMap = new Map(); // id -> first entry (most recent)
    histEntries.forEach(e => {
      if (!currentIds.has(e.id) && !ghostMap.has(e.id)) {
        ghostMap.set(e.id, e);
      }
    });
    ghostMap.forEach((entry, ghostId) => {
      const ev = entry.event;
      let status = null;
      if (ev === 'Tomado' || ev === 'Tomado via Web UI' || ev === 'Tomado fora hora') status = 'Tomado';
      else if (ev === 'Não Tomado') status = 'Não Tomado';
      else if (ev === 'Cancelado') status = 'Cancelado';
      filtered.push({
        id: ghostId,
        name: entry.details || '?',
        hour: entry.h != null ? entry.h : 0,
        minute: entry.m != null ? entry.m : 0,
        color: entry.color || 'gray',
        dosage: entry.dosage || '',
        type: entry.type || 'comprimido',
        quantity: entry.qty || 1,
        active: true,
        _calStatus: status,
        _ghost: true,
        originalIndex: -1
      });
    });
  }
  ```

#### Ghost Alarm Rendering (CSS & HTML)
- Under `index.html` line 407, the CSS class `.pill-card.ghost` is styled to appear visual-inactive:
  ```css
  .pill-card.ghost {
    background: #0a0a0f;
    border-left-style: dashed;
    opacity: 0.6;
  }
  .pill-card.ghost .pill-med-name {
    text-decoration: line-through;
    text-decoration-color: rgba(255, 255, 255, 0.25);
  }
  .pill-card.ghost .pill-icon {
    opacity: 0.4;
  }
  ```
- During rendering (line 7408):
  - It shows the status badge as `"Removido"` (`badge-inactive`) unless it was taken or missed on that date.
  - Frequency text is displayed as `"Removido"`.
  - Clicks are disabled (no `onclick` attribute is generated).

---

### 1.2. Firmware Components (`components/`)

#### Web Server Endpoint
- In `web_server.cpp` at line 1147, `web_handle_remove_alarm` captures the index of the alarm to delete, maps it to an alarm ID, and calls `ctx->alarm_mgr->remove_alarm(alarm_id)`:
  ```cpp
  uint8_t alarm_id = ctx->alarm_mgr->get_all_alarms()[idx].id;
  ...
  esp_err_t ret = ctx->alarm_mgr->remove_alarm(alarm_id);
  ```

#### Alarm Manager Deletion & History Log
- In `alarm_manager.cpp` at line 1264, the alarm is completely deleted from the in-memory array `m_alarms` and persistent configuration:
  ```cpp
  esp_err_t AlarmManager::remove_alarm(uint8_t alarm_id) {
      for (size_t i = 0; i < m_count; i++) {
          if (m_alarms[i].id == alarm_id) {
              for (size_t j = i; j < m_count - 1; j++) {
                  m_alarms[j] = m_alarms[j + 1];
              }
              m_count--;
              memset(&m_alarms[m_count], 0, sizeof(Alarm));
              save_alarms();
              return ESP_OK;
          }
      }
      return ESP_ERR_NOT_FOUND;
  }
  ```
- **Historical Event Enrichment**: In `alarm_manager.cpp` at line 1679, when an alarm event (taken, missed, etc.) is logged via `log_history`, the firmware appends a rich entry to `history.json` storing the state configuration of the alarm at the moment of the event:
  ```cpp
  cJSON_AddStringToObject(entry, "date", date_str); // DD/MM/YYYY
  cJSON_AddStringToObject(entry, "time", time_str);
  cJSON_AddStringToObject(entry, "event", event);
  cJSON_AddStringToObject(entry, "details", alarm.name); // medName
  cJSON_AddNumberToObject(entry, "id", alarm.id);
  cJSON_AddNumberToObject(entry, "h", alarm.hour);
  cJSON_AddNumberToObject(entry, "m", alarm.minute);
  cJSON_AddStringToObject(entry, "color", alarm.color);
  cJSON_AddStringToObject(entry, "dosage", alarm.dosage);
  cJSON_AddStringToObject(entry, "type", alarm.med_type);
  cJSON_AddNumberToObject(entry, "qty", logged_qty);
  ```

---

## 2. Dart/Flutter Project Investigation Findings

### 2.1. Database Schema (`database.dart`)
- **Table `HistoryEvents`**:
  ```dart
  class HistoryEvents extends Table {
    IntColumn get id => integer().autoIncrement()();
    IntColumn get alarmId => integer().nullable()();
    IntColumn get reminderId => integer().nullable()();
    TextColumn get medName => text().nullable()();
    TextColumn get dosage => text().nullable()();
    IntColumn get timestamp => integer()();
    TextColumn get status => text()(); // TOMADO, PERDIDO, SNOOZED, CONCLUIDO
    TextColumn get type => text()(); // alarm, reminder, system
    BoolColumn get pendingSync => boolean().withDefault(const Constant(false))();
  }
  ```
- **Analysis**:
  - The local database does not enforce cascade deletion on `alarmId`. Deleting an alarm from the `Alarms` table keeps historical entries in the `HistoryEvents` table intact.
  - However, unlike the C++ project, the `HistoryEvents` table does **not** persist metadata such as the alarm's hour, minute, color, type, or quantity.
  - As a result, when recreating ghost alarms from a deleted alarm, the app has to look up original alarm details in the remaining active alarms, or fall back to defaults (e.g., using the event's timestamp hour/minute, grey color, standard dosage).

### 2.2. Alarm Repository (`alarm_repository.dart`)
- **Deletion**:
  - `deleteAlarm` (line 351) removes the alarm from the local Drift DB and calls `/remove` on the ESP32 if connected:
    ```dart
    Future<void> deleteAlarm(int id) async {
      if (_isConnected()) {
        try {
          await _apiClient.removeAlarm(id);
        } catch (e) {
          debugPrint('Error removing alarm on ESP32: $e');
        }
      }
      await (_db.delete(_db.alarms)..where((t) => t.id.equals(id))).go();
    }
    ```

### 2.3. Dashboard Notifier (`dashboard_notifier.dart`)
- **Loading Data**:
  - Located in `_updateData` (line 141), active alarms for the selected date are filtered using `_isAlarmActiveOnDate`.
  - For past dates (`targetZero.isBefore(todayZero)`), it fetches historical log events for that date.
  - For active alarms on that day, status is updated using historical log events.
  - **In-Memory Ghost Alarm Reconstruction**:
    - Lines 191-232: It iterates through `dateEvents` (alarm log events for the selected past date).
    - If a log event exists for an alarm that does not exist in `filteredAlarms` (either because the alarm was deleted or its schedule is different), it attempts to reconstruct the alarm.
    - It searches `allAlarms` for metadata by ID or medicine name. If not found, it falls back to defaults.
    ```dart
    // Look up original alarm for metadata fallback
    AlarmModel? orig;
    for (final a in allAlarms) {
      if (a.id == e.alarmId || a.medName == e.medName || a.name == e.medName) {
        orig = a;
        break;
      }
    }
    final ghostAlarm = AlarmModel(
      id: e.alarmId!,
      hour: orig?.hour ?? dt.hour,
      minute: orig?.minute ?? dt.minute,
      name: e.medName ?? orig?.name ?? '',
      medName: e.medName ?? orig?.medName ?? '',
      enabled: false,
      active: false,
      days: orig?.days ?? List.filled(7, true),
      status: isTaken ? 'TOMADO' : 'PENDENTE',
      color: orig?.color ?? 'grey',
      quantity: orig?.quantity ?? 1.0,
      daysQuantity: orig?.daysQuantity ?? List.filled(7, 0.0),
      type: orig?.type ?? 'comprimido',
      dosage: e.dosage ?? orig?.dosage,
      lastStatus: isTaken ? 'Tomado' : (isMissed ? 'Não Tomado' : ''),
      lastStatusDate: dateFormatted,
      snoozeMin: 0,
      durationDays: 0,
      isGhost: true, // Marked as ghost
    );
    filteredAlarms.add(ghostAlarm);
    ```

### 2.4. Alarm Card Widget (`alarm_card_widget.dart`)
- **Rendering & Interaction**:
  - Opacity: If `alarm.isGhost` is true, opacity is reduced to `0.55` (line 101).
  - Borders & Icons: If `alarm.isGhost` is true, the primary color fallback is `Colors.grey` (line 32) and the pill icon background is `Colors.grey.withValues(alpha: 0.2)` (line 108).
  - Badge: Displays "Excluído" (translated from `t('badge_deleted')`) in dark grey/light grey text (line 50-52).
  - Clicks: Click actions are disabled because in `dashboard_screen.dart` (line 610) the tap action is passed as null:
    ```dart
    onTap: (alarm.isPrn == true || alarm.isGhost == true) ? null : () => _openSnoozeModal(context, ref, alarm),
    ```

### 2.5. Calendar Strip Widget (`calendar_strip_widget.dart`)
- **Dot Calculations**:
  - Lines 157-190 calculate `hasRecurring`, `hasDated`, and `hasReminder` for each date in the strip.
  - The notifier feeds `state.allAlarms` and `state.allReminders` (unfiltered, full database lists) into `_calculateItems`.
  - This ensures dots correctly reflect scheduled configuration regardless of selected date and prevents selected day dot replication.
  - Ghost alarms do not have dots rendered since they are not in the main database anymore, matching C++ behavior.

---

## 3. Technical Strategy and Recommendations

### 3.1. What happens when an alarm is deleted
1. **No History**: If an alarm has no entries in `HistoryEvents`, deleting it from the `Alarms` table removes it completely.
2. **With History**: The database maintains history entries because `HistoryEvents.alarmId` is nullable and has no foreign key constraint. The alarm record is still removed from the `Alarms` table, but its memory persists through the historical event logs.
3. **Firmware Synchronization**: In both cases, the repository instructs the ESP32 to drop the alarm config index via HTTP `/remove`.

### 3.2. Ghost Alarm Reconstruction
When navigating to a past date:
1. Load all history events for that day.
2. Compare the `alarmId` of history events against the set of alarms returned for that day by the scheduler.
3. For any history event whose `alarmId` is not present, instantiate a temporary in-memory `AlarmModel` with `isGhost: true`.
4. *Recommendation for enhanced accuracy*: Since the Drift `HistoryEvents` schema lacks metadata (`color`, `type`, `hour`, `minute`, `qty`), the notifier looks up active alarms for matching medicine name `e.medName` as a fallback. 
5. *Future refinement*: If database migration is possible, we should expand the local `HistoryEvents` schema to record `hour`, `minute`, `color`, `type`, and `quantity` at the time of insertion, mirroring the C++ `history.json` event log serialization.

### 3.3. UI Rendering for Ghost Alarm
- The widget tree handles rendering through `AlarmCardWidget` and `dashboard_screen.dart`:
  - Set `onTap` to `null` to disable clicks.
  - Draw border and icon in `Colors.grey`.
  - Set card overall opacity to `0.55` (`Opacity` widget).
  - Display the "Excluído" badge.
  - Display the frequency text as "Removido" (via `t('badge_deleted')` / `t('alarm_removed')`).

### 3.4. Compliance Checklist (AGENTS.md Rules)
- **Rule 12 (IDs)**: Ghost alarms preserve their original `alarmId` in memory since they represent past real events. Any temporary offline alarms must be > 255.
- **Rule 31 (Multiple Alarms)**: Custom multi-time alarm groups are deleted individually from back to front, avoiding shifting indices.
- **Rule 35 (Medication deletion)**: Medications referenced in active alarms are protected against deletion.
- **Rule 47 (Ghost Alarms)**: Recreated with `isGhost: true`, styled with grey borders/icons, opacity `0.55`, "Excluído" badge, and clicks disabled.
- **Rule 49 (Dated vs Recorrentes)**: Classify as dated only if `startDate != null` and `durationDays > 0`. Recurrent if `durationDays == 0`.
- **Rule 50 (Calendar Dots)**: CalendarStrip calculations use `state.allAlarms` and `state.allReminders` to avoid replication bugs.
- **Rule 66 (Clear status for future/past)**: Prior day statuses are cleared on today's view, and future statuses are always empty (Pendente).

---

## 4. Caveats & Uninvestigated Areas
- **Firmware logs limits**: The C++ project limits the event logs array to 500 entries (and 50 system logs). The local Drift DB in Flutter has no automatic truncation mechanism, which means it will retain history events indefinitely unless explicitly cleared by a user setting.
- **Isolate for heavy JSON processing**: Processing large backup files or historical logs lists might trigger frame drops. As per Rule 4, CPU-heavy tasks should run in a dedicated Isolate.

---

## 5. Verification Method
- Execute: `flutter test` to verify current widget tests and ensure they pass.
- Verify in-app:
  1. Add an alarm, mark it taken on a past date.
  2. Delete the alarm.
  3. Re-navigate to the past date and verify that a card for the deleted alarm appears with a gray border/icon, low opacity, "Excluído" badge, and is non-clickable.
