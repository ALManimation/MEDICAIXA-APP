# Light Theme (Claro) Implementation Plan

## Overview
This report outlines the technical analysis and step-by-step plan for implementing the **Light Theme (Claro)** in the MediCaixa Flutter application. The architecture is designed offline-first and aligns with the color variables used in the MediCaixa C++ Web UI (`littlefs_data/www/index.html`).

---

## 1. Color Palette System (`lib/core/constants/app_colors.dart`)

### Current Structure
`AppColors` is currently a utility class (`AppColors._()`) containing core colors, status colors, health banner colors, period colors, and alarm colors. 
Crucially, variables are declared as `static final Color`. Because they are `final`, their values are immutable after initialization and cannot be changed at runtime when a user switches themes.

### Proposed Conversion
To support dynamic theme changes, we must change all the styleable colors from `final` to **non-final** `Color` variables (`static Color`).
*Note: `alarmColors` map and `getAlarmColor()` helper remain unaffected as they represent static firmware colors.*

### Exact Hex Mappings & `setTheme` Implementation
Based on the C++ Web UI CSS variables, here is the complete theme mapping and the exact implementation of the `setTheme(bool isDark)` method.

```dart
// lib/core/constants/app_colors.dart
import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Core Theme Colors
  static Color background = const Color(0xFF111827);
  static Color surface = const Color(0xFF1F2937);
  static Color surfaceVariant = const Color(0xFF374151);
  static Color primary = const Color(0xFF34D399);
  static Color primaryDark = const Color(0xFF10B981);
  static Color onPrimary = Colors.white;
  static Color secondary = const Color(0xFF00ACC1);
  static Color onSecondary = Colors.black;
  static Color text = const Color(0xFFF9FAFB);
  static Color textMuted = const Color(0xFF9CA3AF);
  static Color border = const Color(0xFF374151);

  // Status Colors
  static Color success = const Color(0xFF10B981);
  static Color pending = const Color(0xFFFB8C00);
  static Color missed = const Color(0xFFEF4444);

  // Health Banner Colors
  static Color healthOk = const Color(0xFF34D399);
  static Color healthOkBg = const Color(0xFF064E3B);
  static Color healthOkBorder = const Color(0xFF065F46);
  static Color healthWarn = const Color(0xFFFBBF24);
  static Color healthWarnBg = const Color(0xFF422006);
  static Color healthWarnBorder = const Color(0xFF78350F);
  static Color healthRisk = const Color(0xFFFB923C);
  static Color healthRiskBg = const Color(0xFF431407);
  static Color healthRiskBorder = const Color(0xFF7C2D12);
  static Color healthDanger = const Color(0xFFF87171);
  static Color healthDangerBg = const Color(0xFF450A0A);
  static Color healthDangerBorder = const Color(0xFF7F1D1D);

  // Period Colors
  static Color morningColor = const Color(0xFFD97706);
  static Color afternoonColor = const Color(0xFF2563EB);
  static Color nightColor = const Color(0xFF4B5563);

  // MediCaixa Firmware Color Map
  static const Map<String, Color> alarmColors = {
    'white': Color(0xFFFFFFFF),
    'red': Color(0xFFFF0000),
    'green': Color(0xFF00FF00),
    'blue': Color(0xFF0000FF),
    'yellow': Color(0xFFFFFF00),
    'magenta': Color(0xFFFF00FF),
    'cyan': Color(0xFF00FFFF),
    'orange': Color(0xFFFFA500),
    'purple': Color(0xFF800080),
    'pink': Color(0xFFFFC0CB),
    'brown': Color(0xFFA52A2A),
    'chartreuse': Color(0xFF7FFF00),
    'teal': Color(0xFF008080),
    'coral': Color(0xFFFF7F50),
    'gold': Color(0xFFFFD700),
  };

  static Color getAlarmColor(String? colorName) {
    if (colorName == null || colorName.isEmpty) return primary;
    return alarmColors[colorName.toLowerCase()] ?? primary;
  }

  /// Reassigns static colors dynamically according to the chosen theme mode.
  static void setTheme(bool isDark) {
    if (isDark) {
      // Web UI Dark Mode
      background = const Color(0xFF111827);
      surface = const Color(0xFF1F2937);
      surfaceVariant = const Color(0xFF374151);
      primary = const Color(0xFF34D399);
      primaryDark = const Color(0xFF10B981);
      onPrimary = Colors.white;
      secondary = const Color(0xFF00ACC1);
      onSecondary = Colors.black;
      text = const Color(0xFFF9FAFB);
      textMuted = const Color(0xFF9CA3AF);
      border = const Color(0xFF374151);

      healthOk = const Color(0xFF34D399);
      healthOkBg = const Color(0xFF064E3B);
      healthOkBorder = const Color(0xFF065F46);
      healthWarn = const Color(0xFFFBBF24);
      healthWarnBg = const Color(0xFF422006);
      healthWarnBorder = const Color(0xFF78350F);
      healthRisk = const Color(0xFFFB923C);
      healthRiskBg = const Color(0xFF431407);
      healthRiskBorder = const Color(0xFF7C2D12);
      healthDanger = const Color(0xFFF87171);
      healthDangerBg = const Color(0xFF450A0A);
      healthDangerBorder = const Color(0xFF7F1D1D);
    } else {
      // Web UI Light Mode (:root styles)
      background = const Color(0xFFF3F4F6);
      surface = const Color(0xFFFFFFFF);
      surfaceVariant = const Color(0xFFE5E7EB);
      primary = const Color(0xFF10B981);
      primaryDark = const Color(0xFF059669);
      onPrimary = Colors.white;
      secondary = const Color(0xFF00ACC1);
      onSecondary = Colors.white;
      text = const Color(0xFF1F2937);
      textMuted = const Color(0xFF6B7280);
      border = const Color(0xFFE5E7EB);

      healthOk = const Color(0xFF059669);
      healthOkBg = const Color(0xFFECFDF5);
      healthOkBorder = const Color(0xFF6EE7B7);
      healthWarn = const Color(0xFFB45309);
      healthWarnBg = const Color(0xFFFEFCE8);
      healthWarnBorder = const Color(0xFFFDE047);
      healthRisk = const Color(0xFFC2410C);
      healthRiskBg = const Color(0xFFFFF7ED);
      healthRiskBorder = const Color(0xFFFDBA74);
      healthDanger = const Color(0xFFB91C1C);
      healthDangerBg = const Color(0xFFFEF2F2);
      healthDangerBorder = const Color(0xFFFCA5A5);
    }
  }
}
```

