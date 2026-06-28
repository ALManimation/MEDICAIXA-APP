import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medicaixa_app/core/localization/app_localizations.dart';
import 'package:medicaixa_app/core/constants/app_colors.dart';
import 'package:medicaixa_app/features/reports/presentation/reports_notifier.dart';
import 'package:medicaixa_app/features/reports/presentation/widgets/donut_chart.dart';
import 'package:medicaixa_app/features/reports/presentation/widgets/daily_bars.dart';
import 'package:medicaixa_app/features/reports/presentation/widgets/streak_dots.dart';
import 'package:medicaixa_app/features/reports/presentation/widgets/period_distribution.dart';
import 'package:medicaixa_app/features/reports/presentation/widgets/medication_performance.dart';
import 'package:medicaixa_app/features/reports/presentation/widgets/monthly_heatmap.dart';
import 'package:medicaixa_app/features/reports/presentation/widgets/medication_filter_bar.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(reportsNotifierProvider);
    final notifier = ref.read(reportsNotifierProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(t('reports_screen_title')),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Donut Chart Card (Adesão Geral)
                  _buildMetricCard(
                    title: t('reports_general_adherence_7d'),
                    child: DonutChartWidget(
                      taken: state.generalTakenCount,
                      missed: state.generalMissedCount,
                      skipped: state.generalSkippedCount,
                      percentage: state.generalAdherencePercentage,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 2. Daily Bars Card (Adesão Diária)
                  _buildMetricCard(
                    title: t('reports_daily_adherence_7d'),
                    child: DailyBarsWidget(dailyData: state.dailyAdherence),
                  ),
                  const SizedBox(height: 16),

                  // 3. Streak Card (Sequência)
                  _buildMetricCard(
                    title: t('stats_streak_30d'),
                    child: StreakDotsWidget(
                      currentStreak: state.currentStreak,
                      bestStreak: state.bestStreak,
                      dots: state.last14DaysDots,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 4. Period Distribution Card (Por Horário)
                  _buildMetricCard(
                    title: t('reports_period_distribution_7d'),
                    child: PeriodDistributionWidget(
                      morningPercentage: state.morningPercentage,
                      morningTaken: state.morningTaken,
                      morningExpected: state.morningExpected,
                      afternoonPercentage: state.afternoonPercentage,
                      afternoonTaken: state.afternoonTaken,
                      afternoonExpected: state.afternoonExpected,
                      nightPercentage: state.nightPercentage,
                      nightTaken: state.nightTaken,
                      nightExpected: state.nightExpected,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 5. Medication Performance Card (Por Medicamento) - Hidden if filter != 'Todos'
                  if (state.selectedMedication == 'Todos') ...[
                    _buildMetricCard(
                      title: t('reports_med_performance_7d'),
                      child: MedicationPerformanceWidget(
                        performanceData: state.medicationPerformance,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // 6. Monthly Heatmap Card (Mapa Mensal)
                  _buildMetricCard(
                    title: t('reports_adherence_calendar_30d'),
                    child: MonthlyHeatmapWidget(cells: state.heatmapCells),
                  ),
                ],
              ),
            ),
          ),
          // Sticky Filter Bar
          MedicationFilterBar(
            selectedMedication: state.selectedMedication,
            availableMedications: state.availableMedications,
            onSelected: (medName) {
              notifier.setFilter(medName);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({required String title, required Widget child}) {
    return Card(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.border, width: 1), // Non-const due to AppColors reference
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}
