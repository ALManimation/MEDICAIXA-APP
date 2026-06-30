# Local Alarm Settings Analysis & Recommendation Report

## Executive Summary
This report analyzes the Drift database schema, settings interface, notification service, and active alarm screen in the `medicaixa_app` codebase. We provide a detailed recommendation on how to add local alarm settings (`localAlarmSound`, `localAlarmVolume`, `localVibrationEnabled`, and `localAlarmDurationMins`) to allow users to control alarm behavior directly on their companion app (independent of the physical MediCaixa dispenser box).

---

## 1. Codebase Locations Identified

### 1.1 Drift Database Schema (`lib/core/database/database.dart`)
- **Table Definition**: The `Settings` table is defined as a Drift Table (lines 101-124).
- **Schema Management**: The current `schemaVersion` is 5.
- **Settings Class**: Drift automatically generates the data class `Setting` and a companion class `SettingsCompanion` in `database.g.dart`.
- **Database Connection**: Configured for iOS/macOS via sync `NativeDatabase` connection on the main thread (lines 188-197), satisfying Rule 59.

### 1.2 Settings UI (`lib/features/settings/presentation/settings_screen.dart`)
- **State & Repository**: The screen uses `watchSettingsProvider` to observe settings dynamically, and performs updates through the `SettingsRepository` (via `settingsRepositoryProvider`).
- **Controller/Notifier**: Audio test and sound saving use `soundSettingsActionProvider` (defined at the bottom of `settings_repository.dart`) which runs asynchronously via `SoundSettingsAction`.
- **Theme/Localization**: Utilizes `appLocaleProvider` and `appThemeNotifierProvider` with translation labels via `t(...)`.

### 1.3 Notification Service (`lib/core/services/notification_service.dart`)
- **Mechanism**: Implements a singleton `NotificationService` wrapper around the `flutter_local_notifications` plugin.
- **Scheduling**: The method `scheduleWeeklyAlarm()` configures platform-specific details (`AndroidNotificationDetails`, `DarwinNotificationDetails` for iOS/macOS) and schedules them using timezone-aware dates.
- **Audio Context**: Provides `configureAudioSessionForPlayback()` to route audio appropriately on Apple devices.

### 1.4 Active Alarm Screen (`lib/features/alarms/presentation/alarm_active_screen.dart`)
- **State**: A consumer stateful widget `AlarmActiveScreen` displaying full screen active alarms.
- **Sound Playback**: A local `AudioPlayer` is used to play the alarm audio in a loop. It currently plays the local asset `sounds/alarm_beep.wav` with a remote URL fallback (lines 75-103).
- **Vibration & Haptic**: Contains a fallback vibration loop using `HapticFeedback.vibrate()` and `SystemSound.play()` in `_triggerPeriodicVibration()` (lines 111-128).

### 1.5 Audio Resource Exploration
Using filesystem search, only **one** audio file was identified in the workspace:
- **Path**: `assets/sounds/alarm_beep.wav`
- **Native Raw resources**:
  - Android: `android/app/src/main/res/raw/alarm_beep.wav`
  - iOS: `ios/Runner/alarm_beep.wav`
  - macOS: `macos/Runner/alarm_beep.wav`

---

## 2. Recommendations for Schema Upgrades

To add the local settings, we must update the Drift database definition and handle migration gracefully from Version 5 to 6.

### 2.1 Schema Definition Modifications
In `lib/core/database/database.dart`, append the four columns to the `Settings` table:

```dart
class Settings extends Table {
  // ... existing columns

  // New local alarm settings
  TextColumn get localAlarmSound => text().withDefault(const Constant('alarm_beep'))();
  IntColumn get localAlarmVolume => integer().withDefault(const Constant(80))();
  BoolColumn get localVibrationEnabled => boolean().withDefault(const Constant(true))();
  IntColumn get localAlarmDurationMins => integer().withDefault(const Constant(5))();

  @override
  Set<Column> get primaryKey => {id};
}
```

### 2.2 Migration Logic in `AppDatabase`
Update `schemaVersion` to `6` and add the columns in the migration strategy:

```dart
  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (migrator, from, to) async {
          if (from < 2) {
            await migrator.createTable(historyEvents);
            await migrator.createTable(systemLogs);
          }
          if (from < 3) {
            await migrator.createTable(medications);
          }
          if (from < 4) {
            await migrator.addColumn(alarms, alarms.intervalDays);
            await migrator.addColumn(alarms, alarms.intervalCountdown);
          }
          if (from < 5) {
            await migrator.addColumn(settings, settings.themeMode);
          }
          if (from < 6) {
            await migrator.addColumn(settings, settings.localAlarmSound);
            await migrator.addColumn(settings, settings.localAlarmVolume);
            await migrator.addColumn(settings, settings.localVibrationEnabled);
            await migrator.addColumn(settings, settings.localAlarmDurationMins);
          }
        },
      );
```

