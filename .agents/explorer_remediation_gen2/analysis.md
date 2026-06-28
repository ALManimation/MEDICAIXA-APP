# Detailed Analysis & Remediation Plan (Forensic Audit Remediation — Round 2)

This document provides a precise file-by-file plan to resolve all Rule 22 (No `AppColors` in `const` contexts) and Rule 32 (Use `context.mounted` instead of raw `mounted`) violations, and analyzes the `pubspec.yaml` package additions.

---

## 1. Package Additions Analysis (pubspec.yaml)

A comparison between `pubspec.yaml` and `pubspec.yaml.template` identified six added packages. All additions are **fully justified** and cannot be removed without breaking core features:

1. **`timezone: ^0.10.1`**
   - **Status**: Justified
   - **Reason**: Necessary for scheduling local time-based notifications for alarms and reminders. Used in `lib/core/services/notification_service.dart`.
2. **`flutter_timezone: ^5.1.0`**
   - **Status**: Justified
   - **Reason**: Obtains the local device's timezone. Required to satisfy **Rule 42** using `FlutterTimezone.getLocalTimezone().identifier`. Used in `lib/core/services/notification_service.dart`.
3. **`audioplayers: ^6.8.1`**
   - **Status**: Justified
   - **Reason**: Required to play alarm sounds loop when the dispenser/alarm screen is active. Used in `lib/features/alarms/presentation/alarm_active_screen.dart`.
4. **`file_picker: ^11.0.2`**
   - **Status**: Justified
   - **Reason**: Enables the user to pick a `.json` backup file from local storage to restore data. Used in `lib/features/settings/presentation/settings_screen.dart`.
5. **`share_plus: ^12.0.2`**
   - **Status**: Justified
   - **Reason**: Allows the user to share or export local database backup data to other applications. Used in `lib/features/settings/presentation/settings_screen.dart`.
6. **`flutter_launcher_icons: ^0.13.1` (dev_dependencies)**
   - **Status**: Justified
   - **Reason**: Standard utility to generate and configure launcher icons across Android, iOS, and macOS platforms.

---

## 2. Rule 22 Remediation Plan (No AppColors inside const contexts)

### File: `lib/core/theme/app_theme.dart`
* **Line 12**:
  * *Current*: `colorScheme: const ColorScheme.dark(`
  * *Proposed*: `colorScheme: ColorScheme.dark(`
* **Line 22**:
  * *Current*: `appBarTheme: const AppBarTheme(`
  * *Proposed*: `appBarTheme: AppBarTheme(`
* **Line 37**:
  * *Current*: `side: const BorderSide(color: AppColors.border, width: 1),`
  * *Proposed*: `side: BorderSide(color: AppColors.border, width: 1),`

### File: `lib/features/alarms/presentation/wizard/alarm_wizard_screen.dart`
* **Line 77**:
  * *Current*: `icon: const Icon(Icons.close, color: AppColors.text),`
  * *Proposed*: `icon: Icon(Icons.close, color: AppColors.text),`
* **Line 87**:
  * *Current*: `style: const TextStyle(color: AppColors.text, fontSize: 16, fontWeight: FontWeight.bold),`
  * *Proposed*: `style: TextStyle(color: AppColors.text, fontSize: 16, fontWeight: FontWeight.bold),`
* **Line 100**:
  * *Current*: `valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),`
  * *Proposed*: `valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),`
* **Line 132**:
  * *Current*: `border: const Border(top: BorderSide(color: AppColors.surfaceVariant)),`
  * *Proposed*: `border: Border(top: BorderSide(color: AppColors.surfaceVariant)),`
* **Line 141**:
  * *Current*: `child: const Text('VOLTAR', style: TextStyle(color: AppColors.textMuted)),`
  * *Proposed*: `child: Text('VOLTAR', style: TextStyle(color: AppColors.textMuted)),`

### File: `lib/features/alarms/presentation/wizard/steps/step_1_name.dart`
* **Line 121**:
  * *Current*: `const Text('Qual é o nome do remédio?', style: TextStyle(..., color: AppColors.text))`
  * *Proposed*: `Text('Qual é o nome do remédio?', style: TextStyle(..., color: AppColors.text))` (remove `const` from `Text`)
