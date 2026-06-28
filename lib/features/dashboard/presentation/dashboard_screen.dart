import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/database/database.dart';
import '../../../core/providers/core_providers.dart';
import '../../pairing/domain/connection_state.dart';
import '../../pairing/presentation/pairing_notifier.dart';
import '../../pairing/presentation/pairing_screen.dart';
import '../../alarms/presentation/wizard/alarm_wizard_screen.dart';
import '../../alarms/presentation/snooze_modal.dart';
import '../../alarms/data/alarm_model.dart';
import '../../alarms/data/alarm_repository.dart';
import '../../reminders/data/reminder_repository.dart';
import 'dashboard_notifier.dart';
import '../../reminders/presentation/reminder_form_screen.dart';
import 'package:medicaixa_app/features/reminders/presentation/widgets/reminder_action_modal.dart';
import 'package:intl/intl.dart';
import '../../history/data/history_repository.dart';
import '../../history/presentation/history_screen.dart';
import 'widgets/alarm_card_widget.dart';
import 'widgets/health_banner_widget.dart';
import 'widgets/reminder_card_widget.dart';
import 'widgets/weekly_rhythm_widget.dart';
import 'widgets/calendar_strip_widget.dart';
import '../../../core/providers/locale_provider.dart';
import '../../../core/localization/app_localizations.dart';

/// Allowed override for testing the local date and time.
@visibleForTesting
DateTime Function() currentDateOverride = () => DateTime.now();

/// Main dashboard screen replicating the Web UI layout from index.html.
///
/// Structure:
/// - Header: greeting + date + connection status
/// - Health Banner (adherence indicator)
/// - Reminders section (above alarms, like Web UI)
/// - Alarms grouped by period: Manhã / Tarde / Noite
/// - Desktop sidebar: Weekly Rhythm
/// - FAB: create new alarm
final dashboardCollapseProvider = StateProvider<Map<String, bool>>((ref) => const {});

