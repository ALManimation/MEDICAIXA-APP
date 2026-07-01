# Handoff Report — explorer_3

## 1. Observation
We examined all 17 files listed in the user request:
- `lib/features/alarms/presentation/wizard/alarm_wizard_notifier.dart` (Line 36: `late final AlarmRepository _repository;` in `class AlarmWizardNotifier extends _$AlarmWizardNotifier`)
- `lib/features/pairing/presentation/pairing_notifier.dart` (Line 9: `late final ConnectionRepository _repo;` in `class PairingNotifier extends _$PairingNotifier`)
- `lib/features/medications/data/medication_repository.dart` (Lines 213–222: `deleteMedication` does not verify alarm usage; Lines 261–266: `syncWithDevice` delete loop; Line 90: `import '../../pairing/presentation/pairing_notifier.dart';`)
- `lib/features/medications/presentation/medications_list_screen.dart` (Lines 140–142: calls `deleteMedication`)
- `lib/features/medications/presentation/medication_form_screen.dart` (Line 144: calls `deleteMedication`)
- `lib/features/dashboard/presentation/dashboard_notifier.dart` (Line 22: `final bool isLoading;` in `DashboardState`; Line 65: `Timer? _inactivityTimer;` is not cancelled in `ref.onDispose`; Line 370: sets `isLoading: false`)
- `lib/features/alarms/data/alarm_repository.dart` (Line 10: `import '../../pairing/presentation/pairing_notifier.dart';`; Line 949: `extension AlarmModelCopyWith on AlarmModel` lacks support for explicit null overrides)
- `lib/features/settings/data/settings_repository.dart` (Line 9: `import 'package:medicaixa_app/features/pairing/presentation/pairing_notifier.dart';`; Line 748: `class DeviceResetNotifier extends _$DeviceResetNotifier` returns `AsyncValue<void>` in `build()`; Line 843: `class SoundSettingsAction extends _$SoundSettingsAction`)
- `lib/features/reminders/data/reminder_repository.dart` (Line 10: `import '../../pairing/presentation/pairing_notifier.dart';`; Line 406: `extension ReminderModelCopyWith on ReminderModel` lacks support for explicit null overrides)
- `lib/features/settings/data/wifi_repository.dart` (Line 6: `import 'package:medicaixa_app/features/pairing/presentation/pairing_notifier.dart';`; Line 170: `class WifiActionNotifier extends _$WifiActionNotifier` returns `AsyncValue<void>`)
- `lib/features/dashboard/presentation/dashboard_screen.dart` (Lines 402–427: `_getMissedCountForSection` does not filter out disabled/inactive alarms)
- `lib/features/settings/presentation/settings_screen.dart` (Line 244: `final Map<String, dynamic> rawMap = json.decode(content);` executed synchronously; Line 787: `DropdownMenuItem(value: 0, child: Text('Beep', ...))`)
- `lib/core/services/notification_service.dart` (Line 91: `tz.setLocalLocation(tz.UTC);` on timezone lookup failure; Line 145: `case 0: resolvedSound = 'alarm_gentile';`)
- `lib/features/alarms/presentation/alarm_active_screen.dart` (Line 172: `case 0: soundPath = 'sounds/alarm_gentile.wav';`)
- `lib/features/alarms/data/medication_search_service.dart` (Line 51: `final decompressed = gzip.decode(bytes);` - duplicates ANVISA loading logic of `MedicationRepository`)
- `lib/features/dashboard/presentation/widgets/alarm_card_widget.dart` (Line 352: watches the entire `dashboardNotifierProvider` for `selectedDate`)
- `lib/core/services/alarm_engine.dart` (Line 104-114: relies on `tz.local` initialized by `NotificationService`)

## 2. Logic Chain
1. **Finding 1.1**: The code uses `late final` fields assigned in `build()` which is executed multiple times by Riverpod on Hot Reloads, causing `LateInitializationError`. The logic step is to replace them with dynamic `ref.read` getters.
2. **Finding 1.2**: Deletion of medications directly in the database table can leave orphaned alarms and compromise database consistency. The logic step is to query `_db.alarms` inside `deleteMedication()` and `syncWithDevice()` to ensure in-use medications are blocked/skipped.
3. **Finding 2.1**: The manual `isLoading` flag inside `DashboardState` violates Rule 3. The logic step is refactoring the notifier to extend `AsyncNotifier<DashboardState>`, allowing `AsyncValue` to handle loading/error states.
4. **Finding 3.2**: Repositories directly import `pairing_notifier.dart` from the presentation layer. The logic step is creating a global, core/domain level `deviceConnectionStateProvider` to decouple database repositories from presentation logic.
5. **Finding 3.3**: The inactivity timer is not cancelled when `DashboardNotifier` is disposed, causing potential memory leaks. The logic step is adding `_inactivityTimer?.cancel()` in `ref.onDispose`.
6. **Finding 3.4**: Dropping option 0 is labeled "Beep" in settings, but plays "Gentil" in the active alarm. The logic step is renaming the item to "Gentil".
7. **Finding 3.5**: `_getMissedCountForSection` does not filter out disabled alarms, counting them as missed. The logic step is checking `!alarm.enabled || !alarm.active` and continuing.
8. **Finding 4.1**: `copyWith` logic retains values when `null` is passed due to `value ?? this.value`. The logic step is using a `Sentinel` or custom wrapper to allow explicit `null` updates.
9. **Finding 4.2**: Both `MedicationRepository` and `MedicationSearchService` decompress the same large gzipped database asset. The logic step is removing `loadDatabase` from the repository and redirecting search requests to `MedicationSearchService`.
10. **Finding 4.3**: Sync JSON decoding on the UI thread blocks UI execution. The logic step is utilizing Flutter's `compute` to parse in the background.
11. **Finding 4.4**: Rebuilding `AlarmCardWidget` on any dashboard update is inefficient. The logic step is utilizing Riverpod `select` to watch only the `selectedDate` property.
12. **Finding 4.5**: Timezone failure defaults to UTC, causing offset alarms. The logic step is guessing the local timezone from the system offset.
13. **Finding 4.6**: Action notifiers extend code-generated `Notifier<AsyncValue<void>>` instead of `AsyncNotifier<void>`. The logic step is refactoring `build()` signatures.
14. **Finding 4.7**: Obsolete files like `alarm_wizard_notifier.dart` and `wizard_step_*.dart` are unused and should be removed.

## 3. Caveats
No caveats. The analysis covers all 14 issues, identifies the exact file paths, line numbers, and proposes direct, step-by-step code alterations that satisfy all constraints of `AGENTS.md`.

## 4. Conclusion
The audit report findings are valid. The issues can be resolved with precise code updates focusing on:
- Eliminating class-level `late final` variables inside Notifiers (Rule 28).
- Safeguarding referential integrity at the database layer (Rule 35).
- Moving to standard Riverpod `AsyncValue` / `AsyncNotifier` structures (Rule 3).
- Moving connection state to core to avoid architectural bleeding.
- Clearing memory leaks, UI blockers, and redundant ANVISA database loads.

## 5. Verification Method
Verify changes by:
1. Running `flutter test` to ensure tests run warning-free and pass.
2. Running the app, modifying settings, and testing backup restorations.
3. Simulating a Hot Reload while inside the dashboard and pairing screens to verify that no `LateInitializationError` is thrown.
4. Performing a stress test of ANVISA search autocomplete in the wizard.
