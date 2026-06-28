import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:medicaixa_app/core/database/database.dart';
import 'package:medicaixa_app/features/history/data/history_repository.dart';
import 'package:medicaixa_app/features/medications/data/medication_repository.dart';
import 'package:intl/intl.dart';
import 'package:medicaixa_app/core/providers/locale_provider.dart';

part 'reports_notifier.g.dart';

enum DotStatus {
  fullGreen,     // taken > 0 and missed == 0
  partialOrange,  // taken > 0 and missed > 0
  redMiss,       // taken == 0 and missed > 0
  grayEmpty      // taken == 0 and missed == 0
}

class DailyAdherenceData {
  final String dayName;
  final DateTime date;
  final int percentage;
  final int expectedCount;

  DailyAdherenceData({
    required this.dayName,
    required this.date,
    required this.percentage,
    required this.expectedCount,
  });
}

class MedicationPerformanceData {
  final String name;
  final String colorHex;
  final int takenCount;
  final int expectedCount;
  final int percentage;

  MedicationPerformanceData({
    required this.name,
    required this.colorHex,
    required this.takenCount,
    required this.expectedCount,
    required this.percentage,
  });
}

enum HeatmapLevel {
  level0, // no data
  level1, // < 25%
  level2, // 25-49%
  level3, // 50-74%
  level4, // 75-99%
  level5, // 100%
}

class HeatmapCellData {
  final DateTime date;
  final int dayOfMonth;
  final int percentage;
  final int expectedCount;
  final HeatmapLevel level;
  final bool isFuture;
  final bool isToday;

  HeatmapCellData({
    required this.date,
    required this.dayOfMonth,
    required this.percentage,
    required this.expectedCount,
    required this.level,
    required this.isFuture,
    required this.isToday,
  });
}

class ReportsState {
  final String selectedMedication;
  final List<String> availableMedications;
  
  final int generalAdherencePercentage;
  final int generalTakenCount;
  final int generalMissedCount;
  final int generalSkippedCount;

  final List<DailyAdherenceData> dailyAdherence;

  final int currentStreak;
  final int bestStreak;
  final List<DotStatus> last14DaysDots;

  final double morningPercentage;
  final int morningTaken;
  final int morningExpected;
  
  final double afternoonPercentage;
  final int afternoonTaken;
  final int afternoonExpected;

  final double nightPercentage;
  final int nightTaken;
  final int nightExpected;

  final List<MedicationPerformanceData> medicationPerformance;

  final List<HeatmapCellData> heatmapCells;

  ReportsState({
    required this.selectedMedication,
    required this.availableMedications,
    required this.generalAdherencePercentage,
    required this.generalTakenCount,
    required this.generalMissedCount,
    required this.generalSkippedCount,
    required this.dailyAdherence,
    required this.currentStreak,
    required this.bestStreak,
    required this.last14DaysDots,
    required this.morningPercentage,
    required this.morningTaken,
    required this.morningExpected,
    required this.afternoonPercentage,
    required this.afternoonTaken,
    required this.afternoonExpected,
    required this.nightPercentage,
    required this.nightTaken,
    required this.nightExpected,
    required this.medicationPerformance,
    required this.heatmapCells,
  });

