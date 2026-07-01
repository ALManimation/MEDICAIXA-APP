# Ghost Alarms & Deletion Logic Plan

This document outlines the step-by-step plan to implement alarm deletion logic and display past alarms (Ghost Alarms) in the calendar, matching the C++ original behavior.

## Milestones

| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| 7 | Codebase Investigation & Technical Design | Analyze C++ original code and current Dart database schema, repositories, and UI controllers. | None | IN_PROGRESS |
| 8 | Core Deletion & Ghost Reconstruction Logic | Implement Drift/Repository changes to support alarm deletion, history tracking, and Ghost Alarm reconstruction in memory. | M7 | PLANNED |
| 9 | Dashboard UI & Calendar Integration | Update Dashboard/Calendar widgets to render Ghost Alarms correctly (gray color, 0.55 opacity, badge, disabled clicks). | M8 | PLANNED |
| 10 | Testing, Hardening & Verification | Write unit/widget tests for all scenarios, verify all tests pass, ensure no static analysis errors, and audit codebase. | M9 | PLANNED |

---

## Technical Tasks breakdown

### Milestone 7: Codebase Investigation & Technical Design
- Spawn an Explorer to:
  1. Inspect C++ project (`../Versoes/08.90 C++ Xiaozhi/littlefs_data/www/index.html` and `components/`) to understand how alarms are deleted and how history is tracked for them.
  2. Inspect Dart Drift database file (`lib/core/database/database.dart`) and `AlarmRepository` (`lib/features/alarms/data/alarm_repository.dart`) to check if/how alarm history logs are stored (e.g. logs table, historical statuses).
  3. Inspect `lib/features/dashboard/presentation/dashboard_notifier.dart` to see how the dashboard loads alarms and historical logs.
  4. Write an architectural and technical strategy.

### Milestone 8: Core Deletion & Ghost Reconstruction Logic
- Spawn a Worker to implement the core deletion/reconstruction logic:
  1. Update `AlarmRepository` delete method. If an alarm has historical logs (taken or missed status) recorded in the database, do not delete it completely or mark it deleted (or rebuild it in-memory from logs). Let's see how C++ does it. (For example, we might mark it soft-deleted or rebuild it as a "ghost" in memory based on the logs table).
  2. Implement the in-memory reconstruction logic as requested by Rule 47: "if the history of events contains the taking of an alarm that has already been deleted from the main database, the system must recreate it in memory with the property `isGhost: true`".
  3. Ensure that if an alarm is deleted with NO history/status, it is fully removed from the database and not recreated.

### Milestone 9: Dashboard UI & Calendar Integration
- Spawn a Worker to update the UI:
  1. Add `isGhost` property to the Alarm model / entity if it doesn't exist, or handle it in the UI representation.
  2. Update `DashboardNotifier` to fetch deleted alarms that have history on past days (up to their last status date) and reconstruct them as ghost alarms.
  3. Update `AlarmCardWidget` to check `isGhost`. If true:
     - Render gray borders and icons.
     - Apply opacity of 0.55.
     - Add an "Excluído" badge.
     - Disable click interactions.
  4. Ensure Ghost Alarms do not appear in the calendar/dashboard on days subsequent to the last status date, and do not appear on future days.
  5. Check dot calculations in `CalendarStripWidget` (Rule 50).

### Milestone 10: Testing, Hardening & Verification
- Spawn a Challenger to:
  1. Write widget/unit tests verifying ghost alarm rendering on corresponding dates.
  2. Write tests verifying no ghost alarm is displayed if deleted without history.
  3. Write tests verifying no ghost alarm is displayed after its last status date.
  4. Verify all tests in the project (`flutter test`) pass.
- Spawn a Forensic Auditor to:
  1. Run integrity checks to ensure no cheats, hardcoded results, or bypasses are present in the implementation.
