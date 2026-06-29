# Project: MediCaixa App Bug Fixes and Hardware Alignment

## Architecture
- **Features**: Alarms (`lib/features/alarms/`), Medications (`lib/features/medications/`), Reminders (`lib/features/reminders/`), and Dashboard (`lib/features/dashboard/`).
- **Data Flow**:
  - Offline-first: Presentation reads from Drift SQLite.
  - Alarms and Medications are synced with the ESP32 hardware using `DioClient` with serialized request queueing.
  - AppShell exposes Início, Remédios, Relatórios, and Ajustes.

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|---|---|---|---|
| 1 | Exploration & Design | Analyze requirements, identify file paths, and plan overrides | None | DONE |
| 2 | UI & Interaction Fixes | Implement snooze screen close, modal RenderFlex fix, and round FAB | M1 | DONE |
| 3 | Flicker Prevention | Replace full-screen loading spinner in Dashboard Calendar with LinearProgressIndicator | M2 | DONE |
| 4 | Color Sync & Palettes | Implement 15 official hardware colors in picker options, pre-select wizard colors, propagate color on save, and join queries for central color inheritance | M3 | DONE |
| 5 | Verification & Audit | Verify build, run test suite, and execute Forensic Audit | M4 | DONE |

## Code Layout
- `lib/core/constants/app_colors.dart`
- `lib/features/alarms/data/alarm_repository.dart`
- `lib/features/alarms/presentation/alarm_active_screen.dart`
- `lib/features/alarms/presentation/snooze_modal.dart`
- `lib/features/alarms/presentation/wizard/wizard_notifier.dart`
- `lib/features/alarms/presentation/wizard/steps/wizard_step_options.dart`
- `lib/features/alarms/presentation/wizard/steps/wizard_step_medication.dart`
- `lib/features/medications/presentation/medication_form_screen.dart`
- `lib/features/reminders/presentation/reminder_form_screen.dart`
- `lib/features/dashboard/presentation/dashboard_screen.dart`