### 2.3 Repository Updates (`settings_repository.dart`)
1. **Default Values during table creation**:
   In `SettingsRepository.getSettings()`:
   ```dart
   const defaultSettings = SettingsCompanion(
     id: Value(1),
     patientName: Value('Paciente'),
     speakerVolume: Value(20),
     brightness: Value(50),
     language: Value('pt'),
     wakeWord: Value('jarvis'),
     alarmSound: Value(0),
     alarmSpacingMs: Value(10000),
     alarmWizardEnabled: Value(true),
     themeMode: Value('dark'),
     localAlarmSound: Value('alarm_beep'),
     localAlarmVolume: Value(80),
     localVibrationEnabled: Value(true),
     localAlarmDurationMins: Value(5),
   );
   ```

2. **Backup & Restore Operations**:
   - In `downloadBackupJson()`:
     ```dart
     'settings': {
       // ... existing settings fields
       'local_alarm_sound': settings.localAlarmSound,
       'local_alarm_volume': settings.localAlarmVolume,
       'local_vibration_enabled': settings.localVibrationEnabled,
       'local_alarm_duration_mins': settings.localAlarmDurationMins,
     }
     ```
   - In `executeBackupRestore()`:
     ```dart
     final setting = SettingsCompanion(
       id: const Value(1),
       // ... existing settings fields
       localAlarmSound: Value(item['local_alarm_sound'] as String? ?? 'alarm_beep'),
       localAlarmVolume: Value((item['local_alarm_volume'] as num?)?.toInt() ?? 80),
       localVibrationEnabled: Value(item['local_vibration_enabled'] == true),
       localAlarmDurationMins: Value((item['local_alarm_duration_mins'] as num?)?.toInt() ?? 5),
     );
     ```

