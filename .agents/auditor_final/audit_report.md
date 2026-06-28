## Forensic Audit Report

**Work Product**: MediCaixa App Flutter Codebase (Final Verification)
**Profile**: General Project
**Verdict**: INTEGRITY VIOLATION

### Phase Results
- **Check 1: Hardcoded Test Values / Expected Outputs**: PASS — Verification of repository logic (`alarm_repository.dart`, `settings_repository.dart`, `wifi_repository.dart`, `history_repository.dart`) and reports metrics calculations (`reports_notifier.dart`) confirms they are dynamically computed and integrated with database/API interactions. No hardcoded test values, expected mock results, or bypasses were found.
- **Check 2: Static Rule Compliance (Rule 22 & Rule 32)**: FAIL — The codebase has multiple violations of:
  - **Rule 22** (No AppColors inside `const` constructors): Found dozens of instances across `lib/` where widgets, texts, borders, and dividers are defined as `const` while referencing `AppColors`.
  - **Rule 32** (Use `context.mounted` instead of raw `mounted` in async widgets): Found 14 instances across multiple screens (alarm wizard, medication form, medication list, reminder form) where raw `mounted` is used inside async operations or callbacks.
- **Check 3: Package Additions in pubspec.yaml**: FAIL — Multiple new packages were added to `pubspec.yaml` that are not present in the original template/baseline:
  - `timezone: ^0.10.1`
  - `flutter_timezone: ^5.1.0`
  - `audioplayers: ^6.8.1`
  - `file_picker: ^11.0.2`
  - `share_plus: ^12.0.2`
  - `flutter_launcher_icons: ^0.13.1` (dev_dependencies)

---

### Evidence

#### 1. Rule 22 Violations (AppColors inside const constructors)
Below is a sample of the many lines violating Project Rule #22 by using `const` with `AppColors`:
* **lib/core/theme/app_theme.dart:37**:
  ```dart
  side: const BorderSide(color: AppColors.border, width: 1),
  ```
* **lib/features/alarms/presentation/wizard/alarm_wizard_screen.dart:77**:
  ```dart
  icon: const Icon(Icons.close, color: AppColors.text),
  ```
* **lib/features/alarms/presentation/wizard/alarm_wizard_screen.dart:100**:
  ```dart
  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
  ```
* **lib/features/alarms/presentation/wizard/steps/step_1_name.dart:166**:
  ```dart
  style: const TextStyle(color: AppColors.text, fontSize: 18),
  ```
* **lib/features/alarms/presentation/wizard/steps/step_2_mode.dart:133**:
  ```dart
  const Divider(color: AppColors.border),
  ```
* **lib/features/dashboard/presentation/widgets/calendar_strip_widget.dart:480**:
  ```dart
  child: const Icon(Icons.chevron_left, color: AppColors.textMuted, size: 20),
  ```
* **lib/features/history/presentation/history_screen.dart:169**:
  ```dart
  child: const Text('LIMPAR', style: TextStyle(color: AppColors.missed)),
  ```
* **lib/features/medications/presentation/medication_form_screen.dart:99**:
  ```dart
  child: const Text('EXCLUIR', style: TextStyle(color: AppColors.missed)),
  ```

#### 2. Rule 32 Violations (Raw `mounted` instead of `context.mounted`)
The following files contain raw `mounted` usages in widget states during async callbacks:
* **lib/features/alarms/presentation/wizard/alarm_wizard_screen.dart:183**:
  ```dart
  } finally {
    if (mounted) {
      setState(() => _isSaving = false);
    }
  }
  ```
* **lib/features/alarms/presentation/wizard/steps/step_1_name.dart:95**:
  ```dart
  Future.microtask(() {
    if (mounted) {
      ref.read(wizardNotifierProvider.notifier).updateState(...);
    }
  });
  ```
* **lib/features/alarms/presentation/wizard/steps/wizard_step_medication.dart:61**:
  ```dart
  _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
    final repo = ref.read(medicationRepositoryProvider);
    final list = await repo.search(query);
    if (mounted) {
      setState(() {
        _results = list;
        _searching = false;
      });
    }
  });
  ```
* **lib/features/medications/presentation/medication_form_screen.dart:65, 75, 109, 119**:
  ```dart
  // Multiple occurrences of:
  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(...);
    Navigator.of(context).pop();
  }
  ```
* **lib/features/medications/presentation/medications_list_screen.dart:96, 118, 137**:
  ```dart
  if (confirmed == true && mounted) { ... }
  ```
* **lib/features/reminders/presentation/reminder_form_screen.dart:149, 159, 193, 203**:
  ```dart
  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(...);
  }
  ```

#### 3. pubspec.yaml Differences
The packages added to `pubspec.yaml` compared to `pubspec.yaml.template`:
```diff
@@ -37,6 +37,11 @@ dependencies:
   uuid: ^4.5.0
   connectivity_plus: ^6.1.0
   mcp_toolkit: ^3.0.0
+  timezone: ^0.10.1
+  flutter_timezone: ^5.1.0
+  audioplayers: ^6.8.1
+  file_picker: ^11.0.2
+  share_plus: ^12.0.2
 
 dev_dependencies:
   flutter_test:
@@ -45,6 +50,7 @@ dev_dependencies:
   drift_dev: ^2.22.0
   build_runner: ^2.4.0
   riverpod_generator: ^2.4.0
+  flutter_launcher_icons: ^0.13.1
```

#### 4. Test Execution Output
All 67 tests in the test suite run successfully:
```
00:11 +67: All tests passed!
```
