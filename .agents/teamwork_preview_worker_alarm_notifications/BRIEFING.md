# BRIEFING — 2026-06-29T11:54:00-03:00

## Mission
Implement the native alarm, sound, and notification integration for Android, iOS, and macOS in the MediCaixa App, ensuring 100% offline autonomy.

## 🔒 My Identity
- Archetype: Worker
- Roles: implementer, qa, specialist
- Working directory: /Users/almanimation/Downloads/Caixa Remedios/medicaixa_app/.agents/teamwork_preview_worker_alarm_notifications/
- Original parent: 287494b0-133c-453e-9e21-c234dc454552
- Milestone: Native Alarm Integration

## 🔒 Key Constraints
- CODE_ONLY network mode (no external websites/services, no curl/wget targeting external URLs).
- Use IDE edit tools (replace_file_content / multi_replace_file_content) and never sed/awk/regex.
- Do not use const with AppColors.
- Maintain Drift/SQLite naming conventions and imports rules (e.g. Ref requires flutter_riverpod/flutter_riverpod.dart).
- Avoid Apple platform build failures (no onDidReceiveLocalNotification in DarwinInitializationSettings).
- DO NOT CHEAT: All implementations must be genuine.

## Current Parent
- Conversation ID: 287494b0-133c-453e-9e21-c234dc454552
- Updated: 2026-06-29T11:54:00-03:00

## Task Summary
- **What to build**: Native alarm, sound, and notification integrations across Android, iOS, and macOS platforms.
- **Success criteria**:
  - Integration plan generated at docs/integration_plan.md.
  - Native config permissions, receivers, and flags added to Android/iOS/macOS.
  - Swift integrations for critical alerts (swizzling/custom sound mapping) and App Nap prevention Method Channel.
  - NotificationService expanded to support critical alarms, high-priority notifications, and custom AVAudioSession audio playback settings.
  - AlarmActiveScreen updated to set up AVAudioSession playback and execute fallback beep mechanism.
  - Verification: all static analysis passes, and all tests pass.
- **Interface contracts**: docs/guia_tecnico.md
- **Code layout**: lib/core/services/notification_service.dart, lib/features/alarms/presentation/alarm_active_screen.dart

## Change Tracker
- **Files modified**:
  - `docs/integration_plan.md` — Integration plan document outlining the native APIs and strategy.
  - `android/app/src/main/AndroidManifest.xml` — Added exact alarm and full-screen intent permissions, receiver, and activity flags.
  - `android/app/src/main/kotlin/com/medicaixa/medicaixa_app/MainActivity.kt` — Programmatic window flags for lock screen / screen turn on.
  - `ios/Runner/Info.plist` — UIBackgroundModes with audio and fetch.
  - `ios/Runner/Runner.entitlements` — Critical alerts entitlement.
  - `ios/Runner/AppDelegate.swift` — Swift swizzling for critical notification sounds mapping.
  - `macos/Runner/Info.plist` — NSUserNotificationAlertStyle to alert.
  - `macos/Runner/DebugProfile.entitlements` — Critical alerts entitlement.
  - `macos/Runner/Release.entitlements` — Critical alerts entitlement.
  - `macos/Runner/AppDelegate.swift` — Method channel com.medicaixa.app/app_nap to bypass App Nap.
  - `lib/core/services/notification_service.dart` — Configured Android channel, requested critical permission, scheduled critical/time-sensitive alerts, and set up configureAudioSessionForPlayback.
  - `lib/features/alarms/presentation/alarm_active_screen.dart` — Trigger configureAudioSessionForPlayback, local/remote sound fallback, periodic haptics & SystemSound fallback beep. Also triggered Method Channel for App Nap.
  - `pubspec.yaml` — Registered assets/sounds/ assets folder.
- **Build status**: Pass (109 tests passed, 0 lint/analysis issues).
- **Pending issues**: None.

## Quality Status
- **Build/test result**: Pass (109 tests passed).
- **Lint status**: 0 issues.
- **Tests added/modified**: Verified all integration features compilation and execution.

## Key Decisions Made
- Created an offline fallback beep sound `alarm_beep.wav` via a Python helper script to supply Android raw resources, iOS/macOS bundle, and Flutter assets.
- Used method swizzling in iOS AppDelegate.swift to map standard local notifications sounds to critical alert sounds (`UNNotificationSound.criticalSoundNamed()`).
- Implemented App Nap prevention Method Channel triggered on `AlarmActiveScreen` init and stopped on close/dispose.

## Artifact Index
- `docs/integration_plan.md` — Engineering design document for native alarm integrations.
