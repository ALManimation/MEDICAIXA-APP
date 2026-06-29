# BRIEFING — 2026-06-29T12:00:00Z

## Mission
Implement and verify backup, restore, and reset features for both Standalone and Connected modes in MediCaixa App.

## 🔒 My Identity
- Archetype: implementer
- Roles: implementer, qa, specialist
- Working directory: /Users/almanimation/Downloads/Caixa Remedios/medicaixa_app/.agents/worker_backup_restore_reset
- Original parent: 87efc6fd-3b3a-46e9-aa66-d0927134558c
- Milestone: backup-restore-reset

## 🔒 Key Constraints
- Offline-First: UI reads/writes locally.
- Standalone mode support: App works 100% without hardware.
- Snake_case JSON field names matching ESP32 firmware.
- Rule 22: Do not use const with AppColors.
- Rule 32: Use context.mounted in async callbacks.
- Rule 51: Initial opening directly to Dashboard (no forced pairing).
- Rule 52: SettingsScreen blocks physical device settings visual layout when Standalone, but keeps Maintenance tile accessible.

## Current Parent
- Conversation ID: 87efc6fd-3b3a-46e9-aa66-d0927134558c
- Updated: 2026-06-29T12:00:00Z

## Task Summary
- **What to build**: Implement Backup export/import/restore and Device partition/settings resets (local Drift + ESP32 API propagate) in Standalone/Connected. Modify settings_repository.dart and settings_screen.dart. Run build_runner, flutter test, flutter analyze.
- **Success criteria**: All backup, restore, and reset actions operate locally inside Drift db transactions in Standalone mode, and make REST calls when Connected. Settings Screen shows maintenance tile in Standalone, guards connection-required tasks. Zero failures in `flutter test` and `flutter analyze`.
- **Interface contracts**: lib/features/settings/data/settings_repository.dart and lib/features/settings/presentation/settings_screen.dart
- **Code layout**: Clean Architecture, presentation and data layers.

## Key Decisions Made
- Executed all Drift SQLite database modifications inside a transaction in `executeBackupRestore` to ensure ACID compliance during partial restores.
- Extracted the Maintenance tile from the `Opacity` + `IgnorePointer` connection wrapper to ensure all local backup, restore, and reset features are fully functional offline.
- Guarded the reboot physical device action in settings UI with a connection check that displays a SnackBar if the caixinha is offline.
- Leveraged Dart type casts in `executeBackupRestore` response parser to trigger expected TypeErrors when a malformed payload is returned from `/restore` (maintaining 100% test compatibility).
- Added `settings_device_offline_reboot_error` translations to `pt.json`, `en.json`, and `es.json` to keep localized errors robust.

## Change Tracker
- **Files modified**:
  - `lib/features/settings/data/settings_repository.dart` — Modify `downloadBackupJson`, `executeBackupRestore`, and `DeviceResetNotifier` to run database tasks locally/remotely.
  - `lib/features/settings/presentation/settings_screen.dart` — Expose Maintenance tile offline and guard reboot action.
  - `assets/lang/pt.json`, `assets/lang/en.json`, `assets/lang/es.json` — Add reboot offline error message key.
- **Build status**: Pass (code generation completed, tests passed, analysis succeeded)
- **Pending issues**: None

## Quality Status
- **Build/test result**: All 104 tests passed successfully (`flutter test`).
- **Lint status**: 0 issues found (`flutter analyze`).
- **Tests added/modified**: Covered robust validation tests for `executeBackupRestore` and `DeviceResetNotifier`.

## Artifact Index
- /Users/almanimation/Downloads/Caixa Remedios/medicaixa_app/.agents/worker_backup_restore_reset/handoff.md — Final Handoff Report
- /Users/almanimation/Downloads/Caixa Remedios/medicaixa_app/.agents/worker_backup_restore_reset/progress.md — Task Progress Tracker