3. **Compilation Command**:
   Run the code generator to update Drift output files:
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```

---

## 3. SettingsScreen UI Recommendations

To maintain UX standards and conform strictly to rules, the UI controls should reside under a new card/section labeled **"Ajustes Locais de Alarme"** in the **"AJUSTES LOCAIS"** area of `SettingsScreen`.

### 3.1 Strict Rule Compliance
- **Rule 22 (No `const` with `AppColors`)**: Do NOT write `const` on any widgets referencing `AppColors` (e.g. `TextStyle(color: AppColors.text)`, `activeColor: AppColors.primary`).
- **Rule 32 (`context.mounted`)**: Verify context safety in any asynchronous operation (such as loading sound or showing SnackBars) using `context.mounted`.
- **Rule 17 (Responsive layout)**: Check the screen width using `MediaQuery.of(context).size.width` or `LayoutBuilder` to toggle between a 2-column configuration (large screens like macOS) and a single-column stacked configuration (mobile).

### 3.2 UI Structure Sketch

```dart
  Widget _buildLocalAlarmSettingsCard(Setting settings) {
    final repo = ref.read(settingsRepositoryProvider);
    final isLargeScreen = MediaQuery.of(context).size.width > 600;

    final cardContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t('settings_local_alarms_title') ?? 'Configurações de Alarme do Aplicativo',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.text),
        ),
        const SizedBox(height: 16),
        
        if (isLargeScreen) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildSoundDropdown(settings, repo)),
              const SizedBox(width: 16),
              Expanded(child: _buildDurationDropdown(settings, repo)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildVolumeSlider(settings, repo)),
              const SizedBox(width: 16),
              Expanded(child: _buildVibrationSwitch(settings, repo)),
            ],
          ),
        ] else ...[
          _buildSoundDropdown(settings, repo),
          const SizedBox(height: 16),
          _buildDurationDropdown(settings, repo),
          const SizedBox(height: 16),
          _buildVolumeSlider(settings, repo),
          const SizedBox(height: 16),
          _buildVibrationSwitch(settings, repo),
        ],
        
        const Divider(height: 32),
        Center(
          child: ElevatedButton.icon(
            onPressed: () => _toggleTestSound(settings.localAlarmSound, settings.localAlarmVolume),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            icon: Icon(
              _isTestingSound ? Icons.stop_circle_outlined : Icons.play_circle_outline_rounded,
              color: Colors.white,
            ),
            label: Text(
              _isTestingSound
                  ? (t('settings_local_stop_sound') ?? 'Parar Som')
                  : (t('settings_local_test_sound') ?? 'Testar Som'),
            ),
          ),
        ),
      ],
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: cardContent,
      ),
    );
  }

  Widget _buildSoundDropdown(Setting settings, SettingsRepository repo) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t('settings_local_alarm_sound') ?? 'Som do Alarme',
          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textMuted),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: settings.localAlarmSound,
          dropdownColor: AppColors.surface,
          style: TextStyle(color: AppColors.text, fontSize: 16),
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          items: [
            DropdownMenuItem<String>(
              value: 'alarm_beep',
              child: Text('Bip de Alarme (alarm_beep.wav)', style: TextStyle(color: AppColors.text)),
            ),
            DropdownMenuItem<String>(
              value: 'default',
              child: Text('Som Padrão do Sistema', style: TextStyle(color: AppColors.text)),
            ),
          ],
          onChanged: (val) {
            if (val != null) {
              repo.updateSettings(settings.copyWith(localAlarmSound: val));
            }
          },
        ),
      ],
    );
  }

  Widget _buildDurationDropdown(Setting settings, SettingsRepository repo) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t('settings_local_alarm_duration') ?? 'Duração do Alarme',
          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textMuted),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<int>(
          initialValue: settings.localAlarmDurationMins,
          dropdownColor: AppColors.surface,
          style: TextStyle(color: AppColors.text, fontSize: 16),
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          items: [1, 2, 5, 10, 15, 20].map((mins) {
            return DropdownMenuItem<int>(
              value: mins,
              child: Text('$mins minutos', style: TextStyle(color: AppColors.text)),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) {
              repo.updateSettings(settings.copyWith(localAlarmDurationMins: val));
            }
          },
        ),
      ],
    );
  }

  Widget _buildVolumeSlider(Setting settings, SettingsRepository repo) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${t('settings_local_alarm_volume') ?? 'Volume do Som'}: ${settings.localAlarmVolume}%',
          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textMuted),
        ),
        const SizedBox(height: 8),
        Slider(
          value: settings.localAlarmVolume.toDouble(),
          min: 0,
          max: 100,
          divisions: 10,
          activeColor: AppColors.primary,
          inactiveColor: AppColors.primary.withValues(alpha: 0.24),
          onChanged: (val) {
            repo.updateSettings(settings.copyWith(localAlarmVolume: val.toInt()));
          },
        ),
      ],
    );
  }

  Widget _buildVibrationSwitch(Setting settings, SettingsRepository repo) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        t('settings_local_vibration') ?? 'Vibrar Dispositivo',
        style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.text),
      ),
      value: settings.localVibrationEnabled,
      activeThumbColor: AppColors.primary,
      onChanged: (val) {
        repo.updateSettings(settings.copyWith(localVibrationEnabled: val));
      },
    );
  }
```

---

## 4. Local Test Audio Playback Implementation

The test audio button operates statefully directly on the `SettingsScreen` to play or stop the chosen audio local asset.

### 4.1 Audio Controller & State Setup
Add state variables and a dedicated `AudioPlayer` inside `_SettingsScreenState` (`settings_screen.dart`):

```dart
  AudioPlayer? _testAudioPlayer;
  bool _isTestingSound = false;

  Future<void> _toggleTestSound(String soundPath, int volume) async {
    final buildContext = context;
    if (_isTestingSound) {
      await _testAudioPlayer?.stop();
      if (buildContext.mounted) {
        setState(() {
          _isTestingSound = false;
        });
      }
    } else {
      _testAudioPlayer ??= AudioPlayer();
      await _testAudioPlayer!.setVolume(volume / 100.0);
      await _testAudioPlayer!.setReleaseMode(ReleaseMode.loop);
      
      try {
        if (soundPath == 'alarm_beep') {
          await _testAudioPlayer!.play(AssetSource('sounds/alarm_beep.wav'));
        } else {
          // Play default system sound or default asset fallback
          await _testAudioPlayer!.play(AssetSource('sounds/alarm_beep.wav'));
        }
        if (buildContext.mounted) {
          setState(() {
            _isTestingSound = true;
          });
        }
      } catch (e) {
        debugPrint('Error playing test sound: $e');
        if (buildContext.mounted) {
          ScaffoldMessenger.of(buildContext).showSnackBar(
            SnackBar(content: Text('Erro ao reproduzir áudio local.')),
          );
        }
      }
    }
  }
```

Ensure the resources are disposed in `dispose()`:
```dart
  @override
  void dispose() {
    _testAudioPlayer?.dispose();
    // ... existing disposals
    super.dispose();
  }