  ReportsState copyWith({
    String? selectedMedication,
    List<String>? availableMedications,
    int? generalAdherencePercentage,
    int? generalTakenCount,
    int? generalMissedCount,
    int? generalSkippedCount,
    List<DailyAdherenceData>? dailyAdherence,
    int? currentStreak,
    int? bestStreak,
    List<DotStatus>? last14DaysDots,
    double? morningPercentage,
    int? morningTaken,
    int? morningExpected,
    double? afternoonPercentage,
    int? afternoonTaken,
    int? afternoonExpected,
    double? nightPercentage,
    int? nightTaken,
    int? nightExpected,
    List<MedicationPerformanceData>? medicationPerformance,
    List<HeatmapCellData>? heatmapCells,
  }) {
    return ReportsState(
      selectedMedication: selectedMedication ?? this.selectedMedication,
      availableMedications: availableMedications ?? this.availableMedications,
      generalAdherencePercentage: generalAdherencePercentage ?? this.generalAdherencePercentage,
      generalTakenCount: generalTakenCount ?? this.generalTakenCount,
      generalMissedCount: generalMissedCount ?? this.generalMissedCount,
      generalSkippedCount: generalSkippedCount ?? this.generalSkippedCount,
      dailyAdherence: dailyAdherence ?? this.dailyAdherence,
      currentStreak: currentStreak ?? this.currentStreak,
      bestStreak: bestStreak ?? this.bestStreak,
      last14DaysDots: last14DaysDots ?? this.last14DaysDots,
      morningPercentage: morningPercentage ?? this.morningPercentage,
      morningTaken: morningTaken ?? this.morningTaken,
      morningExpected: morningExpected ?? this.morningExpected,
      afternoonPercentage: afternoonPercentage ?? this.afternoonPercentage,
      afternoonTaken: afternoonTaken ?? this.afternoonTaken,
      afternoonExpected: afternoonExpected ?? this.afternoonExpected,
      nightPercentage: nightPercentage ?? this.nightPercentage,
      nightTaken: nightTaken ?? this.nightTaken,
      nightExpected: nightExpected ?? this.nightExpected,
      medicationPerformance: medicationPerformance ?? this.medicationPerformance,
      heatmapCells: heatmapCells ?? this.heatmapCells,
    );
  }
}

@riverpod
Stream<List<HistoryEvent>> reportsHistoryEvents(ReportsHistoryEventsRef ref, int startTimestamp) {
  return ref.watch(historyRepositoryProvider).watchAlarmHistoryEventsSince(startTimestamp);
}

@riverpod
Stream<List<Medication>> reportsMedications(ReportsMedicationsRef ref) {
  return ref.watch(medicationRepositoryProvider).watchAllMedications();
}

@riverpod
class ReportsNotifier extends _$ReportsNotifier {
  List<HistoryEvent> _allHistoryEvents = [];
  List<Medication> _allMedications = [];

  @override
  ReportsState build() {
    final now = DateTime.now();
    final todayMidnight = DateTime(now.year, now.month, now.day);
    final startOfAnalysis = DateTime(todayMidnight.year, todayMidnight.month, todayMidnight.day - 35);
    final startTimestamp = startOfAnalysis.millisecondsSinceEpoch;

    final historyEventsAsync = ref.watch(reportsHistoryEventsProvider(startTimestamp));
    final medicationsAsync = ref.watch(reportsMedicationsProvider);

    _allHistoryEvents = historyEventsAsync.value ?? [];
    _allMedications = medicationsAsync.value ?? [];

    // Watch appLocaleProvider to rebuild state on language change
    ref.watch(appLocaleProvider);

    final currentFilter = stateOrNull.selectedMedication;

    return _calculateState(currentFilter);
  }

  @override
  ReportsState get stateOrNull {
    try {
      return state;
    } catch (_) {
      return ReportsState(
        selectedMedication: 'Todos',
        availableMedications: ['Todos'],
        generalAdherencePercentage: 0,
        generalTakenCount: 0,
        generalMissedCount: 0,
        generalSkippedCount: 0,
        dailyAdherence: [],
        currentStreak: 0,
        bestStreak: 0,
        last14DaysDots: [],
        morningPercentage: 0.0,
        morningTaken: 0,
        morningExpected: 0,
        afternoonPercentage: 0.0,
        afternoonTaken: 0,
        afternoonExpected: 0,
        nightPercentage: 0.0,
        nightTaken: 0,
        nightExpected: 0,
        medicationPerformance: [],
        heatmapCells: [],
      );
    }
  }

  void setFilter(String medicationName) {
    state = _calculateState(medicationName);
  }

  String formatDate(DateTime dt) {
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final year = dt.year;
    return '$day/$month/$year';
  }

