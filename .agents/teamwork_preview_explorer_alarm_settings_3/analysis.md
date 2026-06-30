# Analysis: Local Alarm Settings Implementation (Sound, Volume, Vibration, Duration)

This report details the investigation of the MediCaixa App codebase to locate core databases, settings, notification services, active alarm screens, and audio files. It provides detailed, production-ready recommendations for implementing local app settings for alarms (sound, volume, vibration, and duration), ensuring offline autonomy and user customization.

---

## 1. Codebase Audit Findings

### 1.1 Drift Database (`lib/core/database/database.dart`)
- **Structure**: The `Settings` table currently holds 20 columns, storing details like `patientName`, `speakerVolume`, `brightness`, `alarmSound` (index), `alarmSpacingMs`, `wakeTime`, `sleepTime`, and `themeMode`.
- **Query & Update Methods**: 
  - Settings are retrieved using `SettingsRepository.getSettings()` which returns a single row (creating a default row with `id = 1` if it is empty).
  - Updates are made using `SettingsRepository.updateSettings(Setting data)`, which replaces the row in the Drift database:
    ```dart
    Future<void> updateSettings(Setting data) async {
      await _db.update(_db.settings).replace(data);
      // Synchronizes to ESP32 physical device if connected...
    }
    ```
  - Reactive streams are exposed via `@riverpod Stream<Setting?> watchSettings` in `settings_repository.dart`.
- **Primary Key**: The table uses `id` (defaulting to `1`) as a singleton primary key.

### 1.2 Settings UI (`lib/features/settings/presentation/settings_screen.dart`)
- **Structure**:
  - The UI uses Riverpod (`ref.watch(watchSettingsProvider)`) to reactively read the single `Setting` instance.
  - Separate helper widgets/methods divide Settings into card segments:
    - `_buildPatientProfileCard`: Edits patient name.
    - `_buildSleepMealsCard`: Manages sleep and meal schedules.
    - `_buildAppConfigCard`: Manages app language and visual theme.
    - `_buildSoundDisplayTile` (under Box Adjustments): Sets physical ESP32 volume, brightness, and ringtone.
- **Provider & Notifier**: 
  - `watchSettingsProvider` provides the reactive stream of the database row.
  - `settingsRepositoryProvider` handles updates and interacts with the database/API client.

### 1.3 NotificationService (`lib/core/services/notification_service.dart`)
- **Initialization**: Configures standard `FlutterLocalNotificationsPlugin` for iOS, Android, and macOS.
- **Scheduling**: `scheduleWeeklyAlarm(...)` schedules local OS notifications for alarm times using:
  - `AndroidNotificationDetails` (using `RawResourceAndroidNotificationSound` for native playback).
  - `DarwinNotificationDetails` (specifying custom sound names).
- **Sound Mapping**: Maps sound names to OS-specific resource paths (Android raw resources vs. iOS `.caf`/`.wav` assets).

### 1.4 AlarmActiveScreen (`lib/features/alarms/presentation/alarm_active_screen.dart`)
- **Overview**: Appears in front of the Dashboard when there are active/firing alarms (status `ATIVO`).
- **Sound Playback**: Instantiates `AudioPlayer` from `audioplayers: ^6.8.1`. In `_playAlarmSound()`, it:
  - Configures the iOS global audio session category (playback/speaker).
  - Tries to play the default `AssetSource('sounds/alarm_beep.wav')`.
  - Falls back to `UrlSource` if the asset is missing.
  - Falls back to `_triggerPeriodicVibration()` (haptic vibration and system sound) if all audio fails.
- **Dismissal**: Screen dismisses automatically when the active alarms stream list is empty (after marking alarms as taken/skipped/snoozed).

### 1.5 Audio Files
We located only one audio file in the project directories:
- **Flutter Assets**: `assets/sounds/alarm_beep.wav`
- **Android Native Resource**: `android/app/src/main/res/raw/alarm_beep.wav`
- **iOS/macOS Native Resource**: `ios/Runner/alarm_beep.wav`, `macos/Runner/alarm_beep.wav`
- **Unit Test Path**: `build/unit_test_assets/assets/sounds/alarm_beep.wav`

