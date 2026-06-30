# Handoff Report: Local Alarm Settings Investigation

---

## 1. Observation

We performed search and view actions on the codebase and observed the following:

- **Drift Schema Location**: `lib/core/database/database.dart`
  - Current settings schema (lines 101-124):
    ```dart
    class Settings extends Table {
      IntColumn get id => integer().withDefault(const Constant(1))();
      TextColumn get deviceIp => text().nullable()();
      TextColumn get patientName => text().withDefault(const Constant('Paciente'))();
      IntColumn get speakerVolume => integer().withDefault(const Constant(20))();
      IntColumn get brightness => integer().withDefault(const Constant(50))();
      TextColumn get language => text().withDefault(const Constant('pt'))();
      TextColumn get wakeWord => text().withDefault(const Constant('jarvis'))();
      IntColumn get alarmSound => integer().withDefault(const Constant(0))();
      IntColumn get alarmSpacingMs => integer().withDefault(const Constant(10000))();
      BoolColumn get alarmWizardEnabled => boolean().withDefault(const Constant(true))();
      TextColumn get sleepTime => text().nullable()();
      TextColumn get wakeTime => text().nullable()();
      BoolColumn get sleepScheduleEnabled => boolean().withDefault(const Constant(false))();
      TextColumn get breakfastTime => text().nullable()();
      TextColumn get lunchTime => text().nullable()();
      TextColumn get dinnerTime => text().nullable()();
      TextColumn get geminiApiKey => text().nullable()();
      TextColumn get prohibitedRanges => text().nullable()(); // JSON serialized List<TimeRange>
      TextColumn get themeMode => text().withDefault(const Constant('dark'))();

      @override
      Set<Column> get primaryKey => {id};
    }
    ```
  - Drift schema version is `5` and `onUpgrade` handles migrations (lines 166-187):
    ```dart
      @override
      int get schemaVersion => 5;

      @override
      MigrationStrategy get migration => MigrationStrategy(
            onUpgrade: (migrator, from, to) async {
              ...
              if (from < 5) {
                await migrator.addColumn(settings, settings.themeMode);
              }
            },
          );
    ```

- **Settings Screen Layout**: `lib/features/settings/presentation/settings_screen.dart`
  - Utilizes `AppColors` fields for styling which are subject to dynamic theme switches (e.g. lines 87-90: `AppColors.primary`, `AppColors.surface`, `AppColors.text`).
  - Contains sections such as profile creation, sleep schedules, language selections, and maintenance tools.
  
- **Notification Services**: `lib/core/services/notification_service.dart`
  - Schedules local notifications using OS channel parameters (lines 110-228) and handles sound mapping based on OS constraints.

- **Active Alarm Overlay**: `lib/features/alarms/presentation/alarm_active_screen.dart`
  - Instantiates `AudioPlayer` (lines 33-36) and loads `AssetSource('sounds/alarm_beep.wav')`.
  - Has haptic fallback `_triggerPeriodicVibration` (lines 111-128).

- **Audio Asset Files**:
  - Found exactly one file `alarm_beep.wav` at `assets/sounds/alarm_beep.wav` (with matching platform resources in `android/app/src/main/res/raw/alarm_beep.wav`, `ios/Runner/alarm_beep.wav`, and `macos/Runner/alarm_beep.wav`).

---

## 2. Logic Chain

1. **Drift Database Modification**:
   - To persist local configuration options, the schema must store them permanently.
   - We must append `localAlarmSound`, `localAlarmVolume`, `localVibrationEnabled`, and `localAlarmDurationMins` in the `Settings` table, increase the schema version to `6`, and add appropriate column updates in `onUpgrade` to support clean database migration.
   - Default fallback Companions in `SettingsRepository` must incorporate these properties to prevent null pointer exceptions when settings records are read or reset.

2. **Settings Screen Design**:
   - The user requires custom Dropdowns, Sliders, and Switches.
   - To respect the project rules, we must avoid declaring widget wrappers (such as `Icon` or `TextStyle`) as `const` if they use the non-final dynamic properties of `AppColors`.
   - Post-asynchronous operations must check lifecycle validity using `context.mounted` before resetting test audio status.
   - Layout parameters must use flexible heights (such as `SingleChildScrollView` and `Card` margins) rather than hardcoded sizing to support macOS/Desktop and mobile devices correctly.

3. **Test Button Mechanics**:
   - Storing a localized `AudioPlayer` instance in the screen's mutable state allows developers to control playback (play, stop) cleanly.
   - Subscribing to `onPlayerComplete` automatically toggles the test button state back to inactive when playback finishes.

4. **Integration with NotificationService & AlarmActiveScreen**:
   - Local OS-level notifications should inherit settings attributes. By querying the settings table reactively or within `AlarmEngine`, the sound parameter can be supplied to `scheduleWeeklyAlarm`. Note that Android requires recreation of the Notification Channel or a new Channel ID version to update immutable sound/vibration attributes.
   - `AlarmActiveScreen` must read settings from the database during initialization, apply the configured volume level (scaled to 0.0 - 1.0) on the player, respect the vibration switch boolean, and initialize a `Timer` instance corresponding to the time limit, automatically triggering `_markSkipped` on timeout.

---

## 3. Caveats

- **Android Notification Channels**: Once created, notification channel parameters (sound, vibration, importance) are locked by the OS. We recommended incrementing the channel ID (e.g., `medicaixa_alarms_channel_v6`) to force updates when the user modifies these preferences.
- **Audio Files**: The only audio asset currently packaged in the app bundle is `alarm_beep.wav`. Adding options to the sound dropdown requires packaging new audio files into the assets directory and declaring them in `pubspec.yaml`.

---

## 4. Conclusion

The application possesses all the necessary architectural components (Drift Database, Riverpod Notifiers, Audioplayers, Local Notifications) to implement local alarm configuration settings. The recommendation outlined in `analysis.md` provides a direct, rule-compliant path for implementation.

---

## 5. Verification Method

To verify the suggested implementation:
1. Run Drift code generation to verify that compile-time mapping holds:
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```
2. Verify visual appearance and layout:
   - Check dark/light mode switches.
   - Ensure console outputs do not throw formatting or layout constraints warnings (such as viewport overflow).
3. Run test suites to ensure standard functionality remains intact:
   ```bash
   flutter test
   ```
