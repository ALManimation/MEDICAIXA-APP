## 2026-06-28T21:24:05Z
Implement the Light Theme (Claro) for the MediCaixa Flutter app based on the requirements in ORIGINAL_REQUEST.md and the explorer's report.

Follow these step-by-step instructions:

1. Modify `lib/core/constants/app_colors.dart`:
   - Change the color variables (background, surface, surfaceVariant, primary, primaryDark, onPrimary, secondary, onSecondary, text, textMuted, border, success, pending, missed, and all 8 healthOk/Warn/Risk/Danger colors) from `static final Color` to `static Color`.
   - Add the `static void setTheme(bool isDark)` method to toggle all these static color variables between dark mode HEX values (original) and light mode HEX values:
     - Light Mode HEX values:
       * background = const Color(0xFFF3F4F6);
       * surface = const Color(0xFFFFFFFF);
       * surfaceVariant = const Color(0xFFE5E7EB);
       * primary = const Color(0xFF10B981);
       * primaryDark = const Color(0xFF059669);
       * onPrimary = Colors.white;
       * secondary = const Color(0xFF00ACC1);
       * onSecondary = Colors.white;
       * text = const Color(0xFF1F2937);
       * textMuted = const Color(0xFF6B7280);
       * border = const Color(0xFFE5E7EB);
       * healthOk = const Color(0xFF059669);
       * healthOkBg = const Color(0xFFECFDF5);
       * healthOkBorder = const Color(0xFF6EE7B7);
       * healthWarn = const Color(0xFFB45309);
       * healthWarnBg = const Color(0xFFFEFCE8);
       * healthWarnBorder = const Color(0xFFFDE047);
       * healthRisk = const Color(0xFFC2410C);
       * healthRiskBg = const Color(0xFFFFF7ED);
       * healthRiskBorder = const Color(0xFFFDBA74);
       * healthDanger = const Color(0xFFB91C1C);
       * healthDangerBg = const Color(0xFFFEF2F2);
       * healthDangerBorder = const Color(0xFFFCA5A5);
     - Dark Mode HEX values (the original ones).

2. Modify `lib/core/theme/app_theme.dart`:
   - Define a static getter `lightTheme` inside `AppTheme` using the light color scheme and `ThemeData.light(useMaterial3: true)`, mimicking `darkTheme` layout but adapted for light mode.

3. Modify `lib/core/database/database.dart`:
   - Add the `themeMode` column to the `Settings` table: `TextColumn get themeMode => text().withDefault(const Constant('dark'))();`.
   - Increment the database `schemaVersion` to 5.
   - Update the `onUpgrade` migration strategy inside the `AppDatabase` class constructor:
     ```dart
     if (from < 5) {
       await migrator.addColumn(settings, settings.themeMode);
     }
     ```

4. Run code generation to update Drift files:
   - Run the command `dart run build_runner build --delete-conflicting-outputs`.

5. Update `lib/features/settings/data/settings_repository.dart`:
   - In `getSettings()`, initialize `themeMode` to `const Value('dark')` in the default `SettingsCompanion`.
   - Ensure the new `themeMode` column is NOT sent in sync payloads to ESP32 (since it's an app-only visual preference).

6. Create `lib/core/providers/theme_provider.dart`:
   - Implement `AppThemeNotifier` (Riverpod Notifier) that manages the active `ThemeMode` (`light` or `dark`).
   - Listen to `watchSettingsProvider` stream. When settings change, get the value of `themeMode` column ('light' -> ThemeMode.light, other -> ThemeMode.dark). If the value changes, trigger `AppColors.setTheme(...)` and update state.
   - Implement `Future<void> setThemeMode(ThemeMode mode)` which reassigns `AppColors` dynamically, updates notifier state, and calls `settingsRepository.updateSettings` to persist theme preference in Drift.
   - Remember to run build_runner again to generate the Riverpod annotation file `theme_provider.g.dart`.

7. Update `lib/app.dart`:
   - Import the theme provider.
   - Watch `appThemeNotifierProvider`.
   - Pass `theme: AppTheme.lightTheme`, `darkTheme: AppTheme.darkTheme`, and `themeMode: ref.watch(appThemeNotifierProvider)` to `MaterialApp`.

8. Update `lib/features/settings/presentation/settings_screen.dart`:
   - In the `_buildAppConfigCard` method, add the "Aparência" selector.
   - Use `SegmentedButton<ThemeMode>` containing "Claro" and "Escuro" options with their respective icons (e.g. Icons.light_mode_rounded, Icons.dark_mode_rounded).
   - Hook `onSelectionChanged` to call `ref.read(appThemeNotifierProvider.notifier).setThemeMode(mode)`.
   - Ensure all async BuildContext usages correctly use `context.mounted` to adhere to Rule 32.

9. Update translation JSON files:
   - In `assets/lang/pt.json`, `assets/lang/en.json`, and `assets/lang/es.json` under the `"web"` section, add the keys:
     - pt.json:
       * `"appearance_label": "Aparência"`
       * `"theme_light": "Claro"`
       * `"theme_dark": "Escuro"`
     - en.json:
       * `"appearance_label": "Appearance"`
       * `"theme_light": "Light"`
       * `"theme_dark": "Dark"`
     - es.json:
       * `"appearance_label": "Apariencia"`
       * `"theme_light": "Claro"`
       * `"theme_dark": "Oscuro"`

10. Verify compile and lint safety:
    - Run the static analysis command: `flutter analyze` and resolve any compile-time const errors (e.g., removing `const` where `AppColors` are used since they are no longer compile-time constants per Rule 22).
    - Run the automated test suite: `flutter test`.
