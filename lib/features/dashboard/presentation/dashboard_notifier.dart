import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../alarms/data/alarm_model.dart';
import '../../alarms/data/alarm_repository.dart';
import '../../reminders/data/reminder_model.dart';
import '../../reminders/data/reminder_repository.dart';

part 'dashboard_notifier.g.dart';

class DashboardState {
  final DateTime selectedDate;
  final List<AlarmModel> alarms;
  final List<AlarmModel> allAlarms;
  final List<ReminderModel> reminders;
  final int takenCount;
  final int pendingCount;
  final int missedCount;
  final bool isLoading;

  const DashboardState({
    required this.selectedDate,
    required this.alarms,
    required this.allAlarms,
    required this.reminders,
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
      takenCount: 0,
      pendingCount: 0,
      missedCount: 0,
      isLoading: true,
    );

    Future.microtask(() => _updateData());

    return state;
  }

  void selectDate(DateTime date) {
    state = state.copyWith(selectedDate: date, isLoading: true);
    _updateData();
    
    _resetInactivityTimer();
  }

  void resetToToday() {
    _inactivityTimer?.cancel();
    _inactivityTimer = null;
    state = state.copyWith(selectedDate: DateTime.now(), isLoading: true);
    _updateData();
  }

  void _resetInactivityTimer() {
    _inactivityTimer?.cancel();
    
    final now = DateTime.now();
    final isToday = state.selectedDate.year == now.year && 
                    state.selectedDate.month == now.month && 
                    state.selectedDate.day == now.day;
                    
    if (!isToday) {
      _inactivityTimer = Timer(const Duration(seconds: 30), () {
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
    int taken = 0;
    int pending = 0;
    int missed = 0;

    final now = DateTime.now();
    final isSelectedToday = date.year == now.year && date.month == now.month && date.day == now.day;
    final dateFormatted = "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";

    for (final alarm in filteredAlarms) {
      final isTakenToday = alarm.lastStatusDate == dateFormatted && alarm.lastStatus == 'Tomado';
      final isSkippedToday = alarm.lastStatusDate == dateFormatted && alarm.lastStatus == 'Não Tomado';

      if (isTakenToday) {
        taken++;
      } else if (isSkippedToday) {
        missed++;
      } else {
        // Not taken or skipped yet
        if (isSelectedToday) {
          // Check if alarm time has passed today
          final alarmTime = DateTime(now.year, now.month, now.day, alarm.hour, alarm.minute);
          if (now.isAfter(alarmTime)) {
            missed++; // Missed since time passed and not marked taken
          } else {
            pending++;
          }
        } else if (date.isBefore(DateTime(now.year, now.month, now.day))) {
          // Date in the past, if not taken, it is missed
          missed++;
        } else {
          // Date in the future, it is pending
          pending++;
        }
      }
    }

    state = DashboardState(
      selectedDate: date,
      alarms: filteredAlarms,
      allAlarms: allAlarms,
      reminders: filteredReminders,
      takenCount: taken,
      pendingCount: pending,
      missedCount: missed,
      isLoading: false,
    );
  }

  bool _isAlarmActiveOnDate(AlarmModel alarm, DateTime dateObj) {
    if (!alarm.enabled) return false;
    final target = DateTime(dateObj.year, dateObj.month, dateObj.day);

    // Alarme mensal fixo
    if (alarm.dayOfMonth != null && alarm.dayOfMonth! > 0) {
      if (target.day != alarm.dayOfMonth) return false;
      if (alarm.createdDate != null && alarm.createdDate!.isNotEmpty) {
        try {
          final created = DateTime.parse(alarm.createdDate!);
          final createdZero = DateTime(created.year, created.month, created.day);
          if (target.isBefore(createdZero)) return false;
        } catch (_) {}
      }
      return true;
    }

    // Alarme com data específica de início
    if (alarm.startDate != null && alarm.startDate!.isNotEmpty) {
      try {
        final start = DateTime.parse(alarm.startDate!);
        final startZero = DateTime(start.year, start.month, start.day);
        
        // Verifica duração
        final endZero = startZero.add(Duration(days: (alarm.durationDays > 0 ? alarm.durationDays : 1) - 1));
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