* **Line 166**:
  * *Current*: `style: const TextStyle(color: AppColors.text, fontSize: 18),`
  * *Proposed*: `style: TextStyle(color: AppColors.text, fontSize: 18),`
* **Line 169**:
  * *Current*: `hintStyle: const TextStyle(color: AppColors.textMuted),`
  * *Proposed*: `hintStyle: TextStyle(color: AppColors.textMuted),`
* **Line 196**:
  * *Current*: `title: Text(option.name, style: const TextStyle(color: AppColors.text)),`
  * *Proposed*: `title: Text(option.name, style: TextStyle(color: AppColors.text)),`
* **Line 197**:
  * *Current*: `subtitle: Text('${option.type} • ${option.dosage}', style: const TextStyle(color: AppColors.textMuted)),`
  * *Proposed*: `subtitle: Text('${option.type} • ${option.dosage}', style: TextStyle(color: AppColors.textMuted)),`
* **Line 468**:
  * *Current*: `style: const TextStyle(color: AppColors.text, fontSize: 18),`
  * *Proposed*: `style: TextStyle(color: AppColors.text, fontSize: 18),`
* **Line 472**:
  * *Current*: `hintStyle: const TextStyle(color: AppColors.textMuted),`
  * *Proposed*: `hintStyle: TextStyle(color: AppColors.textMuted),`
* **Line 477**:
  * *Current*: `borderSide: const BorderSide(color: AppColors.border, width: 1.5),`
  * *Proposed*: `borderSide: BorderSide(color: AppColors.border, width: 1.5),`
* **Line 481**:
  * *Current*: `borderSide: const BorderSide(color: AppColors.border, width: 1.5),`
  * *Proposed*: `borderSide: BorderSide(color: AppColors.border, width: 1.5),`
* **Line 485**:
  * *Current*: `borderSide: const BorderSide(color: AppColors.primary, width: 1.5),`
  * *Proposed*: `borderSide: BorderSide(color: AppColors.primary, width: 1.5),`

### File: `lib/features/alarms/presentation/wizard/steps/step_2_mode.dart`
* **Line 20**:
  * *Current*: `const Text('Como o médico mandou...', style: TextStyle(..., color: AppColors.text))`
  * *Proposed*: `Text('Como o médico mandou...', style: TextStyle(..., color: AppColors.text))`
* **Line 83**:
  * *Current*: `const Text('Limites de segurança...', style: TextStyle(..., color: AppColors.text))`
  * *Proposed*: `Text('Limites de segurança...', style: TextStyle(..., color: AppColors.text))`
* **Line 105**:
  * *Current*: `const Text('Qual o máximo...', style: TextStyle(..., color: AppColors.textMuted))`
  * *Proposed*: `Text('Qual o máximo...', style: TextStyle(..., color: AppColors.textMuted))`
* **Line 124**:
  * *Current*: `const Text('0 = Sem limite...', style: TextStyle(..., color: AppColors.textMuted))`
  * *Proposed*: `Text('0 = Sem limite...', style: TextStyle(..., color: AppColors.textMuted))`
* **Line 133**:
  * *Current*: `const Divider(color: AppColors.border),`
  * *Proposed*: `Divider(color: AppColors.border),`
* **Line 137**:
  * *Current*: `const Text('Tem que esperar...', style: TextStyle(..., color: AppColors.textMuted))`
  * *Proposed*: `Text('Tem que esperar...', style: TextStyle(..., color: AppColors.textMuted))`
* **Line 156**:
  * *Current*: `const Text('0 = Pode tomar...', style: TextStyle(..., color: AppColors.textMuted))`
  * *Proposed*: `Text('0 = Pode tomar...', style: TextStyle(..., color: AppColors.textMuted))`
* **Line 213**:
  * *Current*: `style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.text),`
  * *Proposed*: `style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.text),`
