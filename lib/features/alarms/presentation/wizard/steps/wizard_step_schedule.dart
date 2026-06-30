import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/presentation/widgets/vertical_datetime_selector.dart';
import '../../../../../core/database/database.dart';
import '../../../../../core/providers/core_providers.dart';
import '../alarm_wizard_notifier.dart';

class WizardStepSchedule extends ConsumerStatefulWidget {
  final VoidCallback onNext;

  const WizardStepSchedule({
    super.key,
    required this.onNext,
  });

  @override
  ConsumerState<WizardStepSchedule> createState() => _WizardStepScheduleState();
}

class _WizardStepScheduleState extends ConsumerState<WizardStepSchedule> {
  TimeOfDay _selectedTime = const TimeOfDay(hour: 8, minute: 0);
  List<bool> _selectedDays = List.filled(7, true);

  final List<String> _weekdayLabels = ['D', 'S', 'T', 'Q', 'Q', 'S', 'S'];

  @override
  void initState() {
    super.initState();
    final wizard = ref.read(alarmWizardNotifierProvider);
    _selectedTime = TimeOfDay(hour: wizard.alarm.hour, minute: wizard.alarm.minute);
    _selectedDays = List.from(wizard.alarm.days);
  }

  void _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showVerticalTimePicker(
      context,
      initialTime: _selectedTime,
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
      _updateNotifier();
    }
  }

  void _updateNotifier() {
    ref.read(alarmWizardNotifierProvider.notifier).updateSchedule(
          _selectedTime.hour,
          _selectedTime.minute,
          _selectedDays,
        );
  }

  void _setShortcutDays(String type) {
    setState(() {
      if (type == 'all') {
        _selectedDays = List.filled(7, true);
      } else if (type == 'weekdays') {
        // Seg a Sex = true (index 1 to 5)
        _selectedDays = [false, true, true, true, true, true, false];
      } else if (type == 'weekends') {
        // Sáb e Dom = true (index 0 and 6)
        _selectedDays = [true, false, false, false, false, false, true];
      }
    });
    _updateNotifier();
  }

  void _setShortcutTime(String timeStr) {
    if (timeStr.isEmpty) return;
    try {
      final parts = timeStr.split(':');
      if (parts.length == 2) {
        final h = int.parse(parts[0]);
        final m = int.parse(parts[1]);
        setState(() {
          _selectedTime = TimeOfDay(hour: h, minute: m);
        });
        _updateNotifier();
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseProvider);

    return StreamBuilder<Setting?>(
      stream: db.select(db.settings).watchSingleOrNull(),
      builder: (context, snapshot) {
        final settings = snapshot.data;
        final breakfast = settings?.breakfastTime ?? '08:00';
        final lunch = settings?.lunchTime ?? '12:00';
        final dinner = settings?.dinnerTime ?? '20:00';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Qual o horário e dias da semana?',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),

            // Time Selection Card
            GestureDetector(
              onTap: () => _selectTime(context),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.access_time_rounded, color: AppColors.primary, size: 28),
                        const SizedBox(width: 12),
                        const Text(
                          'Horário do Alarme',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    Text(
                      _selectedTime.format(context),
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Time Shortcuts
            Text(
              'Atalhos de Horário',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _ShortcutButton(
                    label: 'Café ($breakfast)',
                    onTap: () => _shortcutAction(breakfast),
                  ),
                  const SizedBox(width: 8),
                  _ShortcutButton(
                    label: 'Almoço ($lunch)',
                    onTap: () => _shortcutAction(lunch),
                  ),
                  const SizedBox(width: 8),
                  _ShortcutButton(
                    label: 'Jantar ($dinner)',
                    onTap: () => _shortcutAction(dinner),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Weekdays Toggle
            const Text(
              'Repetir nos dias da semana',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(7, (index) {
                final isSelected = _selectedDays[index];
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedDays[index] = !isSelected;
                    });
                    _updateNotifier();
                  },
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : AppColors.surface,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? AppColors.primary : AppColors.border,
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        _weekdayLabels[index],
                        style: TextStyle(
                          color: isSelected ? Colors.white : AppColors.textMuted,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),

            // Weekday Shortcuts
            Row(
              children: [
                _ShortcutButton(
                  label: 'Todos os dias',
                  onTap: () => _setShortcutDays('all'),
                ),
                const SizedBox(width: 8),
                _ShortcutButton(
                  label: 'Segunda a Sexta',
                  onTap: () => _setShortcutDays('weekdays'),
                ),
                const SizedBox(width: 8),
                _ShortcutButton(
                  label: 'Finais de semana',
                  onTap: () => _setShortcutDays('weekends'),
                ),
              ],
            ),

            const Spacer(),
            ElevatedButton(
              onPressed: () {
                _updateNotifier();
                widget.onNext();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text(
                'Avançar',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  void _shortcutAction(String time) {
    _setShortcutTime(time);
  }
}

class _ShortcutButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _ShortcutButton({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      onPressed: onTap,
      label: Text(label),
      backgroundColor: AppColors.surface,
      side: BorderSide(color: AppColors.border),
      labelStyle: const TextStyle(fontSize: 12, color: Colors.white),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
    );
  }
}
