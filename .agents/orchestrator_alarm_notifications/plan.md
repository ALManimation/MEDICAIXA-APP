# Scope: Integração de Alarmes e Sons Nativos

## Architecture
- **NotificationService (`lib/core/services/notification_service.dart`)**: The central entry point in Flutter for scheduling, displaying, and canceling local notifications. Interacts with `flutter_local_notifications`.
- **Platform Manifests**:
  - Android: `android/app/src/main/AndroidManifest.xml` to declare background capabilities, full screen intent, wake lock, and exact alarms.
  - iOS: `ios/Runner/Info.plist` and `ios/Runner/Runner.entitlements` to enable critical alerts and background audio/fetch modes.
  - macOS: `macos/Runner/DebugProfile.entitlements` and `Release.entitlements` to configure sandbox permissions.
- **Lock Screen UI / Full Screen Intent**: On Android, fullScreenIntent will open the app/MainActivity to show `AlarmActiveScreen` over the lock screen when a high-priority alarm fires.

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| 1 | M1: Plano de Engenharia | Escrever `docs/integration_plan.md` detalhando a arquitetura nativa para Android, iOS e macOS. | Nenhum | DONE |
| 2 | M2: Manifestos e Configurações | Atualizar `AndroidManifest.xml`, `Info.plist` e `.entitlements` para habilitar permissões e recursos avançados. | M1 | DONE |
| 3 | M3: Extensão do NotificationService | Atualizar `notification_service.dart` com suporte a Alertas Críticos, `fullScreenIntent`, `AVAudioSession` e macOS. | M2 | DONE |
| 4 | M4: Verificação e Testes | Executar `flutter analyze` e rodar os testes unitários para garantir conformidade e build limpo. | M3 | IN_PROGRESS |

## Interface Contracts
### `NotificationService` API (Updated)
- `Future<void> init()`: Initialize notifications on all platforms. On Android, sets up high-importance channel with `fullScreenIntent`. On iOS/macOS, requests critical alert permissions.
- `Future<void> scheduleWeeklyAlarm(...)`: Schedules zoned notifications. On Android, uses exact alarms. On iOS, configures `DarwinNotificationDetails` with Critical Alerts. On macOS, leverages time-sensitive configs.
- `Future<void> cancelAlarmNotifications(int alarmId)`: Cancels notifications for an alarm.
- `Future<void> cancelAllNotifications()`: Cancels all active notifications.