* **Line 225**:
  * *Current*: `style: const TextStyle(fontSize: 10, color: AppColors.textMuted),`
  * *Proposed*: `style: TextStyle(fontSize: 10, color: AppColors.textMuted),`
* **Line 262**:
  * *Current*: `child: const Text('-', style: TextStyle(color: AppColors.primary, fontSize: 28, ...)),`
  * *Proposed*: `child: Text('-', style: TextStyle(color: AppColors.primary, fontSize: 28, ...)),`
* **Line 278**:
  * *Current*: `style: const TextStyle(color: AppColors.text, fontSize: 38, ...),`
  * *Proposed*: `style: TextStyle(color: AppColors.text, fontSize: 38, ...),`
* **Line 299**:
  * *Current*: `child: const Text('+', style: TextStyle(color: AppColors.primary, fontSize: 28, ...)),`
  * *Proposed*: `child: Text('+', style: TextStyle(color: AppColors.primary, fontSize: 28, ...)),`

### File: `lib/features/alarms/presentation/wizard/steps/step_3_qty.dart`
* **Lines 76, 202, 248, 335, 443, 538, 568, 575, 688, 734, 770, 787**:
  * *Current*: `const Text('...', style: TextStyle(color: AppColors.text))` (or `AppColors.textMuted`)
  * *Proposed*: `Text('...', style: TextStyle(color: AppColors.text))` (or `AppColors.textMuted`) - Remove `const` on all `Text` widgets that style with `AppColors`.
* **Lines 145, 157, 272, 303, 416, 419, 608, 767, 900, 977**:
  * *Current*: `style: const TextStyle(color: AppColors.xxx)` (or `hintStyle: const TextStyle(color: AppColors.xxx)`)
  * *Proposed*: `style: TextStyle(color: AppColors.xxx)` (or `hintStyle: TextStyle(color: AppColors.xxx)`) - Remove `const` on `TextStyle`.
* **Line 425, 429**:
  * *Current*: `borderSide: const BorderSide(color: AppColors.border, width: 1.5),`
  * *Proposed*: `borderSide: BorderSide(color: AppColors.border, width: 1.5),`
* **Line 433**:
  * *Current*: `borderSide: const BorderSide(color: AppColors.primary, width: 1.5),`
  * *Proposed*: `borderSide: BorderSide(color: AppColors.primary, width: 1.5),`
* **Line 660, 830**:
  * *Current*: `side: const BorderSide(color: AppColors.primary),`
  * *Proposed*: `side: BorderSide(color: AppColors.primary),`
* **Lines 884, 921, 961, 998**:
  * *Current*: `child: const Text('...', style: TextStyle(color: AppColors.xxx))`
  * *Proposed*: `child: Text('...', style: TextStyle(color: AppColors.xxx))` - Remove `const` on `Text` wrapping mathematical symbols.

### File: `lib/features/alarms/presentation/wizard/steps/step_4_days.dart`
* **Lines 21, 147, 163, 193, 268, 284, 294, 317, 333, 348, 364, 390, 396, 416**:
  * *Current*: `const Text('...', style: TextStyle(color: AppColors.xxx))`
  * *Proposed*: `Text('...', style: TextStyle(color: AppColors.xxx))` - Remove `const` on `Text` widgets referencing `AppColors`.
* **Lines 92, 104, 470**:
  * *Current*: `style: const TextStyle(...)`
  * *Proposed*: `style: TextStyle(...)` - Remove `const`.
* **Line 344**:
  * *Current*: `const Divider(color: AppColors.border),`
  * *Proposed*: `Divider(color: AppColors.border),`
* **Lines 454, 493**:
  * *Current*: `child: const Text('...', style: TextStyle(color: AppColors.primary))`
  * *Proposed*: `child: Text('...', style: TextStyle(color: AppColors.primary))`

### File: `lib/features/alarms/presentation/wizard/steps/step_5_time.dart`
* **Lines 78, 232, 368, 380, 399, 410**:
  * *Current*: `style: const TextStyle(color: AppColors.xxx)`
  * *Proposed*: `style: TextStyle(color: AppColors.xxx)`
