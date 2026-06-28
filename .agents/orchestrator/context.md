# Context: MediCaixa App CRUD Testing and Bug Identification

This file tracks the operational environment, dependencies, and parameters for the current testing task.

## Target Platform
- **Device**: iPhone 14 Pro Max Simulator
- **UUID**: `FAEFDC66-A2BD-4EE1-ADB5-9880A84CE09D`
- **Command to Run**: `flutter run -d FAEFDC66-A2BD-4EE1-ADB5-9880A84CE09D`

## Objectives
1. Initialize the iOS Simulator.
2. Build and run the app.
3. Review the 4 main tabs (Dashboard/Início, Medications/Remédios, Reports/Logs/Relatórios, Settings/Ajustes) for layout issues (overflows, alignment, colors, contrast).
4. Perform exploratory testing for CRUD:
   - **Medications**: Create, Edit, Delete (Verify Rule 35: block deletion if in use by an active alarm, show dialog).
   - **Alarms**: Create, Edit, Delete (Verify standard times, custom times, alternating days/PRN, persistence in Drift).
   - **Reminders**: Create, Check (Verify Rule 33: hidden on Dashboard if empty list).
5. Identify and document crashes, logic errors, concurrency issues, or alarm loops.
6. Create an automated test (integration or widget test) for at least one CRUD flow.
7. Generate a comprehensive findings report.

## Relevant Rules & Guidelines
- **Rule 22**: Do not use `const` with dynamic `AppColors`.
- **Rule 32**: Use `context.mounted` in async callbacks.
- **Rule 33**: Hide empty reminders.
- **Rule 35**: Prevent deletion of medications in use by alarms.
- **Rule 36**: AppShell must expose exactly 4 tabs (Dashboard, Medications, Reports, Settings).
- **Rule 51**: Initial screen must be Dashboard, not pairing.
- **Rule 52**: Standalone mode Settings layout (device settings blocked if disconnected).
