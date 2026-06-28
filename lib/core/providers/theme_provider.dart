import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../constants/app_colors.dart';
import 'package:medicaixa_app/core/database/database.dart';
import 'package:medicaixa_app/features/settings/data/settings_repository.dart';

part 'theme_provider.g.dart';

@riverpod
class AppThemeNotifier extends _$AppThemeNotifier {
  @override
  ThemeMode build() {
    // 1. Listen to settings reactively for future updates
    ref.listen<AsyncValue<Setting?>>(watchSettingsProvider, (previous, next) {
      final nextSetting = next.value;
      if (nextSetting != null) {
        final newMode = nextSetting.themeMode == 'light' ? ThemeMode.light : ThemeMode.dark;
        if (newMode != state) {
          AppColors.setTheme(newMode == ThemeMode.dark);
          state = newMode;
        }
      }
    });

    // 2. Determine initial state on creation
    final settingsVal = ref.read(watchSettingsProvider).value;
    if (settingsVal != null) {
      final initialMode = settingsVal.themeMode == 'light' ? ThemeMode.light : ThemeMode.dark;
      AppColors.setTheme(initialMode == ThemeMode.dark);
      return initialMode;
    }

    // Default to dark mode
    AppColors.setTheme(true);
    return ThemeMode.dark;
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    // 1. Persist it to the SQLite settings table first
    final repo = ref.read(settingsRepositoryProvider);
    final settings = await repo.getSettings();
    final updated = settings.copyWith(themeMode: mode == ThemeMode.light ? 'light' : 'dark');
    await repo.updateSettings(updated);

    // 2. Set the state and update AppColors
    state = mode;
    AppColors.setTheme(mode == ThemeMode.dark);
  }
}