* **Line 304**:
  * *Current*: `icon: const Icon(Icons.add, size: 18, color: AppColors.primary),`
  * *Proposed*: `icon: Icon(Icons.add, size: 18, color: AppColors.primary),`
* **Line 305**:
  * *Current*: `label: const Text('Adicionar Horário', style: TextStyle(..., color: AppColors.primary)),`
  * *Proposed*: `label: Text('Adicionar Horário', style: TextStyle(..., color: AppColors.primary)),`

### File: `lib/features/alarms/presentation/wizard/steps/step_6_duration.dart`
* **Lines 58, 208, 271, 295, 336, 366, 388**:
  * *Current*: `const Text('...', style: TextStyle(color: AppColors.xxx))`
  * *Proposed*: `Text('...', style: TextStyle(color: AppColors.xxx))` - Remove `const` on `Text` widgets.
* **Lines 172, 184, 243, 309, 317, 425, 465**:
  * *Current*: `style: const TextStyle(...)` (or `hintStyle: const TextStyle(...)`)
  * *Proposed*: `style: TextStyle(...)` (or `hintStyle: TextStyle(...)`) - Remove `const`.
* **Line 464**:
  * *Current*: `icon: const Icon(Icons.arrow_drop_down, color: AppColors.textMuted),`
  * *Proposed*: `icon: Icon(Icons.arrow_drop_down, color: AppColors.textMuted),`

### File: `lib/features/alarms/presentation/wizard/steps/step_7_summary.dart`
* **Line 293**:
  * *Current*: `const Text('RESUMO DO REMÉDIO', style: TextStyle(..., color: AppColors.textMuted))`
  * *Proposed*: `Text('RESUMO DO REMÉDIO', style: TextStyle(..., color: AppColors.textMuted))`

### File: `lib/features/dashboard/presentation/dashboard_screen.dart`
* **Line 524**:
  * *Current*: `child: const Text('CANCELAR', style: TextStyle(color: AppColors.textMuted)),`
  * *Proposed*: `child: Text('CANCELAR', style: TextStyle(color: AppColors.textMuted)),`
* **Line 528**:
  * *Current*: `child: const Text('REGISTRAR', style: TextStyle(color: AppColors.primary)),`
  * *Proposed*: `child: Text('REGISTRAR', style: TextStyle(color: AppColors.primary)),`

### File: `lib/features/dashboard/presentation/widgets/calendar_strip_widget.dart`
* **Line 357**:
  * *Current*: `child: const Text('···', style: TextStyle(color: AppColors.textMuted, fontSize: 16)),`
  * *Proposed*: `child: Text('···', style: TextStyle(color: AppColors.textMuted, fontSize: 16)),`
* **Line 480**:
  * *Current*: `child: const Icon(Icons.chevron_left, color: AppColors.textMuted, size: 20),`
  * *Proposed*: `child: Icon(Icons.chevron_left, color: AppColors.textMuted, size: 20),`
* **Line 503**:
  * *Current*: `child: const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 20),`
  * *Proposed*: `child: Icon(Icons.chevron_right, color: AppColors.textMuted, size: 20),`

### File: `lib/features/history/presentation/history_screen.dart`
* **Lines 150, 213, 218, 276, 346, 352**:
  * *Current*: `style: const TextStyle(color: AppColors.xxx)`
  * *Proposed*: `style: TextStyle(color: AppColors.xxx)`
* **Lines 165, 169, 291, 295**:
  * *Current*: `child: const Text('...', style: TextStyle(color: AppColors.xxx)),`
  * *Proposed*: `child: Text('...', style: TextStyle(color: AppColors.xxx)),`

### File: `lib/features/medications/presentation/medication_form_screen.dart`
* **Lines 95, 99**:
  * *Current*: `child: const Text('...', style: TextStyle(color: AppColors.xxx)),`
  * *Proposed*: `child: Text('...', style: TextStyle(color: AppColors.xxx)),`
