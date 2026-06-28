import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../features/alarms/data/alarm_model.dart';
import '../../features/alarms/data/alarm_repository.dart';
import 'notification_service.dart';
import '../../features/history/data/history_repository.dart';
import '../../features/reminders/data/reminder_repository.dart';

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

  /// The per-minute foreground trigger
  Future<void> _tick() async {
    try {
      final now = DateTime.now();
      final todayStr = "${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}";
      final currentTotalMinutes = now.hour * 60 + now.minute;
      final weekday = now.weekday % 7; // 0 = Sun, 1 = Mon, ..., 6 = Sat

      // Run daily background cleanup of expired alarms and reminders
      if (_lastCleanupDay != now.day) {
        _lastCleanupDay = now.day;
        _runCleanup(now);
      }

      final alarms = await _alarmRepo.getAllAlarms();

      for (final a in alarms) {
        if (!a.enabled) continue;

        // --- Pausa Temporária / Suspensão ---
        if (a.pauseUntil == -1) continue;
        if (a.pauseUntil != null && a.pauseUntil! > 0) {
          final nowEpoch = DateTime.now().millisecondsSinceEpoch ~/ 1000;
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
        if (a.lastStatusDate != null && a.lastStatusDate!.isNotEmpty && a.lastStatusDate != todayStr) {
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
            if (countdown > 0) {
              countdown--;
              debugPrint("Intervalo '${a.name}': countdown decrementado para $countdown");
            } else {
              countdown = a.intervalDays! - 1;
              debugPrint("Intervalo '${a.name}': HOJE dispara, proximo em $countdown dias");
            }
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
                final targetZero = DateTime(now.year, now.month, now.day);
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
                  if (a.taperLoop == true) {
                    final initialQty = a.taperStages![0].quantity;
                    updated = updated.copyWith(
                      taperCurrentStage: 0,
                      taperDayInStage: 1,
                      quantity: initialQty,
                    );
                    await historyRepo.addHistoryEvent(
                      alarmId: a.id,
                      medName: a.medName.isNotEmpty ? a.medName : a.name,
                      status: 'Ciclo Reiniciado',
                      type: 'system',
                    );
                  } else {
                    updated = updated.copyWith(
                      enabled: false,
                      taperCurrentStage: nextStageIndex,
                      taperDayInStage: 0,
                    );
                    await historyRepo.addHistoryEvent(
                      alarmId: a.id,
                      medName: a.medName.isNotEmpty ? a.medName : a.name,
                      status: 'Desmame Concluido',
                      type: 'system',
                    );
                  }
                } else {
                  final nextQty = a.taperStages![nextStageIndex].quantity;
                  updated = updated.copyWith(
                    taperCurrentStage: nextStageIndex,
                    taperDayInStage: 1,
                    quantity: nextQty,
                  );
                  await historyRepo.addHistoryEvent(
                    alarmId: a.id,
                    medName: a.medName.isNotEmpty ? a.medName : a.name,
                    status: 'Desmame Etapa',
                    type: 'system',
                  );
                }
              } else {
                updated = updated.copyWith(taperDayInStage: dayInStage);
              }
            }
          }

          // Salvar alarme atualizado
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

        // Se já foi tomado, cancelado ou perdido hoje, pula (assim como no C++)
        if (a.lastStatusDate == todayStr &&
            (a.lastStatus == 'Tomado' ||
             a.lastStatus == 'Não Tomado' ||
             a.lastStatus == 'Cancelado')) {
          if (a.isPrn != true) {
            continue;
          }
        }

        // PRN does not trigger automatically by time
        if (a.isPrn == true) continue;

        // Cycle pause check
        if (a.cycleOnDays != null && a.cycleOnDays! > 0 && a.cycleIsPaused == true) {
          continue;
        }

        // Real interval check "a cada N dias"
        if (a.intervalDays != null && a.intervalDays! > 1) {
          if (a.intervalCountdown != null && a.intervalCountdown! > 0) {
            continue; // Not active today!
          }
        }

        // Check if day active
        if (a.dayOfMonth != null && a.dayOfMonth! > 0) {
          if (now.day != a.dayOfMonth) continue;
        } else if (a.startDate != null && a.startDate!.isNotEmpty) {
          try {
            final start = DateTime.parse(a.startDate!);
            final startZero = DateTime(start.year, start.month, start.day);
            final targetZero = DateTime(now.year, now.month, now.day);
            final endZero = startZero.add(Duration(days: (a.durationDays > 0 ? a.durationDays : 1) - 1));

            if (targetZero.isBefore(startZero) || targetZero.isAfter(endZero)) {
              if (targetZero.isAfter(endZero)) {
                // Treatment completed - disable alarm
                final updated = a.copyWith(enabled: false);
                await _alarmRepo.updateAlarm(updated);
                debugPrint("Alarm '${a.name}' automatically disabled: treatment completed.");
              }
              continue;
            }
          } catch (_) {
            continue;
          }
        } else {
          // Recurrent weekly check
          if (!a.days[weekday]) continue;
        }

        // Calculate differences in minutes
        final baseMinutes = a.hour * 60 + a.minute;
        final effectiveMinutes = baseMinutes + a.snoozeMin;
        
        int diff = currentTotalMinutes - effectiveMinutes;
        // Handle midnight wrap
        if (diff < -720) {
          diff += 1440;
        } else if (diff > 720) {
          diff -= 1440;
        }

        // 1. Missed Case: Window of 10 minutes exceeded
        if (diff > 10) {
          // If it was already marked as taken/skipped/missed today, skip
          if (a.lastStatusDate == todayStr && (a.lastStatus == 'Tomado' || a.lastStatus == 'Não Tomado')) {
            continue;
          }
          // Do not mark missed if it was never triggered today
          if (a.lastStatusDate == null || a.lastStatusDate!.isEmpty) {
            // New alarm never run, skip marking missed to let it run next time
            continue;
          }

          final updated = a.copyWith(
            status: 'PENDENTE',
            lastStatus: 'Não Tomado',
            lastStatusDate: todayStr,
            snoozeMin: 0,
          );
          await _alarmRepo.updateAlarm(updated);
          
          debugPrint("Alarm '${a.name}' marked missed (past 10 min window, diff: $diff min).");
          continue;
        }

        // 2. Alarm Triggering / Active Case (within the 0 to 10 min window)
        if (diff >= 0 && diff <= 10) {
          if (a.status == 'PENDENTE' || a.status == 'SNOOZED') {
            final updated = a.copyWith(
              status: 'ATIVO',
              lastStatus: 'Pendente',
              lastStatusDate: todayStr,
            );
            await _alarmRepo.updateAlarm(updated);
            debugPrint("Alarm '${a.name}' triggered! (diff: $diff min)");
          }
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
