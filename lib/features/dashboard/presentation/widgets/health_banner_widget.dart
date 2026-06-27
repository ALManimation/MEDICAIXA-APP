import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../alarms/data/alarm_model.dart';

/// Health status level based on adherence percentage.
/// Replicates the updateHealthBanner() logic from index.html (lines 1318-1377).
enum HealthLevel { ok, warn, risk, danger }

/// Widget that displays the daily health adherence banner.
/// Shows different colors, icons and messages based on how many
/// due alarms have been taken today.
class HealthBannerWidget extends StatelessWidget {
  final List<AlarmModel> alarms;
  final DateTime currentDate;

  const HealthBannerWidget({
    super.key,
    required this.alarms,
    required this.currentDate,
  });

  @override
  Widget build(BuildContext context) {
    final result = _calculateHealth();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: result.bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: result.borderColor, width: 1.5),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              result.label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: result.textColor,
              ),
            ),
          ),
          Icon(result.icon, color: result.textColor, size: 24),
        ],
      ),
    );
  }

  _HealthResult _calculateHealth() {
    final now = DateTime.now();
    final isToday = currentDate.year == now.year &&
        currentDate.month == now.month &&
        currentDate.day == now.day;

    if (!isToday) {
      return _HealthResult(
        level: HealthLevel.ok,
        label: 'Sua saúde em dia',
        icon: Icons.spa_rounded,
        textColor: AppColors.healthOk,
        bgColor: AppColors.healthOkBg,
        borderColor: AppColors.healthOkBorder,
      );
    }

    final todayMins = now.hour * 60 + now.minute;
    final todayDow = now.weekday % 7; // 0=Sun, 1=Mon...
    final dateFormatted =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';

    int due = 0;
    int taken = 0;

    for (final alarm in alarms) {
      if (!alarm.enabled) continue;

      // Check weekday match
      if (!alarm.days[todayDow]) continue;

      final schedMins = alarm.hour * 60 + alarm.minute;
      if (schedMins > todayMins) continue; // not due yet

      due++;
      if (alarm.lastStatus == 'Tomado' && alarm.lastStatusDate == dateFormatted) {
        taken++;
      }
    }

    if (due == 0) {
      return _HealthResult(
        level: HealthLevel.ok,
        label: 'Sua saúde em dia',
        icon: Icons.spa_rounded,
        textColor: AppColors.healthOk,
        bgColor: AppColors.healthOkBg,
        borderColor: AppColors.healthOkBorder,
      );
    }

    final pct = taken / due;

    if (pct >= 0.9) {
      return _HealthResult(
        level: HealthLevel.ok,
        label: 'Sua saúde está em dia',
        icon: Icons.spa_rounded,
        textColor: AppColors.healthOk,
        bgColor: AppColors.healthOkBg,
        borderColor: AppColors.healthOkBorder,
      );
    } else if (pct >= 0.5) {
      return _HealthResult(
        level: HealthLevel.warn,
        label: 'Sua saúde está em atenção',
        icon: Icons.warning_rounded,
        textColor: AppColors.healthWarn,
        bgColor: AppColors.healthWarnBg,
        borderColor: AppColors.healthWarnBorder,
      );
    } else if (pct >= 0.2) {
      return _HealthResult(
        level: HealthLevel.risk,
        label: 'Sua saúde está em risco',
        icon: Icons.error_rounded,
        textColor: AppColors.healthRisk,
        bgColor: AppColors.healthRiskBg,
        borderColor: AppColors.healthRiskBorder,
      );
    } else {
      return _HealthResult(
        level: HealthLevel.danger,
        label: 'Sua saúde está em alto risco',
        icon: Icons.heart_broken_rounded,
        textColor: AppColors.healthDanger,
        bgColor: AppColors.healthDangerBg,
        borderColor: AppColors.healthDangerBorder,
      );
    }
  }
}

class _HealthResult {
  final HealthLevel level;
  final String label;
  final IconData icon;
  final Color textColor;
  final Color bgColor;
  final Color borderColor;

  const _HealthResult({
    required this.level,
    required this.label,
    required this.icon,
    required this.textColor,
    required this.bgColor,
    required this.borderColor,
  });
}