---

## 2. App Theme Configurations (`lib/core/theme/app_theme.dart`)

### Current Theme Setup
Currently, `AppTheme` defines a single static `darkTheme` based on `ThemeData.dark(useMaterial3: true)` with overrides using variables from `AppColors`.

### Proposed Light Theme definition
We will define `lightTheme` inside `AppTheme` using the light color schemes and `ThemeData.light(useMaterial3: true)`.

```dart
// lib/core/theme/app_theme.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get darkTheme {
    final baseTheme = ThemeData.dark(useMaterial3: true);
    return _buildTheme(baseTheme, ColorScheme.dark(
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      secondary: AppColors.secondary,
      onSecondary: AppColors.onSecondary,
      surface: AppColors.surface,
      error: AppColors.missed,
    ));
  }

  static ThemeData get lightTheme {
    final baseTheme = ThemeData.light(useMaterial3: true);
    return _buildTheme(baseTheme, ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      secondary: AppColors.secondary,
      onSecondary: AppColors.onSecondary,
      surface: AppColors.surface,
      error: AppColors.missed,
    ));
  }

  static ThemeData _buildTheme(ThemeData baseTheme, ColorScheme colorScheme) {
    return baseTheme.copyWith(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: AppColors.text,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      textTheme: GoogleFonts.interTextTheme(baseTheme.textTheme).copyWith(
        displayLarge: GoogleFonts.outfit(textStyle: baseTheme.textTheme.displayLarge?.copyWith(color: AppColors.text, fontWeight: FontWeight.bold)),
        displayMedium: GoogleFonts.outfit(textStyle: baseTheme.textTheme.displayMedium?.copyWith(color: AppColors.text, fontWeight: FontWeight.bold)),
        displaySmall: GoogleFonts.outfit(textStyle: baseTheme.textTheme.displaySmall?.copyWith(color: AppColors.text, fontWeight: FontWeight.bold)),
        headlineLarge: GoogleFonts.outfit(textStyle: baseTheme.textTheme.headlineLarge?.copyWith(color: AppColors.text, fontWeight: FontWeight.bold)),
        headlineMedium: GoogleFonts.outfit(textStyle: baseTheme.textTheme.headlineMedium?.copyWith(color: AppColors.text, fontWeight: FontWeight.bold)),
        headlineSmall: GoogleFonts.outfit(textStyle: baseTheme.textTheme.headlineSmall?.copyWith(color: AppColors.text, fontWeight: FontWeight.bold)),
        titleLarge: GoogleFonts.outfit(textStyle: baseTheme.textTheme.titleLarge?.copyWith(color: AppColors.text, fontWeight: FontWeight.bold)),
        titleMedium: GoogleFonts.outfit(textStyle: baseTheme.textTheme.titleMedium?.copyWith(color: AppColors.text, fontWeight: FontWeight.w600)),
        titleSmall: GoogleFonts.outfit(textStyle: baseTheme.textTheme.titleSmall?.copyWith(color: AppColors.text, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
```

