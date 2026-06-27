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
import 'package:intl/intl.dart';
import '../../history/data/history_repository.dart';
import '../../history/presentation/history_screen.dart';
import 'widgets/alarm_card_widget.dart';
import 'widgets/health_banner_widget.dart';
import 'widgets/reminder_card_widget.dart';
import 'widgets/weekly_rhythm_widget.dart';
import 'widgets/calendar_strip_widget.dart';

/// Main dashboard screen replicating the Web UI layout from index.html.
///
/// Structure:
/// - Header: greeting + date + connection status
/// - Health Banner (adherence indicator)
/// - Reminders section (above alarms, like Web UI)
/// - Alarms grouped by period: Manhã / Tarde / Noite
/// - Desktop sidebar: Weekly Rhythm
/// - FAB: create new alarm
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dashboardNotifierProvider);
    final notifier = ref.read(dashboardNotifierProvider.notifier);
    final connState = ref.watch(pairingNotifierProvider);
    final db = ref.watch(databaseProvider);
    final settingsStream = db.select(db.settings).watchSingleOrNull();
    final isDesktop = MediaQuery.of(context).size.width >= 800;

    return StreamBuilder<Setting?>(
      stream: settingsStream,
      builder: (context, snapshot) {
        final patientName = snapshot.data?.patientName ?? 'Paciente';

        // Time-based greeting (replicates updateGreeting from Web UI)
        final hour = DateTime.now().hour;
        String greeting;
        if (hour >= 5 && hour < 12) {
          greeting = 'Bom dia';
        } else if (hour >= 12 && hour < 18) {
          greeting = 'Boa tarde';
        } else {
          greeting = 'Boa noite';
        }

        // Formatted date (replicates updateDateDisplay from Web UI)
        final dateStr = _formatPortugueseDate(state.selectedDate);

        // Group alarms by period (replicates loadAlarms from Web UI)
        final morningAlarms = <AlarmModel>[];
        final afternoonAlarms = <AlarmModel>[];
        final nightAlarms = <AlarmModel>[];

        // Separate PRN alarms (they get their own section in the Web UI)
        final prnAlarms = <AlarmModel>[];

        for (final alarm in state.alarms) {
          if (alarm.isPrn == true) {
            prnAlarms.add(alarm);
            continue;
          }
          final effTime = _getEffectiveTime(alarm);
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
        final sortFn = (AlarmModel a, AlarmModel b) =>
            _getEffectiveTime(a).compareTo(_getEffectiveTime(b));
        morningAlarms.sort(sortFn);
        afternoonAlarms.sort(sortFn);
        nightAlarms.sort(sortFn);

        // Build main content
        final mainContent = SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header card (like Web UI <header>)
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
                                  tooltip: 'Desconectar',
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
                                tooltip: 'Sincronizar',
                                onPressed: state.isLoading ? null : () => notifier.sync(),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.history_rounded,
                                  size: 20,
                                  color: AppColors.textMuted,
                                ),
                                tooltip: 'Histórico & Logs',
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

              // Calendar Strip
              const SizedBox(height: 16),
              const CalendarStripWidget(),
              const SizedBox(height: 16),

              // Health Banner
              HealthBannerWidget(
                alarms: state.alarms,
                currentDate: state.selectedDate,
              ),
              const SizedBox(height: 16),

              // Connection status pill
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
                          ? 'MediCaixa conectada'
                          : 'Modo Offline',
                      style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Main body (responsive)
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
                              weekStats: _buildWeekStatsFromHistory(events),
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
        );

        return Scaffold(
          backgroundColor: AppColors.background,
          body: state.isLoading
              ? Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                )
              : RefreshIndicator(
                  onRefresh: () => notifier.sync(),
                  color: AppColors.primary,
                  child: mainContent,
                ),
          floatingActionButton: FloatingActionButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AlarmWizardScreen()),
              );
            },
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            tooltip: 'Novo Alarme',
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header (like Web UI section-title)
        Row(
          children: [
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.text,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        if (alarms.isEmpty)
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
                'Nenhum alarme neste período',
                style: TextStyle(color: AppColors.textMuted, fontSize: 14),
              ),
            ),
          )
        else
          ...alarms.map((alarm) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AlarmCardWidget(
                alarm: alarm,
                onMarkTaken: () => ref.read(alarmRepositoryProvider).markTaken(alarm.id),
                onMarkSkipped: () => ref.read(alarmRepositoryProvider).markSkipped(alarm.id),
                onToggleEnabled: (val) => ref.read(alarmRepositoryProvider).toggleAlarm(alarm.id, val),
                onTap: () => _openSnoozeModal(context, ref, alarm),
              ),
            );
          }),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildRemindersSection(BuildContext context, DashboardState state, WidgetRef ref) {
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
                  'Lembretes',
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
        if (state.reminders.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                Icon(Icons.push_pin_outlined, color: AppColors.textMuted, size: 32),
                const SizedBox(height: 8),
                const Text(
                  'Nenhum lembrete ativo para este dia.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          ...state.reminders.map(
            (reminder) => ReminderCardWidget(
              reminder: reminder,
              selectedDate: state.selectedDate,
              onComplete: () => repo.completeReminder(reminder.id),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ReminderFormScreen(editReminder: reminder),
                  ),
                );
              },
            ),
          ),
        const SizedBox(height: 16),
      ],
    );
  }

  void _openSnoozeModal(BuildContext context, WidgetRef ref, AlarmModel alarm) {
    final repo = ref.read(alarmRepositoryProvider);
    SnoozeModal.show(
      context,
      alarm: alarm,
      onSnooze: (minutes) => repo.snoozeAlarm(alarm.id, minutes),
      onCancelSnooze: () => repo.snoozeAlarm(alarm.id, 0),
      onToggle: (enabled) => repo.toggleAlarm(alarm.id, enabled),
      onEdit: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => AlarmWizardScreen(editAlarm: alarm),
          ),
        );
      },
      onDelete: () => repo.removeAlarm(alarm.id),
    );
  }

  /// Calculates effective time in minutes, accounting for snooze.
  /// Replicates getAlarmEffectiveTime from Web UI.
  static int _getEffectiveTime(AlarmModel alarm) {
    int mins = alarm.hour * 60 + alarm.minute;
    if (alarm.snoozeMin > 0) mins += alarm.snoozeMin;
    return mins % 1440;
  }

  /// Formats date in Portuguese: "Segunda, 12 de Maio"
  String _formatPortugueseDate(DateTime date) {
    const days = ['Domingo', 'Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado'];
    const months = [
      'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
      'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro',
    ];
    return '${days[date.weekday % 7]}, ${date.day} de ${months[date.month - 1]}';
  }

  List<DayStat> _buildWeekStatsFromHistory(List<HistoryEvent> events) {
    final now = DateTime.now();
    const dayNames = ['D', 'S', 'T', 'Q', 'Q', 'S', 'S'];
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
      final dow = date.weekday % 7;
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      final dayEvents = eventsByDate[dateStr] ?? [];

      final taken = dayEvents.where((e) => e.status == 'TOMADO' || e.status == 'CONCLUIDO').length;
      final missed = dayEvents.where((e) => e.status == 'PERDIDO').length;
      final expected = taken + missed;

      stats.add(DayStat(
        dayLabel: dayNames[dow],
        taken: taken,
        expected: expected,
      ));
    }
    return stats;
  }

  int _calcAdherencePercentFromHistory(List<HistoryEvent> events) {
    final now = DateTime.now();
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
