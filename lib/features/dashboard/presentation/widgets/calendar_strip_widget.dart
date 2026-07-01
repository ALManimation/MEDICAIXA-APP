import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../dashboard_notifier.dart';
import '../../../alarms/data/alarm_model.dart';
import '../../../reminders/data/reminder_model.dart';
import '../../../../core/providers/locale_provider.dart';

abstract class StripItem {}

class SparseMarkerItem extends StripItem {}
class MonthLabelItem extends StripItem {
  final String label;
  MonthLabelItem(this.label);
}
class YearLabelItem extends StripItem {
  final String label;
  YearLabelItem(this.label);
}

class DateItem extends StripItem {
  final DateTime date;
  final bool isToday;
  final bool isSelected;
  final bool hasRecurring;
  final bool hasDated;
  final bool hasReminder;

  DateItem({
    required this.date,
    required this.isToday,
    required this.isSelected,
    required this.hasRecurring,
    required this.hasDated,
    required this.hasReminder,
  });
}

class CalendarStripWidget extends ConsumerStatefulWidget {
  const CalendarStripWidget({super.key});

  @override
  ConsumerState<CalendarStripWidget> createState() => _CalendarStripWidgetState();
}

class _CalendarStripWidgetState extends ConsumerState<CalendarStripWidget> {
  late ScrollController _scrollController;
  final double _dateItemWidth = 54.0; // 50 width + 4 margin
  final double _labelItemWidth = 45.0;
  final double _sparseItemWidth = 30.0; 

  late List<StripItem> _items = [];
  int _todayIndex = 0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToToday(animate: false);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToToday({bool animate = true}) {
    if (!_scrollController.hasClients) return;
    _scrollToIndex(_todayIndex, animate: animate);
  }