---

## 3. SQLite Database Migration (`lib/core/database/database.dart`)

### Current Setup & Schema
* **Settings Table Location:** Defined inside `lib/core/database/database.dart` as `class Settings extends Table` (line 101).
* **Current Schema Version:** `schemaVersion => 4;` (line 165).
* **Migration Strategy:** The `MigrationStrategy` is configured within the `AppDatabase` class constructor, executing sequential alterations inside `onUpgrade: (migrator, from, to) async { ... }`.

### Migration Plan (to version 5)
1. In `Settings` table, add a new text column `themeMode`:
   ```dart
   TextColumn get themeMode => text().withDefault(const Constant('dark'))();
   ```
2. Increment the database `schemaVersion` to `5`:
   ```dart
   @override
   int get schemaVersion => 5;
   ```
3. Update the migration path in `onUpgrade` to add this new column:
   ```dart
   if (from < 5) {
     await migrator.addColumn(settings, settings.themeMode);
   }
   ```
4. Run `dart run build_runner build --delete-conflicting-outputs` to regenerate `database.g.dart`.

---

## 4. Settings Repository & Provider Integration

### Load, Save & Conversion Logic
* Settings are loaded locally via `SettingsRepository.getSettings()`. If the table contains no entries, it initializes a default row using a `SettingsCompanion`.
* Modified setting properties are saved via `updateSettings(Setting data)`, which updates the SQLite database and pushes general updates to the ESP32 server (via POST `/save_settings`) if connected.
* Inbound sync is done via `syncSettings()` which queries GET `/settings` on the ESP32, parsing the response and executing a local `copyWith` replace in SQLite.

### Supporting `themeMode`
1. Update `getSettings()` default initialization:
   ```dart
   final defaultSettings = SettingsCompanion(
     id: const Value(1),
     patientName: const Value('Paciente'),
     speakerVolume: const Value(20),
     brightness: const Value(50),
     language: const Value('pt'),
     wakeWord: const Value('jarvis'),
     alarmSound: const Value(0),
     alarmSpacingMs: const Value(10000),
     alarmWizardEnabled: const Value(true),
     themeMode: const Value('dark'), // default
   );
   ```
2. **Local-Only Exclusions:** Because `themeMode` is a purely application-level setting, do NOT include the `theme_mode` variable in ESP32 sync payloads (`updateSettings()` POST body or remote updates). Likewise, `syncSettings()` will naturally preserve `themeMode` because the incoming JSON map from ESP32 doesn't have a `theme_mode` key, and we fallback to `current.themeMode`.

### Implementing the Theme State Provider
Create `lib/core/providers/theme_provider.dart` to manage the reactive theme state and automatically synchronize with `AppColors`:

```dart
// lib/core/providers/theme_provider.dart
import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:medicaixa_app/core/constants/app_colors.dart';
import 'package:medicaixa_app/core/database/database.dart';
import 'package:medicaixa_app/features/settings/data/settings_repository.dart';

part 'theme_provider.g.dart';

@riverpod
class AppThemeNotifier extends _$AppThemeNotifier {
  @override
  ThemeMode build() {
    // 1. Listen to database changes for setting synchronization
    ref.listen<AsyncValue<Setting?>>(watchSettingsProvider, (previous, next) {
      final nextSetting = next.value;
      if (nextSetting != null) {
        final modeStr = nextSetting.themeMode;
        final nextMode = modeStr == 'light' ? ThemeMode.light : ThemeMode.dark;
        if (nextMode != state) {
          AppColors.setTheme(nextMode == ThemeMode.dark);
          state = nextMode;
        }
      }
    });

    // 2. Fetch the initial value if available
    final settingsVal = ref.read(watchSettingsProvider).value;
    if (settingsVal != null) {
      final initialMode = settingsVal.themeMode == 'light' ? ThemeMode.light : ThemeMode.dark;
      AppColors.setTheme(initialMode == ThemeMode.dark);
      return initialMode;
    }

    AppColors.setTheme(true); // default to dark
    return ThemeMode.dark;
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final modeStr = mode == ThemeMode.light ? 'light' : 'dark';
    
    // Immediately apply color changes to reduce UI latency
    AppColors.setTheme(mode == ThemeMode.dark);
    state = mode;

    // Persist changes in the Drift DB
    final repo = ref.read(settingsRepositoryProvider);
    final settings = await repo.getSettings();
    final updated = settings.copyWith(themeMode: modeStr);
    await repo.updateSettings(updated);
  }
}
```

