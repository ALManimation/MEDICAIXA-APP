## 2026-06-28T22:47:21Z

You are a Flutter developer. Your task is to implement the following changes in the codebase:
1. **Reactivity of the Bottom Navigation Bar in AppShell**:
   - File path: `lib/core/presentation/app_shell.dart`
   - In `_AppShellState.build`, watch the theme provider:
     `final themeMode = ref.watch(appThemeNotifierProvider);`
     This makes sure that the `AppShell` rebuilds automatically when the theme changes.
   - Also, in `lib/app.dart`, double check if there's any `const AppShell()`. It is currently instantiated as `home: const AppShell(),`. Keep it as is (or remove the `const` if needed), since watching the provider in `AppShell` will trigger the rebuild correctly anyway.
2. **Settings Screen Language Selector replacement**:
   - File path: `lib/features/settings/presentation/settings_screen.dart`
   - In `_buildAppConfigCard`, replace `SegmentedButton<String>` with a `DropdownButtonFormField<String>`.
   - The dropdown should list the items:
     - `🇧🇷 Português` (value: `'pt'`)
     - `🇺🇸 English` (value: `'en'`)
     - `🇪🇸 Español` (value: `'es'`)
   - Style the `DropdownButtonFormField` to match other fields in settings:
     - Use `dropdownColor: AppColors.surface`
     - Use decoration with `border: OutlineInputBorder()` and contentPadding.
     - Ensure the text style uses `color: AppColors.text`.
     - Ensure no widget using `AppColors.xxx` is marked as `const` (Rule 22).
   - On change, trigger `await ref.read(appLocaleProvider.notifier).changeLocale(value);`. Make sure that if async is awaited, you use `context.mounted` or ensure no state change happens on an unmounted context (Rule 32).
3. **Settings Screen Warning Cards styling in Light Theme**:
   - In `_buildConnectionWarningCard` (Configurações da Caixinha Bloqueadas):
     - Background color: `AppColors.healthDangerBg`
     - Border shape side: `BorderSide(color: AppColors.healthDangerBorder, width: 1.5)`
     - Text and Icon color: `AppColors.healthDanger`
     - Keep description text color as `AppColors.textMuted` and connection button style consistent.
   - In `_buildDeveloperFixtureCard` (Testes Offline (Fixture)):
     - Check if it is light theme using `ref.watch(appThemeNotifierProvider) == ThemeMode.light`.
     - If it is light theme, use background color `AppColors.surface` and border side `BorderSide(color: AppColors.border)`. If dark theme, keep using `AppColors.surfaceVariant.withValues(alpha: 0.5)` and `BorderSide(color: AppColors.border)`.
4. **Mandatory Integrity Warning**:
   - DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A Forensic Auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

After modifying the files:
1. Run `dart run build_runner build --delete-conflicting-outputs` (only if any models/schemas require code generation, but since we are modifying UI layouts, it's optional but good to verify).
2. Run `flutter analyze` to check for compile errors, warnings, and lints.
3. Write a summary of the changes and build results to `/Users/almanimation/Downloads/Caixa Remedios/medicaixa_app/.agents/worker_remedy_theme_dropdown/handoff.md`. Ensure that the handoff includes passing build results and layout compliance. When done, provide your handoff report.
