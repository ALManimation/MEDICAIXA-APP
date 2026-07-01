# Handoff Report — Riverpod Notifiers Codebase Audit

This report presents a deep codebase audit of the Medicaixa Flutter application focusing on Riverpod state management, `AsyncValue` usage, memory leaks, performance, and adherence to `AGENTS.md` rules (specifically rules 3, 24, 28, 38).

---

## 1. Summary of Findings

Our codebase audit revealed:
1. **Critical rule violations** (Rule 28) regarding `late final` variables inside `Notifier` classes that re-assign on Hot Reload, causing immediate `LateInitializationError` crashes.
2. **High severity deviations** (Rule 3) where manual `isLoading` flags are implemented in state classes instead of leveraging Riverpod's native `AsyncValue`.
3. **Medium severity memory leaks** due to timer subscriptions not being cancelled on provider disposal.
4. **Medium/Low performance rebuild inefficiencies** where widgets watch the entire provider state instead of selecting specific properties.
5. **Low severity architectural anti-patterns** regarding the use of `ref.read` in build methods and manual `AsyncValue` wrapping in synchronous notifiers.

---

## 2. Audit Findings by Severity

### Critical Severity

#### Finding 1: `LateInitializationError` due to `late final` Repository in `AlarmWizardNotifier`
- **File Path**: `lib/features/alarms/presentation/wizard/alarm_wizard_notifier.dart`
- **Line Numbers**: 36, 40
- **Code Quote**:
  ```dart
  35: class AlarmWizardNotifier extends _$AlarmWizardNotifier {
  36:   late final AlarmRepository _repository;
  37: 
  38:   @override
  39:   WizardState build() {
  40:     _repository = ref.watch(alarmRepositoryProvider);
  ```
- **Description**: Storing the repository in a `late final` variable and assigning it inside `build()` directly violates Rule 28 of `AGENTS.md`. When the provider is rebuilt (e.g. during a Hot Reload or when a watched dependency changes), `build()` is executed again. Since `_repository` is `final`, this second assignment triggers a `LateInitializationError`.
- **Concrete Fix**:
  Remove the `late final` variable and use a dynamic getter:
  ```dart
  class AlarmWizardNotifier extends _$AlarmWizardNotifier {
    AlarmRepository get _repository => ref.read(alarmRepositoryProvider);

    @override
    WizardState build() {
      // No manual initialization here
  ```

#### Finding 2: `LateInitializationError` due to `late final` Repository in `PairingNotifier`
- **File Path**: `lib/features/pairing/presentation/pairing_notifier.dart`
- **Line Numbers**: 9, 13
- **Code Quote**:
  ```dart
  8: class PairingNotifier extends _$PairingNotifier {
  9:   late final ConnectionRepository _repo;
  10: 
  11:   @override
  12:   ConnectionStateInfo build() {
  13:     _repo = ref.watch(connectionRepositoryProvider);
  ```
- **Description**: Similar to Finding 1, storing `ConnectionRepository` in a `late final` class field and re-initializing it in `build()` violates Rule 28. It will crash with `LateInitializationError` upon Hot Reload or whenever `connectionRepositoryProvider` updates.
- **Concrete Fix**:
  Replace the `late final` variable with a dynamic getter:
  ```dart
  class PairingNotifier extends _$PairingNotifier {
    ConnectionRepository get _repo => ref.read(connectionRepositoryProvider);

    @override
    ConnectionStateInfo build() {
      _autoConnect();
      return const ConnectionStateInfo.disconnected();
    }
  ```

---

### High Severity

#### Finding 3: Rule 3 Violation: Manual `isLoading` State Flag in `DashboardNotifier`
- **File Path**: `lib/features/dashboard/presentation/dashboard_notifier.dart`
- **Line Numbers**: 22, 91, 131, 138, 370
- **Code Quote**:
  ```dart
  22:   final bool isLoading;
  ...
  91:       isLoading: true,
  ...
  131:     state = state.copyWith(isLoading: true);
  ...
  370:       isLoading: false,
  ```