---

## 2. Recommendations for Implementation

### 2.1 Drift Schema Updates (Adding 4 Columns)
We should add four new columns representing the local settings parameters in `lib/core/database/database.dart`.

1. **Column Definition inside `class Settings extends Table`**:
   ```dart
   TextColumn get localAlarmSound => text().withDefault(const Constant('alarm_beep.wav'))();
   IntColumn get localAlarmVolume => integer().withDefault(const Constant(100))(); // 0 - 100%
   BoolColumn get localVibrationEnabled => boolean().withDefault(const Constant(true))();
   IntColumn get localAlarmDurationMins => integer().withDefault(const Constant(5))(); // 1 - 30 minutes
   ```

2. **Schema Migration**:
   - Increment the schema version to `6`:
     ```dart
     @override
     int get schemaVersion => 6;
     ```
   - In `MigrationStrategy.onUpgrade`, add a condition to migration steps:
     ```dart
     if (from < 6) {
       await migrator.addColumn(settings, settings.localAlarmSound);
       await migrator.addColumn(settings, settings.localAlarmVolume);
       await migrator.addColumn(settings, settings.localVibrationEnabled);
       await migrator.addColumn(settings, settings.localAlarmDurationMins);
     }
     ```

3. **Database Defaults Update**:
   - In `SettingsRepository.getSettings()` (`lib/features/settings/data/settings_repository.dart`), the fallback instantiation of `SettingsCompanion` must be updated with the new columns:
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
       localAlarmSound: Value('alarm_beep.wav'),
       localAlarmVolume: Value(100),
       localVibrationEnabled: Value(true),
       localAlarmDurationMins: Value(5),
     );
     ```
   - In `DeviceResetNotifier.resetDevicePartitions` (`lib/features/settings/data/settings_repository.dart`), include these fields when writing default values back to database settings.

---

### 2.2 Rendering the SettingsScreen UI Section

A new card section called **Ajustes de Alarme do Aplicativo** should be rendered inside `settings_screen.dart` under the **Ajustes Locais** section (right below `_buildAppConfigCard`).

```dart
  Widget _buildLocalAlarmConfigCard(Setting settings) {
    final repo = ref.read(settingsRepositoryProvider);
    
    // We currently have alarm_beep.wav in the folder. Add other options if available.
    final List<String> availableSounds = ['alarm_beep.wav'];
    final List<int> durationOptions = [1, 3, 5, 10, 15, 30];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ajustes de Alarme do Aplicativo', // Can be loaded from app translations json
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: AppColors.text, // Rule compliance: No const with AppColors
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Configurações de toque, vibração e limites de tempo para o celular/computador.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textMuted, // Rule compliance: No const with AppColors
              ),
            ),
            const SizedBox(height: 16),

            // Dropdown: Select Local Sound
            DropdownButtonFormField<String>(
              value: settings.localAlarmSound ?? 'alarm_beep.wav',
              dropdownColor: AppColors.surface, // Rule compliance: No const with AppColors
              style: TextStyle(color: AppColors.text, fontSize: 16), // Rule compliance: No const with AppColors
              decoration: const InputDecoration(
                labelText: 'Som do Alarme Local',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: availableSounds.map((sound) {
                return DropdownMenuItem<String>(
                  value: sound,
                  child: Text(sound),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  repo.updateSettings(settings.copyWith(localAlarmSound: Value(val)));
                }
              },
            ),
            const SizedBox(height: 16),

            // Slider: Volume Control
            Row(
              children: [
                Icon(Icons.volume_up_rounded, color: AppColors.primary), // Rule compliance: No const with AppColors
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Volume: ${settings.localAlarmVolume ?? 100}%',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Slider(
                        value: (settings.localAlarmVolume ?? 100).toDouble(),
                        min: 0,
                        max: 100,
                        divisions: 10,
                        activeColor: AppColors.primary, // Rule compliance: No const with AppColors
                        onChanged: (val) {
                          repo.updateSettings(
                            settings.copyWith(localAlarmVolume: Value(val.toInt())),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Switch: Local Vibration Enabled
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Vibração Local',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text('Vibrar o dispositivo ao disparar alarmes locais.'),
              value: settings.localVibrationEnabled ?? true,
              activeColor: AppColors.primary, // Rule compliance: No const with AppColors
              onChanged: (val) {
                repo.updateSettings(
                  settings.copyWith(localVibrationEnabled: Value(val)),
                );
              },
            ),
            const Divider(),

            // Dropdown: Sleep Time Limit (Duration)
            DropdownButtonFormField<int>(
              value: settings.localAlarmDurationMins ?? 5,
              dropdownColor: AppColors.surface, // Rule compliance: No const with AppColors
              style: TextStyle(color: AppColors.text, fontSize: 16), // Rule compliance: No const with AppColors
              decoration: const InputDecoration(
                labelText: 'Tempo Limite do Alarme (Minutos)',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: durationOptions.map((mins) {
                return DropdownMenuItem<int>(
                  value: mins,
                  child: Text('$mins ${mins == 1 ? 'minuto' : 'minutos'}'),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  repo.updateSettings(
                    settings.copyWith(localAlarmDurationMins: Value(val)),
                  );
                }
              },
            ),
            const SizedBox(height: 20),

            // Test Button
            Center(
              child: ElevatedButton.icon(
                onPressed: () => _toggleTestSound(
                  settings.localAlarmSound ?? 'alarm_beep.wav',
                  (settings.localAlarmVolume ?? 100).toDouble(),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isPlayingTestSound ? AppColors.missed : AppColors.primary, // Rule compliance: No const with AppColors
                  foregroundColor: Colors.white,
                  minimumSize: const Size(200, 48),
                ),
                icon: Icon(_isPlayingTestSound ? Icons.stop_rounded : Icons.play_arrow_rounded),
                label: Text(_isPlayingTestSound ? 'Parar Teste' : 'Testar Som Local'),
              ),
            ),
          ],
        ),
      ),
    );
  }
```

---

### 2.3 Audio Test Playback Logic inside SettingsScreen

The `SettingsScreen` will instantiate and dispose a secondary audio player specifically dedicated to sound testing, preserving safety across asynchronous gaps.

1. **State variables in `_SettingsScreenState`**:
   ```dart
   AudioPlayer? _testAudioPlayer;
   bool _isPlayingTestSound = false;
   ```

2. **Initialization and Disposal**:
   ```dart
   @override
   void initState() {
     super.initState();
     _testAudioPlayer = AudioPlayer();
     // ... rest of init code
   }

   @override
   void dispose() {
     _testAudioPlayer?.dispose();
     // ... rest of dispose code
     super.dispose();
   }
   ```

3. **Toggle Playback Controller**:
   ```dart
   Future<void> _toggleTestSound(String soundFile, double volume) async {
     if (_isPlayingTestSound) {
       await _testAudioPlayer?.stop();
       setState(() {
         _isPlayingTestSound = false;
       });
     } else {
       setState(() {
         _isPlayingTestSound = true;
       });
       try {
         await _testAudioPlayer?.setVolume(volume / 100.0);
         await _testAudioPlayer?.play(AssetSource('sounds/$soundFile'));
         
         // Auto-reset button state on play completion
         _testAudioPlayer?.onPlayerComplete.first.then((_) {
           if (mounted) {
             setState(() {
               _isPlayingTestSound = false;
             });
           }
         });
       } catch (e) {
         debugPrint('Error playing test sound: $e');
         if (mounted) {
           setState(() {
             _isPlayingTestSound = false;
           });
         }
       }
     }
   }
   ```

---

### 2.4 Querying and Applying Settings in NotificationService & AlarmActiveScreen

#### A. NotificationService integration (`lib/core/services/notification_service.dart`)
- **Vibration & Sounds**: When `NotificationService` schedules alarms, it must retrieve settings from the database.
- **Android Channel Caution**: Changing Android notification sound or vibration requires recreating the channel or using a new version ID (e.g. changing channel ID to `medicaixa_alarms_channel_v6`) since Android channels do not allow mutable attributes after creation.
- **Implementation in `scheduleWeeklyAlarm`**:
  ```dart
  Future<void> scheduleWeeklyAlarm({
    required int id,
    required int hour,
    required int minute,
    required String title,
    required String body,
    required List<bool> days,
    String? soundName,
    bool vibrationEnabled = true, // pass from local settings
  }) async {
    // ...
    final androidDetails = AndroidNotificationDetails(
      'medicaixa_alarms_channel_v6', // Updated version to reflect changes
      'MediCaixa Alarmes',
      // ...
      playSound: true,
      enableVibration: vibrationEnabled, // dynamic setting integration
      // ...
    );
    // ...
  }
  ```
- **Changes in `AlarmEngine`**:
  In `lib/core/services/alarm_engine.dart` (`_rescheduleAllNotifications`), read the database settings dynamically and propagate the local sound name and vibration values:
  ```dart
  final settings = await ref.read(settingsRepositoryProvider).getSettings();
  final localSound = settings.localAlarmSound ?? 'alarm_beep.wav';
  final localVibe = settings.localVibrationEnabled ?? true;

  await notificationService.scheduleWeeklyAlarm(
    // ...
    soundName: localSound,
    vibrationEnabled: localVibe,
  );
  ```

#### B. AlarmActiveScreen integration (`lib/features/alarms/presentation/alarm_active_screen.dart`)
We will read local settings reactively to configure the foreground ringing player.

1. **Timer state variable**:
   ```dart
   Timer? _autoDismissTimer;
   ```

2. **Fetching Settings in Initialization**:
   Change `initState` to fetch settings asynchronously and set up the playback context:
   ```dart
   @override
   void initState() {
     super.initState();
     _audioPlayer = AudioPlayer();
     _startAppNapPrevention();
     
     _pulsingController = AnimationController(
       vsync: this,
       duration: const Duration(seconds: 1),
     )..repeat(reverse: true);

     _loadSettingsAndPlay();
   }

   Future<void> _loadSettingsAndPlay() async {
     try {
       final settings = await ref.read(settingsRepositoryProvider).getSettings();
       if (!mounted) return;

       // 1. Configure volume (normalized from 0-100 to 0.0-1.0)
       final double volume = (settings.localAlarmVolume ?? 100) / 100.0;
       await _audioPlayer.setVolume(volume);

       // 2. Play local sound
       final String soundFile = settings.localAlarmSound ?? 'alarm_beep.wav';
       await NotificationService.instance.configureAudioSessionForPlayback();
       await _audioPlayer.setReleaseMode(ReleaseMode.loop);
       await _audioPlayer.play(AssetSource('sounds/$soundFile'));

       // 3. Trigger vibration if enabled
       if (settings.localVibrationEnabled ?? true) {
         _triggerPeriodicVibration();
       }

       // 4. Set auto-dismiss limit duration (minutes)
       final int limitMins = settings.localAlarmDurationMins ?? 5;
       _autoDismissTimer = Timer(Duration(minutes: limitMins), () {
         if (mounted) {
           // Automatically skip/miss active alarm upon timeout
           _markSkipped(widget.activeAlarms[_currentAlarmIndex]);
         }
       });
     } catch (e) {
       debugPrint('Error starting local alarm setup: $e');
       _triggerPeriodicVibration(); // Failsafe vibration
     }
   }
   ```

3. **Disposal**:
   Ensure the timer is safely canceled to prevent memory leaks and unexpected background state modifications:
   ```dart
   @override
   void dispose() {
     _autoDismissTimer?.cancel();
     _audioPlayer.dispose();
     _pulsingController.dispose();
     _stopAppNapPrevention();
     super.dispose();
   }
   ```
