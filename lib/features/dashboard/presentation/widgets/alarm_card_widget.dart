import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../alarms/data/alarm_model.dart';
import '../../../alarms/data/alarm_repository.dart';
import '../dashboard_notifier.dart';

/// Alarm card widget that replicates the pill-card from the Web UI.
///
/// Layout: [pill-icon circle] [pill-info column: time + badge, name + dosage, details]
/// With border-left colored by alarm color.
/// Status: taken (opacity), paused (opacity), snoozed (badge).
class AlarmCardWidget extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final alarmColor = alarm.isGhost ? Colors.grey : AppColors.getAlarmColor(alarm.color);
    final now = DateTime.now();

    // --- Determine status (replicates renderPillGroup logic) ---
    final nowEpoch = now.millisecondsSinceEpoch ~/ 1000;
    final isPaused = alarm.pauseUntil != null &&
        alarm.pauseUntil != 0 &&
        (alarm.pauseUntil == -1 || alarm.pauseUntil! > nowEpoch);
    final isTaken = alarm.lastStatus == 'Tomado';
    final isMissed = alarm.lastStatus == 'Não Tomado' || alarm.lastStatus == 'Perdido';
    final isSnoozed = alarm.snoozeMin > 0;

    // --- Badge ---
    String? badgeText;
    Color? badgeBg;
    Color? badgeTextColor;

    if (alarm.isGhost) {
      badgeText = t('badge_deleted');
      badgeBg = const Color(0xFF374151); // Dark grey
      badgeTextColor = const Color(0xFFD1D5DB); // Light grey
    } else if (isPaused) {
      if (alarm.pauseUntil == -1) {
        badgeText = t('badge_paused_indefinite');
      } else {
        final pDate = DateTime.fromMillisecondsSinceEpoch(alarm.pauseUntil! * 1000);
        final datePart = '${pDate.day.toString().padLeft(2, '0')}/${pDate.month.toString().padLeft(2, '0')}';
        badgeText = t('badge_paused_until', [datePart]);
      }
      badgeBg = const Color(0xFF7F1D1D);
      badgeTextColor = const Color(0xFFFCA5A5);
    } else if (!alarm.active) {
      badgeText = t('badge_inactive');
      badgeBg = AppColors.background;
      badgeTextColor = AppColors.textMuted;
    } else if (isTaken) {
      badgeText = t('badge_taken');
      badgeBg = const Color(0xFF064E3B);
      badgeTextColor = const Color(0xFF6EE7B7);
    } else if (isMissed) {
      badgeText = t('badge_missed');
      badgeBg = const Color(0xFF450A0A);
      badgeTextColor = const Color(0xFFFCA5A5);
    } else if (isSnoozed) {
      badgeText = t('badge_snoozed');
      badgeBg = const Color(0xFF422006);
      badgeTextColor = const Color(0xFFFBBF24);
    }

    // --- Time display ---
    final origTime =
        '${alarm.hour.toString().padLeft(2, '0')}:${alarm.minute.toString().padLeft(2, '0')}';
    String mainTime;
    String? snoozeInfo;

    if (alarm.isPrn == true) {
      mainTime = t('alarm_freq_prn');
    } else if (isSnoozed) {
      final effMins = (alarm.hour * 60 + alarm.minute + alarm.snoozeMin) % 1440;
      final effH = (effMins ~/ 60).toString().padLeft(2, '0');
      final effM = (effMins % 60).toString().padLeft(2, '0');
      mainTime = '$effH:$effM';
      snoozeInfo = t('snoozed_time_info', [origTime, alarm.snoozeMin]);
    } else {
      mainTime = origTime;
    }


    // --- Card opacity ---
    final double cardOpacity = (isTaken || isPaused || alarm.isGhost || !alarm.enabled) ? 0.55 : 1.0;

    // --- Icon background: green = recurring, blue = dated ---
    final isDated = alarm.startDate != null &&
        alarm.startDate!.isNotEmpty &&
        alarm.durationDays > 0;
    final typeBg = alarm.isGhost
        ? Colors.grey.withValues(alpha: 0.2)
        : (isDated
            ? const Color(0xFF3B82F6).withValues(alpha: 0.5)
            : const Color(0xFF22C55E).withValues(alpha: 0.5));

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
                      _buildDetailsRow(context, ref),
                      if (alarm.isPrn == true) ...[
                        const SizedBox(height: 8),
                        _buildPrnActionButton(context, ref),
                      ],
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
  Widget _buildDetailsRow(BuildContext context, WidgetRef ref) {
    final parts = <InlineSpan>[];

    // Type + quantity
    final qtyToShow = _getCurrentQuantity(ref);
    parts.add(TextSpan(
      text: '${_formatQuantity(qtyToShow)} ${_formatType(alarm.type)}',
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

    // Dose number / Dose total
    if (alarm.doseNum != null) {
      final doseTotalStr = alarm.doseTotal != null ? '/${alarm.doseTotal}' : '';
      parts.add(TextSpan(
        text: t('dose_info_fmt', [alarm.doseNum, doseTotalStr]),
        style: const TextStyle(fontSize: 12, color: Color(0xFFE67E22), fontWeight: FontWeight.w600),
      ));
    }

    // Cycle badge
    if (alarm.cycleOnDays != null && alarm.cycleOnDays! > 0) {
      final cycleText = alarm.cycleIsPaused == true
          ? t('cycle_paused')
          : t('cycle_day_fmt', [alarm.cycleCurrentDay ?? 1, (alarm.cycleOnDays ?? 0) + (alarm.cycleOffDays ?? 0)]);
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
        text: t('taper_stage_fmt', [(alarm.taperCurrentStage ?? 0) + 1, alarm.taperStages!.length]),
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
        text: t('interval_hours_fmt', [alarm.intervalHours]),
        style: TextStyle(fontSize: 12, color: AppColors.textMuted),
      ));
    }

    // Site rotation / requires removal badge
    if (alarm.requiresRemoval == true && alarm.siteRotationList != null && alarm.siteRotationList!.isNotEmpty) {
      final sites = alarm.siteRotationList!.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      if (sites.isNotEmpty) {
        final nextSite = sites[(alarm.currentSiteIndex ?? 0) % sites.length];
        parts.add(TextSpan(
          text: t('next_site_rotation', [nextSite]),
          style: TextStyle(fontSize: 12, color: AppColors.textMuted.withValues(alpha: 0.8)),
        ));
      }
    }

    return RichText(
      text: TextSpan(children: parts),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  // --- Helpers ---

  double _getCurrentQuantity(WidgetRef ref) {
    // Watch or read the selected date from notifier to determine current weekday
    final selectedDate = ref.watch(dashboardNotifierProvider).selectedDate;
    final wday = selectedDate.weekday % 7;
    final hasAsymmetric = alarm.daysQuantity.any((q) => q > 0);
    if (hasAsymmetric && wday < alarm.daysQuantity.length && alarm.daysQuantity[wday] > 0) {
      return alarm.daysQuantity[wday];
    }
    return alarm.quantity;
  }

  String _formatQuantity(double qty) {
    if (qty == qty.toInt()) return qty.toInt().toString();
    return qty.toStringAsFixed(1);
  }

  String _formatType(String type) {
    switch (type.toLowerCase()) {
      case 'comprimido':
        return t('med_type_tablet_short');
      case 'capsula':
        return t('med_type_capsule_short');
      case 'gota':
        return t('med_type_drops_short');
      case 'dose':
      case 'dose liquida':
        return t('med_type_dose_short');
      case 'adesivo':
        return t('med_type_patch_short');
      case 'injecao':
        return t('med_type_injection_short');
      case 'inalacao':
        return t('med_type_inhalation_short');
      case 'supositorio':
        return t('med_type_suppos_short');
      default:
        return type;
    }
  }

  String _formatFrequency(AlarmModel alarm) {
    if (alarm.startDate != null && alarm.startDate!.isNotEmpty && alarm.durationDays > 0) {
      return t('duration_days_fmt', [alarm.durationDays]);
    }
    final activeDays = alarm.days.where((d) => d).length;
    if (activeDays == 7) return t('freq_daily_label');
    if (activeDays == 5 &&
        alarm.days[1] &&
        alarm.days[2] &&
        alarm.days[3] &&
        alarm.days[4] &&
        alarm.days[5]) {
      return t('freq_weekdays_short');
    }
    final names = [
      t('day_sun'),
      t('day_mon'),
      t('day_tue'),
      t('day_wed'),
      t('day_thu'),
      t('day_fri'),
      t('day_sat'),
    ];
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
        return '⚡ ${t('spec_empty_stomach_short')}';
      case 'with_food':
        return '🍽️ ${t('spec_with_food_short')}';
      case 'sublingual':
        return t('spec_sublingual_short');
      case 'before_sleep':
        return t('spec_before_sleep_short');
      case 'after_meal':
        return t('spec_after_meal_short');
      case 'with_water':
        return t('spec_with_water_short');
      default:
        return key;
    }
  }

  Widget _buildPrnActionButton(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final todayStr = "${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}";
    int dosesToday = alarm.prnDosesToday ?? 0;
    if (alarm.lastStatusDate != todayStr) {
      dosesToday = 0;
    }

    final limitReached = alarm.prnMaxDailyDoses != null && alarm.prnMaxDailyDoses! > 0 && dosesToday >= alarm.prnMaxDailyDoses!;

    return FutureBuilder<DateTime?>(
      future: ref.read(alarmRepositoryProvider).getLastPrnTakeTime(alarm.id),
      builder: (context, snapshot) {
        final lastTake = snapshot.data;
        int remainingMins = 0;
        if (lastTake != null && alarm.prnMinIntervalHours != null && alarm.prnMinIntervalHours! > 0) {
          final elapsedMs = now.difference(lastTake).inMilliseconds;
          final requiredMs = alarm.prnMinIntervalHours! * 3600 * 1000;
          if (elapsedMs < requiredMs) {
            remainingMins = ((requiredMs - elapsedMs) / 60000).ceil();
          }
        }

        final bool canTake = !limitReached && remainingMins == 0;

        String btnText = t('prn_take_now');
        if (limitReached) {
          btnText = t('prn_limit_reached_fmt', [dosesToday, alarm.prnMaxDailyDoses]);
        } else if (remainingMins > 0) {
          final waitStr = remainingMins > 60 ? '~${(remainingMins/60).ceil()}h' : '${remainingMins}min';
          btnText = t('prn_wait_fmt', [waitStr]);
        }

        return SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: canTake ? onMarkTaken : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: canTake ? const Color(0xFF3B82F6) : AppColors.surface,
              disabledBackgroundColor: AppColors.surface.withValues(alpha: 0.5),
              foregroundColor: Colors.white,
              disabledForegroundColor: AppColors.textMuted,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(
                  color: canTake ? Colors.transparent : AppColors.border.withValues(alpha: 0.5),
                ),
              ),
              padding: const EdgeInsets.symmetric(vertical: 6),
            ),
            child: Text(btnText, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          ),
        );
      },
    );
  }
}