- **Description**: `DashboardNotifier` handles its async data loading states by manually setting a `bool isLoading` flag on the `DashboardState` class and calling `copyWith(isLoading: true)` during updates. This violates Rule 3: *"AsyncValue: Use AsyncValue do Riverpod para todos os estados assíncronos. Nunca use flags manuais isLoading ou hasError."*
- **Concrete Fix**:
  Refactor `DashboardNotifier` to return an `AsyncValue<DashboardState>` instead of a plain sync state:
  ```dart
  @riverpod
  class DashboardNotifier extends _$DashboardNotifier {
    @override
    FutureOr<DashboardState> build() async {
      // Watch streams reactively or load initial state asynchronously
      ...
    }
    
    // In the UI, use state.when(data: (state) => ..., loading: () => ..., error: ...)
  }
  ```

---

### Medium Severity

#### Finding 4: Inactivity Timer Memory Leak in `DashboardNotifier`
- **File Path**: `lib/features/dashboard/presentation/dashboard_notifier.dart`
- **Line Numbers**: 65, 124, 75-79
- **Code Quote**:
  ```dart
  65:   Timer? _inactivityTimer;
  ...
  75:     ref.onDispose(() {
  76:       alarmSub.cancel();
  77:       reminderSub.cancel();
  78:       historySub.cancel();
  79:     });
  ...
  124:       _inactivityTimer = Timer(const Duration(minutes: 3), () {
  125:         resetToToday();
  126:       });
  ```
- **Description**: `DashboardNotifier` creates a `_inactivityTimer` of 3 minutes when navigating to past/future days to automatically reset to today. While it cancels the timer inside `_resetInactivityTimer()` when a new date is selected, it does **not** cancel it when the provider is disposed (e.g. when the user navigates away to another screen and the provider goes out of scope). This causes a memory leak and can trigger state modifications on a disposed notifier when the timer fires.
- **Concrete Fix**:
  Cancel the `_inactivityTimer` in the `ref.onDispose` handler:
  ```dart
  ref.onDispose(() {
    alarmSub.cancel();
    reminderSub.cancel();
    historySub.cancel();
    _inactivityTimer?.cancel(); // Cancel timer here
  });
  ```

#### Finding 5: Excess UI Rebuild Performance Issue in `AlarmCardWidget`
- **File Path**: `lib/features/dashboard/presentation/widgets/alarm_card_widget.dart`
- **Line Numbers**: 352
- **Code Quote**:
  ```dart
  350:   double _getCurrentQuantity(WidgetRef ref) {
  351:     // Watch or read the selected date from notifier to determine current weekday
  352:     final selectedDate = ref.watch(dashboardNotifierProvider).selectedDate;
  ```
- **Description**: Inside `AlarmCardWidget._getCurrentQuantity()`, it uses `ref.watch(dashboardNotifierProvider)` to retrieve `selectedDate`. Because it watches the entire `dashboardNotifierProvider` state, this card widget will rebuild every time *any* property of `DashboardState` changes (such as when `takenCount` updates, or `isLoading` changes, or when the filtered `alarms` lists update), even though the card only needs the `selectedDate` property.
- **Concrete Fix**:
  Use `ref.watch(dashboardNotifierProvider.select((s) => s.selectedDate))` so that the card only rebuilds when the selected date itself changes:
  ```dart
  final selectedDate = ref.watch(dashboardNotifierProvider.select((s) => s.selectedDate));
  ```

---

### Low Severity

#### Finding 6: Non-Idiomatic `AsyncValue` Wrapper inside Synchronous Notifiers
- **File Paths**:
  - `lib/features/settings/data/settings_repository.dart` (DeviceResetNotifier at line 748, SoundSettingsAction at line 843)
  - `lib/features/settings/data/wifi_repository.dart` (WifiActionNotifier at line 170)
- **Code Quote** (`DeviceResetNotifier` example):
  ```dart
  748: @riverpod
  749: class DeviceResetNotifier extends _$DeviceResetNotifier {
  750:   @override
  751:   AsyncValue<void> build() => const AsyncValue.data(null);
  ```
