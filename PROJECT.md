# Project: MediCaixa App Local Alarm and Sound Settings

## Architecture
- **Features**: Settings (`lib/features/settings/`), Alarms (`lib/features/alarms/`), Medications (`lib/features/medications/`), and Core (`lib/core/`).
- **Data Flow**:
  - Offline-first: Presentation reads settings from Drift SQLite (`database.dart`).
  - Settings Screen updates table values reactively.
  - Notification Service (`notification_service.dart`) schedules local alerts utilizing local database preferences.
  - Alarm Active Screen (`alarm_active_screen.dart`) plays sound, controls haptics, and handles inactivity dismissals.

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|---|---|---|---|
| 1 | Exploration & Design | Analyze code, locate sound assets, plan integration | None | DONE |
| 2 | Drift Schema Update | Add columns to Settings table, run build_runner | M1 | DONE |
| 3 | Settings Screen UI | Sound selector, volume slider, vibration toggle, timeout, test button | M2 | DONE |
| 4 | Alarm & Notification Integration | Wire settings to NotificationService and AlarmActiveScreen | M3 | DONE |
| 5 | Verification & Audit | Static analysis, test suites, forensic auditing | M4 | DONE |

## Code Layout
- `lib/core/database/database.dart`
- `lib/core/services/notification_service.dart`
- `lib/features/settings/presentation/settings_screen.dart`
- `lib/features/alarms/presentation/alarm_active_screen.dart`
- `assets/` (for sound files)
