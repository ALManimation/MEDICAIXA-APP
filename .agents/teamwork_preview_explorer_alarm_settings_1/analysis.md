# Analysis Report: Local Alarm Settings Integration

This report provides a detailed analysis of the current implementation of settings, notifications, active alarm screens, and audio assets in the MediCaixa Flutter codebase, followed by recommendations for implementing local alarm settings.

---

## 1. Summary of Discovered Codebase File Locations

We have analyzed the codebase and located the following files:

1. **Drift Database File**: `lib/core/database/database.dart`
   * **State/Storage**: The `Settings` table stores device configurations. By default, it contains a single row (primary key `id = 1`).
   * **Query & Update**: The settings are observed reactively using the Stream-based provider `watchSettingsProvider` and updated via methods in `SettingsRepository` (located in `lib/features/settings/data/settings_repository.dart`).

2. **Settings UI Screen**: `lib/features/settings/presentation/settings_screen.dart`
   * **Controllers**: Uses a stateful widget `_SettingsScreenState` with controllers for text fields (e.g. `_nameController`, `_geminiKeyController`).
   * **Providers**: Watches `watchSettingsProvider` to load the current settingsCompanion, `pairingNotifierProvider` for device connection state, `appLocaleProvider` for locales, and `appThemeNotifierProvider` for themes.
   * **Repository**: Uses `settingsRepositoryProvider` to save changes to the local SQLite database via Drift.

3. **Notification Service**: `lib/core/services/notification_service.dart`
   * **Purpose**: Coordinates local notifications using `flutter_local_notifications`.
   * **Scheduling**: Alarms are scheduled via `scheduleWeeklyAlarm` which sets up platform-specific notification details (`AndroidNotificationDetails`, `DarwinNotificationDetails` for iOS/macOS) and schedules them using timezone-aware dates.

4. **Active Alarm Firing Screen**: `lib/features/alarms/presentation/alarm_active_screen.dart`
   * **Purpose**: Renders the fullscreen overlay when an alarm is actively firing in the foreground.
   * **Audio/Vibration**: Plays the alarm sound using `audioplayers` (`AssetSource('sounds/alarm_beep.wav')` with a fallback URL) and triggers haptic vibration/system alerts if audio fails.

5. **Audio Files Inventory**:
   * Asset File: `assets/sounds/alarm_beep.wav`
   * Android Raw Resource: `android/app/src/main/res/raw/alarm_beep.wav`
   * iOS / macOS Runner Files: `ios/Runner/alarm_beep.wav` and `macos/Runner/alarm_beep.wav`
   * *Conclusion*: `alarm_beep.wav` is currently the only available audio asset in the workspace.

---

## 2. Drift Database Recommendations (Schema & Migrations)

### Schema Expansion
To support local configuration of phone-side alarm alerts, add 4 columns to the `Settings` table in `lib/core/database/database.dart`:

```dart
class Settings extends Table {
  // Existing columns ...

  // 1. Sound file/identifier for the phone alarm (default is 'alarm_beep')
  TextColumn get localAlarmSound => text().withDefault(const Constant('alarm_beep'))();

  // 2. Playback volume for the phone alarm (0-100%, default 80%)
  IntColumn get localAlarmVolume => integer().withDefault(const Constant(80))();

  // 3. Flag to enable or disable vibration on the phone during alarms
  BoolColumn get localVibrationEnabled => boolean().withDefault(const Constant(true))();

  // 4. Ringing duration in minutes before automatic timeout/snooze (default 5 mins)
  IntColumn get localAlarmDurationMins => integer().withDefault(const Constant(5))();
}
```

### Migration Execution
1. Increment `schemaVersion` from `5` to `6` in `lib/core/database/database.dart`.
2. Update the `migration` strategy to support the version `6` column addition:

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

### Code Generation & Companion Defaults
After modifying `database.dart`, run the following command to update generated code:
```bash
dart run build_runner build --delete-conflicting-outputs
```

Then, update default companion and copy values in `lib/features/settings/data/settings_repository.dart`:
* In `getSettings()` default insert companion:
  ```dart
  localAlarmSound: Value('alarm_beep'),
  localAlarmVolume: Value(80),
  localVibrationEnabled: Value(true),
  localAlarmDurationMins: Value(5),
  ```
