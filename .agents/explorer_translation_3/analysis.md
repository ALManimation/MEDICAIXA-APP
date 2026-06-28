# Analysis: Dynamic Localization & Settings Persistence

## Executive Summary
This analysis details the current implementation of date/time formatting and language selection in the MediCaixa App, and proposes a complete, read-only solution to:
1. Dynamically localize date/time formatting on the Dashboard header, the `CalendarStripWidget`, and the `ReportsScreen` based on the active locale.
2. Persist the user's language selection reactively in the Drift SQLite `settings` database table, enabling correct initialization and real-time UI updates on app startup.

---

## 1. Investigation of Date/Time and Calendar Usages
The following hardcoded date/time formatting and calendar components were identified in the codebase:

### 1.1 Dashboard Header Date Formatting
- **File**: `lib/features/dashboard/presentation/dashboard_screen.dart`
- **Location**: Line 89 (invocation) and Lines 806–813 (definition).
- **Code**:
  ```dart
  // Line 89
  final dateStr = _formatPortugueseDate(state.selectedDate);

  // Lines 806-813
  String _formatPortugueseDate(DateTime date) {
    const days = ['Domingo', 'Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado'];
    const months = [
      'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
      'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro',
    ];
    return '${days[date.weekday % 7]}, ${date.day} de ${months[date.month - 1]}';
  }
  ```
- **Limitation**: The date string format is entirely hardcoded in Portuguese and does not adapt when the language changes.

### 1.2 CalendarStripWidget Weekday Abbreviations and Month Labels
- **File**: `lib/features/dashboard/presentation/widgets/calendar_strip_widget.dart`
- **Location**: Lines 258, 326, and 426.
- **Code**:
  ```dart
  // Lines 258 & 326
  items.add(MonthLabelItem(DateFormat('MMM', 'pt_BR').format(d).toUpperCase()));

  // Line 426
  DateFormat('E', 'pt_BR').format(item.date).toUpperCase().replaceAll('.', '')
  ```
- **Limitation**: Formatting is locked to the `'pt_BR'` locale parameters.

### 1.3 ReportsScreen Date Labels
- **Weekly Adherence (Daily Bars)**:
  - **File**: `lib/features/reports/presentation/reports_notifier.dart`
  - **Location**: Lines 304 and 334 in the `_calculateState` method.
  - **Code**:
    ```dart
    final List<String> ptWeekdayNames = ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb'];
    ...
    dailyAdherence.add(DailyAdherenceData(
      dayName: ptWeekdayNames[day.weekday % 7],
      ...
    ));
    ```
  - **Limitation**: Weekdays are hardcoded to the Portuguese list `ptWeekdayNames`.
- **Monthly Heatmap Headers**:
  - **File**: `lib/features/reports/presentation/widgets/monthly_heatmap.dart`
  - **Location**: Line 36.
  - **Code**:
    ```dart
    final List<String> headers = ['D', 'S', 'T', 'Q', 'Q', 'S', 'S'];
    ```
  - **Limitation**: Single-letter weekday headers are hardcoded to Portuguese initials.
- **Monthly Heatmap Row Labels**:
  - **File**: `lib/features/reports/presentation/widgets/monthly_heatmap.dart`
  - **Location**: Line 78.
  - **Code**:
    ```dart
    final sundayLabel = '${sunday.day.toString().padLeft(2, '0')}/${sunday.month.toString().padLeft(2, '0')}';
    ```
  - **Limitation**: Formatted using the European/Brazilian `DD/MM` layout regardless of locale.

### 1.4 Additional Log Screen Date Labels (Bonus Observation)
- **File**: `lib/features/history/presentation/history_screen.dart`
- **Location**: Lines 20, 22, 24.
- **Code**:
  ```dart
  if (eventDay == today) {
    return 'Hoje às $timeStr';
  } else if (eventDay == yesterday) {
    return 'Ontem às $timeStr';
  } else {
    return '${DateFormat('dd/MM/yyyy').format(dt)} às $timeStr';
  }
  ```
- **Limitation**: Contains hardcoded Portuguese conjunctions (`às`) and terms (`Hoje`, `Ontem`), and uses the static `dd/MM/yyyy` layout.

---

## 2. Formulated Localization Solution

To solve the date/time formatting dynamically, the `intl` package can be leveraged alongside the active locale code watched from `appLocaleProvider`.

### 2.1 Dashboard Header Formatting Solution
Modify `dashboard_screen.dart` to watch the active locale and format the date dynamically based on English vs. other languages (Spanish and Portuguese both use "de"):
```dart
// 1. In DashboardScreen build method, watch the active locale:
final locale = ref.watch(appLocaleProvider);

// 2. Modify line 89 to pass the locale:
final dateStr = _formatLocalizedDate(state.selectedDate, locale);

// 3. Replace _formatPortugueseDate with the localized helper:
String _formatLocalizedDate(DateTime date, String locale) {
  final String pattern;
  if (locale.startsWith('en')) {
    pattern = "EEEE, MMMM d";
  } else {
    pattern = "EEEE, d 'de' MMMM";
  }
  String formatted = DateFormat(pattern, locale).format(date);
  if (locale.startsWith('pt')) {
    // Strip "-feira" from Portuguese day names (e.g. Segunda-feira -> Segunda)
    formatted = formatted.replaceAll('-feira', '');
  }
  return formatted.isNotEmpty 
      ? '${formatted[0].toUpperCase()}${formatted.substring(1)}'
      : formatted;
}
```