```

---

## 5. Applying Local Settings to Notification & Alarm Services

### 5.1 Dynamic Notification Scheduling (`NotificationService` & `AlarmEngine`)
1. **Pass settings down from the Riverpod engine**:
   In `lib/core/services/alarm_engine.dart`, read the settings companion when rescheduling notifications:
   ```dart
   final settings = await ref.read(settingsRepositoryProvider).getSettings();
   
   await notificationService.scheduleWeeklyAlarm(
     id: alarm.id,
     hour: alarm.hour,
     minute: alarm.minute,
     title: alarm.medName.isNotEmpty ? alarm.medName : alarm.name,
     body: "Hora de tomar seu medicamento: ...",
     days: alarm.days,
     soundName: settings.localAlarmSound, // Dynamic sound name passed to OS
     enableVibration: settings.localVibrationEnabled, // Dynamic vibration passed to OS
   );
   ```

2. **Configure Local Notifications with variables**:
   Modify `NotificationService.scheduleWeeklyAlarm` signature to receive configuration flags:
   ```dart
   Future<void> scheduleWeeklyAlarm({
     required int id,
     required int hour,
     required int minute,
     required String title,
     required String body,
     required List<bool> days,
     String? soundName,
     bool enableVibration = true,
   }) async { ... }
   ```
   Apply `enableVibration` to `AndroidNotificationDetails` and handle dynamic system sounds or custom file mapping:
   - On Android: `enableVibration: enableVibration`
   - On Apple platforms: Map `soundName` appropriately into `DarwinNotificationDetails(sound: ...)`

> **⚠️ Android Platform Caveat (Immutable Notification Channels)**:
> On Android, once a notification channel is created, its sound and vibration configurations are cached by the OS and cannot be modified programmatically. 
> To bypass this restriction, the channel ID should incorporate a hash of the settings, e.g.:
> `channelId = 'medicaixa_alarms_channel_${soundName}_${enableVibration ? "vibr" : "novibr"}'`.
> This forces the Android OS to register a new channel with the chosen settings.

### 5.2 Foreground Active Alarm Screen (`AlarmActiveScreen`)
When an alarm is triggered in the foreground, `AlarmActiveScreen` plays the alarm audio and controls haptics directly.

1. **Retrieve local settings**:
   Query settings asynchronously in `_playAlarmSound` inside `_AlarmActiveScreenState`:
   ```dart
   final settings = await ref.read(settingsRepositoryProvider).getSettings();
   final String localSound = settings.localAlarmSound;
   final int localVolume = settings.localAlarmVolume;
   final bool vibrationEnabled = settings.localVibrationEnabled;
   final int durationMins = settings.localAlarmDurationMins;
   ```

2. **Apply Volume**:
   Set player volume scale dynamically (from 0.0 to 1.0):
   ```dart
   await _audioPlayer.setVolume(localVolume / 100.0);
   ```

3. **Play Selected Sound**:
   ```dart
   if (localSound == 'alarm_beep') {
     await _audioPlayer.play(AssetSource('sounds/alarm_beep.wav'));
   } else {
     // System default or fallback to alarm_beep
     await _audioPlayer.play(AssetSource('sounds/alarm_beep.wav'));
   }
   ```

4. **Vibration Loop**:
   If `vibrationEnabled` is true, spin up a periodic timer for standard vibration instead of blocking loops:
   ```dart
   Timer? _vibrationTimer;

   void _startVibrationLoop() {
     _vibrationTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
       if (!context.mounted) {
         timer.cancel();
         return;
       }
       try {
         await HapticFeedback.vibrate();
       } catch (e) {
         debugPrint('HapticFeedback.vibrate failed: $e');
       }
     });
   }
   ```

5. **Apply Alarm Duration limit**:
   To automatically dismiss or silence the alarm after the timeout expires, create a duration timer:
   ```dart
   Timer? _durationTimer;
   
   // Inside _playAlarmSound:
   _durationTimer = Timer(Duration(minutes: durationMins), () {
     _audioPlayer.stop();
     _vibrationTimer?.cancel();
     debugPrint('Alarm playback stopped automatically after $durationMins mins.');
   });
   ```

6. **Cleanup resources**:
   In `dispose()`, cancel the timers:
   ```dart
   @override
   void dispose() {
     _vibrationTimer?.cancel();
     _durationTimer?.cancel();
     _audioPlayer.dispose();
     _pulsingController.dispose();
     _stopAppNapPrevention();
     super.dispose();
   }
   ```
