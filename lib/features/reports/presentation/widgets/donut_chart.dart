import 'dart:math';
import 'package:flutter/material.dart';
import 'package:medicaixa_app/core/constants/app_colors.dart';
import 'package:medicaixa_app/core/localization/app_localizations.dart';

class DonutChartPainter extends CustomPainter {
  final double takenPct;
  final double missedPct;
  final double skippedPct;

  DonutChartPainter({
    required this.takenPct,
    required this.missedPct,
    required this.skippedPct,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2;
    final strokeWidth = radius * 0.25;
    final drawRadius = radius - strokeWidth / 2;

    final paintBg = Paint()
      ..color = const Color(0xFF374151) // Dark grey border track
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, drawRadius, paintBg);

    double startAngle = -pi / 2;

    final total = takenPct + missedPct + skippedPct;
    if (total == 0) return;

    final takenAngle = (takenPct / total) * 2 * pi;
    final missedAngle = (missedPct / total) * 2 * pi;
    final skippedAngle = (skippedPct / total) * 2 * pi;

    final rect = Rect.fromCircle(center: center, radius: drawRadius);

    if (takenPct > 0) {
      final paintTaken = Paint()
        ..color = const Color(0xFF10B981) // Green success
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.square;
      canvas.drawArc(rect, startAngle, takenAngle, false, paintTaken);
      startAngle += takenAngle;
    }

    if (missedPct > 0) {
      final paintMissed = Paint()
        ..color = const Color(0xFFEF4444) // Red missed
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.square;
      canvas.drawArc(rect, startAngle, missedAngle, false, paintMissed);
      startAngle += missedAngle;
    }

    if (skippedPct > 0) {
      final paintSkipped = Paint()
        ..color = const Color(0xFFF59E0B) // Orange skipped
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.square;
      canvas.drawArc(rect, startAngle, skippedAngle, false, paintSkipped);
    }
  }

  @override
  bool shouldRepaint(covariant DonutChartPainter oldDelegate) {
    return oldDelegate.takenPct != takenPct ||
        oldDelegate.missedPct != missedPct ||
        oldDelegate.skippedPct != skippedPct;
  }
}

class DonutChartWidget extends StatelessWidget {
  final int taken;
  final int missed;
  final int skipped;
  final int percentage;

  const DonutChartWidget({
    super.key,
    required this.taken,
    required this.missed,
    required this.skipped,
    required this.percentage,
  });

  @override
  Widget build(BuildContext context) {
    final double total = (taken + missed + skipped).toDouble();
    final double takenPct = total > 0 ? taken.toDouble() : 0.0;
    final double missedPct = total > 0 ? missed.toDouble() : 0.0;
    final double skippedPct = total > 0 ? skipped.toDouble() : 0.0;

    final Color percentageColor = percentage >= 80
        ? AppColors.success
        : percentage >= 50
            ? AppColors.pending
            : AppColors.missed;

    return Row(
      children: [
        SizedBox(
          width: 120,
          height: 120,
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: DonutChartPainter(
                    takenPct: takenPct,
                    missedPct: missedPct,
                    skippedPct: skippedPct,
                  ),
                ),
              ),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$percentage%',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: percentageColor,
                      ),
                    ),
                    Text(
                      t('stats_adherence_label'),
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLegendItem(t('stats_taken'), taken, AppColors.success),
              const SizedBox(height: 8),
              _buildLegendItem(t('stats_missed'), missed, AppColors.missed),
              const SizedBox(height: 8),
              _buildLegendItem(t('stats_skipped'), skipped, AppColors.pending),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLegendItem(String label, int value, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: AppColors.text, fontSize: 13),
          ),
        ),
        Text(
          value.toString(),
          style: TextStyle(color: AppColors.text, fontSize: 13, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