/// Main dashboard screen replicating the Web UI layout from index.html.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<DateTime>(
      dashboardNotifierProvider.select((s) => s.selectedDate),
      (previous, next) {
        ref.read(dashboardCollapseProvider.notifier).state = const {};
      },
    );

    final state = ref.watch(dashboardNotifierProvider);
    final notifier = ref.read(dashboardNotifierProvider.notifier);
    final connState = ref.watch(pairingNotifierProvider);
    final db = ref.watch(databaseProvider);
    final settingsStream = db.select(db.settings).watchSingleOrNull();
    final isDesktop = MediaQuery.of(context).size.width >= 800;

    return StreamBuilder<Setting?>(
      stream: settingsStream,
      builder: (context, snapshot) {
        final patientName = snapshot.data?.patientName ?? t('tab_patient');

        // Time-based greeting (replicates updateGreeting from Web UI)
        final now = currentDateOverride();
        final hour = now.hour;
        String greeting;
        if (hour >= 5 && hour < 12) {
          greeting = t('greeting_morning');
        } else if (hour >= 12 && hour < 18) {
          greeting = t('greeting_afternoon');
        } else {
          greeting = t('greeting_evening');
        }

        // Group alarms by period (replicates loadAlarms from Web UI)
        final morningAlarms = <AlarmModel>[];
        final afternoonAlarms = <AlarmModel>[];
        final nightAlarms = <AlarmModel>[];

        // Separate PRN alarms (they get their own section in the Web UI)
        final prnAlarms = <AlarmModel>[];

        final isToday = state.selectedDate.year == now.year &&
            state.selectedDate.month == now.month &&
            state.selectedDate.day == now.day;
        final locale = ref.watch(appLocaleProvider);
        final dateStr = _formatLocalizedDate(state.selectedDate, locale);

        for (final alarm in state.alarms) {
          if (alarm.isPrn == true) {
            prnAlarms.add(alarm);
            continue;
          }
          final effTime = _getEffectiveTime(alarm, isToday: isToday);
          // Web UI grouping: 00:00-11:59 → morning, 12:00-17:59 → afternoon, 18:00-23:59 → night
          if (effTime >= 0 && effTime < 720) {
            morningAlarms.add(alarm);
          } else if (effTime >= 720 && effTime < 1080) {
            afternoonAlarms.add(alarm);
          } else {
            nightAlarms.add(alarm);
          }
        }

        // Sort each group by effective time
        int sortFn(AlarmModel a, AlarmModel b) =>
            _getEffectiveTime(a, isToday: isToday).compareTo(_getEffectiveTime(b, isToday: isToday));
        morningAlarms.sort(sortFn);
        afternoonAlarms.sort(sortFn);
        nightAlarms.sort(sortFn);

        // Build fixed header column
        final fixedHeader = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 1. Header Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: SafeArea(
                bottom: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top row: greeting + sync button
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$greeting, $patientName!',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.text,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                dateStr,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Connection indicator
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (connState.status == ConnectionStatus.connected)
                              IconButton(
                                icon: const Icon(Icons.link_off_rounded, size: 20),
                                tooltip: t('dash_disconnect'),
                                color: AppColors.textMuted,
                                onPressed: () {
                                  ref.read(pairingNotifierProvider.notifier).disconnect();
                                  Navigator.of(context).pushReplacement(
                                    MaterialPageRoute(builder: (_) => const PairingScreen()),
                                  );
                                },
                              ),
                            IconButton(
                              icon: Icon(
                                Icons.sync_rounded,
                                size: 20,
                                color: state.isLoading ? AppColors.border : AppColors.textMuted,
                              ),
                              tooltip: t('dash_sync'),
                              onPressed: state.isLoading ? null : () => notifier.sync(),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.history_rounded,
                                size: 20,
                                color: AppColors.textMuted,
                              ),
                              tooltip: t('dash_history_logs'),
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => const HistoryScreen()),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // 2. Health Adherence Banner
            const SizedBox(height: 16),
            HealthBannerWidget(
              alarms: state.alarms,
              currentDate: state.selectedDate,
            ),

            // 3. Calendar Strip
            const SizedBox(height: 16),
            const CalendarStripWidget(),

            // 4. Connection status indicator
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: connState.status == ConnectionStatus.connected
                          ? AppColors.success
                          : AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    connState.status == ConnectionStatus.connected
                        ? t('dash_connected_status')
                        : t('dash_offline_status'),
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        );

        // Build scrollable body wrapped in Expanded and RefreshIndicator
        final scrollableBody = Expanded(
          child: RefreshIndicator(
            onRefresh: () => notifier.sync(),
            color: AppColors.primary,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isDesktop)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left: alarms
                          Expanded(
                            flex: 2,
                            child: _buildAlarmsBody(
                              context, ref, state,
                              morningAlarms, afternoonAlarms, nightAlarms, prnAlarms,
                            ),
                          ),
                          const SizedBox(width: 24),
                          // Right: weekly rhythm sidebar
                          Expanded(
                            flex: 1,
                            child: StreamBuilder<List<HistoryEvent>>(
                              stream: ref.watch(historyRepositoryProvider).watchAllHistoryEvents(),
                              builder: (context, snapshot) {
                                final events = snapshot.data ?? [];
                                return WeeklyRhythmWidget(
                                  weekStats: _buildWeekStatsFromHistory(events, locale),
                                  adherencePercent: _calcAdherencePercentFromHistory(events),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _buildAlarmsBody(
                        context, ref, state,
                        morningAlarms, afternoonAlarms, nightAlarms, prnAlarms,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );

        return Scaffold(
          backgroundColor: AppColors.background,
          body: state.isLoading
              ? Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                )
              : Column(
                  children: [
                    fixedHeader,
                    scrollableBody,
                  ],
                ),
          floatingActionButton: FloatingActionButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AlarmWizardScreen()),
              );
            },
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            tooltip: t('new_alarm_title'),
            child: const Icon(Icons.add_rounded),
          ),
        );
      },
    );
  }

  /// Builds the main alarms body with reminders on top and 3 period groups.
  Widget _buildAlarmsBody(
    BuildContext context,
    WidgetRef ref,
    DashboardState state,
    List<AlarmModel> morning,
    List<AlarmModel> afternoon,
    List<AlarmModel> night,
    List<AlarmModel> prn,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Reminders section (above alarms, as user requested)
        _buildRemindersSection(context, state, ref),

        // PRN section (Sob Demanda — between reminders and alarms, like Web UI)
        if (prn.isNotEmpty)
          _buildPeriodSection(
            context, ref,
            icon: Icons.medication_liquid_rounded,
            iconColor: const Color(0xFF60A5FA),
            label: 'Sob Demanda (PRN)',
            alarms: prn,
            serverDate: state.selectedDate,
          ),

        // Morning section
        _buildPeriodSection(
          context, ref,
          icon: Icons.wb_sunny_rounded,
          iconColor: AppColors.morningColor,
          label: 'Manhã',
          alarms: morning,
          serverDate: state.selectedDate,
        ),

        // Afternoon section
        _buildPeriodSection(
          context, ref,
          icon: Icons.cloud_rounded,
          iconColor: AppColors.afternoonColor,
          label: 'Tarde',
          alarms: afternoon,
          serverDate: state.selectedDate,
        ),

        // Night section
        _buildPeriodSection(
          context, ref,
          icon: Icons.nightlight_round,
          iconColor: AppColors.nightColor,
          label: 'Noite',
          alarms: night,
          serverDate: state.selectedDate,
        ),
      ],
    );
  }

  bool _isAlarmPending(
    AlarmModel alarm,
    DateTime selectedDate,
    bool isToday,
    DateTime now,
    String dateFormatted,
  ) {
    if (!alarm.enabled || !alarm.active) {
      return false;
    }
    final isTakenToday = alarm.lastStatusDate == dateFormatted && alarm.lastStatus == 'Tomado';
    if (isTakenToday) {
      return false;
    }
    final isSkippedToday = alarm.lastStatusDate == dateFormatted && alarm.lastStatus == 'Não Tomado';
    if (isSkippedToday) {
      return false;
    }

    if (isToday) {
      final alarmTime = DateTime(now.year, now.month, now.day, alarm.hour, alarm.minute);
      if (now.isAfter(alarmTime)) {
        return false; // missed, so not pending
      }
    } else {
      final targetZero = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
      final todayZero = DateTime(now.year, now.month, now.day);
      if (targetZero.isBefore(todayZero)) {
        return false; // past date, not taken is missed, so not pending
      }
    }

    return true;
  }

  int _getMissedCountForSection(
    List<AlarmModel> alarms,
    DateTime selectedDate,
    bool isToday,
    DateTime now,
    String dateFormatted,
  ) {
    int missedCount = 0;
    for (final alarm in alarms) {
      final isTakenToday = alarm.lastStatusDate == dateFormatted && alarm.lastStatus == 'Tomado';
      if (isTakenToday) {
        continue;
      }
      final isSkippedToday = alarm.lastStatusDate == dateFormatted && alarm.lastStatus == 'Não Tomado';
      if (isSkippedToday) {
        missedCount++;
      } else {
        if (isToday) {
          final alarmTime = DateTime(now.year, now.month, now.day, alarm.hour, alarm.minute);
          if (now.isAfter(alarmTime)) {
            missedCount++;
          }
        } else {
          final targetZero = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
          final todayZero = DateTime(now.year, now.month, now.day);
          if (targetZero.isBefore(todayZero)) {
            missedCount++;
          }
        }
      }
    }
    return missedCount;
  }

  bool _isSectionCollapsed(
    String label,
    List<AlarmModel> alarms,
    DateTime selectedDate,
    WidgetRef ref,
  ) {
    final overrides = ref.watch(dashboardCollapseProvider);
    if (overrides.containsKey(label)) {
      return overrides[label]!;
    }

    if (alarms.isEmpty) {
      return false;
    }

    final now = currentDateOverride();
    final isToday = selectedDate.year == now.year &&
        selectedDate.month == now.month &&
        selectedDate.day == now.day;
    final dateFormatted = "${selectedDate.day.toString().padLeft(2, '0')}/${selectedDate.month.toString().padLeft(2, '0')}/${selectedDate.year}";

    if (!isToday) {
      return false;
    }

    final hasPending = alarms.any((alarm) => _isAlarmPending(alarm, selectedDate, isToday, now, dateFormatted));
    if (!hasPending) {
      return true;
    }

    if (label == 'Manhã' && now.hour >= 12) {
      return true;
    }
    if (label == 'Tarde' && now.hour >= 18) {
      return true;
    }

    return false;
  }

  /// Builds a period section (Manhã, Tarde, Noite) with icon and alarm list.
  Widget _buildPeriodSection(
    BuildContext context,
    WidgetRef ref, {
    required IconData icon,
    required Color iconColor,
    required String label,
    required List<AlarmModel> alarms,
    required DateTime serverDate,
  }) {
    final now = currentDateOverride();
    final isToday = serverDate.year == now.year &&
        serverDate.month == now.month &&
        serverDate.day == now.day;
    final dateFormatted = "${serverDate.day.toString().padLeft(2, '0')}/${serverDate.month.toString().padLeft(2, '0')}/${serverDate.year}";

    final isCollapsed = _isSectionCollapsed(label, alarms, serverDate, ref);

    final totalCount = alarms.length;
    final missedCount = _getMissedCountForSection(alarms, serverDate, isToday, now, dateFormatted);

    final String translatedLabel;
    if (label == 'Manhã') {
      translatedLabel = t('section_morning');
    } else if (label == 'Tarde') {
      translatedLabel = t('section_afternoon');
    } else if (label == 'Noite') {
      translatedLabel = t('section_night');
    } else if (label == 'Sob Demanda (PRN)') {
      translatedLabel = t('alarm_freq_prn');
    } else {
      translatedLabel = label;
    }

    final Widget headerContent = Row(
      children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(width: 8),
        Text(
          totalCount > 0 ? '$translatedLabel ($totalCount)' : translatedLabel,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.text,
          ),
        ),
        if (totalCount > 0 && missedCount > 0) ...[
          const SizedBox(width: 8),
          Text(
            '• $missedCount ${missedCount > 1 ? t('dash_missed_plural') : t('dash_missed_singular')}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.missed,
            ),
          ),
        ],
        const Spacer(),
        if (alarms.isNotEmpty)
          AnimatedRotation(
            turns: isCollapsed ? 0.0 : 0.5,
            duration: const Duration(milliseconds: 200),
            child: Icon(
              Icons.keyboard_arrow_down_rounded,
              color: AppColors.textMuted,
            ),
          ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (alarms.isEmpty) ...[
          headerContent,
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                t('no_alarms_period'),
                style: TextStyle(color: AppColors.textMuted, fontSize: 14),
              ),
            ),
          ),
        ] else ...[
          InkWell(
            onTap: () {
              final currentOverrides = ref.read(dashboardCollapseProvider);
              final newOverrides = Map<String, bool>.from(currentOverrides);
              newOverrides[label] = !isCollapsed;
              ref.read(dashboardCollapseProvider.notifier).state = newOverrides;
            },
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: headerContent,
            ),
          ),
          const SizedBox(height: 10),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            child: isCollapsed
                ? const SizedBox.shrink()
                : Column(
                    children: [
                      ...alarms.map((alarm) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: AlarmCardWidget(
                            alarm: alarm,
                            onMarkTaken: alarm.isGhost
                                ? () {}
                                : () async {
                                    if (alarm.isPrn == true) {
                                      await _handleTakePrn(context, ref, alarm);
                                    } else {
                                      await ref.read(alarmRepositoryProvider).markTaken(alarm.id);
                                    }
                                    ref.read(dashboardNotifierProvider.notifier).refresh();
                                  },
                            onMarkSkipped: alarm.isGhost
                                ? () {}
                                : () async {
                                    await ref.read(alarmRepositoryProvider).markSkipped(alarm.id);
                                    ref.read(dashboardNotifierProvider.notifier).refresh();
                                  },
                            onToggleEnabled: alarm.isGhost
                                ? (_) {}
                                : (val) async {
                                    await ref.read(alarmRepositoryProvider).toggleAlarm(alarm.id, val);
                                    ref.read(dashboardNotifierProvider.notifier).refresh();
                                  },
                            onTap: (alarm.isPrn == true || alarm.isGhost == true) ? null : () => _openSnoozeModal(context, ref, alarm),
                          ),
                        );
                      }),
                      const SizedBox(height: 12),
                    ],
                  ),
          ),
        ],
      ],
    );
  }

  Widget _buildRemindersSection(BuildContext context, DashboardState state, WidgetRef ref) {
    if (state.reminders.isEmpty) {
      return const SizedBox.shrink();
    }

    final repo = ref.read(reminderRepositoryProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.push_pin_rounded, color: AppColors.secondary, size: 20),
                const SizedBox(width: 8),
                Text(
                  t('section_reminders'),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                  ),
                ),
              ],
            ),
            IconButton(
              icon: Icon(Icons.add_rounded, color: AppColors.primary),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ReminderFormScreen(),
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...state.reminders.map(
            (reminder) => ReminderCardWidget(
              reminder: reminder,
              selectedDate: state.selectedDate,
              onComplete: () async {
                await repo.completeReminder(reminder.id);
                ref.read(dashboardNotifierProvider.notifier).refresh();
              },
              onTap: () {
                ReminderActionModal.show(
                  context,
                  reminder: reminder,
                  repository: repo,
                  onRefresh: () => ref.read(dashboardNotifierProvider.notifier).refresh(),
                );
              },
            ),
          ),
        const SizedBox(height: 16),
      ],
    );
  }

  Future<void> _handleTakePrn(BuildContext context, WidgetRef ref, AlarmModel alarm) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t('alarm_freq_prn')),
        content: Text(t('prn_confirm_take')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(t('cancel_btn').toUpperCase(), style: TextStyle(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(t('dash_register_btn'), style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ref.read(alarmRepositoryProvider).takePrn(alarm.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(t('prn_taken_success')),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          final errorMsg = e.toString().replaceFirst('Exception: ', '');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMsg),
              backgroundColor: AppColors.missed,
            ),
          );
        }
      }
    }
  }

  void _openSnoozeModal(BuildContext context, WidgetRef ref, AlarmModel alarm) {
    final repo = ref.read(alarmRepositoryProvider);
    final notifier = ref.read(dashboardNotifierProvider.notifier);
    SnoozeModal.show(
      context,
      alarm: alarm,
      onMarkTaken: (customQty) async {
        await repo.markTaken(alarm.id, customQty: customQty);
        notifier.refresh();
      },
      onMarkSkipped: () async {
        await repo.markSkipped(alarm.id);
        notifier.refresh();
      },
      onSnooze: (minutes) async {
        await repo.snoozeAlarm(alarm.id, minutes);
        notifier.refresh();
      },
      onCancelSnooze: () async {
        await repo.snoozeAlarm(alarm.id, 0);
        notifier.refresh();
      },
      onToggle: (enabled) async {
        await repo.toggleAlarm(alarm.id, enabled);
        notifier.refresh();
      },
      onEdit: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => AlarmWizardScreen(editAlarm: alarm),
          ),
        );
      },
      onDelete: () async {
        await repo.removeAlarm(alarm.id);
        notifier.refresh();
      },
    ).then((_) => notifier.refresh());
  }

  /// Calculates effective time in minutes, accounting for snooze.
  /// Replicates getAlarmEffectiveTime from Web UI.
  static int _getEffectiveTime(AlarmModel alarm, {required bool isToday}) {
    int mins = alarm.hour * 60 + alarm.minute;
    if (isToday && alarm.snoozeMin > 0) mins += alarm.snoozeMin;
    return mins % 1440;
  }

  /// Formats date localized
  String _formatLocalizedDate(DateTime date, String locale) {
    if (locale == 'en') {
      return DateFormat('EEEE, MMMM d', locale).format(date);
    } else {
      final formatted = DateFormat("EEEE, d 'de' MMMM", locale).format(date);
      if (formatted.isEmpty) return formatted;
      var result = formatted[0].toUpperCase() + formatted.substring(1);
      final index = result.lastIndexOf(' de ');
      if (index != -1 && index + 4 < result.length) {
        result = result.substring(0, index + 4) +
            result[index + 4].toUpperCase() +
            result.substring(index + 5);
      }
      return result;
    }
  }

  List<DayStat> _buildWeekStatsFromHistory(List<HistoryEvent> events, String locale) {
    final now = currentDateOverride();
    final stats = <DayStat>[];

    // Map events by date (YYYY-MM-DD)
    final eventsByDate = <String, List<HistoryEvent>>{};
    for (final e in events) {
      final dt = DateTime.fromMillisecondsSinceEpoch(e.timestamp);
      final dateStr = DateFormat('yyyy-MM-dd').format(dt);
      eventsByDate.putIfAbsent(dateStr, () => []).add(e);
    }

    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      final dayEvents = eventsByDate[dateStr] ?? [];

      final taken = dayEvents.where((e) => e.status == 'TOMADO' || e.status == 'CONCLUIDO').length;
      final missed = dayEvents.where((e) => e.status == 'PERDIDO').length;
      final expected = taken + missed;

      // Get first letter of localized day name
      final dayName = DateFormat('E', locale).format(date);
      final dayLabel = dayName.isNotEmpty ? dayName[0].toUpperCase() : '';

      stats.add(DayStat(
        dayLabel: dayLabel,
        taken: taken,
        expected: expected,
      ));
    }
    return stats;
  }

  int _calcAdherencePercentFromHistory(List<HistoryEvent> events) {
    final now = currentDateOverride();
    final sevenDaysAgo = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 7));
    final weekEvents = events.where((e) {
      final dt = DateTime.fromMillisecondsSinceEpoch(e.timestamp);
      return dt.isAfter(sevenDaysAgo);
    }).toList();

    final taken = weekEvents.where((e) => e.status == 'TOMADO' || e.status == 'CONCLUIDO').length;
    final missed = weekEvents.where((e) => e.status == 'PERDIDO').length;
    final total = taken + missed;
    
    if (total == 0) return 100;
    return ((taken / total) * 100).round();
  }
}