### 2.2 CalendarStripWidget Solution
Modify `calendar_strip_widget.dart` to watch the locale and apply it inside formatting logic:
```dart
// 1. In CalendarStripWidget build method:
final locale = ref.watch(appLocaleProvider);

// 2. Update the invocation of _calculateItems to pass the locale:
_calculateItems(state.allAlarms, state.allReminders, selectedDate, locale);

// 3. Inside _calculateItems(..., String locale), replace 'pt_BR' with locale:
items.add(MonthLabelItem(DateFormat('MMM', locale).format(d).toUpperCase()));

// 4. In DateItem builder (around Line 426), replace 'pt_BR' with locale:
DateFormat('E', locale).format(item.date).toUpperCase().replaceAll('.', '')
```

### 2.3 ReportsScreen Solution
1. **Daily Bars chart in `reports_notifier.dart`**:
   - Establish dependency on the active locale in `build()` of `ReportsNotifier`:
     ```dart
     final locale = ref.watch(appLocaleProvider);
     return _calculateState(currentFilter, locale);
     ```
   - Generate the weekday abbreviations dynamically in `_calculateState(String filter, String locale)`:
     ```dart
     final rawDayName = DateFormat('E', locale).format(day);
     final dayName = rawDayName.isNotEmpty 
         ? '${rawDayName[0].toUpperCase()}${rawDayName.substring(1).replaceAll('.', '')}'
         : rawDayName;
     ```
2. **Heatmap Grid in `monthly_heatmap.dart`**:
   - Convert `MonthlyHeatmapWidget` into a `ConsumerWidget` to read the active locale:
     ```dart
     class MonthlyHeatmapWidget extends ConsumerWidget {
     ```
   - Watch the locale in the `build(BuildContext context, WidgetRef ref)` method:
     ```dart
     final locale = ref.watch(appLocaleProvider);
     ```
   - Dynamically generate weekday headers using the single-letter skeleton (`'EEEEE'`):
     ```dart
     final sunday = DateTime(2026, 6, 28); // Known Sunday
     final headers = List.generate(7, (i) {
       final d = sunday.add(Duration(days: i));
       return DateFormat('EEEEE', locale).format(d).toUpperCase();
     });
     ```
   - Dynamically format row starting labels according to the locale's layout standard (`MM/dd` for English, `dd/MM` for others):
     ```dart
     final sundayLabel = (locale.startsWith('en')) 
         ? DateFormat('MM/dd').format(sunday) 
         : DateFormat('dd/MM').format(sunday);
     ```

---

## 3. Database Settings and Locale Provider Integration

The SQLite `settings` table schema contains a `language` column that defaults to `'pt'`. We can link the `appLocaleProvider` directly to this column in a reactive manner using Drift streams.

### 3.1 Reactive Locale Provider Refactoring
Refactor `lib/core/providers/locale_provider.dart` to watch the Drift stream provider `watchSettingsProvider` reactively.
- When the app launches, `AppLocale.build()` watches the settings stream.
- Initially, it defaults to `'pt'` until the database query yields the persisted settings object.
- Once the settings object is loaded, it extracts the stored `language` code (e.g. `'en'` or `'es'`) and asynchronously updates translation assets (`AppLocalizations`).
- When the settings page modifies the language, it writes to the database Settings row. Drift alerts the stream, updating the state of `appLocaleProvider` and trigger rebuilding of all dependent UI elements automatically.

```dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:medicaixa_app/features/settings/data/settings_repository.dart';
import '../localization/app_localizations.dart';

part 'locale_provider.g.dart';

@riverpod
class AppLocale extends _$AppLocale {
  @override
  String build() {
    // Watch database settings reactively via the existing stream provider
    final settingsAsync = ref.watch(watchSettingsProvider);
    final languageCode = settingsAsync.value?.language ?? 'pt';

    // Asynchronously trigger loading of language JSON files without blocking synchronous build
    _loadTranslations(languageCode);

    return languageCode;
  }

  Future<void> _loadTranslations(String languageCode) async {
    await AppLocalizations.load(languageCode);
  }

  Future<void> changeLocale(String languageCode) async {
    // Persist choice to Drift database settings table
    final repo = ref.read(settingsRepositoryProvider);
    final settings = await repo.getSettings();
    await repo.updateSettings(settings.copyWith(language: languageCode));
  }
}
```

### 3.2 Initialize Date Formatting on Startup
To prevent `LocaleDataException` crashes in the `intl` package when switching to English or Spanish, add corresponding initializations to the `main()` function inside `lib/main.dart`:
```dart
void main() async {
  // Load default portuguese translations on startup
  await AppLocalizations.load('pt');
  
  // Initialize date formatting for ALL supported locales
  await initializeDateFormatting('pt_BR', null);
  await initializeDateFormatting('en', null);
  await initializeDateFormatting('es', null);

  await MCPToolkitBinding.instance.bootstrapFlutter(...);
}
```
Similarly, any widget tests that exercise layout navigation should also include these initializations in their `setUpAll` or `setUp` blocks.
