import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../features/alarms/data/alarm_model.dart';
import '../../features/alarms/data/alarm_repository.dart';
import 'notification_service.dart';
import '../../features/history/data/history_repository.dart';
import '../../features/reminders/data/reminder_repository.dart';
import 'package:timezone/timezone.dart' as tz;
import '../../core/providers/core_providers.dart';

part 'alarm_engine.g.dart';

@Riverpod(keepAlive: true)
class AlarmEngine extends _$AlarmEngine {
  Timer? _timer;
  StreamSubscription<List<AlarmModel>>? _alarmsSubscription;
  String _lastStructuralHash = '';
  int _lastCleanupDay = 0;

  AlarmRepository get _alarmRepo => ref.read(alarmRepositoryProvider);

  @override
  void build() {
    // Bind database to NotificationService instance
    NotificationService.instance.database = ref.read(databaseProvider);

    // 1. Listen to alarms to schedule OS notifications on change
    _alarmsSubscription = ref.read(alarmRepositoryProvider).watchAllAlarms().listen((alarms) {
      _rescheduleAllNotifications(alarms);
    });

    // 2. Start foreground timer
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _tick();
    });

    // Run initial tick immediately
    Future.microtask(() => _tick());

    ref.onDispose(() {
      _timer?.cancel();
      _alarmsSubscription?.cancel();
    });
  }

  String _calculateStructuralHash(List<AlarmModel> alarms) {
    final buffer = StringBuffer();
    // Sort to ensure deterministic hash regardless of list order
    final sorted = List<AlarmModel>.from(alarms)..sort((a, b) => a.id.compareTo(b.id));
    for (final a in sorted) {
      buffer.write('${a.id}-${a.hour}-${a.minute}-${a.enabled}-${a.days.join(',')}-${a.pauseUntil}-${a.cycleIsPaused}-${a.startDate}-${a.durationDays};');
    }
    return buffer.toString();
  }

  /// Reschedule all notifications in the OS
  Future<void> _rescheduleAllNotifications(List<AlarmModel> alarms) async {
    final currentHash = _calculateStructuralHash(alarms);
    if (currentHash == _lastStructuralHash) {
      return; // Structural configuration didn't change, avoid redundant reschedule
    }
    _lastStructuralHash = currentHash;

    try {
      final notificationService = NotificationService.instance;
      // We don't want to cancel all if we have other notifications,
      // but since we manage weekly alarms, canceling all and rescheduling is safest
      await notificationService.cancelAllNotifications();

      for (final alarm in alarms) {
        if (!alarm.enabled || alarm.isPrn == true) continue;

        // Verify if it is suspended
        if (alarm.pauseUntil == -1) continue;
        if (alarm.pauseUntil != null && alarm.pauseUntil! > 0) {
          final nowEpoch = DateTime.now().millisecondsSinceEpoch ~/ 1000;
          if (nowEpoch < alarm.pauseUntil!) continue;
        }

        // Verify cycle pause
        if (alarm.cycleOnDays != null && alarm.cycleOnDays! > 0 && alarm.cycleIsPaused == true) {
          continue;
        }

        await notificationService.scheduleWeeklyAlarm(
          id: alarm.id,
          hour: alarm.hour,
          minute: alarm.minute,
          title: alarm.medName.isNotEmpty ? alarm.medName : alarm.name,
          body: "Hora de tomar seu medicamento: ${alarm.quantity} ${alarm.type}${alarm.dosage != null ? ' (${alarm.dosage})' : ''}",
          days: alarm.days,
        );
      }
      debugPrint('Rescheduled notifications for ${alarms.length} alarms.');
    } catch (e) {
      debugPrint('Error rescheduling notifications: $e');
    }
  }

  Future<void> _tick() async {
    try {
      final now = DateTime.now();
      tz.Location localLocation;
      try {
        localLocation = tz.local;
      } catch (_) {
        // Se a timezone local ainda não foi configurada, dispara a inicialização
        // em background e aborta o tick atual para evitar corrupção de datas
        NotificationService.instance.init().then((_) {
          debugPrint('NotificationService fallback initialization complete.');
        });
        return;
      }
      final localNow = tz.TZDateTime.from(now, localLocation);
      final todayStr = "${localNow.day.toString().padLeft(2, '0')}/${localNow.month.toString().padLeft(2, '0')}/${localNow.year}";

      // Run daily background cleanup of expired alarms and reminders
      if (_lastCleanupDay != localNow.day) {
        _lastCleanupDay = localNow.day;
        _runCleanup(localNow);
      }

      final alarms = await _alarmRepo.getAllAlarms();

      for (final a in alarms) {
        try {
          if (!a.enabled || a.active != true) continue;

          // --- Pausa Temporária / Suspensão ---
          if (a.pauseUntil == -1) continue;
          if (a.pauseUntil != null && a.pauseUntil! > 0) {
            final nowEpoch = localNow.millisecondsSinceEpoch ~/ 1000;
            if (nowEpoch < a.pauseUntil!) {
              continue; // Still within pause duration
            } else {
              // Pause expired
              final updated = a.copyWith(pauseUntil: 0);
              await _alarmRepo.updateAlarm(updated);
              debugPrint("Temporary pause for alarm '${a.name}' expired. Resuming.");
            }
          }

          // --- Daily Tick / Reset of Status from previous days ---
          bool shouldDelayReset = false;
          if (a.lastStatusDate != null && a.lastStatusDate!.isNotEmpty && a.lastStatusDate != todayStr) {
            try {
              final parts = a.lastStatusDate!.split('/');
              if (parts.length == 3) {
                final day = int.tryParse(parts[0]);
                final month = int.tryParse(parts[1]);
                final year = int.tryParse(parts[2]);
                if (day != null && month != null && year != null) {
                  final lastScheduled = tz.TZDateTime(
                    localLocation,
                    year,
                    month,
                    day,
                    a.hour,
                    a.minute,
                  );
                  final lastEffective = lastScheduled.add(Duration(minutes: a.snoozeMin));
                  final windowEnd = lastEffective.add(const Duration(minutes: 10));
                  if (localNow.isBefore(windowEnd)) {
                    shouldDelayReset = true;
                  }
                }
              }
            } catch (_) {}
          }

          if (a.lastStatusDate != null && a.lastStatusDate!.isNotEmpty && a.lastStatusDate != todayStr && !shouldDelayReset &&
              (a.lastStatus == 'Tomado' || a.lastStatus == 'Não Tomado' || a.lastStatus == 'Cancelado')) {
            var updated = a.copyWith(
              status: 'PENDENTE',
              snoozeMin: 0,
              lastStatus: '',
              lastStatusDate: '',
              prnDosesToday: a.isPrn == true ? 0 : a.prnDosesToday,
            );

            // 4. Intervalo real "a cada N dias" (intervalDays)
            if (a.intervalDays != null && a.intervalDays! > 1) {
              int countdown = a.intervalCountdown ?? 0;
              int daysDiff = 1;
              if (a.lastStatusDate != null && a.lastStatusDate!.isNotEmpty) {
                try {
                  final parts = a.lastStatusDate!.split('/');
                  if (parts.length == 3) {
                    final day = int.tryParse(parts[0]);
                    final month = int.tryParse(parts[1]);
                    final year = int.tryParse(parts[2]);
                    if (day != null && month != null && year != null) {
                      final lastDate = DateTime(year, month, day);
                      final targetDate = DateTime(localNow.year, localNow.month, localNow.day);
                      daysDiff = targetDate.difference(lastDate).inDays;
                      if (daysDiff <= 0) daysDiff = 1;
                    }
                  }
                } catch (_) {}
              }
              for (int i = 0; i < daysDiff; i++) {
                if (countdown > 0) {
                  countdown--;
                } else {
                  countdown = a.intervalDays! - 1;
                }
              }
              debugPrint("Intervalo '${a.name}': countdown atualizado para $countdown (dias decorridos: $daysDiff)");
              updated = updated.copyWith(intervalCountdown: countdown);
            }

            final historyRepo = ref.read(historyRepositoryProvider);

            // 1. Ajuste Progressivo Gradual (adjustStep)
            if (a.adjustStep != null && a.adjustStep != 0.0) {
              final startStr = a.startDate ?? a.createdDate;
              if (startStr != null && startStr.isNotEmpty) {
                try {
                  final start = DateTime.parse(startStr);
                  final startZero = DateTime(start.year, start.month, start.day);
                  final targetZero = DateTime(localNow.year, localNow.month, localNow.day);
                  final diffDays = targetZero.difference(startZero).inDays;
                  final intervalDays = a.adjustIntervalDays ?? 1;

                  if (diffDays > 0 && diffDays % intervalDays == 0) {
                    double newQty = a.quantity + a.adjustStep!;
                    double adjustStep = a.adjustStep!;

                    // Check if limit reached
                    final bool reached = (a.adjustStep! > 0 && newQty >= (a.adjustLimit ?? 0.0)) ||
                                   (a.adjustStep! < 0 && newQty <= (a.adjustLimit ?? 0.0));
                    if (reached) {
                      newQty = a.adjustLimit ?? 0.0;
                      adjustStep = 0.0; // Concluído
                      debugPrint("Ajuste gradual CONCLUIDO para alarme '${a.name}' qty ${a.quantity} -> $newQty");
                    } else {
                      debugPrint("Ajuste gradual aplicado para alarme '${a.name}' qty ${a.quantity} -> $newQty");
                    }

                    updated = updated.copyWith(
                      quantity: newQty,
                      adjustStep: adjustStep,
                    );

                    await historyRepo.addHistoryEvent(
                      alarmId: a.id,
                      medName: a.medName.isNotEmpty ? a.medName : a.name,
                      status: 'Ajuste Progressivo',
                      type: 'system',
                    );
                  }
                } catch (_) {}
              }
            }

            // 2. Esquema cíclico ON/OFF
            if (a.cycleOnDays != null && a.cycleOnDays! > 0) {
              final total = a.cycleOnDays! + (a.cycleOffDays ?? 0);
              int currentDay = (a.cycleCurrentDay ?? 0) + 1;
              if (currentDay > total) {
                currentDay = 1;
              }
              final isPaused = currentDay > a.cycleOnDays!;

              updated = updated.copyWith(
                cycleCurrentDay: currentDay,
                cycleIsPaused: isPaused,
              );

              final wasPaused = a.cycleIsPaused ?? false;
              if (wasPaused != isPaused) {
                await historyRepo.addHistoryEvent(
                  alarmId: a.id,
                  medName: a.medName.isNotEmpty ? a.medName : a.name,
                  status: isPaused ? 'Ciclo Pausa' : 'Ciclo Retomado',
                  type: 'system',
                );
                await historyRepo.addSystemLog(
                  level: 'INFO',
                  message: "Ciclo do alarme '${a.name}': ${isPaused ? 'PAUSA iniciada' : 'USO retomado'} (dia $currentDay/$total)",
                  source: 'System',
                );
              }
            }

            // 3. Desmame / Titulação (taper stages)
            if (a.taperStageCount != null && a.taperStageCount! > 0 && a.taperStages != null && a.taperStages!.isNotEmpty) {
              final currentStageIndex = a.taperCurrentStage ?? 0;
              if (currentStageIndex < a.taperStageCount!) {
                final stage = a.taperStages![currentStageIndex];
                final int dayInStage = (a.taperDayInStage ?? 0) + 1;

                if (dayInStage > stage.durationDays) {
                  final nextStageIndex = currentStageIndex + 1;

                  if (nextStageIndex >= a.taperStageCount!) {
                    // Completed desmame -> disable alarm
                    updated = updated.copyWith(
                      enabled: false,
                      taperCurrentStage: nextStageIndex,
                      taperDayInStage: dayInStage,
                    );
                    await historyRepo.addHistoryEvent(
                      alarmId: a.id,
                      medName: a.medName.isNotEmpty ? a.medName : a.name,
                      status: 'Desmame Concluído',
                      type: 'system',
                    );
                    await historyRepo.addSystemLog(
                      level: 'INFO',
                      message: "Desmame do alarme '${a.name}' concluído com sucesso.",
                      source: 'System',
                    );
                  } else {
                    // Move to next stage
                    final nextStage = a.taperStages![nextStageIndex];
                    updated = updated.copyWith(
                      quantity: nextStage.quantity,
                      taperCurrentStage: nextStageIndex,
                      taperDayInStage: 1,
                    );
                    await historyRepo.addHistoryEvent(
                      alarmId: a.id,
                      medName: a.medName.isNotEmpty ? a.medName : a.name,
                      status: 'Desmame Avanço',
                      type: 'system',
                    );
                    await historyRepo.addSystemLog(
                      level: 'INFO',
                      message: "Desmame do alarme '${a.name}' avançou para estágio ${nextStageIndex + 1}/${a.taperStageCount!} (nova dose: ${nextStage.quantity})",
                      source: 'System',
                    );
                  }
                } else {
                  // Increment day in current stage
                  updated = updated.copyWith(taperDayInStage: dayInStage);
                }
              }
            }

            await _alarmRepo.updateAlarm(updated);

            // 4. Propagação por groupId para os demais alarmes do grupo
            if (a.groupId != null && a.groupId! > 0) {
              final groupAlarms = alarms.where((ga) => ga.id != a.id && ga.groupId == a.groupId).toList();
              for (final ga in groupAlarms) {
                final updatedGa = ga.copyWith(
                  quantity: updated.quantity,
                  adjustStep: updated.adjustStep,
                  cycleCurrentDay: updated.cycleCurrentDay,
                  cycleIsPaused: updated.cycleIsPaused,
                  taperCurrentStage: updated.taperCurrentStage,
                  taperDayInStage: updated.taperDayInStage,
                  status: updated.status,
                  lastStatus: updated.lastStatus,
                  lastStatusDate: updated.lastStatusDate,
                  intervalCountdown: updated.intervalCountdown,
                );
                await _alarmRepo.updateAlarm(updatedGa);
              }
            }

            debugPrint("Processed daily tick for alarm '${a.name}' and propagated group status.");
            continue;
          }

          // PRN does not trigger automatically by time
          if (a.isPrn == true) continue;

          // Se já foi tomado, cancelado ou perdido hoje, pula para evitar re-disparos no mesmo minuto/janela
          if (a.lastStatusDate == todayStr &&
              (a.lastStatus == 'Tomado' ||
               a.lastStatus == 'Não Tomado' ||
               a.lastStatus == 'Cancelado')) {
            continue;
          }

          // Cycle pause check
          if (a.cycleOnDays != null && a.cycleOnDays! > 0 && a.cycleIsPaused == true) {
            continue;
          }

          // Determine the best active occurrence
          tz.TZDateTime? bestScheduledDate;
          int? bestDiff;
          int? bestCountdown;

          for (int d in [-1, 0, 1]) {
            final targetDate = localNow.add(Duration(days: d));

            bool isActive = false;
            if (a.dayOfMonth != null && a.dayOfMonth! > 0) {
              isActive = (targetDate.day == a.dayOfMonth);
            } else if (a.startDate != null && a.startDate!.isNotEmpty && a.durationDays > 0) {
              try {
                final start = DateTime.parse(a.startDate!);
                final startZero = DateTime(start.year, start.month, start.day);
                final targetZero = DateTime(targetDate.year, targetDate.month, targetDate.day);
                final endZero = startZero.add(Duration(days: (a.durationDays > 0 ? a.durationDays : 1) - 1));

                if (targetZero.isBefore(startZero) || targetZero.isAfter(endZero)) {
                  if (d == 0 && targetZero.isAfter(endZero)) {
                    // Treatment completed - disable alarm
                    final updated = a.copyWith(enabled: false);
                    await _alarmRepo.updateAlarm(updated);
                    debugPrint("Alarm '${a.name}' automatically disabled: treatment completed.");
                  }
                  isActive = false;
                } else {
                  isActive = true;
                }
              } catch (_) {
                isActive = false;
              }
            } else {
              final targetWeekday = targetDate.weekday % 7;
              isActive = a.days[targetWeekday];
            }

            if (!isActive) continue;

            // Real interval check "a cada N dias"
            int currentSimulatedCountdown = a.intervalCountdown ?? 0;
            if (a.intervalDays != null && a.intervalDays! > 1) {
              final baseCountdown = a.intervalCountdown ?? 0;
              int daysDiff = 0;
              if (a.lastStatusDate != null && a.lastStatusDate!.isNotEmpty) {
                try {
                  final parts = a.lastStatusDate!.split('/');
                  if (parts.length == 3) {
                    final day = int.tryParse(parts[0]);
                    final month = int.tryParse(parts[1]);
                    final year = int.tryParse(parts[2]);
                    if (day != null && month != null && year != null) {
                      final lastDate = DateTime(year, month, day);
                      final targetDateOnly = DateTime(targetDate.year, targetDate.month, targetDate.day);
                      daysDiff = targetDateOnly.difference(lastDate).inDays;
                    }
                  }
                } catch (_) {}
              } else {
                daysDiff = d;
              }

              int simulatedCountdown = baseCountdown;
              if (daysDiff > 0) {
                for (int i = 0; i < daysDiff - 1; i++) {
                  if (simulatedCountdown > 0) {
                    simulatedCountdown--;
                  } else {
                    simulatedCountdown = a.intervalDays! - 1;
                  }
                }
              } else if (daysDiff < 0) {
                for (int i = 0; i < -daysDiff; i++) {
                  if (simulatedCountdown < a.intervalDays! - 1) {
                    simulatedCountdown++;
                  } else {
                    simulatedCountdown = 0;
                  }
                }
              }

              currentSimulatedCountdown = simulatedCountdown;
              if (simulatedCountdown != 0) continue;
            }

            final scheduledDate = tz.TZDateTime(
              localLocation,
              targetDate.year,
              targetDate.month,
              targetDate.day,
              a.hour,
              a.minute,
            );

            final effectiveScheduled = scheduledDate.add(Duration(minutes: a.snoozeMin));
            final diffForOffset = (localNow.difference(effectiveScheduled).inSeconds / 60.0).floor();

            bool isProcessed = false;
            final targetDateOnly = DateTime(targetDate.year, targetDate.month, targetDate.day);

            if (a.lastStatusDate != null && a.lastStatusDate!.isNotEmpty) {
              try {
                final parts = a.lastStatusDate!.split('/');
                if (parts.length == 3) {
                  final day = int.tryParse(parts[0]);
                  final month = int.tryParse(parts[1]);
                  final year = int.tryParse(parts[2]);
                  if (day != null && month != null && year != null) {
                    final lastStatusDateTime = DateTime(year, month, day);
                    if (targetDateOnly.isBefore(lastStatusDateTime)) {
                      isProcessed = true;
                    } else if (targetDateOnly.isAtSameMomentAs(lastStatusDateTime)) {
                      isProcessed = (a.lastStatus == 'Tomado' ||
                                     a.lastStatus == 'Não Tomado' ||
                                     a.lastStatus == 'Cancelado');
                    }
                  }
                }
              } catch (_) {}
            } else {
              final todayMidnight = DateTime(localNow.year, localNow.month, localNow.day);
              if (targetDateOnly.isBefore(todayMidnight)) {
                if (diffForOffset < 0 || diffForOffset > 10) {
                  isProcessed = true;
                }
              }
            }

            if (!isProcessed || a.isPrn == true) {
              bestDiff = diffForOffset;
              bestScheduledDate = scheduledDate;
              bestCountdown = currentSimulatedCountdown;
              break;
            }
          }

          if (bestDiff == null || bestScheduledDate == null) {
            continue;
          }

          final bestScheduledDateStr = "${bestScheduledDate.day.toString().padLeft(2, '0')}/${bestScheduledDate.month.toString().padLeft(2, '0')}/${bestScheduledDate.year}";
          final diff = bestDiff;

          // Se já foi tomado, cancelado ou perdido para esta ocorrência, pula
          if (a.lastStatusDate == bestScheduledDateStr &&
              (a.lastStatus == 'Tomado' ||
               a.lastStatus == 'Não Tomado' ||
               a.lastStatus == 'Cancelado')) {
            if (a.isPrn != true) {
              continue;
            }
          }

          // 1. Missed Case: Window of 10 minutes exceeded
          if (diff > 10) {
            // If it was already marked as taken/skipped/missed for this occurrence, skip
            if (a.lastStatusDate == bestScheduledDateStr && (a.lastStatus == 'Tomado' || a.lastStatus == 'Não Tomado')) {
              continue;
            }

            final updated = a.copyWith(
              status: 'PENDENTE',
              lastStatus: 'Não Tomado',
              lastStatusDate: bestScheduledDateStr,
              snoozeMin: 0,
              intervalCountdown: a.intervalDays != null && a.intervalDays! > 1 ? bestCountdown : a.intervalCountdown,
            );
            await _alarmRepo.updateAlarm(updated);

            final historyRepo = ref.read(historyRepositoryProvider);
            await historyRepo.addHistoryEvent(
              alarmId: a.id,
              medName: a.medName.isNotEmpty ? a.medName : a.name,
              dosage: a.dosage,
              status: 'PERDIDO',
              type: 'alarm',
            );
            await historyRepo.addSystemLog(
              level: 'WARNING',
              message: 'Medicamento "${a.medName.isNotEmpty ? a.medName : a.name}" marcado como Não Tomado (Perdido)',
              source: 'System',
            );

            debugPrint("Alarm '${a.name}' marked missed (past 10 min window, diff: $diff min).");
            continue;
          }

          // 2. Alarm Triggering / Active Case (within the 0 to 10 min window)
          if (diff >= 0 && diff <= 10) {
            if (a.status == 'PENDENTE' || a.status == 'SNOOZED') {
              final updated = a.copyWith(
                status: 'ATIVO',
                lastStatus: 'Pendente',
                lastStatusDate: bestScheduledDateStr,
                intervalCountdown: a.intervalDays != null && a.intervalDays! > 1 ? bestCountdown : a.intervalCountdown,
              );
              await _alarmRepo.updateAlarm(updated);
              debugPrint("Alarm '${a.name}' triggered! (diff: $diff min)");
            }
          }
        } catch (e) {
          debugPrint('Error inside AlarmEngine loop for alarm ${a.id}: $e');
        }
      }

      // No manual reschedule call needed here since the stream subscription in build()
      // will automatically pick up any database changes and trigger _rescheduleAllNotifications.
    } catch (e) {
      debugPrint('Error inside AlarmEngine tick: $e');
    }
  }

  /// Triggers a tick manually (useful after adding/updating alarms)
  Future<void> triggerTick() async {
    await _tick();
  }

  /// Run daily background cleanup of expired alarms and reminders (Phase 3)
  Future<void> _runCleanup(DateTime now) async {
    try {
      final alarms = await _alarmRepo.getAllAlarms();
      final targetZero = DateTime(now.year, now.month, now.day);

      // 1. Cleanup expired date-based alarms
      for (final a in alarms) {
        if (a.startDate != null && a.startDate!.isNotEmpty && a.durationDays > 0) {
          try {
            final start = DateTime.parse(a.startDate!);
            final startZero = DateTime(start.year, start.month, start.day);
            final endZero = startZero.add(Duration(days: a.durationDays));
            final expirationLimit = endZero.add(const Duration(days: 15));

            if (targetZero.isAfter(expirationLimit)) {
              await _alarmRepo.deleteAlarm(a.id);
              debugPrint("Alarm '${a.name}' expired over 15 days ago. Automatically deleted by cleanup.");
            }
          } catch (_) {}
        }
      }

      // 2. Cleanup expired single-run (one-time) reminders
      final reminderRepo = ref.read(reminderRepositoryProvider);
      final reminders = await reminderRepo.getAllReminders();
      for (final r in reminders) {
        if (r.period.isEmpty && r.startDate.isNotEmpty) {
          try {
            final start = DateTime.parse(r.startDate);
            final startZero = DateTime(start.year, start.month, start.day);
            final expirationLimit = startZero.add(const Duration(days: 15));

            if (targetZero.isAfter(expirationLimit)) {
              await reminderRepo.deleteReminder(r.id);
              debugPrint("Reminder '${r.title}' expired over 15 days ago. Automatically deleted by cleanup.");
            }
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint('Error running background cleanup: $e');
    }
  }
}

/// Provider to list all active (currently firing) alarms
@riverpod
Stream<List<AlarmModel>> activeAlarms(ActiveAlarmsRef ref) {
  return ref.watch(alarmRepositoryProvider).watchAllAlarms().map((list) {
    return list.where((a) => a.enabled && a.status == 'ATIVO').toList();
  });
}