* In `executeBackupRestore()` settings block:
  ```dart
  localAlarmSound: Value(item['local_alarm_sound'] as String? ?? 'alarm_beep'),
  localAlarmVolume: Value((item['local_alarm_volume'] as num?)?.toInt() ?? 80),
  localVibrationEnabled: Value(item['local_vibration_enabled'] == true),
  localAlarmDurationMins: Value((item['local_alarm_duration_mins'] as num?)?.toInt() ?? 5),
  ```
* In `downloadBackupJson()` settings block:
  ```dart
  'local_alarm_sound': settings.localAlarmSound,
  'local_alarm_volume': settings.localAlarmVolume,
  'local_vibration_enabled': settings.localVibrationEnabled,
  'local_alarm_duration_mins': settings.localAlarmDurationMins,
  ```

---

## 3. Settings UI (SettingsScreen) Recommendation

The UI section for **Local Alarm Settings** should be added under "AJUSTES LOCAIS" (Local Settings) inside `settings_screen.dart` to separate them from device settings.

### UI Layout Structure
* **Card Container**: Standard rounded-corner card.
* **Dropdown for Alarm Sound**: Let the user choose between the existing sounds (currently `alarm_beep.wav` or system sounds).
* **Slider for Alarm Volume**: Value range `0` to `100`, showing percentage labels.
* **Switch for Vibration**: Toggle switch for vibration state.
* **Dropdown for Alarm Duration**: Options such as `1 Minuto`, `2 Minutos`, `5 Minutos`, `10 Minutos` or `Contínuo (15 Minutos)`.
* **Sound Test Button**: Play/Stop toggle. When tapped, it starts playing the audio locally at the selected volume and changes color/icon to let the user stop it.

### Critical Implementation Rules

1. **No `const` with `AppColors`**:
   Widgets referencing variables from `AppColors` (such as `AppColors.primary`, `AppColors.textMuted`, etc.) must not use the `const` keyword.
   * *Correct*: `Icon(Icons.volume_up, color: AppColors.primary)`
   * *Incorrect*: `const Icon(Icons.volume_up, color: AppColors.primary)`

2. **Use `context.mounted`**:
   Ensure state checks are safe after asynchronous operations (like saving configurations or stopping test audio):
   ```dart
   if (context.mounted) {
     ScaffoldMessenger.of(context).showSnackBar(...);
   }
   ```

3. **Responsive Grid Layout (`isWide`)**:
   Aligning with rule 17 (Responsive Layout), check context viewport width to layout local settings cards. If wide screen (macOS/Desktop/Tablet, >= 800px), render widgets side-by-side using `Row` and `Expanded` columns rather than a long vertical list.

