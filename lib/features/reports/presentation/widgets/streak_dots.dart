import 'dart:math';
import 'package:flutter/material.dart';
import 'package:medicaixa_app/core/constants/app_colors.dart';
import 'package:medicaixa_app/features/reports/presentation/reports_notifier.dart';
import 'package:medicaixa_app/core/localization/app_localizations.dart';

class StreakDotsPainter extends CustomPainter {
  final List<DotStatus> dots;

  StreakDotsPainter({required this.dots});

  @override
  void paint(Canvas canvas, Size size) {
    if (dots.isEmpty) return;

    final dotCount = dots.length;
    // Each dot has diameter = size.height. Total width for all dots = dotCount * size.height.
    // Remaining width is for spacing.
    final double dotDiameter = size.height;
    final double radius = dotDiameter / 2;
    final double spacing = dotCount > 1 
        ? max(0.0, (size.width - (dotCount * dotDiameter)) / (dotCount - 1))
        : 0;

    for (int i = 0; i < dotCount; i++) {
      final double cx = radius + i * (dotDiameter + spacing);
      final double cy = size.height / 2;

      final paint = Paint()..style = PaintingStyle.fill;

      switch (dots[i]) {
        case DotStatus.fullGreen:
          paint.color = const Color(0xFF10B981);
          break;
        case DotStatus.partialOrange:
          paint.color = const Color(0xFFF59E0B);
          break;
        case DotStatus.redMiss:
          paint.color = const Color(0xFFEF4444);
          break;
        case DotStatus.grayEmpty:
          paint.color = const Color(0xFF374151);
          break;
      }

      canvas.drawCircle(Offset(cx, cy), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant StreakDotsPainter oldDelegate) {
    return oldDelegate.dots != dots;
  }
}

class StreakDotsWidget extends StatelessWidget {
  final int currentStreak;
  final int bestStreak;
  final List<DotStatus> dots;

  const StreakDotsWidget({
    super.key,
    required this.currentStreak,
    required this.bestStreak,
    required this.dots,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      currentStreak.toString(),
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      currentStreak == 1 ? t('streak_day_singular') : t('streak_day_plural'),
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
                Text(
                  t('stats_streak_current_title'),
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 32),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t('stats_streak_history_14d'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 12,
                    child: CustomPaint(
                      painter: StreakDotsPainter(dots: dots),
                      child: Container(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        Divider(height: 24, color: AppColors.border),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              t('stats_streak_best_title'),
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textMuted,
              ),
            ),
            Text(
              '$bestStreak ${bestStreak == 1 ? t('streak_day_singular') : t('streak_day_plural')}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.text,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