- **Description**: These notifiers use the synchronous `Notifier` base class (`AutoDisposeNotifier<AsyncValue<void>>`) and manually construct `AsyncValue` wrapper transitions (`state = const AsyncValue.loading()`, `AsyncValue.error(...)`, `AsyncValue.data(...)`) in their methods. Although functional, this is non-idiomatic. Standard Riverpod practice is to write an `AsyncNotifier` (returning `FutureOr<void>` in `build`), which lets the framework handle the asynchronous state transitions and error logging automatically.
- **Concrete Fix**:
  Refactor these notifiers to inherit from `AsyncNotifier<void>`:
  ```dart
  @riverpod
  class DeviceResetNotifier extends _$DeviceResetNotifier {
    @override
    FutureOr<void> build() => null; // Automatically initialized to AsyncData(null)
    
    Future<bool> resetDevicePartitions(Map<String, bool> payload) async {
      state = const AsyncValue.loading();
      state = await AsyncValue.guard(() async {
        ...
      });
      return !state.hasError;
    }
  }
  ```

#### Finding 7: Anti-Pattern: `ref.read` Inside `build()` and Notifier Initialization
- **File Paths**:
  - `lib/app.dart` (Line 31)
  - `lib/core/services/alarm_engine.dart` (Lines 21, 26, 29)
- **Code Quote** (`lib/app.dart`):
  ```dart
  31:     // Initialize AlarmEngine at startup (Riverpod build)
  32:     ref.read(alarmEngineProvider);
  ```
- **Description**: Calling `ref.read` inside `build()` is discouraged because it can bypass reactivity if the provider changes or is recreated. While `alarmEngineProvider`, `databaseProvider`, and `alarmRepositoryProvider` are keep-alive singletons, it is still an anti-pattern.
- **Concrete Fix**:
  Use `ref.watch(alarmEngineProvider)` inside `build()` to ensure proper dependency tracking:
  ```dart
  // Initialize AlarmEngine at startup
  ref.watch(alarmEngineProvider);
  ```

---

## 3. Observation
Observations were collected using case-insensitive `grep_search` and `view_file` calls targeting references to the `Ref` type, `@riverpod` annotations, `late final` fields inside providers, and the usage of `ref.watch` and `ref.read`.

- **Observation 1**: Checked `lib/main.dart` and verified compliance with **Rule 38**. `WidgetsFlutterBinding.ensureInitialized()` and locale configuration are correctly wrapped inside the `MCPToolkitBinding.instance.bootstrapFlutter` callback:
  ```dart
  10: void main() async {
  11:   await MCPToolkitBinding.instance.bootstrapFlutter(
  12:     runApp: () async {
  13:       WidgetsFlutterBinding.ensureInitialized();
  ```
- **Observation 2**: Verified all files utilizing the raw `Ref` type. All 9 files correctly imported `package:flutter_riverpod/flutter_riverpod.dart` along with `package:riverpod_annotation/riverpod_annotation.dart`, complying with **Rule 24**.
- **Observation 3**: Discovered that two notifiers store provider instances in `late final` fields: `AlarmWizardNotifier` (`_repository` in `lib/features/alarms/presentation/wizard/alarm_wizard_notifier.dart:36`) and `PairingNotifier` (`_repo` in `lib/features/pairing/presentation/pairing_notifier.dart:9`). During hot reload, these fields are re-assigned, leading to a `LateInitializationError` (**Rule 28**).
- **Observation 4**: Detected manual state flag `final bool isLoading;` inside `DashboardState` (managed by `DashboardNotifier`), violating **Rule 3**.
- **Observation 5**: Detected that the `_inactivityTimer` in `DashboardNotifier` is not cancelled in the `ref.onDispose` handler, posing a memory leak risk.
- **Observation 6**: Discovered `ref.watch(dashboardNotifierProvider).selectedDate` inside `AlarmCardWidget` (line 352), which forces rebuilding the card widget on any state change inside the dashboard.

---

## 4. Logic Chain

