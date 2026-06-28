import 'dart:math';
import 'package:flutter/material.dart';
import 'package:medicaixa_app/core/constants/app_colors.dart';
import 'package:medicaixa_app/features/reports/presentation/reports_notifier.dart';

class DailyBarPainter extends CustomPainter {
  final int percentage;
  final int expectedCount;

  DailyBarPainter({
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
    final double pct = percentage.toDouble();
    final double barHeightFactor = (max(10.0, pct) / 100.0).clamp(0.0, 1.0);
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
  bool shouldRepaint(covariant DailyBarPainter oldDelegate) {
    return oldDelegate.percentage != percentage || oldDelegate.expectedCount != expectedCount;
  }
}

class DailyBarsWidget extends StatelessWidget {
  final List<DailyAdherenceData> dailyData;

  const DailyBarsWidget({
    super.key,
    required this.dailyData,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final todayStr = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: dailyData.map((d) {
        final dayStr = '${d.date.day.toString().padLeft(2, '0')}/${d.date.month.toString().padLeft(2, '0')}/${d.date.year}';
        final isToday = dayStr == todayStr;

        return Column(
          children: [
            SizedBox(
              height: 120,
              width: 16,
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: DailyBarPainter(
                        percentage: d.percentage,
                        expectedCount: d.expectedCount,
                      ),
                    ),
                  ),
                  if (d.expectedCount > 0)
                    Positioned(
                      top: 4,
                      child: Text(
                        '${d.percentage}%',
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
              d.dayName,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                color: isToday ? AppColors.primary : AppColors.textMuted,
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}
