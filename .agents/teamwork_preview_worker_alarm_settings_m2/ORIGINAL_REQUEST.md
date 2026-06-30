## 2026-06-29T17:14:46Z
You are tasked with implementing Milestone 2: Drift Database Schema Update.

### Tasks:
1. Update `lib/core/database/database.dart`:
   - Add the 4 columns to the `Settings` table:
     * `localAlarmSound`: IntColumn, default value 0.
     * `localAlarmVolume`: IntColumn, default value 70.
     * `localVibrationEnabled`: BoolColumn, default value true.
     * `localAlarmDurationMins`: IntColumn, default value 2.
   - Increment `schemaVersion` from `5` to `6`.
   - Update the migration strategy in `database.dart` to handle upgrading from version 5 to 6 by adding these 4 new columns to the `settings` table.
2. Run the Drift code generator to update `database.g.dart`:
   - Command: `dart run build_runner build --delete-conflicting-outputs` (in the project root directory).
3. Update `lib/features/settings/data/settings_repository.dart` to ensure default companion settings and backup/restore logic include these 4 new settings fields:
   - In `getSettings()` (or default insert logic), initialize these fields with their default values.
   - In `executeBackupRestore()` and `downloadBackupJson()`, add these fields.
4. Verify the database changes compile successfully by running `flutter analyze`.

### MANDATORY INTEGRITY WARNING
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A Forensic Auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

Write your report to `changes.md` in your working directory `/Users/almanimation/Downloads/Caixa Remedios/medicaixa_app/.agents/teamwork_preview_worker_alarm_settings_m2/` and handoff when complete.
