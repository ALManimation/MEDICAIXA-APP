## 2026-06-29T17:17:09Z
You are tasked with implementing Milestone 3: SettingsScreen Local Controls UI & Sound Test Player, and Milestone 4: NotificationService & AlarmActiveScreen Integration.

### Core Requirements:
1. **Milestone 3: UI Controls in SettingsScreen (`lib/features/settings/presentation/settings_screen.dart`)**
   - Add a new section/card titled "Notificações e Sons do App" (Notifications & Sounds) under the Local Settings section.
   - Implement the following inputs:
     * Sound selection Dropdown: Choice of 5 sounds:
       - 0: Beep (maps to `alarm_beep.wav` or `'alarm_beep'`)
       - 1: Alerta
       - 2: Melodia
       - 3: Musical
       - 4: Urgente
     * Volume Slider: 0 to 100 (persisted as integer). Display the volume percent.
     * Vibration Switch: toggles haptic feedback.
     * Duration limit Dropdown: options for 1 minute, 2 minutes, or 5 minutes (persisted as integer).
     * "Testar Alarme" Button: Toggles playback of the selected sound using an `AudioPlayer`. When playing, the label changes to "Parar Teste" and the button background color changes to indicate it's active. Correctly handles completion of playback and resource cleanup on dispose or when the user leaves the screen.
   - Ensure the new UI elements are responsive (layout side-by-side if screen width is >= 800px) and immediately save changes to the local settings table using the settings repository.
   - **Strict Rules**:
     * NEVER use `const` with widgets referencing `AppColors` (such as `Icon(..., color: AppColors.primary)` or `activeColor: AppColors.primary` or `textColor: AppColors.text`).
     * Always use `context.mounted` before accessing context in callbacks after async database saves or audio player actions.
     * Do NOT use `sed`/`awk`/regex for editing files.

2. **Milestone 4: Integrations**
   - **NotificationService (`lib/core/services/notification_service.dart`)**:
     * Retrieve local settings (`localAlarmSound` and `localVibrationEnabled`) when scheduling notifications.
     * Dynamically update the notification sound resource path. Since only `alarm_beep.wav` is available in native folders, map the sound index: index 0 maps to `alarm_beep`. For indices 1 to 4, you can use `alarm_beep` as fallback or system defaults.
     * Apply sound and vibration to `AndroidNotificationDetails` and `DarwinNotificationDetails`.
     * To bypass Android's channel caching limits, dynamically vary/recreate the Android Notification Channel ID based on sound/vibration choices (e.g., `'medicaixa_alarms_v' + soundIndex + '_' + (vibration ? 'y' : 'n' )`).
   - **AlarmActiveScreen (`lib/features/alarms/presentation/alarm_active_screen.dart`)**:
     * Fetch settings upon loading.
     * Apply the user-selected volume (`localVolume / 100.0`) to the active `AudioPlayer`.
     * Use the custom sound based on the sound index.
     * Conditionally trigger vibration in the haptic loop based on `localVibrationEnabled`.
     * Start a timeout timer (`Timer(Duration(minutes: localAlarmDurationMins), ...)`) that automatically snoozes/skips the alarm and closes the screen if the user does not respond within the duration. Ensure this timer is safely canceled on dispose.

### MANDATORY INTEGRITY WARNING
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A Forensic Auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

Write your report to `changes.md` in your working directory `/Users/almanimation/Downloads/Caixa Remedios/medicaixa_app/.agents/teamwork_preview_worker_alarm_settings_m3_m4/` and handoff when complete.