### Code Sketch for UI Card
```dart
Widget _buildLocalAlarmSettingsCard(Setting settings, BuildContext context) {
  final repo = ref.read(settingsRepositoryProvider);
  final isWide = MediaQuery.of(context).size.width >= 800;

  final content = Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        t('local_alarm_settings_title'), // Define translations or strings
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
      const SizedBox(height: 16),
      
      // Sound Selector Row/Column
      DropdownButtonFormField<String>(
        value: settings.localAlarmSound,
        decoration: InputDecoration(
          labelText: t('local_alarm_sound_label'),
          border: const OutlineInputBorder(),
        ),
        dropdownColor: AppColors.surface, // No const on widgets using AppColors!
        style: TextStyle(color: AppColors.text, fontSize: 16),
        items: const [
          DropdownMenuItem(value: 'alarm_beep', child: Text('Bipe Padrão (Local)')),
        ],
        onChanged: (val) {
          if (val != null) {
            repo.updateSettings(settings.copyWith(localAlarmSound: val));
          }
        },
      ),
      const SizedBox(height: 16),

      // Volume Slider
      Row(
        children: [
          Icon(Icons.volume_up, color: AppColors.primary), // No const!
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${t('local_volume_title')}: ${settings.localAlarmVolume}%',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Slider(
                  value: settings.localAlarmVolume.toDouble(),
                  min: 0,
                  max: 100,
                  divisions: 10,
                  onChanged: (val) {
                    repo.updateSettings(
                      settings.copyWith(localAlarmVolume: val.toInt()),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),

      // Vibration Switch
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(t('local_vibration_title')),
        value: settings.localVibrationEnabled,
        activeColor: AppColors.primary, // No const!
        onChanged: (val) {
          repo.updateSettings(settings.copyWith(localVibrationEnabled: val));
        },
      ),
      const SizedBox(height: 16),

      // Duration Dropdown
      DropdownButtonFormField<int>(
        value: settings.localAlarmDurationMins,
        decoration: InputDecoration(
          labelText: t('local_duration_label'),
          border: const OutlineInputBorder(),
        ),
        dropdownColor: AppColors.surface, // No const!
        style: TextStyle(color: AppColors.text, fontSize: 16),
        items: const [
          DropdownMenuItem(value: 1, child: Text('1 Minuto')),
          DropdownMenuItem(value: 2, child: Text('2 Minutos')),
          DropdownMenuItem(value: 5, child: Text('5 Minutos')),
          DropdownMenuItem(value: 10, child: Text('10 Minutos')),
          DropdownMenuItem(value: 15, child: Text('Contínuo (15 Minutos)')),
        ],
        onChanged: (val) {
          if (val != null) {
            repo.updateSettings(settings.copyWith(localAlarmDurationMins: val));
          }
        },
      ),
      const SizedBox(height: 20),

      // Test Audio Button
      Center(
        child: _LocalAudioTestButton(
          soundName: settings.localAlarmSound,
          volume: settings.localAlarmVolume,
        ),
      ),
    ],
  );

  return Card(
    child: Padding(
      padding: const EdgeInsets.all(16.0),
      child: content,
    ),
  );
}
```

---

## 4. Local Test Audio Button Logic Recommendation

The audio testing feature should toggle playback states reactively, using a dedicated stateful widget `_LocalAudioTestButton`:

### Implementation Strategy
1. Declare a stateful widget `_LocalAudioTestButton` which initializes its own `AudioPlayer` instance.
2. Toggle playback state (`isPlaying`) locally.
3. Manage audio resources responsibly by disposing of the player when the widget is disposed.

```dart
class _LocalAudioTestButton extends StatefulWidget {
  final String soundName;
  final int volume;

  const _LocalAudioTestButton({
    required this.soundName,
    required this.volume,
  });

  @override
  State<_LocalAudioTestButton> createState() => _LocalAudioTestButtonState();
}

class _LocalAudioTestButtonState extends State<_LocalAudioTestButton> {
  AudioPlayer? _audioPlayer;
  bool _isPlaying = false;

  @override
  void dispose() {
    _audioPlayer?.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (_isPlaying) {
      await _audioPlayer?.stop();
      if (mounted) {
        setState(() {
          _isPlaying = false;
        });
      }
    } else {
      _audioPlayer ??= AudioPlayer();
      try {
        await NotificationService.instance.configureAudioSessionForPlayback();
        await _audioPlayer!.setVolume(widget.volume / 100.0);
        await _audioPlayer!.play(AssetSource('sounds/${widget.soundName}.wav'));
        if (mounted) {
          setState(() {
            _isPlaying = true;
          });
        }
        
        // Listen to playback completion to reset button state
        _audioPlayer!.onPlayerComplete.first.then((_) {
          if (mounted) {
            setState(() {
              _isPlaying = false;
            });
          }
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao reproduzir áudio local: $e'),
              backgroundColor: AppColors.missed, // No const!
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: _togglePlay,
      style: ElevatedButton.styleFrom(
        backgroundColor: _isPlaying ? AppColors.missed : AppColors.primary, // No const!
        foregroundColor: Colors.white,
      ),
      icon: Icon(_isPlaying ? Icons.stop_circle : Icons.play_circle),
      label: Text(_isPlaying ? 'PARAR SOM LOCAL' : 'TESTAR SOM LOCAL'),
    );
  }
}
```

---

## 5. Integration with NotificationService & AlarmActiveScreen

### 5.1. NotificationService Updates
To apply custom local alarm sounds:

