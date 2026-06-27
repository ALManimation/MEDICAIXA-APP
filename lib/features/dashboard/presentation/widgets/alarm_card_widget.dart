import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../alarms/data/alarm_model.dart';

/// Alarm card widget that replicates the pill-card from the Web UI.
///
/// Layout: [pill-icon circle] [pill-info column: time + badge, name + dosage, details]
/// With border-left colored by alarm color.
/// Status: taken (opacity), paused (opacity), snoozed (badge).
class AlarmCardWidget extends StatelessWidget {
  final AlarmModel alarm;
  final VoidCallback onMarkTaken;
  final VoidCallback onMarkSkipped;
  final Function(bool) onToggleEnabled;
  final VoidCallback? onTap;

  const AlarmCardWidget({
    super.key,
    required this.alarm,
    required this.onMarkTaken,
    required this.onMarkSkipped,
    required this.onToggleEnabled,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final alarmColor = AppColors.getAlarmColor(alarm.color);
    final now = DateTime.now();
    final todayStr =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';

    // --- Determine status (replicates renderPillGroup logic) ---
    final nowEpoch = now.millisecondsSinceEpoch ~/ 1000;
    final isPaused = alarm.pauseUntil != null &&
        alarm.pauseUntil != 0 &&
        (alarm.pauseUntil == -1 || alarm.pauseUntil! > nowEpoch);
    final isTaken =
        alarm.lastStatus == 'Tomado' && alarm.lastStatusDate == todayStr;
    final isMissed =
        (alarm.lastStatus == 'Não Tomado' || alarm.lastStatus == 'Perdido') &&
            alarm.lastStatusDate == todayStr;
    final isSnoozed = alarm.snoozeMin > 0;

    // --- Badge ---
    String? badgeText;
    Color? badgeBg;
    Color? badgeTextColor;

    if (isPaused) {
      if (alarm.pauseUntil == -1) {
        badgeText = 'Suspenso';
      } else {
        final pDate = DateTime.fromMillisecondsSinceEpoch(alarm.pauseUntil! * 1000);
        badgeText = 'Suspenso até ${pDate.day.toString().padLeft(2, '0')}/${pDate.month.toString().padLeft(2, '0')}';
      }
      badgeBg = const Color(0xFF7F1D1D);
      badgeTextColor = const Color(0xFFFCA5A5);
    } else if (!alarm.active) {
      badgeText = 'Inativo';
      badgeBg = AppColors.background;
      badgeTextColor = AppColors.textMuted;
    } else if (isTaken) {
      badgeText = 'Tomado';
      badgeBg = const Color(0xFF064E3B);
      badgeTextColor = const Color(0xFF6EE7B7);
    } else if (isMissed) {
      badgeText = 'Perdido';
      badgeBg = const Color(0xFF450A0A);
      badgeTextColor = const Color(0xFFFCA5A5);
    } else if (isSnoozed) {
      badgeText = 'Adiado';
      badgeBg = const Color(0xFF422006);
      badgeTextColor = const Color(0xFFFBBF24);
    }

    // --- Time display ---
    final origTime =
        '${alarm.hour.toString().padLeft(2, '0')}:${alarm.minute.toString().padLeft(2, '0')}';
    String mainTime;
    String? snoozeInfo;

    if (alarm.isPrn == true) {
      mainTime = 'Sob Demanda';
    } else if (isSnoozed) {
      final effMins = (alarm.hour * 60 + alarm.minute + alarm.snoozeMin) % 1440;
      final effH = (effMins ~/ 60).toString().padLeft(2, '0');
      final effM = (effMins % 60).toString().padLeft(2, '0');
      mainTime = '$effH:$effM';
      snoozeInfo = '$origTime (+${alarm.snoozeMin}min)';
    } else {
      mainTime = origTime;
    }

    // --- Details ---
    final typeStr = '${_formatQuantity(alarm.quantity)} ${_formatType(alarm.type)}';
    final freqStr = _formatFrequency(alarm);

    // --- Card opacity ---
    final double cardOpacity = (isTaken || isPaused) ? 0.55 : 1.0;

    // --- Icon background: green = recurring, blue = dated ---
    final isDated = alarm.startDate != null &&
        alarm.startDate!.isNotEmpty &&
        alarm.durationDays > 0;
    final typeBg = isDated
        ? const Color(0xFF3B82F6).withValues(alpha: 0.5)
        : const Color(0xFF22C55E).withValues(alpha: 0.5);

    return Opacity(
      opacity: cardOpacity,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border(
                left: BorderSide(color: alarmColor, width: 4),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              children: [
                // Pill icon circle
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: typeBg,
                  ),
                  child: Icon(
                    _getTypeIcon(alarm.type),
                    size: 20,
                    color: alarmColor,
                  ),
                ),
                const SizedBox(width: 14),

                // Pill info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top row: time + snooze info + badge
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          // Main time
                          Text(
                            mainTime,
                            style: TextStyle(
                              fontSize: alarm.isPrn == true ? 15 : 20,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.4,
                              color: alarm.isPrn == true
                                  ? const Color(0xFF60A5FA)
                                  : AppColors.text,
                            ),
                          ),
                          if (snoozeInfo != null) ...[
                            const SizedBox(width: 6),
                            Text(
                              snoozeInfo,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                          const Spacer(),
                          // Status badge
                          if (badgeText != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: badgeBg,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                badgeText,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: badgeTextColor,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),

                      // Medication name + dosage
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              alarm.name,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.text,
                                decoration: isTaken
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (alarm.dosage != null &&
                              alarm.dosage!.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Text(
                              alarm.dosage!,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),

                      // Details line: type + frequency + badges
                      _buildDetailsRow(context),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Builds the details row with inline badges for cycle, taper, etc.
  Widget _buildDetailsRow(BuildContext context) {
    final parts = <InlineSpan>[];

    // Type + quantity
    parts.add(TextSpan(
      text: '${_formatQuantity(alarm.quantity)} ${_formatType(alarm.type)}',
      style: TextStyle(fontSize: 12, color: AppColors.textMuted),
    ));

    // Frequency
    final freq = _formatFrequency(alarm);
    if (freq.isNotEmpty) {
      parts.add(TextSpan(
        text: ' · $freq',
        style: TextStyle(fontSize: 12, color: AppColors.textMuted),
      ));
    }

    // Cycle badge
    if (alarm.cycleOnDays != null && alarm.cycleOnDays! > 0) {
      final cycleText = alarm.cycleIsPaused == true
          ? ' · Pausa'
          : ' · Dia ${alarm.cycleCurrentDay ?? 1}/${(alarm.cycleOnDays ?? 0) + (alarm.cycleOffDays ?? 0)}';
      parts.add(TextSpan(
        text: cycleText,
        style: TextStyle(
          fontSize: 12,
          color: alarm.cycleIsPaused == true
              ? AppColors.pending
              : AppColors.success,
        ),
      ));
    }

    // Taper badge
    if (alarm.taperStages != null && alarm.taperStages!.isNotEmpty) {
      parts.add(TextSpan(
        text: ' · Etapa ${(alarm.taperCurrentStage ?? 0) + 1}/${alarm.taperStages!.length}',
        style: const TextStyle(fontSize: 12, color: Color(0xFF9B59B6)),
      ));
    }

    // Special instruction
    if (alarm.specialInstruction != null &&
        alarm.specialInstruction!.isNotEmpty) {
      parts.add(TextSpan(
        text: ' · ${_formatInstruction(alarm.specialInstruction!)}',
        style: TextStyle(fontSize: 12, color: AppColors.textMuted),
      ));
    }

    // Interval hours
    if (alarm.intervalHours != null && alarm.intervalHours! > 0) {
      parts.add(TextSpan(
        text: ' · ${alarm.intervalHours}h em ${alarm.intervalHours}h',
        style: TextStyle(fontSize: 12, color: AppColors.textMuted),
      ));
    }

    return RichText(
      text: TextSpan(children: parts),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  // --- Helpers ---

  String _formatQuantity(double qty) {
    if (qty == qty.toInt()) return qty.toInt().toString();
    return qty.toStringAsFixed(1);
  }

  String _formatType(String type) {
    switch (type.toLowerCase()) {
      case 'comprimido':
        return 'comp.';
      case 'capsula':
        return 'cáps.';
      case 'gota':
        return 'gotas';
      case 'dose':
      case 'dose liquida':
        return 'dose';
      case 'adesivo':
        return 'adesivo';
      case 'injecao':
        return 'injeção';
      case 'inalacao':
        return 'inalação';
      case 'supositorio':
        return 'supos.';
      default:
        return type;
    }
  }

  String _formatFrequency(AlarmModel alarm) {
    if (alarm.startDate != null && alarm.startDate!.isNotEmpty && alarm.durationDays > 0) {
      return '${alarm.durationDays} dias';
    }
    final activeDays = alarm.days.where((d) => d).length;
    if (activeDays == 7) return 'Diário';
    if (activeDays == 5 &&
        alarm.days[1] &&
        alarm.days[2] &&
        alarm.days[3] &&
        alarm.days[4] &&
        alarm.days[5]) {
      return 'Seg-Sex';
    }
    const names = ['D', 'S', 'T', 'Q', 'Q', 'S', 'S'];
    final activeNames = <String>[];
    for (int i = 0; i < 7; i++) {
      if (alarm.days[i]) activeNames.add(names[i]);
    }
    return activeNames.join(', ');
  }

  IconData _getTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'capsula':
        return Icons.medical_services_rounded;
      case 'gota':
        return Icons.opacity_rounded;
      case 'dose':
      case 'dose liquida':
        return Icons.local_drink_rounded;
      case 'adesivo':
        return Icons.healing_rounded;
      case 'injecao':
        return Icons.vaccines_rounded;
      case 'inalacao':
        return Icons.air_rounded;
      case 'comprimido':
      default:
        return Icons.medication_rounded;
    }
  }

  String _formatInstruction(String key) {
    switch (key) {
      case 'empty_stomach':
        return '⚡ Em jejum';
      case 'with_food':
        return '🍽️ Com comida';
      case 'sublingual':
        return '👅 Sublingual';
      case 'before_sleep':
        return '🌙 Antes de dormir';
      case 'after_meal':
        return '🍴 Após refeição';
      case 'with_water':
        return '💧 Com água';
      default:
        return key;
    }
  }
}
