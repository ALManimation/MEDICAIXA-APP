# Progress Tracking - Light Theme Implementation

Last visited: 2026-06-28T21:28:56-03:00

## Checklist

- [x] 1. Modify `lib/core/constants/app_colors.dart` (convert variables to `static Color` and add `setTheme(bool isDark)`)
- [x] 2. Modify `lib/core/theme/app_theme.dart` (define `lightTheme` getter)
- [x] 3. Modify `lib/core/database/database.dart` (add `themeMode` column, bump schemaVersion to 5, write onUpgrade migration)
- [x] 4. Run `dart run build_runner build --delete-conflicting-outputs`
- [x] 5. Update `lib/features/settings/data/settings_repository.dart` (default value in companion, omit `themeMode` from sync payload)
- [x] 6. Create `lib/core/providers/theme_provider.dart` (Riverpod theme notifier, dynamic color swap on change, persist theme selection)
- [x] 7. Run `dart run build_runner build --delete-conflicting-outputs` to generate Riverpod annotations
- [x] 8. Update `lib/app.dart` (listen to `appThemeNotifierProvider` and wire themes/themeMode in MaterialApp)
- [x] 9. Update `lib/features/settings/presentation/settings_screen.dart` (add theme selection SegmentedButton under local adjustments, use context.mounted)
- [x] 10. Update translations (`assets/lang/{pt,en,es}.json` under `"web"` key)
- [x] 11. Run `flutter analyze` and fix any const issues or errors
- [x] 12. Run `flutter test` to ensure all tests pass
- [x] 13. Create detailed change report `changes.md` and complete handoff
