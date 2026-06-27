import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../data/history_repository.dart';
import '../../../core/database/database.dart';

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
      return 'Hoje às $timeStr';
    } else if (eventDay == yesterday) {
      return 'Ontem às $timeStr';
    } else {
      return '${DateFormat('dd/MM/yyyy').format(dt)} às $timeStr';
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'TOMADO':
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
          title: const Text('Histórico & Logs'),
          backgroundColor: AppColors.background,
          elevation: 0,
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.history_rounded), text: 'Eventos'),
              Tab(icon: Icon(Icons.developer_board_rounded), text: 'Logs do Sistema'),
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
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history_rounded, size: 48, color: AppColors.textMuted),
                        SizedBox(height: 12),
                        Text(
                          'Nenhum evento registrado ainda.',
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
                            '${events.length} eventos registrados',
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                          ),
                          TextButton.icon(
                            style: TextButton.styleFrom(foregroundColor: AppColors.missed),
                            icon: const Icon(Icons.delete_sweep_rounded, size: 18),
                            label: const Text('Limpar'),
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (confirmContext) => AlertDialog(
                                  title: const Text('Limpar Histórico'),
                                  content: const Text('Deseja mesmo apagar todo o histórico de eventos?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.of(confirmContext).pop(false),
                                      child: const Text('CANCELAR', style: TextStyle(color: AppColors.textMuted)),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.of(confirmContext).pop(true),
                                      child: const Text('LIMPAR', style: TextStyle(color: AppColors.missed)),
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
                          final typeLabel = event.type == 'alarm' ? 'Alarme' : 'Lembrete';
                          
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
                                event.medName ?? 'Evento',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (event.dosage != null && event.dosage!.isNotEmpty)
                                    Text(
                                      'Dose: ${event.dosage}',
                                      style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                                    ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '$typeLabel · ${_formatTimestamp(event.timestamp)}',
                                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
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
                                  event.status,
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
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.developer_board_rounded, size: 48, color: AppColors.textMuted),
                        SizedBox(height: 12),
                        Text(
                          'Nenhum log gerado ainda.',
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
                            '${logs.length} logs registrados',
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                          ),
                          TextButton.icon(
                            style: TextButton.styleFrom(foregroundColor: AppColors.missed),
                            icon: const Icon(Icons.delete_sweep_rounded, size: 18),
                            label: const Text('Limpar'),
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (confirmContext) => AlertDialog(
                                  title: const Text('Limpar Logs'),
                                  content: const Text('Deseja mesmo apagar todos os logs de depuração?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.of(confirmContext).pop(false),
                                      child: const Text('CANCELAR', style: TextStyle(color: AppColors.textMuted)),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.of(confirmContext).pop(true),
                                      child: const Text('LIMPAR', style: TextStyle(color: AppColors.missed)),
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
                                          style: const TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w500),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      _formatTimestamp(log.timestamp),
                                      style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  log.message,
                                  style: const TextStyle(fontSize: 13, color: Colors.white),
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
