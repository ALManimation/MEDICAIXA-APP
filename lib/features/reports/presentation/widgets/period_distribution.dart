import 'dart:math';
import 'package:flutter/material.dart';
import 'package:medicaixa_app/core/constants/app_colors.dart';
import 'package:medicaixa_app/core/localization/app_localizations.dart';

class PeriodBarPainter extends CustomPainter {
  final double percentage;
  final int expectedCount;

  PeriodBarPainter({
    required this.percentage,
    required this.expectedCount,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw background track
    final paintTrack = Paint()
      ..color = const Color(0xFF374151) // Grey border track
      ..style = PaintingStyle.fill;
    
    final trackRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(8),
    );
    canvas.drawRRect(trackRRect, paintTrack);

    if (expectedCount == 0) return;

    // Determine height factor (minimum 10% if expected > 0)
    final double barHeightFactor = (max(10.0, percentage) / 100.0).clamp(0.0, 1.0);
    final double barHeight = size.height * barHeightFactor;

    // Determine color based on compliance ranges
    final Color barColor = percentage >= 80
        ? const Color(0xFF10B981) // Green success
        : percentage >= 50
            ? const Color(0xFFF59E0B) // Orange warning
            : const Color(0xFFEF4444); // Red missed

    final paintFill = Paint()
      ..color = barColor
      ..style = PaintingStyle.fill;

    final fillRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, size.height - barHeight, size.width, barHeight),
      const Radius.circular(8),
    );
    canvas.drawRRect(fillRRect, paintFill);
  }

  @override
  bool shouldRepaint(covariant PeriodBarPainter oldDelegate) {
    return oldDelegate.percentage != percentage || oldDelegate.expectedCount != expectedCount;
  }
}

class PeriodDistributionWidget extends StatelessWidget {
  final double morningPercentage;
  final int morningTaken;
  final int morningExpected;

  final double afternoonPercentage;
  final int afternoonTaken;
  final int afternoonExpected;

  final double nightPercentage;
  final int nightTaken;
  final int nightExpected;

  const PeriodDistributionWidget({
    super.key,
    required this.morningPercentage,
    required this.morningTaken,
    required this.morningExpected,
    required this.afternoonPercentage,
    required this.afternoonTaken,
    required this.afternoonExpected,
    required this.nightPercentage,
    required this.nightTaken,
    required this.nightExpected,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildPeriodColumn(
          icon: Icons.light_mode_rounded,
          iconColor: const Color(0xFFD97706),
          label: t('stats_period_morning'),
          percentage: morningPercentage,
          taken: morningTaken,
          expected: morningExpected,
        ),
        _buildPeriodColumn(
          icon: Icons.wb_sunny_outlined,
          iconColor: const Color(0xFF2563EB),
          label: t('stats_period_afternoon'),
          percentage: afternoonPercentage,
          taken: afternoonTaken,
          expected: afternoonExpected,
        ),
        _buildPeriodColumn(
          icon: Icons.dark_mode_rounded,
          iconColor: const Color(0xFF4B5563),
          label: t('stats_period_night'),
          percentage: nightPercentage,
          taken: nightTaken,
          expected: nightExpected,
        ),
      ],
    );
  }

  Widget _buildPeriodColumn({
    required IconData icon,
    required Color iconColor,
    required String label,
    required double percentage,
    required int taken,
    required int expected,
  }) {
    return Column(
      children: [
        Icon(icon, color: iconColor, size: 24),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 100,
          width: 16,
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: PeriodBarPainter(
                    percentage: percentage,
                    expectedCount: expected,
                  ),
                ),
              ),
              if (expected > 0)
                Positioned(
                  top: 4,
                  child: Text(
                    '${percentage.round()}%',
                    style: const TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '$taken/$expected',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: AppColors.text,
          ),
        ),
      ],
    );
  }
}
