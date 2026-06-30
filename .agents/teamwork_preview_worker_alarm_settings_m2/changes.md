# Changes - Drift Database Schema Update (Milestone 2)

## Files Modified
1. `lib/core/database/database.dart`
   - Added columns to `Settings` Drift table: `localAlarmSound`, `localAlarmVolume`, `localVibrationEnabled`, `localAlarmDurationMins`.
   - Incremented `schemaVersion` from `5` to `6`.
   - Updated `onUpgrade` migration strategy to include the 4 new columns when migrating from version 5 or lower.
2. `lib/features/settings/data/settings_repository.dart`
   - Initialized the new columns with default values in the default fallback row within `getSettings()`.
   - Updated `downloadBackupJson()` to include the 4 new settings keys serialized in snake_case format: `local_alarm_sound`, `local_alarm_volume`, `local_vibration_enabled`, and `local_alarm_duration_mins`.
   - Updated `executeBackupRestore()` to support extracting and mapping these keys during restore.
   - Updated `DeviceResetNotifier` factory reset settings defaults to include the new columns' default values.

## Design Decisions
- **Non-nullable Fields with Defaults**: The columns are non-nullable and set with appropriate defaults at database creation time to maintain data integrity and avoid runtime null check errors.
- **Sequential Migration Strategy**: Migrations check `if (from < 6)` to conditionally add columns, keeping the schema versioning sequential.
- **Snake-case JSON Representation**: Standardized setting backup keys to snake_case (`local_alarm_sound`, etc.) to stay compatible with existing backend integration patterns.

## Verification
- **Code Generation**: Run `dart run build_runner build --delete-conflicting-outputs` which completed with output `Built with build_runner in 28s; wrote 186 outputs.`
- **Static Analysis**: `flutter analyze` completed successfully: `No issues found!`
- **Tests**: `flutter test` completed successfully: `All tests passed!` (128 tests).
