import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../data/history_repository.dart';
import '../../../core/database/database.dart';
import '../../../core/localization/app_localizations.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  String _formatTimestamp(int timestamp) {
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final eventDay = DateTime(dt.year, dt.month, dt.day);

    final timeStr = DateFormat('HH:mm').format(dt);
    if (eventDay == today) {
      return t('today_at_time', [timeStr]);
    } else if (eventDay == yesterday) {
      return t('yesterday_at_time', [timeStr]);
    } else {
      final dateStr = DateFormat('dd/MM/yyyy').format(dt);
      return t('date_at_time', [dateStr, timeStr]);
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'TOMADO':
      case 'TOMADO FORA HORA':
      case 'TOMADO PRN':
      case 'CONCLUIDO':
        return AppColors.success;
      case 'PERDIDO':
        return AppColors.missed;
      case 'SNOOZED':
        return AppColors.pending;
      default:
        return AppColors.textMuted;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toUpperCase()) {
      case 'TOMADO':
      case 'TOMADO FORA HORA':
      case 'TOMADO PRN':
      case 'CONCLUIDO':
        return Icons.check_circle_rounded;
      case 'PERDIDO':
        return Icons.cancel_rounded;
      case 'SNOOZED':
        return Icons.snooze_rounded;
      default:
        return Icons.info_outline_rounded;
    }
  }

  String _formatStatusText(String status) {
    switch (status.toUpperCase()) {
      case 'TOMADO':
        return t('badge_taken').toUpperCase();
      case 'TOMADO FORA HORA':
        return t('status_taken_late');
      case 'TOMADO PRN':
        return t('status_prn_caps');
      case 'CONCLUIDO':
        return t('status_completed_caps');
      case 'PERDIDO':
        return t('status_missed_caps');
      case 'SNOOZED':
        return t('status_snoozed_caps');
      default:
        return status.toUpperCase();
    }
  }

  Color _getLogLevelColor(String level) {
    switch (level.toUpperCase()) {
      case 'ERROR':
        return AppColors.missed;
      case 'WARNING':
        return AppColors.pending;
      case 'INFO':
        return AppColors.primary;
      case 'DEBUG':
      default:
        return AppColors.textMuted;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(historyRepositoryProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(t('history_logs_title')),
          backgroundColor: AppColors.background,
          elevation: 0,
          bottom: TabBar(
            tabs: [
              Tab(icon: const Icon(Icons.history_rounded), text: t('history_tab_events')),
              Tab(icon: const Icon(Icons.developer_board_rounded), text: t('logs_title')),
            ],
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textMuted,
          ),
        ),
        body: TabBarView(
          children: [
            // 1. History Events Tab
            StreamBuilder<List<HistoryEvent>>(
              stream: repo.watchAllHistoryEvents(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final events = snapshot.data ?? [];
                if (events.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history_rounded, size: 48, color: AppColors.textMuted),
                        const SizedBox(height: 12),
                        Text(
                          t('history_no_events'),
                          style: TextStyle(color: AppColors.textMuted, fontSize: 14),
                        ),
                      ],
                    ),
                  );
                }

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            t('history_events_count', [events.length]),
                            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                          ),
                          TextButton.icon(
                            style: TextButton.styleFrom(foregroundColor: AppColors.missed),
                            icon: const Icon(Icons.delete_sweep_rounded, size: 18),
                            label: Text(t('btn_clear')),
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (confirmContext) => AlertDialog(
                                  title: Text(t('dialog_clear_history_title')),
                                  content: Text(t('dialog_clear_history_desc')),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.of(confirmContext).pop(false),
                                      child: Text(t('cancel_btn').toUpperCase(), style: TextStyle(color: AppColors.textMuted)),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.of(confirmContext).pop(true),
                                      child: Text(t('btn_clear_caps'), style: TextStyle(color: AppColors.missed)),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                await repo.clearHistory();
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: events.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final event = events[index];
                          final color = _getStatusColor(event.status);
                          final icon = _getStatusIcon(event.status);
                          final typeLabel = event.type == 'alarm' ? t('fab_alarm') : t('fab_reminder');
                          
                          return Card(
                            child: ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(icon, color: color, size: 22),
                              ),
                              title: Text(
                                event.medName ?? t('history_default_event'),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (event.dosage != null && event.dosage!.isNotEmpty)
                                    Text(
                                      t('dose_label_fmt', [event.dosage]),
                                      style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                                    ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '$typeLabel · ${_formatTimestamp(event.timestamp)}',
                                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                                  ),
                                ],
                              ),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  _formatStatusText(event.status),
                                  style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),

            // 2. System Logs Tab
            StreamBuilder<List<SystemLog>>(
              stream: repo.watchAllSystemLogs(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final logs = snapshot.data ?? [];
                if (logs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.developer_board_rounded, size: 48, color: AppColors.textMuted),
                        const SizedBox(height: 12),
                        Text(
                          t('logs_empty'),
                          style: TextStyle(color: AppColors.textMuted, fontSize: 14),
                        ),
                      ],
                    ),
                  );
                }

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            t('logs_count_fmt', [logs.length]),
                            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                          ),
                          TextButton.icon(
                            style: TextButton.styleFrom(foregroundColor: AppColors.missed),
                            icon: const Icon(Icons.delete_sweep_rounded, size: 18),
                            label: Text(t('btn_clear')),
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (confirmContext) => AlertDialog(
                                  title: Text(t('dialog_clear_logs_title')),
                                  content: Text(t('dialog_clear_logs_desc')),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.of(confirmContext).pop(false),
                                      child: Text(t('cancel_btn').toUpperCase(), style: TextStyle(color: AppColors.textMuted)),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.of(confirmContext).pop(true),
                                      child: Text(t('btn_clear_caps'), style: TextStyle(color: AppColors.missed)),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                await repo.clearLogs();
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: logs.length,
                        itemBuilder: (context, index) {
                          final log = logs[index];
                          final color = _getLogLevelColor(log.level);
                          
                          return Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: color.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            log.level,
                                            style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          log.source,
                                          style: TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w500),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      _formatTimestamp(log.timestamp),
                                      style: TextStyle(fontSize: 10, color: AppColors.textMuted),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  log.message,
                                  style: TextStyle(fontSize: 13, color: AppColors.text),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
