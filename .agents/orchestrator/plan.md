# Plan — MediCaixa App Comprehensive Bugfixes & New Features

## Objective
Implement all bug fixes, layout enhancements, advanced native notification configurations, color synchronization, and custom standardized input controls as requested in `ORIGINAL_REQUEST.md`.

## Milestones

### Milestone 1: Exploratory Analysis & Technical Design
- Explore all screens, dialogs, wizard steps, database files, and native configuration files.
- Understand the existing code for:
  - AlarmActiveScreen snooze button.
  - SnoozeModal (RenderFlex overflow).
  - Dashboard screen state loading / calendar strip chevrons / WeeklyRhythmWidget.
  - Color palettes and DB mapping in drift.
  - Native config files: AndroidManifest, Info.plist, entitlements.
  - NotificationService setup.
  - Steppers and Date/Time picker dialogs.
- Outputs: Detailed investigation report and layout/code analysis.

### Milestone 2: Basic Bug Fixes and UI Tweaks
- **R1 (Active Alarm Screen)**: Ensure "Adiar 10 min" pops/dismisses the alarm active screen.
- **R2 (Snooze Modal)**: Wrap `SnoozeModal` contents in a `SingleChildScrollView` or adjust padding/SafeArea to fix RenderFlex overflow.
- **R3 (Dashboard loading flicker)**: Update `dashboard_screen.dart` loading state to preserve existing layout (or use a subtle progress indicator) instead of a full screen loading widget.
- **R4 (Dashboard FAB)**: Configure `shape: const CircleBorder()` on the Dashboard FAB.
- **R5 (Calendar Strip arrows)**: Remove lateral Positioned chevrons and return the `ListView.builder` cleanly.
- **R6 (Weekly Rhythm removal)**: Remove `WeeklyRhythmWidget` and related database/history calls from the Dashboard.

### Milestone 3: Color Sync & Palettes
- Update the colors grid in both medication screens and alarm wizard steps to display all 15 official hardware colors.
- Implement bidirectional synchronization:
  - If a medication is chosen in the wizard, pre-select its database color in the alarm wizard colors step.
  - Changing the color of an alarm or choosing a color for a new medication updates/synchronizes the medication color in the DB.
  - Ensure reminder color assignment uses only the 15 official colors.

### Milestone 4: Responsive Grid Layouts
- Implement GridView layouts (when screen width >= 800px) with `SliverGridDelegateWithMaxCrossAxisExtent` (max 400px width) for:
  - Dashboard alarms and reminders.
  - Medications list screen.
- Ensure smooth scaling and zero overflow on window resize.

### Milestone 5: Advanced Native Notifications & OS Configuration
- Document integration design in `docs/integration_plan.md`.
- Configure `AndroidManifest.xml` with permissions: `USE_FULL_SCREEN_INTENT`, `SCHEDULE_EXACT_ALARM`, `USE_EXACT_ALARM`, `WAKE_LOCK`, `RECEIVE_BOOT_COMPLETED`.
- Configure iOS `Info.plist` and entitlements for Critical Alerts and Background Modes (audio, fetch).
- Configure macOS entitlements for networking/notifications.
- Update `NotificationService` for Android `fullScreenIntent` (loading `AlarmActiveScreen`), iOS critical notifications with audio session playback initialization, and macOS Time-Sensitive documentation/support.

### Milestone 6: Custom Steppers and Vertical DateTime Selectors
- Implement standardized stepper widget (width 160px-180px, (+/-) buttons, option for "+ ½" sub-button).
- Implement vertical DateTime selector (+ on top, - at bottom) with fast touch and accelerated long-press (>2s).
- Integrate new widgets in all screens: alarm wizard steps, snooze modal, reminders form, settings screen, etc.

### Milestone 7: Testing and Integrity Audit
- Run static analysis (`flutter analyze`) and tests (`flutter test`).
- Ensure no warnings, errors, or lints.
- Run a Forensic Audit to verify integrity compliance.
- Final verify that 100% of features work standalone and with proper alignment to C++ specs.
