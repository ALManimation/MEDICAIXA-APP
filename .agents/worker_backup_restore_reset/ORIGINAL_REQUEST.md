## 2026-06-29T11:53:31Z
You are a software implementer. Your task is to implement the backup, restore, and reset features for the MediCaixa App, operating in both Standalone (offline-first) and Connected modes.

Please refer to the following findings:
- Exploration Report: `/Users/almanimation/Downloads/Caixa Remedios/medicaixa_app/.agents/orchestrator_backup/exploration_report.md`
- Original Request Requirements: `/Users/almanimation/Downloads/Caixa Remedios/medicaixa_app/.agents/ORIGINAL_REQUEST.md` (specifically lines 433-489)
- Technical guidelines/rules in: `/Users/almanimation/Downloads/Caixa Remedios/medicaixa_app/.agents/AGENTS.md`

Your tasks:
1. Update `lib/features/settings/data/settings_repository.dart`:
   - Modify `downloadBackupJson()`: If connected, fetch from `/backup` HTTP endpoint. If offline (standalone), retrieve all records from local Drift SQLite tables (`medications`, `alarms`, `reminders`, `historyEvents`, `settings`) and serialize them to a JSON string with `snake_case` keys and `backup_date` in ISO8601 format.
   - Modify `executeBackupRestore(Map<String, dynamic> partialBackup)`: Perform local table wiping and restoration inside a database transaction. For each selected table key present in the map, delete existing rows first, then parse the `snake_case` JSON keys back to the corresponding Drift entities/companions and insert. If connected, also POST the partial backup payload to `/restore` on the ESP32.
   - Modify `DeviceResetNotifier` -> `resetDevicePartitions(Map<String, bool> payload)`: Clean up the selected tables locally in Drift SQLite. For the `settings` key, update the row back to default settings values (themeMode: 'dark', brightness: 50, speakerVolume: 20, etc.). If connected, propagate the `/reset` POST request to the ESP32. If Wi-Fi or factory reset is performed, disconnect/unpair the app and redirect to the pairing screen/standalone initialization.
2. Update `lib/features/settings/presentation/settings_screen.dart`:
   - Adjust layout so `_buildMaintenanceTile` is NOT wrapped in the Connection Guard (Opacity + IgnorePointer) container, making it always accessible in Standalone mode.
   - Guard specific buttons inside the maintenance tile (like "Reiniciar Caixinha") with connection checks to display a SnackBar error if clicked when offline.
   - Verify compliance with Rule 22 (no const when referencing AppColors, check SnackBars or other widgets) and Rule 32 (context.mounted in async callbacks).
3. Run code generation: `dart run build_runner build --delete-conflicting-outputs` (or flutter equivalent).
4. Run tests: `flutter test` and check if all tests pass.
5. Run analysis: `flutter analyze` and ensure there are 0 issues.

Write your implementation report to `/Users/almanimation/Downloads/Caixa Remedios/medicaixa_app/.agents/worker_backup_restore_reset/handoff.md`.
