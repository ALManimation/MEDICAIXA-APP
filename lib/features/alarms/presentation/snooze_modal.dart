import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../data/alarm_model.dart';

/// Bottom sheet modal for managing an alarm.
/// Replicates the openSnoozeModal() from index.html (lines 1414-1435).
///
/// Features:
/// - Alarm name display
/// - Activate/Deactivate toggle
/// - Snooze controls (+/- minutes, 10-60 range, step 10)
/// - Cancel snooze (if active)
/// - Edit and Delete buttons
class SnoozeModal extends StatefulWidget {
  final AlarmModel alarm;
  final Future<void> Function(int minutes) onSnooze;
  final Future<void> Function() onCancelSnooze;
  final Future<void> Function(bool enabled) onToggle;
  final VoidCallback onEdit;
  final Future<void> Function() onDelete;

  const SnoozeModal({
    super.key,
    required this.alarm,
    required this.onSnooze,
    required this.onCancelSnooze,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  /// Shows this modal as a bottom sheet.
  static Future<void> show(
    BuildContext context, {
    required AlarmModel alarm,
    required Future<void> Function(int minutes) onSnooze,
    required Future<void> Function() onCancelSnooze,
    required Future<void> Function(bool enabled) onToggle,
    required VoidCallback onEdit,
    required Future<void> Function() onDelete,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SnoozeModal(
        alarm: alarm,
        onSnooze: onSnooze,
        onCancelSnooze: onCancelSnooze,
        onToggle: onToggle,
        onEdit: onEdit,
        onDelete: onDelete,
      ),
    );
  }

  @override
  State<SnoozeModal> createState() => _SnoozeModalState();
}

class _SnoozeModalState extends State<SnoozeModal> {
  int _snoozeMinutes = 10;

  @override
  Widget build(BuildContext context) {
    final alarmColor = AppColors.getAlarmColor(widget.alarm.color);

    return Padding(
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

          // Title
          Text(
            'Gerenciar Alarme',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 16),

          // Medication name with color indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: alarmColor,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                widget.alarm.name,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Toggle active/inactive
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                await widget.onToggle(!widget.alarm.enabled);
                if (context.mounted) Navigator.pop(context);
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: widget.alarm.enabled
                    ? AppColors.missed
                    : AppColors.success,
                side: BorderSide(
                  color: widget.alarm.enabled
                      ? AppColors.missed.withValues(alpha: 0.5)
                      : AppColors.success.withValues(alpha: 0.5),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: Icon(
                widget.alarm.enabled
                    ? Icons.pause_circle_outline_rounded
                    : Icons.play_circle_outline_rounded,
                size: 20,
              ),
              label: Text(
                widget.alarm.enabled ? 'Desativar Alarme' : 'Ativar Alarme',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Snooze controls
          Text(
            'Adiar por:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 8),

          // Stepper: - [value] +
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _StepperButton(
                icon: Icons.remove,
                onPressed: _snoozeMinutes > 10
                    ? () => setState(() => _snoozeMinutes -= 10)
                    : null,
              ),
              Container(
                width: 60,
                alignment: Alignment.center,
                child: Text(
                  '$_snoozeMinutes',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.text,
                  ),
                ),
              ),
              _StepperButton(
                icon: Icons.add,
                onPressed: _snoozeMinutes < 60
                    ? () => setState(() => _snoozeMinutes += 10)
                    : null,
              ),
            ],
          ),
          Text(
            'minutos',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          const SizedBox(height: 12),

          // Snooze button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                await widget.onSnooze(_snoozeMinutes);
                if (context.mounted) Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Adiar', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),

          // Cancel snooze (only shown if snooze is active)
          if (widget.alarm.snoozeMin > 0) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  await widget.onCancelSnooze();
                  if (context.mounted) Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.missed,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Cancelar Soneca',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],

          // Divider
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Divider(color: AppColors.border),
          ),

          // Edit + Delete row
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onEdit();
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textMuted,
                    side: BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.edit_rounded, size: 18),
                  label: const Text('Editar',
                      style: TextStyle(fontWeight: FontWeight.w600)),
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
                        title: Text('Excluir Alarme',
                            style: TextStyle(color: AppColors.text)),
                        content: Text('Tem certeza que deseja excluir "${widget.alarm.name}"?',
                            style: TextStyle(color: AppColors.textMuted)),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancelar'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.missed,
                            ),
                            child: const Text('Excluir'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await widget.onDelete();
                      if (context.mounted) Navigator.pop(context);
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.missed,
                    side: BorderSide(color: AppColors.missed.withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.delete_rounded, size: 18),
                  label: const Text('Excluir',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;

  const _StepperButton({required this.icon, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceVariant,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          child: Icon(
            icon,
            color: onPressed != null ? AppColors.text : AppColors.border,
            size: 22,
          ),
        ),
      ),
    );
  }
}
