## 2026-06-28T21:21:13Z
Analyze the MediCaixa Flutter app codebase to plan the implementation of the Light Theme (Claro).
Specifically, inspect and answer the following:
1. lib/core/constants/app_colors.dart:
   - What is its current structure?
   - How should we convert all the colors from final to static non-final Color variables?
   - How should we implement `setTheme(bool isDark)`? Please provide the exact color HEX values for light and dark modes based on the requirements.
2. lib/core/theme/app_theme.dart:
   - What is the current theme setup?
   - How should we define `lightTheme` inside it?
3. lib/core/database/database.dart:
   - Where is the Settings table defined?
   - What is the current schemaVersion?
   - How is the MigrationStrategy set up? How do we increment the schemaVersion to 5 and add the column `themeMode` (or `theme_mode`) with default 'dark'?
4. lib/features/settings/data/settings_models.dart & settings_repository.dart:
   - How do settings get loaded, saved, and converted?
   - Where should we update them to support `themeMode`?
   - How should we implement the `appThemeProvider` (Riverpod Notifier) to reactively manage theme state and sync it with `AppColors` and the Drift database?
5. lib/features/settings/presentation/settings_screen.dart:
   - Where is the local settings section?
   - How should we integrate the "Aparência" seletor (`SegmentedButton` with "Claro" and "Escuro")?
6. Verify compliance constraints:
   - Identify any usages of `const` with `AppColors` or widgets using AppColors that need to be cleaned up.
   - Review Rule 22 and Rule 32.

Please write a detailed report to `/Users/almanimation/Downloads/Caixa Remedios/medicaixa_app/.agents/explorer_light_theme/analysis.md` and complete the handoff.
