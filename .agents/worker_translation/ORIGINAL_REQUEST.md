## 2026-06-28T19:40:00Z
You are worker_translation (Archetype: teamwork_preview_worker).
Your mission is to implement the complete multilingual translation (pt, en, es) of the entire Flutter application interface based on the user request and findings of the Explorers.

Ensure you adhere strictly to AGENTS.md constraints (e.g. no const with AppColors, use context.mounted, etc.).

MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A Forensic Auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

Tasks:
1. Append the new translation keys (from explorer 2's analysis.md) to 'assets/lang/pt.json', 'assets/lang/en.json', and 'assets/lang/es.json' inside their respective "web" object block. Make sure to separate them from existing entries with a comma.
2. In 'lib/main.dart', initialize date formatting for English ('en') and Spanish ('es') using initializeDateFormatting.
3. In 'lib/core/providers/locale_provider.dart', refactor the AppLocale notifier class so it watches the settings table reactively. When settings emit a new language choice:
   - Load the translations asynchronously using AppLocalizations.load.
   - Update its state.
   - When changeLocale(code) is called, load the translations, update state, and persist it to the SQLite settings table (via settingsRepositoryProvider).
4. Localize date and calendar formatting:
   - Dashboard date header: convert to dynamic format using DateFormat and active locale.
   - CalendarStripWidget: replace hardcoded 'pt_BR' references with the active locale from appLocaleProvider.
   - ReportsScreen and Weekly Adherence weekday name list: dynamically format weekday names according to active locale instead of using a hardcoded Portuguese list.
   - MonthlyHeatmap: convert to ConsumerWidget (if not already), read active locale, and localize the tooltip texts and weekday initials.
5. Replace all hardcoded strings (listed in explorer 1 and 2 reports) in the following files with calls to the global translation function t('key') or t('key', [args]):
   - lib/core/presentation/app_shell.dart
   - lib/features/dashboard/presentation/dashboard_screen.dart
   - lib/features/dashboard/presentation/widgets/alarm_card_widget.dart
   - lib/features/dashboard/presentation/widgets/day_summary_widget.dart
   - lib/features/dashboard/presentation/widgets/health_banner_widget.dart
   - lib/features/dashboard/presentation/widgets/reminder_card_widget.dart
   - lib/features/medications/presentation/medications_list_screen.dart
   - lib/features/medications/presentation/medication_form_screen.dart
   - lib/features/reports/presentation/reports_screen.dart
   - lib/features/reports/presentation/widgets/donut_chart.dart
   - lib/features/reports/presentation/widgets/streak_dots.dart
   - lib/features/reports/presentation/widgets/period_distribution.dart
   - lib/features/reports/presentation/widgets/medication_performance.dart
   - lib/features/reports/presentation/widgets/monthly_heatmap.dart
   - lib/features/history/presentation/history_screen.dart
   - lib/features/settings/presentation/settings_screen.dart
   - lib/features/alarms/presentation/snooze_modal.dart
   - lib/features/reminders/presentation/widgets/reminder_action_modal.dart
   - lib/features/alarms/presentation/widgets/dynamic_dose_dialog.dart
6. Write automated tests (in a new test file test/localization_test.dart) verifying that language switching dynamically updates texts and dates on key screens (Dashboard, Settings, etc.).
7. Verify with 'flutter test' and 'flutter analyze' that all tests pass and there are 0 errors/warnings.
8. Write your completion report to your handoff.md and notify me when done.
