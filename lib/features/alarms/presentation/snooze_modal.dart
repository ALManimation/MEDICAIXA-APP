import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/presentation/widgets/standard_stepper.dart';
import '../data/alarm_model.dart';
import 'widgets/dynamic_dose_dialog.dart';

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
  final Future<void> Function(double? customQty) onMarkTaken;
  final Future<void> Function() onMarkSkipped;
  final Future<void> Function(int minutes) onSnooze;
  final Future<void> Function() onCancelSnooze;
  final Future<void> Function(bool enabled) onToggle;
  final VoidCallback onEdit;
  final Future<void> Function() onDelete;

  const SnoozeModal({
    super.key,
    required this.alarm,
    required this.onMarkTaken,
    required this.onMarkSkipped,
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
    required Future<void> Function(double? customQty) onMarkTaken,
    required Future<void> Function() onMarkSkipped,
    required Future<void> Function(int minutes) onSnooze,
    required Future<void> Function() onCancelSnooze,
    required Future<void> Function(bool enabled) onToggle,
    required VoidCallback onEdit,
    required Future<void> Function() onDelete,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SnoozeModal(
        alarm: alarm,
        onMarkTaken: onMarkTaken,
        onMarkSkipped: onMarkSkipped,
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
  late double _qty;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final wday = now.weekday % 7;
    final hasAsymmetric = widget.alarm.daysQuantity.any((q) => q > 0);
    _qty = (hasAsymmetric && wday < widget.alarm.daysQuantity.length && widget.alarm.daysQuantity[wday] > 0)
        ? widget.alarm.daysQuantity[wday]
        : widget.alarm.quantity;
  }

  String _formatType(String type) {
    switch (type.toLowerCase()) {
      case 'comprimido':
        return t('med_type_tablet_short');
      case 'capsula':
        return t('med_type_capsule_short');
      case 'gota':
        return t('med_type_drops_short');
      case 'xarope':
        return 'ml';
      case 'adesivo':
        return t('med_type_patch_short');
      case 'injetavel':
        return t('med_type_injection_short');
      default:
        return t('med_type_dose_short');
    }
  }

  @override
  Widget build(BuildContext context) {
    final alarmColor = AppColors.getAlarmColor(widget.alarm.color);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        24,
        16,
        24,
        32,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
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
            t('alarm_manage_title'),
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
                widget.alarm.enabled ? t('deactivate_alarm') : t('activate_alarm'),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
          
          // Action Buttons: Tomei and Pular (only if not PRN)
          if (widget.alarm.isPrn != true) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      double? qty;
                      if (widget.alarm.isDynamic == true) {
                        qty = await DynamicDoseDialog.show(context, widget.alarm);
                        if (qty == null) return; // User cancelled
                      } else {
                        qty = _qty;
                      }
                      await widget.onMarkTaken(qty);
                      if (context.mounted) Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.check_circle_outline_rounded, size: 20),
                    label: Text(t('snooze_taken_btn'), style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await widget.onMarkSkipped();
                      if (context.mounted) Navigator.pop(context);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.missed,
                      side: BorderSide(color: AppColors.missed.withValues(alpha: 0.5)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.cancel_outlined, size: 20),
                    label: Text(t('snooze_skip_btn'), style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Custom Quantity field (or Dynamic Dose indicator)
            if (widget.alarm.isDynamic == true) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(26), // 0.1 of 255
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.primary.withAlpha(76)), // 0.3 of 255
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        t('snooze_dynamic_dose_desc'),
                        style: TextStyle(color: AppColors.text, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        t('snooze_qty_to_take'),
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.text),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatType(widget.alarm.type),
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  StandardStepper(
                    value: _qty,
                    onChanged: (v) {
                      setState(() {
                        _qty = v;
                      });
                    },
                    min: 0.5,
                    max: 50.0,
                    step: 0.5,
                    hasFractionButton: widget.alarm.type == 'comprimido',
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Divider(color: AppColors.border),
          ],

          const SizedBox(height: 20),

          // Snooze controls
          Text(
            t('snooze_snooze_for'),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 8),

          // Stepper: - [value] +
          StandardStepper(
            value: _snoozeMinutes.toDouble(),
            onChanged: (v) {
              setState(() {
                _snoozeMinutes = v.toInt();
              });
            },
            min: 10,
            max: 60,
            step: 10,
          ),
          Text(
            t('snooze_minutes_label'),
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
              child: Text(t('snooze_btn'), style: const TextStyle(fontWeight: FontWeight.w700)),
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
                child: Text(t('cancel_snooze_btn'),
                    style: const TextStyle(fontWeight: FontWeight.w700)),
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
                  label: Text(t('edit_btn'),
                      style: const TextStyle(fontWeight: FontWeight.w600)),
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
                        title: Text(t('snooze_delete_alarm_title'),
                            style: TextStyle(color: AppColors.text)),
                        content: Text(t('snooze_delete_alarm_confirm', [widget.alarm.name]),
                            style: TextStyle(color: AppColors.textMuted)),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: Text(t('snooze_cancel_action')),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.missed,
                            ),
                            child: Text(t('snooze_delete_action')),
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
                  label: Text(t('snooze_delete_action'),
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
          SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
        ],
      ),
      ),
      ),
    );
  }
}


