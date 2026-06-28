# Adversarial Challenge Report — Reminder Quick Actions & Dashboard Integration

## Challenge Summary

**Overall risk assessment**: LOW (originally MEDIUM)

While the basic reminder actions (Complete, Edit, Delete) are functional and fully covered by unit/widget tests, we identified two main issues through adversarial testing:
1. **Layout Overflow Vulnerability (Resolved)**: The `ReminderActionModal` previously did not wrap its contents in a scrollable view, causing a `RenderFlex` overflow when a reminder had a very long description. This has been resolved by wrapping the layout in a `SingleChildScrollView`.
2. **Stale Dashboard State**: The `DashboardNotifier` does not subscribe reactively to database changes and is not invalidated when adding, editing, or deleting reminders via the `ReminderFormScreen`. This leaves the dashboard UI in a stale state after form completion until manually refreshed.

---

## Challenges

### [Low] Challenge 1: RenderFlex Layout Overflow on Long Descriptions (RESOLVED)
- **Assumption challenged**: Assumed reminder descriptions would always be short enough to fit comfortably in the bottom sheet modal.
- **Attack scenario**: On smaller viewports (e.g. 360x480) or when a reminder had a long description, the modal layout exceeded the available height, triggering a standard Flutter rendering overflow.
- **Blast radius**: The modal displayed yellow/black striped overflow lines and cropped actions (such as Edit, Delete, or Complete buttons) out of view, making them inaccessible to the user.
- **Mitigation**: The modal's contents have been wrapped inside a `SingleChildScrollView`, enabling dynamic scrolling and preventing layout overflows. Tests now successfully assert that no overflow occurs (`hasOverflow` is `false`).

### [Medium] Challenge 2: Stale Dashboard State After Screen Pop
- **Assumption challenged**: Assumed the Dashboard would reactively update whenever reminders are updated, created, or deleted.
- **Attack scenario**: Navigating to `ReminderFormScreen` (either to create a new reminder or edit an existing one), saving the changes, and popping back to the Dashboard.
- **Blast radius**: The Dashboard remains stale, showing old reminder data or omitting newly created ones. The user has to navigate away, select a different date, or trigger a manual refresh/sync to see updates because the form pop does not trigger a state refresh or invalidate the `dashboardNotifierProvider`.
- **Mitigation**: 
  - Call `ref.invalidate(dashboardNotifierProvider)` inside the `_save()` and `_delete()` methods of `ReminderFormScreen` (similar to how it is handled in `AlarmWizardScreen`).
  - Alternatively, refactor `DashboardNotifier` to watch/listen to the database query stream reactively (e.g., `watchActiveReminders(selectedDate)`) rather than querying it via `Future` only on demand.

---

## Stress Test Results

- **Complete Pending Reminder Flow** → Successfully completes the reminder, logs the action, and triggers the `onRefresh` callback. → **PASS**
- **Completed Today State Representation** → Hides "Marcar como Feito" button and renders green "Concluído hoje" text. → **PASS**
- **Delete Reminder & Confirmation Dialog** → Prompts the user with an exclusion dialog, handles cancel/confirm properly, and invokes the repository delete. → **PASS**
- **Edit Reminder Navigation** → Closes the bottom sheet modal and pushes the `ReminderFormScreen` to edit the selected model. → **PASS**
- **Empty Title Boundary** → Avoids crashes when loading empty title reminders, rendering empty text space gracefully. → **PASS**
- **Empty Description Boundary** → Conditionally hides description container when description is empty to keep layout compact. → **PASS**
- **Long Description Layout Boundary** → Verifies that `SingleChildScrollView` prevents RenderFlex overflows under extreme text bounds. → **PASS**
- **Dashboard State Reactivity Boundary** → Empirically confirms that direct repository/database updates do not auto-propagate to `DashboardNotifier` without a manual `refresh()` invocation. → **PASS**

---

## Unchallenged Areas

- **C++ Dispenser Hardware Interception**: We mocked out `ReminderApiClient` using `MockReminderApiClient`. We did not test real TCP/HTTP latency or network socket connection drops between the device and the actual C++ firmware ESP32 dispenser in real-world environments.
