import 'package:flutter/material.dart';
import 'package:medicaixa_app/core/constants/app_colors.dart';
import 'package:medicaixa_app/features/reports/presentation/reports_notifier.dart';
import 'package:medicaixa_app/core/localization/app_localizations.dart';

class MedicationPerformanceWidget extends StatelessWidget {
  final List<MedicationPerformanceData> performanceData;

  const MedicationPerformanceWidget({
    super.key,
    required this.performanceData,
  });

  @override
  Widget build(BuildContext context) {
    if (performanceData.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24.0),
          child: Text(
            t('stats_med_no_data_short'),
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
        ),
      );
    }

    return Column(
      children: performanceData.map((data) {
        final Color medColor = AppColors.getAlarmColor(data.colorHex);

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Text(
                  data.name,
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 5,
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: const Color(0xFF374151), // Grey background track
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: (data.percentage / 100.0).clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: medColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 40,
                child: Text(
                  '${data.percentage}%',
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
