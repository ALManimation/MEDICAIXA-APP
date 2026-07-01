# Challenge Report — Milestone 1 Remediation

**Overall risk assessment**: LOW

All verification tests and parallel runs have succeeded. The critical issue of loading flickering during database stream writes and data synchronization has been fully resolved. Static analysis checks and a high-concurrency test run have validated the robustness of the implementation.

---

## Challenges

### [Low Risk] Challenge 1: Redundant Stream Initial Events & Race Conditions
- **Assumption challenged**: Drift's `watchAllAlarms()` and other reactive streams emit their initial dataset as their first event. Subscribing to them without `.skip(1)` triggered immediate redundant state updates during notifier initialization.
- **Attack scenario**: A concurrent database write happens exactly during initialization.
- **Blast radius**: If the initial event is skipped, does the system miss the concurrent write?
- **Mitigation/Verification**:
  - The notifier's `build()` method asynchronously calls `_performUpdate()` directly, executing after the stream listeners have been registered.
  - Since Dart's stream subscriptions are set up first, any write that happens while `build()` is starting will trigger a secondary stream event (event #2), which is NOT skipped and will correctly trigger `_updateData()`.
  - Any write prior to subscription will already be fetched by the initial `_performUpdate()` database query.
  - We verified this timing safety and correctness in `test/milestone_1_challenger_test.dart` and `test/challenge_dst_test.dart`.

### [Low Risk] Challenge 2: Hot-Reload and LateInitializationError in PairingNotifier
- **Assumption challenged**: Storing providers or repositories in `late final` variables within Riverpod Notifiers will cause crashes on Hot Reload.
- **Attack scenario**: Flutter developer triggers a Hot Reload in development or tests run multiple builds.
- **Blast radius**: App crashes with `LateInitializationError: Field '_repo' has already been initialized.`
- **Mitigation**:
  - Refactored `late final ConnectionRepository _repo;` to a dynamic getter: `ConnectionRepository get _repo => ref.read(connectionRepositoryProvider);`.
  - Since getters are dynamic and read the provider state on demand, hot reload safely recreates the notifier and queries the repository without re-assignment.
  - Verifiable through the test: `1. Hot Reload Safety: PairingNotifier does not throw LateInitializationError on multiple builds` which passes.

### [Low Risk] Challenge 3: Jarring UX and Blank Screen Flicker on Sync
- **Assumption challenged**: Setting `state = const AsyncLoading()` during background network/disk actions resets the state, forcing the UI to display a blank page with a loading spinner.
- **Attack scenario**: The user triggers synchronization or loads sample data.
- **Blast radius**: The entire dashboard vanishes for 1-2 seconds, causing visual disorientation.
- **Mitigation**:
  - Replaced simple `AsyncLoading` with `.copyWithPrevious(state)`: `state = const AsyncLoading<DashboardState>().copyWithPrevious(state);`.
  - The UI now preserves the previous alarms and reminders in memory while the loading flag is active.
  - The UI (`dashboard_screen.dart`) checks `asyncState.isLoading` to show a non-intrusive `LinearProgressIndicator` and a subtle opacity shift (0.65) rather than rendering a blank page.

---

## Stress Test Results

| Test Scenario / Command | Expected Behavior | Actual Behavior | Pass/Fail |
|---|---|---|---|
| Run Challenger Test Suite (`flutter test test/milestone_1_challenger_test.dart`) | 3 tests run, all assert successfully, verifying hot reload safety, memory leaks/timers, and widget correctness. | 3 tests passed without error. | **PASS** |
| Run full test suite (`flutter test`) | 223 unit and widget tests pass. | 223 tests passed. | **PASS** |
| Concurrency stress run (`flutter test -j 8`) | Run all 223 tests in parallel with high process concurrency. No race conditions, file locks, or database collision crashes. | 223 tests passed in parallel successfully. | **PASS** |
| State transitions during database writes | Non-flickering background update of UI state directly from `AsyncData(old)` to `AsyncData(new)`. | Handled smoothly, list elements update inline. | **PASS** |

---

## Unchallenged Areas

- **Platform-specific local notifications** — Not fully challenged on physical devices (iOS/Android/macOS) due to testing environment limits, though mock platform behavior in tests works flawlessly.
- **Hardware ESP32 network sync latency** — Network latency on real hardware is not simulated in unit/widget tests.
