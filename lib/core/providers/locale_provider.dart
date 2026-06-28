import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../localization/app_localizations.dart';
import 'package:medicaixa_app/core/database/database.dart';
import 'package:medicaixa_app/features/settings/data/settings_repository.dart';

part 'locale_provider.g.dart';

@riverpod
class AppLocale extends _$AppLocale {
  String _normalizeLocale(String locale) {
    final lang = locale.split('_').first.split('-').first.toLowerCase();
    if (lang == 'en' || lang == 'es') {
      return lang;
    }
    return 'pt';
  }

  @override
  String build() {
    // 1. Listen to settings reactively for future updates
    ref.listen<AsyncValue<Setting?>>(watchSettingsProvider, (previous, next) async {
      final nextSetting = next.value;
      if (nextSetting != null) {
        final newLang = _normalizeLocale(nextSetting.language);
        if (newLang != state) {
          await AppLocalizations.load(newLang);
          state = newLang;
        }
      }
    });

    // 2. Determine initial state on creation
    final settingsVal = ref.read(watchSettingsProvider).value;
    if (settingsVal != null) {
      final initialLang = _normalizeLocale(settingsVal.language);
      if (initialLang != 'pt') {
        // Trigger async load for the DB language
        AppLocalizations.load(initialLang).then((_) {
          state = initialLang;
        });
      }
    }

    return 'pt'; // Default PT
  }

  Future<void> changeLocale(String languageCode) async {
    final normalized = _normalizeLocale(languageCode);

    // Load the translations asynchronously
    await AppLocalizations.load(normalized);
    
    // Update its state
    state = normalized;

    // Persist it to the SQLite settings table (via settingsRepositoryProvider)
    final repo = ref.read(settingsRepositoryProvider);
    final settings = await repo.getSettings();
    final updated = settings.copyWith(language: normalized);
    await repo.updateSettings(updated);
  }
}
