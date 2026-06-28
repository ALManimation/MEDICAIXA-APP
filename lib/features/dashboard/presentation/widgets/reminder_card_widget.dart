import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../reminders/data/reminder_model.dart';
import '../../../../core/localization/app_localizations.dart';

class ReminderCardWidget extends StatelessWidget {
  final ReminderModel reminder;
  final VoidCallback onComplete;
  final DateTime selectedDate;
  final VoidCallback? onTap;

  const ReminderCardWidget({
    super.key,
    required this.reminder,
    required this.onComplete,
    required this.selectedDate,
    this.onTap,
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
          color: isDone ? AppColors.success.withValues(alpha: 0.5) : AppColors.border,
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
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
                color: hexColor.withValues(alpha: 0.1),
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
                          color: AppColors.text,
                          decoration: isDone ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      if (timeStr.isNotEmpty)
                        Text(
                          timeStr,
                          style: TextStyle(
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
                      style: TextStyle(
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
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (proximityStr.isNotEmpty) ...[
                        Text(
                          ' · ',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                        ),
                        Text(
                          proximityStr,
                          style: TextStyle(
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
                icon: Icon(
                  Icons.check_circle_outline_rounded,
                  color: AppColors.textMuted,
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.success,
                ),
              ),
            ],
          ),
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

      if (diffDays == 0) return t('today');
      if (diffDays == 1) return t('proximity_tomorrow');
      if (diffDays == -1) return t('proximity_yesterday');
      if (diffDays > 1) return t('proximity_in_days', [diffDays]);
      if (diffDays < -1) return t('proximity_ago_days', [diffDays.abs()]);
    } catch (_) {}
    return '';
  }

  String _getFrequencyString(String period, int interval) {
    if (period.isEmpty || interval == 0) return t('rem_once_label');
    final String label = _getPeriodLabel(period, interval);
    if (interval == 1) {
      return label;
    }
    return t('rem_every_interval_fmt', [interval, label]);
  }

  String _getPeriodLabel(String period, int interval) {
    switch (period.toLowerCase()) {
      case 'day':
        return interval == 1 ? t('freq_daily') : t('days_lowercase');
      case 'week':
        return interval == 1 ? t('freq_weekly') : t('weeks_lowercase');
      case 'month':
        return interval == 1 ? t('freq_monthly') : t('months_lowercase');
      case 'year':
        return interval == 1 ? t('freq_yearly') : t('years_lowercase');
      default:
        return t('freq_period_lowercase');
    }
  }
}
