# Execution Plan - Navigation Reactivity, Light Theme Alert Cards, & Language Dropdown

This plan outlines the milestones and steps to fix the bottom navigation bar theme reactivity, refine light theme alert card styling, and replace the language segmented button with a dropdown in the settings screen.

## Milestones

### Milestone 1: Codebase Analysis (Explorer)
- [ ] Spawn `teamwork_preview_explorer` to inspect:
  - `lib/features/dashboard/presentation/app_shell.dart` (or corresponding AppShell file) to analyze bottom navigation/navigation bar rendering and how it references/watches the theme notifier.
  - `lib/features/settings/presentation/settings_screen.dart` to analyze:
    - How language selection is currently rendered (the SegmentedButton).
    - How language changes are saved and persisted.
    - How the warning/alert cards ("Configurações da Caixinha Bloqueadas" and "Testes Offline") are styled and styled in Light Theme.
  - Check `lib/core/constants/app_colors.dart` and `lib/core/theme/app_theme.dart` for the relevant colors like `AppColors.healthDangerBg`, `AppColors.healthDangerBorder`, `AppColors.healthDanger`, `AppColors.missed`, `AppColors.surface`, `AppColors.border`, and see how they are defined.
  - Check existing tests `test/features/settings/presentation/localization_test.dart` and `test/features/settings/presentation/theme_ui_integration_test.dart` (or similar paths) to see their structure and how they check language/theme changes.

### Milestone 2: Implementation (Worker)
- [ ] Spawn `teamwork_preview_worker` to:
  - Fix AppShell's bottom navigation bar reactivity: Make sure `AppShell` watches `appThemeNotifierProvider` (or the appropriate theme state) so it rebuilds immediately when the theme changes.
  - Refine alert card colors for the Light Theme:
    - Update "Configurações da Caixinha Bloqueadas" alert card styling in light theme to use:
      - Fundo: `AppColors.healthDangerBg` (or #fef2f2 if not defined)
      - Borda: `AppColors.healthDangerBorder` (or #fca5a5 if not defined)
      - Texto/Ícone: `AppColors.healthDanger` or `AppColors.missed`
    - Update "Testes Offline (Fixture)" card styling to use:
      - Fundo: `AppColors.surface`
      - Borda: `AppColors.border` (discreet border for light theme)
  - Replace the SegmentedButton language selector with a `DropdownButtonFormField` matching the C++ UI:
    - List the items: `🇧🇷 Português` (value: `'pt'`), `🇺🇸 English` (value: `'en'`), `🇪🇸 Español` (value: `'es'`).
    - Use `AppColors.border` for border, `AppColors.surface` for background, `AppColors.text` for text, matching other form fields in the settings screen.
    - Ensure dynamic language switching reactively updates the app translations and persists correctly in the Drift SQLite database.
  - Run code generation if needed (e.g. if files requiring code gen are modified, but typically changing UI layout doesn't require drift rebuild, unless model changes).
  - Run `flutter analyze` locally in the worker to verify no errors.

### Milestone 3: Reviews, Verification & Challenger Tests (Reviewer & Challenger)
- [ ] Spawn `teamwork_preview_reviewer` to review code changes:
  - Verify that Rule 22 is followed: No widget referencing dynamic `AppColors` is declared as `const`.
  - Verify that Rule 32 is followed: `context.mounted` is checked in async callbacks.
  - Verify overall layout stability and look-and-feel of the new Dropdown and warning cards.
- [ ] Spawn `teamwork_preview_challenger` to:
  - Update or write unit/widget tests (specifically targeting `localization_test.dart` and `theme_ui_integration_test.dart`).
  - Verify that language switching changes translations dynamically and persists to Drift SQLite.
  - Verify that theme changing dynamically rebuilds the bottom navigation bar.
  - Run all tests to ensure 100% pass and no analyzer errors.

### Milestone 4: Forensic Audit (Auditor)
- [ ] Spawn `teamwork_preview_auditor` to run integrity checks and verify clean implementation without cheating or mocks.

## Acceptance Criteria
- [ ] Changing theme to "Claro" instantly changes bottom navigation bar background to white (`AppColors.surface`).
- [ ] Light Theme alert card "Configurações da Caixinha Bloqueadas" has pastel pinkish background and reddish border.
- [ ] Language selection in Settings uses a Dropdown with flag emojis: `🇧🇷 Português`, `🇺🇸 English`, `🇪🇸 Español`.
- [ ] Changing language instantly translates the app and persists to Drift SQLite.
- [ ] All tests pass and `flutter analyze` has 0 issues.
