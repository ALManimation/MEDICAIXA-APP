# Plan: MediCaixa App Bug Fixes and Hardware Alignment

This plan outlines the milestones and step-by-step tasks to address the bug fixes requested in the root ORIGINAL_REQUEST.md.

## Milestones

### Milestone 1: Technical Exploration and Setup
- [x] Analyze requirements and identify relevant file paths (completed during first turn).
- [ ] Schedule heartbeat cron to monitor subagent progress.

### Milestone 2: Implement UI and Interaction Fixes (R1, R2, R4)
- [ ] Fix snooze active screen dismissal: Set alarm status to 'SNOOZED' in `snoozeAlarm` in `alarm_repository.dart` to automatically trigger stream updates.
- [ ] Fix bottom RenderFlex overflow in `SnoozeModal` by wrapping controls in a `SingleChildScrollView` with safe paddings.
- [ ] Make Dashboard FAB round (`CircleBorder`).

### Milestone 3: Implement Dashboard Calendar Flickering Fix (R3)
- [ ] Modify `DashboardScreen` to preserve layout during loading states: remove full-screen loading spinner, keeping the Scaffold body intact and displaying a discrete `LinearProgressIndicator` at the top.

### Milestone 4: Color Synchronization & Pallette Expansion (R5)
- [ ] Expand medication and alarm color pickers to 15 official hardware colors dynamically from `AppColors.alarmColors`.
- [ ] Pre-select medication color in `wizard_step_medication.dart` if a medication with the same name exists in the database.
- [ ] Save or update medication color in the local database when saving an alarm in the wizard (`saveAlarm` in `wizard_notifier.dart`).
- [ ] Centralize color inheritance for alarms by doing a left outer join between `alarms` and `medications` inside `watchAllAlarms()` and `getAllAlarms()` in `alarm_repository.dart`.
- [ ] Restrict reminder color picker to the 15 official hardware colors.

### Milestone 5: Verification & Audit
- [ ] Run automated tests and analyze the project code using `flutter analyze` to ensure zero compilation or static analysis issues.
- [ ] Perform a forensic audit to verify that all code changes comply with instructions and rules.
- [ ] Synthesize findings and report completion.