1. **Database Query inside Alarm Engine**:
   In `lib/core/services/alarm_engine.dart`, watch the settings Provider:
   ```dart
   final settings = ref.watch(watchSettingsProvider).value;
   final localSound = settings?.localAlarmSound ?? 'alarm_beep';
   ```
   Pass the local sound name to the scheduling method:
   ```dart
   await notificationService.scheduleWeeklyAlarm(
     id: alarm.id,
     hour: alarm.hour,
     minute: alarm.minute,
     title: alarm.medName.isNotEmpty ? alarm.medName : alarm.name,
     body: "Hora de tomar seu medicamento...",
     days: alarm.days,
     soundName: localSound, // Pass setting
   );
   ```

2. **Vibration/Audio Configuration**:
   In `NotificationService.scheduleWeeklyAlarm`:
   On Android, the sound & vibration properties are bound to the `AndroidNotificationChannel`. Since Android Oreo (8.0+), once a channel is created, its sound and vibration settings are locked.
   * *Recommendation*: Dynamically recreate the notification channel if sound files or vibration policies change. To do this, delete the channel:
     ```dart
     await androidImplementation?.deleteNotificationChannel('medicaixa_alarms_channel');
     ```
     Then, recreate the channel using the updated `localAlarmSound` raw sound path and `localVibrationEnabled` flag:
     ```dart
     final AndroidNotificationChannel channel = AndroidNotificationChannel(
       'medicaixa_alarms_channel',
       'MediCaixa Alarmes',
       importance: Importance.max,
       playSound: true,
       enableVibration: localVibrationEnabled, // Bind to setting
       sound: RawResourceAndroidNotificationSound(localAlarmSound), // Bind to setting
     );
     ```

### 5.2. AlarmActiveScreen (Foreground Active Firing) Updates
`AlarmActiveScreen` is a `ConsumerStatefulWidget` and can query settings dynamically using Riverpod.

1. **Watch local settings**:
   In the widget's build or initialization sequence, retrieve the configuration:
   ```dart
   final settings = ref.watch(watchSettingsProvider).value;
   final localSound = settings?.localAlarmSound ?? 'alarm_beep';
   final localVolume = (settings?.localAlarmVolume ?? 80) / 100.0;
   final isVibrationEnabled = settings?.localVibrationEnabled ?? true;
   final timeoutMins = settings?.localAlarmDurationMins ?? 5;
   ```

2. **Playback Config**:
   Inside `_playAlarmSound`:
   ```dart
   Future<void> _playAlarmSound() async {
     try {
       await NotificationService.instance.configureAudioSessionForPlayback();
       await _audioPlayer.setReleaseMode(ReleaseMode.loop);
       await _audioPlayer.setVolume(localVolume); // Set volume from settings
     } catch (e) {
       debugPrint('Error setting volume: $e');
     }

     bool soundPlayingSucceeded = false;
     try {
       await _audioPlayer.play(AssetSource('sounds/$localSound.wav')); // Load settings sound
       soundPlayingSucceeded = true;
     } catch (assetError) {
       // URL Fallback logic ...
     }

     if (!soundPlayingSucceeded || isVibrationEnabled) {
       _triggerPeriodicVibration(); // Check configuration
     }
   }
   ```

3. **Autoclean / Timeout Timer**:
   To prevent battery drainage, implement a timeout timer.
   In `initState` of `_AlarmActiveScreenState`:
   ```dart
   Timer? _timeoutTimer;

   @override
   void initState() {
     super.initState();
     // Existing init ...
     
     // Retrieve timeout minutes from settings and start timer
     final duration = ref.read(watchSettingsProvider).value?.localAlarmDurationMins ?? 5;
     _timeoutTimer = Timer(Duration(minutes: duration), () {
       if (mounted) {
         // Auto-dismiss the active screen and log the event as missed (Não Tomado)
         final safeIndex = _currentAlarmIndex.clamp(0, widget.activeAlarms.length - 1);
         _markSkipped(widget.activeAlarms[safeIndex]);
       }
     });
   }

   @override
   void dispose() {
     _timeoutTimer?.cancel();
     // Existing dispose ...
   }
   ```
   *Note: If the active alarm window (10 minutes) expires, the background `AlarmEngine` tick will automatically update the state, but having an active screen timer ensures the UI cleans up instantly.*