  void _scrollToIndex(int index, {bool animate = true}) {
    if (!_scrollController.hasClients || index < 0 || index >= _items.length) return;
    
    final screenWidth = MediaQuery.of(context).size.width;
    double offset = 0.0;
    for (int i = 0; i < index; i++) {
      final item = _items[i];
      if (item is DateItem) {
        offset += _dateItemWidth;
      } else if (item is MonthLabelItem || item is YearLabelItem) {
        offset += _labelItemWidth;
      } else {
        offset += _sparseItemWidth;
      }
    }
    
    double itemW = 0;
    final target = _items[index];
    if (target is DateItem) {
      itemW = _dateItemWidth;
    } else if (target is MonthLabelItem || target is YearLabelItem) {
      itemW = _labelItemWidth;
    } else {
      itemW = _sparseItemWidth;
    }
    
    offset = offset - (screenWidth / 2) + (itemW / 2) + 24; // +24 for list padding
    
    if (animate) {
      _scrollController.animateTo(
        offset.clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _scrollController.jumpTo(
        offset.clamp(0.0, _scrollController.position.maxScrollExtent),
      );
    }
  }

  bool _isReminderActiveOnDate(ReminderModel r, DateTime date) {
    if (!r.enabled || r.startDate.isEmpty) return false;
    final sd = DateTime.parse(r.startDate);
    final target = DateTime(date.year, date.month, date.day);
    
    if (target.isBefore(sd)) {
      if (r.notifyDaysBefore > 0) {
        return sd.difference(target).inDays <= r.notifyDaysBefore;
      }
      return false;
    }
    
    if (r.period.isEmpty) {
      return sd.year == target.year && sd.month == target.month && sd.day == target.day;
    }
    
    final diffDays = target.difference(sd).inDays;
    final interval = r.interval > 0 ? r.interval : 1;
    
    if (r.period == 'day') return diffDays % interval == 0;
    if (r.period == 'week') return diffDays % (interval * 7) == 0;
    if (r.period == 'month') {
      final int mDiff = (target.year - sd.year) * 12 + (target.month - sd.month);
      return mDiff >= 0 && mDiff % interval == 0 && target.day == sd.day;
    }
    if (r.period == 'year') {
      final int yDiff = target.year - sd.year;
      return yDiff >= 0 && yDiff % interval == 0 && target.month == sd.month && target.day == sd.day;
    }
    return false;
  }

  DateItem _buildDateItem(
    DateTime date, 
    DateTime today, 
    DateTime selected, 
    List<AlarmModel> alarms, 
    List<ReminderModel> reminders
  ) {
    final bool hasRecurring = alarms.any((a) {
      if (!a.enabled) return false;
      final isDated = a.startDate != null && a.startDate!.isNotEmpty && a.durationDays > 0;
      if (isDated) return false;
      if (a.createdDate != null && a.createdDate!.isNotEmpty) {
        try {
          final cd = DateTime.parse(a.createdDate!);
          final cdZero = DateTime(cd.year, cd.month, cd.day);
          final targetZero = DateTime(date.year, date.month, date.day);
          if (targetZero.isBefore(cdZero)) return false;
        } catch (_) {}
      }
      final int idx = date.weekday % 7; 
      return a.days[idx] == true;
    });

    final bool hasDated = alarms.any((a) {
      final isDated = a.startDate != null && a.startDate!.isNotEmpty && a.durationDays > 0;
      if (!isDated) return false;
      final sd = DateTime.parse(a.startDate!);
      final ed = sd.add(Duration(days: a.durationDays - 1));
      return !date.isBefore(sd) && !date.isAfter(ed);
    });

    final bool hasReminder = reminders.any((r) => _isReminderActiveOnDate(r, date));

    return DateItem(
      date: date,
      isToday: date.year == today.year && date.month == today.month && date.day == today.day,
      isSelected: date.year == selected.year && date.month == selected.month && date.day == selected.day,
      hasRecurring: hasRecurring,
      hasDated: hasDated,
      hasReminder: hasReminder,
    );
  }

  void _calculateItems(List<AlarmModel> alarms, List<ReminderModel> reminders, DateTime selectedDate, String locale) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    DateTime? oldestDate;
    for (var a in alarms) {
      if (a.createdDate != null) {
        final d = DateTime.parse(a.createdDate!);
        if (oldestDate == null || d.isBefore(oldestDate)) oldestDate = d;
      } else if (a.startDate != null && a.startDate!.isNotEmpty) {
        final d = DateTime.parse(a.startDate!);
        if (oldestDate == null || d.isBefore(oldestDate)) oldestDate = d;
      }
    }
    for (var r in reminders) {
      if (r.startDate.isNotEmpty) {
        final d = DateTime.parse(r.startDate);
        if (oldestDate == null || d.isBefore(oldestDate)) oldestDate = d;
      }
    }
    
    int pastDays = 0;
    if (oldestDate != null) {
      final diff = today.difference(oldestDate).inDays;
      pastDays = diff.clamp(0, 15);
    }
    
    final bool hasActiveRecurring = alarms.any((a) => a.enabled && a.durationDays == 0);
    int maxFutureDays = 0;
    if (hasActiveRecurring) {
      maxFutureDays = 14;
    } else {
      for (var a in alarms.where((a) => a.active && a.startDate != null && a.startDate!.isNotEmpty && a.durationDays > 0)) {
        final sd = DateTime.parse(a.startDate!);
        final ed = sd.add(Duration(days: a.durationDays - 1));
        final diff = ed.difference(today).inDays;
        if (diff > maxFutureDays) maxFutureDays = diff;
      }
      for (var r in reminders.where((r) => r.enabled && r.startDate.isNotEmpty)) {
         final sd = DateTime.parse(r.startDate);
         final diff = sd.difference(today).inDays;
         if (diff > 0 && diff <= 14 && diff > maxFutureDays) {
            maxFutureDays = diff;
         }
      }
      maxFutureDays = maxFutureDays.clamp(0, 14);
    }
    final futureDays = maxFutureDays;
    
    final items = <StripItem>[];
    int lastMonth = -1;
    int lastYear = today.year;
    
    // Part 1: Continuous Calendar
    for (int i = 0; i < pastDays + 1 + futureDays; i++) {
       final d = today.subtract(Duration(days: pastDays)).add(Duration(days: i));
       
       final bool showYear = d.year != lastYear;
       if (showYear) {
         lastYear = d.year;
         lastMonth = -1;
         items.add(YearLabelItem(lastYear.toString()));
       }
       final bool showMonth = d.month != lastMonth;
       if (showMonth) {
         lastMonth = d.month;
         items.add(MonthLabelItem(DateFormat('MMM', locale).format(d).toUpperCase()));
       }
       
       items.add(_buildDateItem(d, today, selectedDate, alarms, reminders));
       if (d.year == today.year && d.month == today.month && d.day == today.day) {
         _todayIndex = items.length - 1;
       }
    }
    
    // Part 2: Sparse Calendar
    final sparseStart = today.add(Duration(days: futureDays + 1));
    final sparseDatesSet = <DateTime>{};
    
    for (var a in alarms.where((a) => a.active && a.startDate != null && a.startDate!.isNotEmpty && a.durationDays > 0)) {
       final sd = DateTime.parse(a.startDate!);
       final ed = sd.add(Duration(days: a.durationDays - 1));
       if (!sd.isBefore(sparseStart)) sparseDatesSet.add(sd);
       if (!ed.isBefore(sparseStart)) sparseDatesSet.add(ed);
       int added = 0;
       for (var d = sd.isBefore(sparseStart) ? sparseStart : sd; !d.isAfter(ed); d = d.add(const Duration(days: 1))) {
          sparseDatesSet.add(d);
          added++;
          if (added > 200) break;
       }
    }
    
    for (var r in reminders.where((r) => r.enabled && r.startDate.isNotEmpty)) {
       if (r.period.isEmpty) { 
          final sd = DateTime.parse(r.startDate);
          if (!sd.isBefore(sparseStart)) sparseDatesSet.add(sd);
       } else {
          int found = 0;
          final maxSearch = DateTime(today.year + 2, today.month, today.day);
          for (var d = sparseStart; !d.isAfter(maxSearch) && found < 3; d = d.add(const Duration(days: 1))) {
             if (_isReminderActiveOnDate(r, d)) {
                sparseDatesSet.add(d);
                found++;
             }
          }
       }
    }
    
    if (sparseDatesSet.isNotEmpty) {
       final sortedList = sparseDatesSet.toList()..sort();
       DateTime? prevDate;
       bool isFirstSparse = true;
       
       for (var d in sortedList) {
         if (isFirstSparse) {
           items.add(SparseMarkerItem());
           isFirstSparse = false;
           lastMonth = -1; 
         } else if (prevDate != null) {
           if (d.difference(prevDate).inDays > 7) {
             items.add(SparseMarkerItem());
             lastMonth = -1;
           }
         }
         
         final bool showYear = d.year != lastYear;
         if (showYear) {
           lastYear = d.year;
           lastMonth = -1;
           items.add(YearLabelItem(lastYear.toString()));
         }
         final bool showMonth = d.month != lastMonth;
         if (showMonth) {
           lastMonth = d.month;
           items.add(MonthLabelItem(DateFormat('MMM', locale).format(d).toUpperCase()));
         }
         
         items.add(_buildDateItem(d, today, selectedDate, alarms, reminders));
         prevDate = d;
       }
    }
    
    _items = items;
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(dashboardNotifierProvider);
    final state = asyncState.valueOrNull;
    if (state == null) return const SizedBox.shrink();
    
    final selectedDate = state.selectedDate;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final locale = ref.watch(appLocaleProvider);
    
    _calculateItems(state.allAlarms, state.allReminders, selectedDate, locale);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 64, // Reduced from 80 since labels are aside, not stacked
          child: ListView.builder(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            itemCount: _items.length,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemBuilder: (context, index) {
              final item = _items[index];
              
              if (item is SparseMarkerItem) {
                return Container(
                  width: _sparseItemWidth,
                  alignment: Alignment.center,
                  child: Text('···', style: TextStyle(color: AppColors.textMuted, fontSize: 16)),
                );
              }
              
              if (item is MonthLabelItem) {
                return Container(
                  width: _labelItemWidth,
                  alignment: Alignment.center,
                  child: Text(
                    item.label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                      letterSpacing: 0.5,
                    ),
                  ),
                );
              }
              
              if (item is YearLabelItem) {
                return Container(
                  width: _labelItemWidth,
                  alignment: Alignment.center,
                  child: Text(
                    item.label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMuted,
                    ),
                  ),
                );
              }
              
              if (item is DateItem) {
                return GestureDetector(
                  onTap: () {
                    ref.read(dashboardNotifierProvider.notifier).selectDate(item.date);
                    _scrollToIndex(index);
                  },
                  child: Container(
                    width: 50,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    padding: const EdgeInsets.only(top: 8, bottom: 6),
                    decoration: BoxDecoration(
                      color: item.isSelected 
                        ? AppColors.primary 
                        : (item.isToday ? Colors.transparent : Colors.transparent),
                      borderRadius: BorderRadius.circular(12),
                      border: item.isToday && !item.isSelected 
                        ? Border.all(color: AppColors.primary, width: 2) 
                        : null,
                      boxShadow: item.isSelected 
                        ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.35), blurRadius: 8, offset: const Offset(0, 2))]
                        : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          DateFormat('E', locale).format(item.date).toUpperCase().replaceAll('.', ''),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: item.isSelected 
                              ? Colors.white 
                              : (item.isToday ? AppColors.primary : AppColors.textMuted),
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${item.date.day}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: item.isToday ? FontWeight.w700 : FontWeight.w600,
                            color: item.isSelected 
                              ? Colors.white 
                              : (item.isToday ? AppColors.primary : AppColors.text),
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 3),
                        // Dots
                        SizedBox(
                          height: 5,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (item.hasRecurring) _buildDot(const Color(0xFF22C55E), item.isSelected),
                              if (item.hasDated) _buildDot(const Color(0xFF3B82F6), item.isSelected),
                              if (item.hasReminder) _buildDot(const Color(0xFFEF4444), item.isSelected),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ),
        
        // "Hoje" or "Voltar para Hoje" Button
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () {
            ref.read(dashboardNotifierProvider.notifier).resetToToday();
            _scrollToToday();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Builder(
              builder: (context) {
                final isSelectedToday = today.year == selectedDate.year && 
                                        today.month == selectedDate.month && 
                                        today.day == selectedDate.day;
                
                return Text(
                  isSelectedToday ? 'HOJE' : 'VOLTAR PARA HOJE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: isSelectedToday ? FontWeight.normal : FontWeight.bold,
                    color: isSelectedToday ? AppColors.textMuted : AppColors.primary,
                    letterSpacing: 1.2,
                  ),
                );
              }
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDot(Color color, bool isSelected) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 1.5),
      width: 5,
      height: 5,
      decoration: BoxDecoration(
        color: isSelected ? color.withValues(alpha: 0.8) : color,
        shape: BoxShape.circle,
      ),
    );
  }
}
