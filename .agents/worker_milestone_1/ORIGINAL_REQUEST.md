## 2026-07-01T12:26:10Z

You are the Worker agent responsible for Milestone 1: State, Architecture & Memory Leaks (State & UI Cleanup).
Your task is to implement code changes for the following findings described in /Users/almanimation/Downloads/Caixa Remedios/medicaixa_app/audit_report.md and /Users/almanimation/Downloads/Caixa Remedios/medicaixa_app/.agents/explorer_3/analysis.md:

1. Finding 1.1: LateInitializationError due to late final Fields in Notifiers
   - Refactor lib/features/pairing/presentation/pairing_notifier.dart to remove the late final ConnectionRepository _repo field and replace it with a dynamic getter ConnectionRepository get _repo => ref.read(connectionRepositoryProvider). Remove its assignment from build().
   - (Note: lib/features/alarms/presentation/wizard/alarm_wizard_notifier.dart is obsolete and will be deleted in the next step, so do not refactor it).

2. Finding 4.7: Dead Code (Unused Legacy Wizard Classes)
   - Remove these obsolete files from the project:
     - lib/features/alarms/presentation/wizard/alarm_wizard_notifier.dart
     - lib/features/alarms/presentation/wizard/alarm_wizard_notifier.g.dart
     - lib/features/alarms/presentation/wizard/steps/wizard_step_dosage.dart
     - lib/features/alarms/presentation/wizard/steps/wizard_step_medication.dart
     - lib/features/alarms/presentation/wizard/steps/wizard_step_options.dart
     - lib/features/alarms/presentation/wizard/steps/wizard_step_schedule.dart

3. Finding 2.1: Manual isLoading State Flags Instead of AsyncValue in DashboardNotifier
   - In lib/features/dashboard/presentation/dashboard_notifier.dart:
     - Remove `isLoading` from the `DashboardState` class and update the constructor and copyWith method.
     - Refactor `DashboardNotifier` to extend `AsyncNotifier<DashboardState>` and return `FutureOr<DashboardState>` in `build()`.
     - In `build()`, watch database streams and reload the notifier reactively. Call ref.onDispose to cancel the subscriptions and the inactivity timer.
     - Update all status mutation methods (sync, loadSampleData, _updateData, selectDate, resetToToday) to manage `state` using standard AsyncNotifier conventions (const AsyncLoading(), AsyncValue.data(updated), AsyncValue.error(e, st)).
   - In lib/features/dashboard/presentation/dashboard_screen.dart:
     - Update `build` method to watch `dashboardNotifierProvider` as an `AsyncValue<DashboardState>`.
     - Replace checks of `state.isLoading` with `asyncState.isLoading`, and obtain the current `state = asyncState.valueOrNull`.
     - Add a loading fallback if `state == null`.
     - Update `ref.listen` on selectedDate to use `s.value?.selectedDate`.

4. Finding 3.2: Layer Violations (Presentation-to-Data Bleeding)
   - Create a global connection state provider `deviceConnectionStateProvider` in `lib/core/providers/connection_providers.dart` (use @riverpod to generate it, returning ConnectionStateInfo.disconnected() initially, and providing an update method).
   - In lib/features/pairing/presentation/pairing_notifier.dart, synchronize pairing notifier's state to the global provider using `ref.listenSelf` inside build().
   - In the following repositories, replace the direct import and reading of `pairingNotifierProvider` with `deviceConnectionStateProvider` (from lib/core/providers/connection_providers.dart):
     - lib/features/alarms/data/alarm_repository.dart
     - lib/features/settings/data/settings_repository.dart
     - lib/features/reminders/data/reminder_repository.dart
     - lib/features/medications/data/medication_repository.dart
     - lib/features/settings/data/wifi_repository.dart

5. Finding 3.3: Dashboard Inactivity Timer Memory Leak
   - Cancel the `_inactivityTimer` in the `ref.onDispose` block of `DashboardNotifier`.

6. Finding 4.4: Inefficient UI Rebuilds in AlarmCardWidget
   - In lib/features/dashboard/presentation/widgets/alarm_card_widget.dart, watch `selectedDate` selectively using:
     `final selectedDate = ref.watch(dashboardNotifierProvider.select((s) => s.value?.selectedDate ?? DateTime.now()));`

7. Finding 4.6: Non-Idiomatic AsyncValue Usage in Synchronous Notifiers
   - In lib/features/settings/data/settings_repository.dart (`DeviceResetNotifier`, `SoundSettingsAction`) and lib/features/settings/data/wifi_repository.dart (`WifiActionNotifier`):
     - Refactor these classes to extend `AsyncNotifier<void>` and return `FutureOr<void>` in `build()` instead of returning `AsyncValue<void>` from a standard Notifier.

8. Code Generation:
   - Run `dart run build_runner build --delete-conflicting-outputs` to regenerate Riverpod code.
   - Run `flutter test` to ensure there are no compilation errors or test regressions.
