import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medicaixa_app/core/constants/app_colors.dart';
import 'package:medicaixa_app/features/reports/presentation/reports_notifier.dart';
import 'package:medicaixa_app/core/localization/app_localizations.dart';
import 'package:medicaixa_app/core/providers/locale_provider.dart';

class MonthlyHeatmapWidget extends ConsumerWidget {
  final List<HeatmapCellData> cells;

  const MonthlyHeatmapWidget({
    super.key,
    required this.cells,
  });

  Color _getLevelColor(HeatmapLevel level) {
    switch (level) {
      case HeatmapLevel.level5:
        return const Color(0xFF22C55E); // Bright Green
      case HeatmapLevel.level4:
        return const Color(0xFF16A34A); // Green
      case HeatmapLevel.level3:
        return const Color(0xFFCA8A04); // Yellow/Orange
      case HeatmapLevel.level2:
        return const Color(0xFFC2410C); // Dark Orange
      case HeatmapLevel.level1:
        return const Color(0xFF991B1B); // Red/Dark Red
      case HeatmapLevel.level0:
        return AppColors.surfaceVariant;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(appLocaleProvider); // watch to rebuild on locale changes

    if (cells.isEmpty) {
      return const SizedBox.shrink();
    }

    final List<String> headers = [
      t('day_initial_sunday'),
      t('day_initial_monday'),
      t('day_initial_tuesday'),
      t('day_initial_wednesday'),
      t('day_initial_thursday'),
      t('day_initial_friday'),
      t('day_initial_saturday'),
    ];

    // Group cells into weeks (7 days each)
    final List<List<HeatmapCellData>> weeks = [];
    for (int i = 0; i < cells.length; i += 7) {
      if (i + 7 <= cells.length) {
        weeks.add(cells.sublist(i, i + 7));
      } else {
        weeks.add(cells.sublist(i));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header Row
        Row(
          children: [
            const SizedBox(
              width: 50,
              child: Center(
                child: Text(''),
              ),
            ),
            ...headers.map((h) => Expanded(
              child: Center(
                child: Text(
                  h,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            )),
          ],
        ),
        const SizedBox(height: 8),
        // Week Rows
        ...weeks.map((week) {
          final sunday = week.first.date;
          final sundayLabel = '${sunday.day.toString().padLeft(2, '0')}/${sunday.month.toString().padLeft(2, '0')}';

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Row(
              children: [
                SizedBox(
                  width: 50,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      sundayLabel,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ),
                ...week.map((cell) {
                  return Expanded(
                    child: Center(
                      child: Tooltip(
                        message: cell.isFuture
                            ? t('reports_heatmap_future')
                            : '${cell.percentage}% (${cell.expectedCount} ${cell.expectedCount == 1 ? t('reports_heatmap_alarms_singular') : t('reports_heatmap_alarms_plural')})',
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: cell.isFuture ? Colors.transparent : _getLevelColor(cell.level),
                            borderRadius: BorderRadius.circular(6),
                            border: cell.isToday
                                ? Border.all(color: AppColors.primary, width: 2)
                                : Border.all(color: Colors.transparent, width: 2),
                          ),
                          child: Center(
                            child: Text(
                              cell.dayOfMonth.toString(),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: cell.isToday ? FontWeight.bold : FontWeight.normal,
                                color: cell.isFuture
                                    ? AppColors.textMuted.withValues(alpha: 0.4)
                                    : (cell.level == HeatmapLevel.level0 ? AppColors.text : Colors.white),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
                // Pad if partial week
                if (week.length < 7)
                  ...List.generate(7 - week.length, (_) => const Expanded(child: SizedBox.shrink())),
              ],
            ),
          );
        }),
        const SizedBox(height: 16),
        // Legend Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(
                  '0%',
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
                const SizedBox(width: 4),
                Row(
                  children: [
                    _buildLegendScaleCell(HeatmapLevel.level1),
                    _buildLegendScaleCell(HeatmapLevel.level2),
                    _buildLegendScaleCell(HeatmapLevel.level3),
                    _buildLegendScaleCell(HeatmapLevel.level4),
                    _buildLegendScaleCell(HeatmapLevel.level5),
                  ],
                ),
                const SizedBox(width: 4),
                Text(
                  '100%',
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
              ],
            ),
            Row(
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: _getLevelColor(HeatmapLevel.level0),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  t('stats_no_data'),
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLegendScaleCell(HeatmapLevel level) {
    return Container(
      width: 14,
      height: 14,
      margin: const EdgeInsets.symmetric(horizontal: 1),
      decoration: BoxDecoration(
        color: _getLevelColor(level),
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}
