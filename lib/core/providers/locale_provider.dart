import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../localization/app_localizations.dart';

part 'locale_provider.g.dart';

@riverpod
class AppLocale extends _$AppLocale {
  @override
  String build() {
    return 'pt'; // Default PT
  }

  Future<void> changeLocale(String languageCode) async {
    await AppLocalizations.load(languageCode);
    state = languageCode;
  }
}
