import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medicaixa_app/features/reports/presentation/reports_notifier.dart';
import 'package:medicaixa_app/features/reports/presentation/widgets/donut_chart.dart';
import 'package:medicaixa_app/features/reports/presentation/widgets/daily_bars.dart';
import 'package:medicaixa_app/features/reports/presentation/widgets/streak_dots.dart';
import 'package:medicaixa_app/features/reports/presentation/widgets/period_distribution.dart';
import 'package:medicaixa_app/features/reports/presentation/widgets/monthly_heatmap.dart';
import 'package:medicaixa_app/features/reports/presentation/widgets/medication_performance.dart';
import 'package:medicaixa_app/features/reports/presentation/widgets/medication_filter_bar.dart';

void main() {
  group('DonutChartPainter & DonutChartWidget Robustness Tests', () {
    testWidgets('Handles zero totals gracefully without crashing', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DonutChartWidget(
              taken: 0,
              missed: 0,
              skipped: 0,
              percentage: 0,
            ),
          ),
        ),
      );

      expect(find.text('0%'), findsOneWidget);
      expect(find.text('Tomados'), findsOneWidget);
    });

    testWidgets('Handles large integer values gracefully without overflow or crash', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DonutChartWidget(
              taken: 99999999,
              missed: 99999999,
              skipped: 99999999,
              percentage: 33,
            ),
          ),
        ),
      );

      expect(find.text('33%'), findsOneWidget);
      expect(find.text('99999999'), findsNWidgets(3));
    });
  });

  group('DailyBarsWidget & DailyBarPainter Robustness Tests', () {
    testWidgets('Handles empty daily data list without crash', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DailyBarsWidget(dailyData: []),
          ),
        ),
      );
      expect(find.byType(DailyBarsWidget), findsOneWidget);
    });

    testWidgets('Handles expectedCount = 0 gracefully', (tester) async {
      final data = [
        DailyAdherenceData(
          dayName: 'Seg',
          date: DateTime(2026, 6, 22),
          percentage: 0,
          expectedCount: 0,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DailyBarsWidget(dailyData: data),
          ),
        ),
      );

      expect(find.text('Seg'), findsOneWidget);
      // Percentage text should NOT be rendered when expectedCount is 0
      expect(find.text('0%'), findsNothing);
    });

    testWidgets('Handles large and negative percentages gracefully', (tester) async {
      final data = [
        DailyAdherenceData(
          dayName: 'Ter',
          date: DateTime(2026, 6, 23),
          percentage: 500, // Overflow percentage
          expectedCount: 10,
        ),
        DailyAdherenceData(
          dayName: 'Qua',
          date: DateTime(2026, 6, 24),
          percentage: -50, // Negative percentage
          expectedCount: 5,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DailyBarsWidget(dailyData: data),
          ),
        ),
      );

      expect(find.text('500%'), findsOneWidget);
      expect(find.text('-50%'), findsOneWidget);
    });
  });

  group('StreakDotsWidget & StreakDotsPainter Robustness Tests', () {
    testWidgets('Handles empty dots list gracefully', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StreakDotsWidget(
              currentStreak: 0,
              bestStreak: 0,
              dots: [],
            ),
          ),
        ),
      );

      expect(find.text('0'), findsOneWidget);
      expect(find.text('dias'), findsOneWidget); // "dias" is the label for currentStreak
      expect(find.text('0 dias'), findsOneWidget); // bestStreak label
    });

    testWidgets('Handles large number of dots without division by zero or crash', (tester) async {
      final dots = List<DotStatus>.generate(100, (index) => DotStatus.fullGreen);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StreakDotsWidget(
              currentStreak: 100,
              bestStreak: 100,
              dots: dots,
            ),
          ),
        ),
      );

      expect(find.text('100'), findsOneWidget);
    });

    testWidgets('Handles negative or large streaks', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StreakDotsWidget(
              currentStreak: -5,
              bestStreak: 99999,
              dots: [DotStatus.fullGreen],
            ),
          ),
        ),
      );

      expect(find.text('-5'), findsOneWidget);
      expect(find.text('99999 dias'), findsOneWidget);
    });
  });

  group('PeriodDistributionWidget & PeriodBarPainter Robustness Tests', () {
    testWidgets('Handles zero expected counts without crash', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PeriodDistributionWidget(
              morningPercentage: 0.0,
              morningTaken: 0,
              morningExpected: 0,
              afternoonPercentage: 0.0,
              afternoonTaken: 0,
              afternoonExpected: 0,
              nightPercentage: 0.0,
              nightTaken: 0,
              nightExpected: 0,
            ),
          ),
        ),
      );

      expect(find.text('Manhã'), findsOneWidget);
      expect(find.text('Tarde'), findsOneWidget);
      expect(find.text('Noite'), findsOneWidget);
      expect(find.text('0/0'), findsNWidgets(3));
    });

    testWidgets('Handles negative or large percentages gracefully', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PeriodDistributionWidget(
              morningPercentage: -100.0,
              morningTaken: 0,
              morningExpected: 5,
              afternoonPercentage: 500.0,
              afternoonTaken: 25,
              afternoonExpected: 5,
              nightPercentage: 80.0,
              nightTaken: 4,
              nightExpected: 5,
            ),
          ),
        ),
      );

      expect(find.text('-100%'), findsOneWidget);
      expect(find.text('500%'), findsOneWidget);
      expect(find.text('80%'), findsOneWidget);
    });
  });

  group('MonthlyHeatmapWidget Robustness Tests', () {
    testWidgets('Handles empty cells list by returning empty widget', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: MonthlyHeatmapWidget(cells: []),
            ),
          ),
        ),
      );

      expect(find.byType(MonthlyHeatmapWidget), findsOneWidget);
      expect(find.byType(Column), findsNothing);
    });

    testWidgets('Handles non-7-multiple cell lists correctly with week padding', (tester) async {
      final cells = [
        HeatmapCellData(
          date: DateTime(2026, 6, 1),
          dayOfMonth: 1,
          percentage: 100,
          expectedCount: 1,
          level: HeatmapLevel.level5,
          isFuture: false,
          isToday: false,
        ),
        HeatmapCellData(
          date: DateTime(2026, 6, 2),
          dayOfMonth: 2,
          percentage: 0,
          expectedCount: 0,
          level: HeatmapLevel.level0,
          isFuture: false,
          isToday: true,
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: MonthlyHeatmapWidget(cells: cells),
            ),
          ),
        ),
      );

      expect(find.text('01/06'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('Handles all heatmap levels correctly', (tester) async {
      final cells = List<HeatmapCellData>.generate(6, (index) {
        return HeatmapCellData(
          date: DateTime(2026, 6, index + 1),
          dayOfMonth: index + 1,
          percentage: index * 20,
          expectedCount: 1,
          level: HeatmapLevel.values[index],
          isFuture: false,
          isToday: false,
        );
      });

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: MonthlyHeatmapWidget(cells: cells),
            ),
          ),
        ),
      );

      for (int i = 1; i <= 6; i++) {
        expect(find.text(i.toString()), findsOneWidget);
      }
    });
  });

  group('MedicationPerformanceWidget Robustness Tests', () {
    testWidgets('Handles empty list correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MedicationPerformanceWidget(performanceData: []),
          ),
        ),
      );

      expect(find.text('Nenhum dado por medicamento.'), findsOneWidget);
    });

    testWidgets('Handles overflow percentages (>100) without crashing', (tester) async {
      final performance = [
        MedicationPerformanceData(
          name: 'SuperMed',
          colorHex: 'red',
          takenCount: 10,
          expectedCount: 2,
          percentage: 500, // Invalid percentage > 100
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MedicationPerformanceWidget(performanceData: performance),
          ),
        ),
      );

      expect(find.text('500%'), findsOneWidget);
    });

    testWidgets('Handles negative percentages gracefully without throwing assertion error', (tester) async {
      final performance = [
        MedicationPerformanceData(
          name: 'UnderMed',
          colorHex: 'blue',
          takenCount: 0,
          expectedCount: 2,
          percentage: -50, // Negative percentage
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MedicationPerformanceWidget(performanceData: performance),
          ),
        ),
      );

      final exception = tester.takeException();
      expect(exception, isNull);
    });
  });

  group('MedicationFilterBar Robustness Tests', () {
    testWidgets('Renders items and triggers selection', (tester) async {
      String? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MedicationFilterBar(
              selectedMedication: 'Todos',
              availableMedications: const ['Todos', 'Paracetamol', 'Ibuprofeno'],
              onSelected: (val) {
                selected = val;
              },
            ),
          ),
        ),
      );

      expect(find.text('Todos'), findsOneWidget);
      expect(find.text('Paracetamol'), findsOneWidget);
      expect(find.text('Ibuprofeno'), findsOneWidget);

      await tester.tap(find.text('Paracetamol'));
      await tester.pumpAndSettle();

      expect(selected, 'Paracetamol');
    });
  });
}