  ReportsState _calculateState(String filter) {
    final filteredEvents = filter == 'Todos'
        ? _allHistoryEvents
        : _allHistoryEvents.where((e) => e.medName?.toLowerCase() == filter.toLowerCase()).toList();

    // 1. Available medications list
    final Set<String> medNames = {};
    for (final med in _allMedications) {
      if (med.name.isNotEmpty) {
        medNames.add(med.name);
      }
    }
    for (final event in _allHistoryEvents) {
      if (event.medName != null && event.medName!.isNotEmpty) {
        medNames.add(event.medName!);
      }
    }
    final availableMedications = ['Todos', ...medNames.toList()..sort()];

    final now = DateTime.now();
    final todayMidnight = DateTime(now.year, now.month, now.day);
    final sevenDaysStart = DateTime(todayMidnight.year, todayMidnight.month, todayMidnight.day - 6);

    // 2. Recent events in last 7 days (including today)
    final recentEvents = filteredEvents
        .where((e) =>
            e.timestamp >= sevenDaysStart.millisecondsSinceEpoch &&
            e.timestamp <= DateTime.now().millisecondsSinceEpoch)
        .toList();

    int generalTakenCount = 0;
    int generalMissedCount = 0;
    int generalSkippedCount = 0;

    for (final e in recentEvents) {
      final status = e.status.toUpperCase();
      if (status == 'TOMADO' || status == 'TOMADO FORA HORA' || status == 'TOMADO PRN' || status == 'CONCLUIDO') {
        generalTakenCount++;
      } else if (status == 'PERDIDO') {
        generalMissedCount++;
      } else if (status == 'CANCELADO') {
        generalSkippedCount++;
      }
    }

    final totalExpected = generalTakenCount + generalMissedCount + generalSkippedCount;
    final generalAdherencePercentage = totalExpected > 0 ? ((generalTakenCount / totalExpected) * 100).round() : 0;

    // 3. Daily adherence
    final List<DailyAdherenceData> dailyAdherence = [];
    final locale = ref.read(appLocaleProvider);

    for (int i = 6; i >= 0; i--) {
      final day = DateTime(todayMidnight.year, todayMidnight.month, todayMidnight.day - i);
      final dayStr = formatDate(day);
      
      final dayEvents = recentEvents.where((e) {
        final dt = DateTime.fromMillisecondsSinceEpoch(e.timestamp);
        return formatDate(dt) == dayStr;
      }).toList();

      int t = 0;
      int m = 0;
      int s = 0;

      for (final e in dayEvents) {
        final status = e.status.toUpperCase();
        if (status == 'TOMADO' || status == 'TOMADO FORA HORA' || status == 'TOMADO PRN' || status == 'CONCLUIDO') {
          t++;
        } else if (status == 'PERDIDO') {
          m++;
        } else if (status == 'CANCELADO') {
          s++;
        }
      }

      final expected = t + m + s;
      final pct = expected > 0 ? ((t / expected) * 100).round() : 0;

      String formattedDay = DateFormat('E', locale).format(day);
      if (formattedDay.isNotEmpty) {
        formattedDay = formattedDay[0].toUpperCase() + formattedDay.substring(1).replaceAll('.', '');
      }

      dailyAdherence.add(DailyAdherenceData(
        dayName: formattedDay,
        date: day,
        percentage: pct,
        expectedCount: expected,
      ));
    }

    // 4. Streak
    final List<Map<String, dynamic>> streakDays = [];
    for (int i = 0; i < 30; i++) {
      final day = DateTime(todayMidnight.year, todayMidnight.month, todayMidnight.day - i);
      final dayStr = formatDate(day);
      
      final dayEvents = filteredEvents.where((e) {
        final dt = DateTime.fromMillisecondsSinceEpoch(e.timestamp);
        return formatDate(dt) == dayStr;
      }).toList();

      int taken = 0;
      int missed = 0;
      int skipped = 0;

      for (final e in dayEvents) {
        final status = e.status.toUpperCase();
        if (status == 'TOMADO' || status == 'TOMADO FORA HORA' || status == 'TOMADO PRN' || status == 'CONCLUIDO') {
          taken++;
        } else if (status == 'PERDIDO') {
          missed++;
        } else if (status == 'CANCELADO') {
          skipped++;
        }
      }

      streakDays.add({
        'date': day,
        'dateStr': dayStr,
        'taken': taken,
        'missed': missed,
        'skipped': skipped,
      });
    }

    int currentStreak = 0;
    for (int i = 0; i < 30; i++) {
      final dStat = streakDays[i];
      final int taken = dStat['taken'];
      final int missed = dStat['missed'];
      final hasAlarms = (taken + missed) > 0;

      if (!hasAlarms) {
        continue;
      }

      if (taken > 0 && missed == 0) {
        currentStreak++;
      } else {
        if (i == 0 && missed == 0) {
          continue;
        }
        break;
      }
    }

    int bestStreak = 0;
    int tempStreak = 0;
    for (int i = 29; i >= 0; i--) {
      final dStat = streakDays[i];
      final int taken = dStat['taken'];
      final int missed = dStat['missed'];
      final hasAlarms = (taken + missed) > 0;

      if (!hasAlarms) {
        continue;
      }

      if (taken > 0 && missed == 0) {
        tempStreak++;
        if (tempStreak > bestStreak) {
          bestStreak = tempStreak;
        }
      } else {
        tempStreak = 0;
      }
    }

    if (currentStreak > bestStreak) {
      bestStreak = currentStreak;
    }

    final List<DotStatus> last14DaysDots = [];
    for (int i = 13; i >= 0; i--) {
      final dStat = streakDays[i];
      final int taken = dStat['taken'];
      final int missed = dStat['missed'];

      if (taken > 0 && missed == 0) {
        last14DaysDots.add(DotStatus.fullGreen);
      } else if (taken > 0 && missed > 0) {
        last14DaysDots.add(DotStatus.partialOrange);
      } else if (taken == 0 && missed > 0) {
        last14DaysDots.add(DotStatus.redMiss);
      } else {
        last14DaysDots.add(DotStatus.grayEmpty);
      }
    }

    // 5. Period Distribution
    int morningTaken = 0;
    int morningExpected = 0;
    int afternoonTaken = 0;
    int afternoonExpected = 0;
    int nightTaken = 0;
    int nightExpected = 0;

    for (final e in recentEvents) {
      final dt = DateTime.fromMillisecondsSinceEpoch(e.timestamp);
      final hour = dt.hour;
      final status = e.status.toUpperCase();
      final isTaken = status == 'TOMADO' || status == 'TOMADO FORA HORA' || status == 'TOMADO PRN' || status == 'CONCLUIDO';
      final isExpected = isTaken || status == 'PERDIDO' || status == 'CANCELADO';

      if (isExpected) {
        if (hour >= 0 && hour < 12) {
          if (isTaken) morningTaken++;
          morningExpected++;
        } else if (hour >= 12 && hour < 18) {
          if (isTaken) afternoonTaken++;
          afternoonExpected++;
        } else {
          if (isTaken) nightTaken++;
          nightExpected++;
        }
      }
    }

    final double morningPercentage = morningExpected > 0 ? (morningTaken / morningExpected * 100) : 0.0;
    final double afternoonPercentage = afternoonExpected > 0 ? (afternoonTaken / afternoonExpected * 100) : 0.0;
    final double nightPercentage = nightExpected > 0 ? (nightTaken / nightExpected * 100) : 0.0;

    // 6. Medication Performance
    final Map<String, _MedTempStats> medStats = {};

    for (final m in _allMedications) {
      if (m.name.isNotEmpty) {
        final keyLower = m.name.toLowerCase();
        medStats[keyLower] = _MedTempStats(
          name: m.name,
          taken: 0,
          expected: 0,
          colorName: m.color,
        );
      }
    }

    for (final e in recentEvents) {
      if (e.medName == null || e.medName!.isEmpty) continue;
      final key = e.medName!.trim();
      final keyLower = key.toLowerCase();

      final status = e.status.toUpperCase();
      final isTaken = status == 'TOMADO' || status == 'TOMADO FORA HORA' || status == 'TOMADO PRN' || status == 'CONCLUIDO';
      final isExpected = isTaken || status == 'PERDIDO' || status == 'CANCELADO';

      if (isExpected) {
        if (!medStats.containsKey(keyLower)) {
          medStats[keyLower] = _MedTempStats(
            name: key,
            taken: 0,
            expected: 0,
            colorName: 'white',
          );
        }

        if (isTaken) {
          medStats[keyLower]!.taken++;
        }
        medStats[keyLower]!.expected++;
      }
    }

    final List<MedicationPerformanceData> medicationPerformance = [];
    for (final mStat in medStats.values) {
      if (mStat.expected > 0) {
        final pct = ((mStat.taken / mStat.expected) * 100).round();
        medicationPerformance.add(MedicationPerformanceData(
          name: mStat.name,
          colorHex: mStat.colorName,
          takenCount: mStat.taken,
          expectedCount: mStat.expected,
          percentage: pct,
        ));
      }
    }
    medicationPerformance.sort((a, b) => b.expectedCount.compareTo(a.expectedCount));

    // 7. Monthly Heatmap
    final List<HeatmapCellData> heatmapCells = [];
    final DateTime startDate = DateTime(todayMidnight.year, todayMidnight.month, todayMidnight.day - 30);
    final int daysToSubtract = startDate.weekday % 7;
    final DateTime startDateAligned = DateTime(startDate.year, startDate.month, startDate.day - daysToSubtract);

    final int daysToAdd = 6 - (todayMidnight.weekday % 7);
    final DateTime endDateAligned = DateTime(todayMidnight.year, todayMidnight.month, todayMidnight.day + daysToAdd);

    DateTime tempDate = startDateAligned;
    while (tempDate.isBefore(endDateAligned) || tempDate.isAtSameMomentAs(endDateAligned)) {
      final dateStr = formatDate(tempDate);
      final isFuture = tempDate.isAfter(todayMidnight);
      final isToday = tempDate.isAtSameMomentAs(todayMidnight);

      final dayEvents = filteredEvents.where((e) {
        final dt = DateTime.fromMillisecondsSinceEpoch(e.timestamp);
        return formatDate(dt) == dateStr;
      }).toList();

      int taken = 0;
      int missed = 0;
      int skipped = 0;

      for (final e in dayEvents) {
        final status = e.status.toUpperCase();
        if (status == 'TOMADO' || status == 'TOMADO FORA HORA' || status == 'TOMADO PRN' || status == 'CONCLUIDO') {
          taken++;
        } else if (status == 'PERDIDO') {
          missed++;
        } else if (status == 'CANCELADO') {
          skipped++;
        }
      }

      final expected = taken + missed + skipped;
      final pct = expected > 0 ? ((taken / expected) * 100).round() : 0;

      HeatmapLevel level = HeatmapLevel.level0;
      if (expected > 0) {
        if (pct == 100) {
          level = HeatmapLevel.level5;
        } else if (pct >= 75) {
          level = HeatmapLevel.level4;
        } else if (pct >= 50) {
          level = HeatmapLevel.level3;
        } else if (pct >= 25) {
          level = HeatmapLevel.level2;
        } else {
          level = HeatmapLevel.level1;
        }
      }

      heatmapCells.add(HeatmapCellData(
        date: tempDate,
        dayOfMonth: tempDate.day,
        percentage: pct,
        expectedCount: expected,
        level: level,
        isFuture: isFuture,
        isToday: isToday,
      ));

      tempDate = DateTime(tempDate.year, tempDate.month, tempDate.day + 1);
    }

    return ReportsState(
      selectedMedication: filter,
      availableMedications: availableMedications,
      generalAdherencePercentage: generalAdherencePercentage,
      generalTakenCount: generalTakenCount,
      generalMissedCount: generalMissedCount,
      generalSkippedCount: generalSkippedCount,
      dailyAdherence: dailyAdherence,
      currentStreak: currentStreak,
      bestStreak: bestStreak,
      last14DaysDots: last14DaysDots,
      morningPercentage: morningPercentage,
      morningTaken: morningTaken,
      morningExpected: morningExpected,
      afternoonPercentage: afternoonPercentage,
      afternoonTaken: afternoonTaken,
      afternoonExpected: afternoonExpected,
      nightPercentage: nightPercentage,
      nightTaken: nightTaken,
      nightExpected: nightExpected,
      medicationPerformance: medicationPerformance,
      heatmapCells: heatmapCells,
    );
  }
}

class _MedTempStats {
  final String name;
  int taken;
  int expected;
  final String colorName;

  _MedTempStats({
    required this.name,
    required this.taken,
    required this.expected,
    required this.colorName,
  });
}
