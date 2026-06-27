import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

/// Weekly adherence rhythm widget for the sidebar.
/// Replicates renderStats() from index.html (lines 1742-1782).
///
/// Displays:
/// - A circular progress indicator with adherence percentage
/// - 7 vertical bars for each day of the week
class WeeklyRhythmWidget extends StatelessWidget {
  /// Map of day stats: key = day index (0=oldest..6=today),
  /// value = (taken, expected) tuple.
  final List<DayStat> weekStats;
  final int adherencePercent;

  const WeeklyRhythmWidget({
    super.key,
    required this.weekStats,
    required this.adherencePercent,
  });

  @override
  Widget build(BuildContext context) {
    // Adherence color
    final Color adherenceColor;
    if (adherencePercent >= 80) {
      adherenceColor = AppColors.success;
    } else if (adherencePercent >= 50) {
      adherenceColor = AppColors.pending;
    } else {
      adherenceColor = AppColors.missed;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Section title
          Row(
            children: [
              Icon(Icons.bar_chart_rounded, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Ritmo Semanal',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Adherence circle
          SizedBox(
            width: 120,
            height: 120,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 120,
                  height: 120,
                  child: CircularProgressIndicator(
                    value: adherencePercent / 100.0,
                    strokeWidth: 8,
                    backgroundColor: AppColors.border,
                    valueColor: AlwaysStoppedAnimation<Color>(adherenceColor),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$adherencePercent%',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: adherenceColor,
                      ),
                    ),
                    Text(
                      'Adesão',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Day bars
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: weekStats.map((stat) {
              final double heightPct;
              final Color barColor;

              if (stat.expected == 0) {
                heightPct = 0.05; // Minimal bar for no-data days
                barColor = AppColors.border;
              } else {
                heightPct = (stat.taken / stat.expected).clamp(0.1, 1.0);
                barColor = stat.taken == stat.expected
                    ? AppColors.success
                    : AppColors.missed;
              }

              return Column(
                children: [
                  SizedBox(
                    height: 60,
                    width: 12,
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.easeOut,
                        width: 12,
                        height: 60 * heightPct,
                        decoration: BoxDecoration(
                          color: barColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    stat.dayLabel,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

/// Statistics for a single day.
class DayStat {
  final String dayLabel; // 'D', 'S', 'T', 'Q', 'Q', 'S', 'S'
  final int taken;
  final int expected;

  const DayStat({
    required this.dayLabel,
    required this.taken,
    required this.expected,
  });
}
