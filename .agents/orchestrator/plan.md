# Plan: MediCaixa App CRUD Testing and Bug Hunting

This plan outlines the milestones and step-by-step tasks to perform comprehensive testing, verify business rules, and write automated tests.

## Milestones

### Milestone 1: Environment & Simulator Initialization
- [ ] Initialize iPhone 14 Pro Max Simulator (`FAEFDC66-A2BD-4EE1-ADB5-9880A84CE09D`).
- [ ] Run the app using `flutter run -d FAEFDC66-A2BD-4EE1-ADB5-9880A84CE09D`.
- [ ] Check all 4 main tabs of the UI (Início, Remédios, Relatórios, Ajustes) for layout issues, overflows, alignment, text/icon colors, contrast.
- [ ] Document findings on initial UI layout.

### Milestone 2: Exploratory Testing & Bug Identification
- [ ] Perform exploratory testing on Medications CRUD:
  - Create a medication, edit its details, delete it.
  - Associate a medication with an active alarm, attempt to delete it, verify Rule 35 is enforced (blocked with warning dialog).
- [ ] Perform exploratory testing on Alarms CRUD:
  - Create alarms with standard times, custom times, alternating days, and PRN.
  - Edit and delete these alarms.
  - Verify they are persisted correctly in Drift SQLite.
- [ ] Perform exploratory testing on Reminders:
  - Create and check reminders.
  - Clear all reminders, verify Rule 33 (reminders hidden on Dashboard when list is empty).
- [ ] Check for crashes, logic errors, concurrency issues, or alarm loops.
- [ ] Document all identified issues and inconsistencies.

### Milestone 3: Automated Test Creation
- [ ] Create an automated test (integration test in `integration_test/` or widget test in `test/`) covering at least one CRUD flow.
- [ ] Verify the test compiles and passes.

### Milestone 4: Review, Forensic Audit & Report Compilation
- [ ] Spawn Reviewer to check any test code created for rule compliance.
- [ ] Run Forensic Auditor on the codebase.
- [ ] Synthesize all test findings, crashes, UI layout inconsistencies, and rule adherence/violations.
- [ ] Generate the final detailed markdown report.
