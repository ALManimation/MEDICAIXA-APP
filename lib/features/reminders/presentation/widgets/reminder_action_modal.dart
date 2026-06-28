import 'package:flutter/material.dart';
import 'package:medicaixa_app/core/constants/app_colors.dart';
import 'package:medicaixa_app/features/reminders/data/reminder_model.dart';
import 'package:medicaixa_app/features/reminders/data/reminder_repository.dart';
import 'package:medicaixa_app/features/reminders/presentation/reminder_form_screen.dart';
import 'package:medicaixa_app/core/localization/app_localizations.dart';

/// Bottom sheet modal for managing a reminder.
/// Provides quick actions like complete, edit, and delete.
class ReminderActionModal extends StatelessWidget {
  final ReminderModel reminder;
  final ReminderRepository repository;
  final VoidCallback onRefresh;

  const ReminderActionModal({
    super.key,
    required this.reminder,
    required this.repository,
    required this.onRefresh,
  });

  /// Shows this modal as a bottom sheet.
  static Future<void> show(
    BuildContext context, {
    required ReminderModel reminder,
    required ReminderRepository repository,
    required VoidCallback onRefresh,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => ReminderActionModal(
        reminder: reminder,
        repository: repository,
        onRefresh: onRefresh,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final day = DateTime.now().day.toString().padLeft(2, '0');
    final month = DateTime.now().month.toString().padLeft(2, '0');
    final year = DateTime.now().year;
    final todayFormatted = '$day/$month/$year';

    final isCompletedToday = reminder.lastCompletedDate == todayFormatted;
    final reminderColor = AppColors.getAlarmColor(reminder.color);

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Centralized Window Title
            Text(
              t('reminder_manage_title'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 16),

            // Identification (Icon and Title)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.push_pin_rounded,
                  color: reminderColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    reminder.title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AppColors.text,
                    ),
                  ),
                ),
              ],
            ),

            // Description (if not empty)
            if (reminder.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                reminder.description,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textMuted,
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Principal Action (Marcar como Feito)
            if (!isCompletedToday)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    await repository.completeReminder(reminder.id);
                    onRefresh();
                    if (context.mounted) {
                      Navigator.pop(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    t('btn_mark_done'),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  t('reminder_completed_today'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.success,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // Divisor
            Divider(
              color: AppColors.border,
              height: 1,
            ),

            const SizedBox(height: 20),

            // Configuration Actions (Editar / Excluir)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ReminderFormScreen(editReminder: reminder),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.text,
                      side: BorderSide(color: AppColors.border),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(
                      Icons.edit_rounded,
                      size: 18,
                    ),
                    label: Text(
                      t('edit_btn'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: AppColors.surface,
                          title: Text(
                            t('dialog_delete_reminder_title'),
                            style: TextStyle(
                              color: AppColors.text,
                            ),
                          ),
                          content: Text(
                            t('dialog_delete_reminder_desc', [reminder.title]),
                            style: TextStyle(
                              color: AppColors.textMuted,
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: Text(
                                t('cancel_btn'),
                                style: TextStyle(
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: Text(
                                t('delete_btn'),
                                style: TextStyle(
                                  color: AppColors.missed,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await repository.deleteReminder(reminder.id);
                        onRefresh();
                        if (context.mounted) {
                          Navigator.pop(context);
                        }
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.missed,
                      side: BorderSide(
                        color: AppColors.missed.withValues(alpha: 0.5),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(
                      Icons.delete_rounded,
                      size: 18,
                    ),
                    label: Text(
                      t('delete_btn'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
