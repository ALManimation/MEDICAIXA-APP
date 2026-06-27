import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../reminders/data/reminder_model.dart';

class ReminderCardWidget extends StatelessWidget {
  final ReminderModel reminder;
  final VoidCallback onComplete;
  final DateTime selectedDate;

  const ReminderCardWidget({
    super.key,
    required this.reminder,
    required this.onComplete,
    required this.selectedDate,
  });

  @override
  Widget build(BuildContext context) {
    final hexColor = AppColors.getAlarmColor(reminder.color);
    final timeStr = reminder.hasTime && reminder.hour != null && reminder.minute != null
        ? ' ${reminder.hour!.toString().padLeft(2, '0')}:${reminder.minute!.toString().padLeft(2, '0')}'
        : '';

    final todayFormatted = "${DateTime.now().day.toString().padLeft(2, '0')}/${DateTime.now().month.toString().padLeft(2, '0')}/${DateTime.now().year}";
    final isDone = reminder.lastCompletedDate == todayFormatted;

    final proximityStr = _getProximityString(reminder.startDate, selectedDate);
    final freqStr = _getFrequencyString(reminder.period, reminder.interval);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDone ? AppColors.success.withOpacity(0.5) : AppColors.border,
          width: 1,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border(
            left: BorderSide(color: hexColor, width: 4),
          ),
        ),
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Pin Icon representing a reminder
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: hexColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.push_pin_rounded,
                size: 16,
                color: hexColor,
              ),
            ),
            const SizedBox(width: 12),

            // Reminder content details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        reminder.title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          decoration: isDone ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      if (timeStr.isNotEmpty)
                        Text(
                          timeStr,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                    ],
                  ),
                  if (reminder.description.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      reminder.description,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        freqStr,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (proximityStr.isNotEmpty) ...[
                        const Text(
                          ' · ',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                        ),
                        Text(
                          proximityStr,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ]
                    ],
                  )
                ],
              ),
            ),

            // Done check button
            if (!isDone)
              IconButton(
                onPressed: onComplete,
                icon: const Icon(
                  Icons.check_circle_outline_rounded,
                  color: AppColors.textMuted,
                ),
              )
            else
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12.0),
                child: Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.success,
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _getProximityString(String startDateStr, DateTime filterDate) {
    if (startDateStr.isEmpty) return '';
    try {
      final sd = DateTime.parse(startDateStr);
      final todayZero = DateTime(filterDate.year, filterDate.month, filterDate.day);
      final startZero = DateTime(sd.year, sd.month, sd.day);
      final diffDays = startZero.difference(todayZero).inDays;

      if (diffDays == 0) return 'Hoje';
      if (diffDays == 1) return 'Amanhã';
      if (diffDays == -1) return 'Ontem';
      if (diffDays > 1) return 'Em $diffDays dias';
      if (diffDays < -1) return 'Há ${diffDays.abs()} dias';
    } catch (_) {}
    return '';
  }

  String _getFrequencyString(String period, int interval) {
    if (period.isEmpty || interval == 0) return 'Vez única';
    final String label = _getPeriodLabel(period, interval);
    if (interval == 1) {
      return label;
    }
    return 'A cada $interval $label';
  }

  String _getPeriodLabel(String period, int interval) {
    switch (period.toLowerCase()) {
      case 'day':
        return interval == 1 ? 'Diário' : 'dias';
      case 'week':
        return interval == 1 ? 'Semanal' : 'semanas';
      case 'month':
        return interval == 1 ? 'Mensal' : 'meses';
      case 'year':
        return interval == 1 ? 'Anual' : 'anos';
      default:
        return 'período';
    }
  }
}