1. **Rule 28 (Late final variable reassignment)**:
   - *Observation*: `AlarmWizardNotifier` and `PairingNotifier` declare class-level fields as `late final` and assign them in `build()` via `_repository = ref.watch(...)`.
   - *Logic*: In Riverpod, a notifier is instantiated once, but its `build()` method is invoked multiple times (e.g. during hot reload or when watched dependencies emit new values). Re-executing `build()` re-assigns `late final` variables. By Dart rules, re-assigning a `final` field throws a `LateInitializationError`. Thus, these variables will crash on hot reload or dependency update.
   - *Conclusion*: A dynamic getter `AlarmRepository get _repository => ref.read(alarmRepositoryProvider);` must be used to eliminate the field-level assignment.

2. **Rule 3 (Manual state flags vs AsyncValue)**:
   - *Observation*: `DashboardNotifier` manages a `DashboardState` with a custom `isLoading` boolean.
   - *Logic*: Riverpod requires `AsyncValue` to handle loading/error states for asynchronous operations. A manual flag defeats the compiler safety of `AsyncValue.when`, requires manual reset boilerplate, and violates the offline-first/async rules of `AGENTS.md`.
   - *Conclusion*: Refactoring the notifier to inherit from `AsyncNotifier` (returning `FutureOr<DashboardState>`) is required to strictly follow Rule 3.

3. **Memory Leaks**:
   - *Observation*: `_inactivityTimer` is instantiated in `DashboardNotifier._resetInactivityTimer` but never cancelled in `ref.onDispose`.
   - *Logic*: If the `DashboardNotifier` is disposed (e.g., user navigates to settings/reports and dashboard goes out of scope), the timer remains registered in the event loop. When it fires, it calls `resetToToday()`, which tries to modify `state = state.copyWith(...)` of a disposed notifier, causing leaks or crashes.
   - *Conclusion*: The timer must be explicitly cancelled inside the `ref.onDispose` block.

4. **Performance / Rebuilds**:
   - *Observation*: `AlarmCardWidget` uses `ref.watch(dashboardNotifierProvider).selectedDate`.
   - *Logic*: Watching a provider registers a listener on the entire state. If any field of the `DashboardState` changes (like `takenCount`), `ref.watch(dashboardNotifierProvider)` triggers a rebuild of the widget.
   - *Conclusion*: Using `.select((s) => s.selectedDate)` ensures the widget is only updated when the date itself changes.

---

## 5. Caveats
- **Static Analysis Scope**: This audit was performed using static analysis only (grep search and file inspection). No runtime tests or execution traces were conducted.
- **BuildRunner**: Code generation configurations (such as in `build.yaml`) were not reviewed in detail, but inspection of `.g.dart` files indicates the generation is working as expected.
- **Mock data loading**: The backup fixture loading method (`loadSampleData`) performs heavy database writes synchronously inside the notifier. In production, database wipes/inserts should preferably be routed through repository isolates.

---

## 6. Conclusion
The codebase is mostly well-structured and follows modern Riverpod generator architectures, but suffers from severe crashes on hot-reload due to `late final` provider assignments (Rule 28), and has some technical debt regarding manual state management flags (Rule 3) and un-cancelled timers. Applying the recommended fixes will eliminate these crashes, prevent memory leaks, and optimize UI rendering.

---

## 7. Verification Method
To verify the audit findings:
1. **Rule 28 Verification**: Run the app and execute a Flutter Hot Reload. Navigate to the Alarm Wizard or Pairing screen. If `late final` variables remain, a `LateInitializationError` crash will appear in the debugger console.
2. **Rule 3 Verification**: Open `lib/features/dashboard/presentation/dashboard_notifier.dart` and inspect the class definition. Verify if `DashboardState` contains a `bool isLoading` field and if `DashboardNotifier` modifies it manually.
3. **Memory Leak Verification**: Enable Flutter DevTools Memory tab, navigate to the Dashboard page, select a date other than today (to trigger the inactivity timer), navigate away, and trigger Garbage Collection (GC). If `DashboardNotifier` remains in memory, the timer is keeping it alive.
4. **Performance Verification**: Add a print statement inside `AlarmCardWidget.build`. Mark an alarm as taken on the Dashboard. If the print triggers (even though the selected date did not change), the card widget is rebuilding unnecessarily due to watching the entire state.
