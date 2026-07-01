## Challenge Summary

**Overall risk assessment**: LOW

All verification tests run by the Challenger completed successfully. The project was audited for memory leaks, lifecycle robustness under Hot Reloading, and query performance in widgets. Milestone 1 modifications successfully resolve the previously identified leaks and crash triggers while maintaining full functional compatibility and performance.

---

## Challenges

### [Low Risk] Challenge 1: Hot Reload Safety (LateInitializationError Prevention)
- **Assumption challenged**: Notifier instances are completely re-instantiated during Flutter Hot Reloads.
- **Attack scenario**: During hot reload, the notifier state and instances are preserved, but their `build()` method is re-executed. If dependencies are assigned to `late final` variables inside `build()`, a `LateInitializationError` is thrown on re-execution.
- **Blast radius**: Entire application crash during local development on any code edit in settings or pairing views.
- **Mitigation**: Replacing `late final` fields with dynamic, type-safe getters that read from the `ref` on demand (e.g., `ConnectionRepository get _repo => ref.read(connectionRepositoryProvider)`). This has been verified to execute multiple times on a single notifier instance without throwing any initialization errors.

### [Low Risk] Challenge 2: Memory Leak & Safety in DashboardNotifier
- **Assumption challenged**: Disposal of Riverpod providers automatically cancels all active timers and stream subscriptions registered within them.
- **Attack scenario**: When a provider is disposed, standard Dart timers do not automatically cancel unless explicitly handled. If a user navigates away from the Dashboard screen, the `DashboardNotifier` is disposed. An active inactivity timer (configured to reset to today after 3 minutes) would execute its callback later. The callback calls `resetToToday()`, which writes to `state` on the disposed notifier, resulting in a fatal runtime `StateError`.
- **Blast radius**: Memory leak of the disposed notifier instance and possible background crashes/state errors when the timer triggers.
- **Mitigation**: Verified that stream subscriptions and `_inactivityTimer` are cancelled inside `ref.onDispose()`.
- **Stress test validation**: A mock container was disposed with an active timer; advancing the fake async zone by 4 minutes triggered no errors and verified that no state updates were attempted on the disposed notifier.

### [Low Risk] Challenge 3: Widget Rebuild Performance on AlarmCardWidget
- **Assumption challenged**: The widget needs to watch the entire dashboard state to get the selected date.
- **Attack scenario**: If `AlarmCardWidget` watches the full `dashboardNotifierProvider`, any state update (such as updates to loading state, logs, alarm status, or unrelated lists) will cause every visible `AlarmCardWidget` to rebuild.
- **Blast radius**: Degraded UI performance, frame drops, and redundant layout cycles on screens with a large number of alarms.
- **Mitigation**: Replaced full provider watch with a target-specific select query: `ref.watch(dashboardNotifierProvider.select((s) => s.value?.selectedDate ?? DateTime.now()))`. This guarantees the widget only rebuilds if the selected date changes, rather than on every state mutation.
- **Verification**: Verified that the selected date sub-state is resolved correctly and returns the appropriate day-specific quantity from asymmetric quantities list.

---

## Stress Test Results

- **Hot Reload Stability** → Re-running `build()` on the same `PairingNotifier` instance → Returns normally without `LateInitializationError` → **PASS**
- **Inactivity Timer Disposal** → Dispose `DashboardNotifier` with active timer & advance time → No errors/leaks triggered in fake async zone → **PASS**
- **AlarmCardWidget Query Correctness** → Select weekday with asymmetric quantity and verify details rendering → Correct day quantity matches (index 1 of `daysQuantity` = 1.0) → **PASS**
- **Full Test Suite Validation** → Execute `flutter test` on the entire test suite → 220/220 tests passed successfully → **PASS**

---

## Unchallenged Areas

- **C++ Webserver / ESP32 physical connection** — Reason not challenged: Out of scope. We operate under Standalone/Mock environment constraints inside the local Flutter workspace.
