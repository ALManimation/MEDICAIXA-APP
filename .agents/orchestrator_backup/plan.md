# Project: MediCaixa App Backup, Restore, and Reset Implementation

## Architecture
- **Offline-First / Standalone Mode**: The app reads/writes from the local SQLite database using Drift. When performing backup, restore, or reset in standalone mode, it directly acts on the local tables (`meds`, `alarms`, `reminders`, `history_events`, `settings`).
- **Connected Mode**: When connected to the ESP32 (MediCaixa device), the app acts locally AND triggers REST API endpoints on the ESP32:
  - `/backup` (GET) to download the device's backup.
  - `/restore` (POST) to restore the chosen parts.
  - `/reset` (POST) to reset the chosen partitions.
  - `/restart` (POST) to reboot the device if needed.
- **Data Sync & Modeling**: SQLite models (Drift classes) are converted to/from JSON maps with `snake_case` keys, aligning with the C++ firmware expectations.

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| 1 | Exploration & API Contracts | Explore Drift database schemas, settings screen UI layout, REST endpoints, and existing repository stubs. | None | PLANNED |
| 2 | Backup (Export) Feature | Implement local backup JSON generation for Standalone mode, and fetching from ESP32 for Connected mode. Provide download using FilePicker (Desktop) or Share (mobile). | M1 | PLANNED |
| 3 | Restore (Import) Feature | Implement backup JSON parsing, validation, local table cleanup, and row inserts. If connected, forward selected payload to ESP32 `/restore`. | M2 | PLANNED |
| 4 | Reset Feature | Implement local table wiping for selected categories. If connected, forward reset request to `/reset`. Implement disconnection and redirect to pairing screen for Wi-Fi or factory reset. | M3 | PLANNED |
| 5 | Verification & Testing | Run existing robustness tests and ensure all tests pass (`flutter test`), analyze with zero issues (`flutter analyze`). | M4 | PLANNED |

## Interface Contracts
### Backup Format (JSON)
The JSON schema of the backup file contains:
- `backup_date`: String (ISO timestamp or DD/MM/YYYY HH:mm:ss)
- `meds`: List of medications (`id`, `name`, `color`, `dosage`, `is_liquid`, `stock`, `unit`, etc.)
- `alarms`: List of alarms (`id`, `med_id`, `time`, `qty`, `frequency`, `interval_days`, `last_status_date`, `last_status`, etc.)
- `reminders`: List of reminders (`id`, `title`, `description`, `time`, `color`, `completed_dates`, etc.)
- `history`: List of history events (`id`, `med_name`, `med_color`, `status`, `event_date`, `time`, `qty`, etc.)
- `settings`: The settings object/map (`patient_name`, `speaker_volume`, `brightness`, `theme_mode`, etc.)

### ESP32 REST Endpoints
- `GET /backup` -> returns full device backup JSON
- `POST /restore` -> sends partial backup JSON, returns `{"restored_files": int}`
- `POST /reset` -> sends `{"factory": bool, "wifi": bool, "settings": bool, "meds": bool, "alarms": bool, "reminders": bool, "history": bool}`
- `POST /restart` -> restarts the ESP32

## Code Layout
- `lib/core/database/database.dart`: SQLite tables definition via Drift.
- `lib/features/settings/data/settings_repository.dart`: Manages backup download, restore payload sending, and reset requests.
- `lib/features/settings/presentation/settings_screen.dart`: UI controls for backup, restore, and reset, including dialogs.
- `test/settings_robustness_test.dart`: Automated test suite for settings features.