* **Lines 157, 181**:
  * *Current*: `hintStyle: const TextStyle(color: AppColors.textMuted),`
  * *Proposed*: `hintStyle: TextStyle(color: AppColors.textMuted),`
* **Line 251**:
  * *Current*: `side: const BorderSide(color: AppColors.missed),`
  * *Proposed*: `side: BorderSide(color: AppColors.missed),`

### File: `lib/features/medications/presentation/medications_list_screen.dart`
* **Lines 109, 127, 131**:
  * *Current*: `child: const Text('...', style: TextStyle(color: AppColors.xxx)),`
  * *Proposed*: `child: Text('...', style: TextStyle(color: AppColors.xxx)),`
* **Lines 238, 284**:
  * *Current*: `style: const TextStyle(color: AppColors.xxx)`
  * *Proposed*: `style: TextStyle(color: AppColors.xxx)`
* **Lines 250, 253, 278**:
  * *Current*: `const Icon(..., color: AppColors.textMuted)`
  * *Proposed*: `Icon(..., color: AppColors.textMuted)` - Remove `const`.
* **Line 402**:
  * *Current*: `border: const Border(top: BorderSide(color: AppColors.border, width: 1)),`
  * *Proposed*: `border: Border(top: BorderSide(color: AppColors.border, width: 1)),`
* **Line 412**:
  * *Current*: `side: const BorderSide(color: AppColors.border),`
  * *Proposed*: `side: BorderSide(color: AppColors.border),`

### File: `lib/features/reminders/presentation/reminder_form_screen.dart`
* **Lines 179, 183, 298, 386, 397**:
  * *Current*: `const Text('...', style: TextStyle(color: AppColors.xxx))`
  * *Proposed*: `Text('...', style: TextStyle(color: AppColors.xxx))` - Remove `const`.
* **Lines 241, 266**:
  * *Current*: `hintStyle: const TextStyle(color: AppColors.textMuted),`
  * *Proposed*: `hintStyle: TextStyle(color: AppColors.textMuted),`
* **Lines 303, 391**:
  * *Current*: `trailing: const Icon(..., color: AppColors.primary),`
  * *Proposed*: `trailing: Icon(..., color: AppColors.primary),`
* **Line 442**:
  * *Current*: `side: const BorderSide(color: AppColors.missed),`
  * *Proposed*: `side: BorderSide(color: AppColors.missed),`

---

## 3. Rule 32 Remediation Plan (Use context.mounted instead of raw mounted)

### File: `lib/features/alarms/presentation/alarm_active_screen.dart`
* **Line 64**:
  * *Current*: `if (!mounted) return false;`
  * *Proposed*: `if (!context.mounted) return false;`
* **Line 67**:
  * *Current*: `return mounted;`
  * *Proposed*: `return context.mounted;`

### File: `lib/features/alarms/presentation/wizard/alarm_wizard_screen.dart`
* **Line 183**:
  * *Current*: `if (mounted) {`
  * *Proposed*: `if (context.mounted) {`

### File: `lib/features/alarms/presentation/wizard/steps/step_1_name.dart`
* **Line 95**:
  * *Current*: `if (mounted) {`
  * *Proposed*: `if (context.mounted) {`

### File: `lib/features/alarms/presentation/wizard/steps/wizard_step_medication.dart`
* **Line 61**:
  * *Current*: `if (mounted) {`
  * *Proposed*: `if (context.mounted) {`

### File: `lib/features/medications/presentation/medication_form_screen.dart`
* **Lines 65, 75, 109, 119**:
  * *Current*: `if (mounted) {`
  * *Proposed*: `if (context.mounted) {`

### File: `lib/features/medications/presentation/medications_list_screen.dart`
* **Lines 96, 118, 137**:
  * *Current*: `if (mounted) {` (or `&& mounted`)
  * *Proposed*: `if (context.mounted) {` (or `&& context.mounted`)

### File: `lib/features/reminders/presentation/reminder_form_screen.dart`
* **Lines 149, 159, 193, 203**:
  * *Current*: `if (mounted) {`
  * *Proposed*: `if (context.mounted) {`
