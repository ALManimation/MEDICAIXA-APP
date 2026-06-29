# Handoff Report — Backup, Restore, and Reset Investigation

## 1. Observation
- In `lib/core/database/database.dart`, table schemas are defined for `Alarms`, `Reminders`, `Settings`, `HistoryEvents`, and `Medications`.
- In `lib/features/settings/data/settings_repository.dart` (lines 185-212, 343-379), `downloadBackupJson()`, `executeBackupRestore()`, and `resetDevicePartitions()` are defined but throw exceptions or fail when `_isConnected()` is false.
- In `lib/features/settings/presentation/settings_screen.dart` (lines 424-451), the `_buildMaintenanceTile` is wrapped in an `Opacity` and `IgnorePointer` that disables all interactions if `connState.status != ConnectionStatus.connected`.
- In `lib/features/settings/presentation/settings_screen.dart` (e.g. lines 140, 167, 176, 209), asynchronous methods use context guards like `buildContext.mounted` prior to executing operations, complying with **Rule 32**.
- Referencing colors from `AppColors` is never done with `const` prefixes (e.g., line 1558), complying with **Rule 22**.

## 2. Logic Chain
- For backup/restore/reset to work in Standalone (offline-first) mode, the repository must perform local database reads/writes/deletes when `_isConnected()` is false.
- The C++ firmware expects all JSON parameters in `snake_case` (e.g. `patient_name`, `speaker_volume`). Consequently, serialization and deserialization in `SettingsRepository` must map Drift's camelCase parameters to/from `snake_case` maps.
- To prevent circular dependencies and follow **Rule 6 (Feature-First)**, direct mapping of Drift entities (using `json.decode` for complex columns) should be implemented directly in the `SettingsRepository` without importing the `alarms` or `reminders` feature repositories.
- Moving the `_buildMaintenanceTile` outside the `IgnorePointer` and `Opacity` container in `settings_screen.dart` is required to allow offline users to access backup/restore/reset UI features.

## 3. Caveats
- Checked static files only. Did not execute compile, test, or build commands due to role constraints.
- Assumed the ESP32 REST API matches C++ documentation and expected schemas (relying on `plan.md`).

## 4. Conclusion
- Implementing local fallback serialization/deserialization inside `SettingsRepository` and adjusting the Maintenance tile's UI layout in `settings_screen.dart` will achieve fully functional offline backup, restore, and reset.

## 5. Verification Method
- Review the compiled findings in `/Users/almanimation/Downloads/Caixa Remedios/medicaixa_app/.agents/orchestrator_backup/exploration_report.md`.
- Validate that implementing these adjustments compiles successfully under `flutter analyze`.
