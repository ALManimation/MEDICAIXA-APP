import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../alarms/data/alarm_model.dart';
import '../../alarms/data/alarm_repository.dart';
import '../../reminders/data/reminder_model.dart';
import '../../reminders/data/reminder_repository.dart';
import '../../history/data/history_repository.dart';
import '../../../core/database/database.dart';

part 'dashboard_notifier.g.dart';

class DashboardState {
  final DateTime selectedDate;
  final List<AlarmModel> alarms;
  final List<AlarmModel> allAlarms;
  final List<ReminderModel> reminders;
  final List<ReminderModel> allReminders;
  final int takenCount;
  final int pendingCount;
  final int missedCount;
  final bool isLoading;

  const DashboardState({
    required this.selectedDate,
    required this.alarms,
    required this.allAlarms,
    required this.reminders,
    required this.allReminders,
    required this.takenCount,
    required this.pendingCount,
    required this.missedCount,
    required this.isLoading,
  });

  DashboardState copyWith({
    DateTime? selectedDate,
    List<AlarmModel>? alarms,
    List<AlarmModel>? allAlarms,
    List<ReminderModel>? reminders,
    List<ReminderModel>? allReminders,
    int? takenCount,
    int? pendingCount,
    int? missedCount,
    bool? isLoading,
  }) {
    return DashboardState(
      selectedDate: selectedDate ?? this.selectedDate,
      alarms: alarms ?? this.alarms,
      allAlarms: allAlarms ?? this.allAlarms,
      reminders: reminders ?? this.reminders,
      allReminders: allReminders ?? this.allReminders,
      takenCount: takenCount ?? this.takenCount,
      pendingCount: pendingCount ?? this.pendingCount,
      missedCount: missedCount ?? this.missedCount,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

@riverpod
class DashboardNotifier extends _$DashboardNotifier {
  AlarmRepository get _alarmRepo => ref.read(alarmRepositoryProvider);
  ReminderRepository get _reminderRepo => ref.read(reminderRepositoryProvider);
  Timer? _inactivityTimer;

  @override
  DashboardState build() {

    // Watch alarms and reminders reactively
    ref.listen(alarmRepositoryProvider, (_, __) {
      _updateData();
    });
    ref.listen(reminderRepositoryProvider, (_, __) {
      _updateData();
    });

    // Run initial data fetch
    final state = DashboardState(
      selectedDate: DateTime.now(),
      alarms: [],
      allAlarms: [],
      reminders: [],
      allReminders: [],
      takenCount: 0,
      pendingCount: 0,
      missedCount: 0,
      isLoading: true,
    );

    Future.microtask(() => _updateData());

    return state;
  }

  void selectDate(DateTime date) {
    state = state.copyWith(selectedDate: date);
    _updateData();
    
    _resetInactivityTimer();
  }

  void refresh() => _updateData();

  void resetToToday() {
    _inactivityTimer?.cancel();
    _inactivityTimer = null;
    state = state.copyWith(selectedDate: DateTime.now());
    _updateData();
  }

  void _resetInactivityTimer() {
    _inactivityTimer?.cancel();
    
    final now = DateTime.now();
    final isToday = state.selectedDate.year == now.year && 
                    state.selectedDate.month == now.month && 
                    state.selectedDate.day == now.day;
                    
    if (!isToday) {
      _inactivityTimer = Timer(const Duration(minutes: 3), () {
        resetToToday();
      });
    }
  }

  Future<void> sync() async {
    state = state.copyWith(isLoading: true);
    await _alarmRepo.syncWithDevice();
    await _reminderRepo.syncWithDevice();
    await _updateData();
  }

  Future<void> loadSampleData(String jsonContent) async {
    state = state.copyWith(isLoading: true);
    await _alarmRepo.loadBackupFixture(jsonContent);
    await _reminderRepo.loadBackupFixture(jsonContent);
    await _updateData();
  }

  Future<void> _updateData() async {
    final date = state.selectedDate;

    // Get all alarms and filter for selected date
    final allAlarms = await _alarmRepo.getAllAlarms();
    final filteredAlarms = allAlarms.where((a) => _isAlarmActiveOnDate(a, date)).toList();

    // Check for ghost alarms (past dates only)
    final now = DateTime.now();
    final todayZero = DateTime(now.year, now.month, now.day);
    final targetZero = DateTime(date.year, date.month, date.day);
    final isToday = date.year == now.year && date.month == now.month && date.day == now.day;
    final dateFormatted = "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
    
    if (targetZero.isBefore(todayZero)) {
      try {
        final historyRepo = ref.read(historyRepositoryProvider);
        final allHistory = await historyRepo.getAllHistoryEvents();
        final dateEvents = allHistory.where((e) {
          final dt = DateTime.fromMillisecondsSinceEpoch(e.timestamp);
          return dt.year == date.year && dt.month == date.month && dt.day == date.day;
        }).toList();

        // Update existing alarms with historical status
        for (int i = 0; i < filteredAlarms.length; i++) {
          final alarm = filteredAlarms[i];
          HistoryEvent? event;
          for (final e in dateEvents) {
            if (e.alarmId == alarm.id && e.type == 'alarm') {
              event = e;
              break;
            }
          }
          if (event != null) {
            final isTaken = event.status == 'TOMADO' || event.status == 'TOMADO FORA HORA' || event.status == 'TOMADO PRN';
            final isMissed = event.status == 'PERDIDO';
            filteredAlarms[i] = alarm.copyWith(
              lastStatus: isTaken ? 'Tomado' : (isMissed ? 'Não Tomado' : ''),
              lastStatusDate: dateFormatted,
            );
          } else {
            // Past date, no event recorded = not taken (missed)
            filteredAlarms[i] = alarm.copyWith(
              lastStatus: '',
              lastStatusDate: '',
            );
          }
        }

        // Add ghost alarms
        for (final e in dateEvents) {
          if (e.type == 'alarm' && e.alarmId != null) {
            final exists = filteredAlarms.any((a) => a.id == e.alarmId);
            if (!exists) {
              final dt = DateTime.fromMillisecondsSinceEpoch(e.timestamp);
              final isTaken = e.status == 'TOMADO' || e.status == 'TOMADO FORA HORA' || e.status == 'TOMADO PRN';
              final isMissed = e.status == 'PERDIDO';
              
              // Look up original alarm for metadata fallback
              AlarmModel? orig;
              for (final a in allAlarms) {
                if (a.id == e.alarmId || a.medName == e.medName || a.name == e.medName) {
                  orig = a;
                  break;
                }
              }

              final ghostAlarm = AlarmModel(
                id: e.alarmId!,
                hour: orig?.hour ?? dt.hour,
                minute: orig?.minute ?? dt.minute,
                name: e.medName ?? orig?.name ?? '',
                medName: e.medName ?? orig?.medName ?? '',
                enabled: false,
                active: false,
                days: orig?.days ?? List.filled(7, true),
                status: isTaken ? 'TOMADO' : 'PENDENTE',
                color: orig?.color ?? 'grey',
                quantity: orig?.quantity ?? 1.0,
                daysQuantity: orig?.daysQuantity ?? List.filled(7, 0.0),
                type: orig?.type ?? 'comprimido',
                dosage: e.dosage ?? orig?.dosage,
                lastStatus: isTaken ? 'Tomado' : (isMissed ? 'Não Tomado' : ''),
                lastStatusDate: dateFormatted,
                snoozeMin: 0,
                durationDays: 0,
                isGhost: true, // Mark as ghost
              );
              filteredAlarms.add(ghostAlarm);
            }
          }
        }
      } catch (err) {
        debugPrint('Error loading ghost alarms: $err');
      }
    }

    // Compute dose number and total dose for interval alarms
    for (int i = 0; i < filteredAlarms.length; i++) {
      final alarm = filteredAlarms[i];
      int? doseNum;
      int? doseTotal;

      if (alarm.intervalDays != null && alarm.intervalDays! > 1) {
        if (alarm.startDate != null && alarm.startDate!.isNotEmpty) {
          try {
            final sd = DateTime.parse(alarm.startDate!);
            final sdZero = DateTime(sd.year, sd.month, sd.day);
            final diffDays = targetZero.difference(sdZero).inDays;
            doseNum = (diffDays ~/ alarm.intervalDays!) + 1;
            doseTotal = ((alarm.durationDays > 0 ? alarm.durationDays : 1) ~/ alarm.intervalDays!) + 1;
          } catch (_) {}
        } else if (alarm.createdDate != null && alarm.createdDate!.isNotEmpty) {
          try {
            final cd = DateTime.parse(alarm.createdDate!);
            final cdZero = DateTime(cd.year, cd.month, cd.day);
            final diffDays = targetZero.difference(cdZero).inDays;
            doseNum = (diffDays ~/ alarm.intervalDays!) + 1;
          } catch (_) {}
        }
      }
      if (doseNum != null || doseTotal != null) {
        filteredAlarms[i] = alarm.copyWith(doseNum: doseNum, doseTotal: doseTotal);
      }
    }

    // Sort by hour/minute
    filteredAlarms.sort((a, b) {
      final hourComp = a.hour.compareTo(b.hour);
      if (hourComp != 0) return hourComp;
      return a.minute.compareTo(b.minute);
    });

    // Get all reminders and filter for selected date
    final allReminders = await _reminderRepo.getAllReminders();
    final filteredReminders = allReminders.where((r) => _reminderRepo.isReminderActiveOnDate(r, date)).toList();

    // Calculate summary
    int takenCount = 0;
    int pendingCount = 0;
    int missedCount = 0;

    for (final alarm in filteredAlarms) {
      final isTakenToday = alarm.lastStatusDate == dateFormatted && alarm.lastStatus == 'Tomado';
      final isSkippedToday = alarm.lastStatusDate == dateFormatted && alarm.lastStatus == 'Não Tomado';

      if (isTakenToday) {
        takenCount++;
      } else if (isSkippedToday) {
        missedCount++;
      } else {
        // Not taken or skipped yet
        if (isToday) {
          // Check if alarm time has passed today
          final alarmTime = DateTime(now.year, now.month, now.day, alarm.hour, alarm.minute);
          if (now.isAfter(alarmTime)) {
            missedCount++; // Missed since time passed and not marked taken
          } else {
            pendingCount++;
          }
        } else if (targetZero.isBefore(todayZero)) {
          // Date in the past, if not taken, it is missed
          missedCount++;
        } else {
          // Date in the future, it is pending
          pendingCount++;
        }
      }
    }

    state = DashboardState(
      selectedDate: date,
      alarms: filteredAlarms,
      allAlarms: allAlarms,
      reminders: filteredReminders,
      allReminders: allReminders,
      takenCount: takenCount,
      pendingCount: pendingCount,
      missedCount: missedCount,
      isLoading: false,
    );
  }

  bool _isAlarmActiveOnDate(AlarmModel alarm, DateTime dateObj) {
    final target = DateTime(dateObj.year, dateObj.month, dateObj.day);

    // Filter by creation date: alarm only starts on/after created_date
    if (alarm.createdDate != null && alarm.createdDate!.isNotEmpty) {
      try {
        final created = DateTime.parse(alarm.createdDate!);
        final createdZero = DateTime(created.year, created.month, created.day);
        if (target.isBefore(createdZero)) return false;
      } catch (_) {}
    }

    // 1. Verifica frequência de intervalo de dias ("a cada N dias")
    if (alarm.intervalDays != null && alarm.intervalDays! > 1) {
      final today = DateTime.now();
      final todayZero = DateTime(today.year, today.month, today.day);
      final isToday = target.isAtSameMomentAs(todayZero);

      if (isToday) {
        if (alarm.intervalCountdown != null && alarm.intervalCountdown! > 0) {
          return false;
        }
      } else {
        final startStr = alarm.startDate ?? alarm.createdDate;
        if (startStr != null && startStr.isNotEmpty) {
          try {
            final start = DateTime.parse(startStr);
            final startZero = DateTime(start.year, start.month, start.day);
            final diffDays = target.difference(startZero).inDays;
            if (diffDays < 0 || diffDays % alarm.intervalDays! != 0) {
              return false;
            }
          } catch (_) {
            return false;
          }
        } else {
          return false;
        }
      }
    }

    // Alarme mensal fixo
    if (alarm.dayOfMonth != null && alarm.dayOfMonth! > 0) {
      if (target.day != alarm.dayOfMonth) return false;
      return true;
    }

    // Alarme com data específica de início
    if (alarm.startDate != null && alarm.startDate!.isNotEmpty && alarm.durationDays > 0) {
      try {
        final start = DateTime.parse(alarm.startDate!);
        final startZero = DateTime(start.year, start.month, start.day);
        
        // Verifica duração
        final endZero = startZero.add(Duration(days: alarm.durationDays - 1));
        if (target.isBefore(startZero) || target.isAfter(endZero)) return false;

        // Verifica intervalo de horas/dias (se existir)
        if (alarm.intervalHours != null && alarm.intervalHours! > 24) {
          final intervalDays = alarm.intervalHours! ~/ 24;
          final diffDays = target.difference(startZero).inDays;
          if (diffDays % intervalDays != 0) return false;
        }

        // Verifica se o dia da semana bate
        final firmwareWeekday = target.weekday % 7; // 0 = Sun, 1 = Mon...
        return alarm.days[firmwareWeekday];
      } catch (_) {
        return false;
      }
    }

    // Check weekday (recorrente sem data específica)
    final firmwareWeekday = target.weekday % 7; // 0 = Sun, 1 = Mon...
    return alarm.days[firmwareWeekday];
  }
}
