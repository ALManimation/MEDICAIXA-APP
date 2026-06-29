## 2026-06-29T11:50:00Z

You are a code explorer. Your task is to investigate the backup, restore, and reset implementation details in the MediCaixa App.
Please analyze:
1. `lib/core/database/database.dart` to understand the table schema and column mapping for `meds`, `alarms`, `reminders`, `history_events`, and `settings`.
2. `lib/features/settings/data/settings_repository.dart` to see what is already implemented, what needs to be changed, and how standalone/offline modes should generate the backup JSON.
3. `lib/features/settings/presentation/settings_screen.dart` to examine the UI integration for downloading backups, restoring backups, and resetting data, and checking if there are any rule violations (Rule 22: no const with AppColors, Rule 32: context.mounted in async callbacks).
Please write your findings to `/Users/almanimation/Downloads/Caixa Remedios/medicaixa_app/.agents/orchestrator_backup/exploration_report.md` detailing:
- The Drift DB table structure and classes.
- A draft of how the JSON mapping should look for both serializing the database to JSON (backup) and deserializing from JSON to database (restore).
- Necessary adjustments in `SettingsRepository` and `settings_screen.dart`.
- Any compilation or static analysis issues you see.