---

## 5. UI Integration on Settings Screen (`settings_screen.dart`)

### Section Location
We will place the appearance selector in the **Ajustes Locais** section (specifically, inside the `_buildAppConfigCard` method at line 629 of `lib/features/settings/presentation/settings_screen.dart`).

### UI Elements Implementation
To implement the **SegmentedButton** appearance selector, we'll need to define localization keys inside our translation map JSONs (`assets/lang/*.json`) under the `"web"` section:
* `"appearance_label": "Aparência"` (PT) / `"Appearance"` (EN) / `"Apariencia"` (ES)
* `"theme_light": "Claro"` (PT) / `"Light"` (EN) / `"Claro"` (ES)
* `"theme_dark": "Escuro"` (PT) / `"Dark"` (EN) / `"Oscuro"` (ES)

Then, inside `_buildAppConfigCard` in `settings_screen.dart`:

```dart
  Widget _buildAppConfigCard(String currentLocale, Setting settings) {
    final themeMode = ref.watch(appThemeNotifierProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Idioma Section
            Text(
              t('language_label'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Center(
              child: SegmentedButton<String>(
                segments: [
                  ButtonSegment(value: 'pt', label: Text(t('lang_pt'))),
                  ButtonSegment(value: 'en', label: Text(t('lang_en'))),
                  ButtonSegment(value: 'es', label: Text(t('lang_es'))),
                ],
                selected: {currentLocale},
                onSelectionChanged: (newSelection) async {
                  final code = newSelection.first;
                  await ref.read(appLocaleProvider.notifier).changeLocale(code);
                },
              ),
            ),
            
            const Divider(height: 32),

            // Aparência Section
            Text(
              t('appearance_label'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Center(
              child: SegmentedButton<ThemeMode>(
                segments: [
                  ButtonSegment(
                    value: ThemeMode.light,
                    label: Text(t('theme_light')),
                    icon: const Icon(Icons.light_mode_rounded),
                  ),
                  ButtonSegment(
                    value: ThemeMode.dark,
                    label: Text(t('theme_dark')),
                    icon: const Icon(Icons.dark_mode_rounded),
                  ),
                ],
                selected: {themeMode},
                onSelectionChanged: (newSelection) async {
                  final mode = newSelection.first;
                  await ref.read(appThemeNotifierProvider.notifier).setThemeMode(mode);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
```

---

## 6. Verification and Compliance Checking

### Rule 22: Const vs AppColors
"Widgets referencing `AppColors.xxx` MUST NOT be marked as `const`."
* **Rationale:** Since `AppColors` changes its static values dynamically at runtime, any widget instantiated using `const` would be compiled as a constant expression, ignoring subsequent theme changes.
* **Audit findings:** Because `AppColors.primary`, `AppColors.text`, etc. are defined as `static Color` (and previously `static final Color`), Dart compile time prevents these widgets from being declared `const` directly (e.g. `const Icon(Icons.star, color: AppColors.primary)` fails to compile).
* **Actionable Rule:** Ensure no parent widget tree is marked as `const` where children consume color fields from `AppColors`.

### Rule 32: Life Cycle Verification (`context.mounted`)
"In asynchronous operations within widgets, verify `context.mounted` before interacting with the context."
* **Audit findings:** Inside `settings_screen.dart`, all operations including dialog calls, snackbars, and file selection verify context via `buildContext.mounted` or `ctx.mounted`. There are zero occurrences of raw `mounted` checks. This constraint is fully met.

---

## 7. Verification Method

Once implemented, developers can verify the Light Theme behavior through:
1. Running code generator:
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```
2. Running the analyzer to check for any `const` issues or syntax errors:
   ```bash
   flutter analyze
   ```
3. Executing unit and widget tests:
   ```bash
   flutter test
   ```
4. Opening the app, navigating to Settings, switching between "Claro" and "Escuro", and inspecting the immediate visual theme changes.
