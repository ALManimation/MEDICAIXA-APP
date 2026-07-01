import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medicaixa_app/core/presentation/widgets/standard_stepper.dart';
import 'package:medicaixa_app/core/presentation/widgets/vertical_datetime_selector.dart';

void main() {
  group('StandardStepper Touch Acceleration & Lifecycle Tests', () {
    testWidgets('Tap increments by exactly 1 unit', (WidgetTester tester) async {
      double value = 10.0;
      int callCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return StandardStepper(
                  value: value,
                  onChanged: (v) {
                    callCount++;
                    setState(() {
                      value = v;
                    });
                  },
                  min: 0.0,
                  max: 100.0,
                  step: 1.0,
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('10'), findsOneWidget);

      await tester.runAsync(() async {
        // Press and release quickly
        final gesture = await tester.startGesture(tester.getCenter(find.text('+')));
        await Future.delayed(const Duration(milliseconds: 100));
        await gesture.up();
      });

      await tester.pumpAndSettle();

      // Only the immediate step should have happened
      expect(value, 11.0);
      expect(callCount, 1);
    });

    testWidgets('Holding for 1 second uses slow ticks (200ms)', (WidgetTester tester) async {
      double value = 10.0;
      final List<double> valuesObserved = [];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return StandardStepper(
                  value: value,
                  onChanged: (v) {
                    valuesObserved.add(v);
                    setState(() {
                      value = v;
                    });
                  },
                  min: 0.0,
                  max: 100.0,
                  step: 1.0,
                );
              },
            ),
          ),
        ),
      );

      await tester.runAsync(() async {
        final gesture = await tester.startGesture(tester.getCenter(find.text('+')));
        
        // Wait 1.0s (500ms delay + ~2x200ms periodic ticks)
        for (int i = 0; i < 42; i++) {
          await tester.pump(const Duration(milliseconds: 20));
          await Future.delayed(const Duration(milliseconds: 20));
        }

        await gesture.up();
      });

      await tester.pumpAndSettle();

      // Start: 10
      // Immediate: 11 (at 0ms)
      // 500ms delay: no ticks
      // 700ms tick: 12
      // 900ms tick: 13
      // We expect the final value to be around 13 or 14 (allowing minor timing variance)
      debugPrint('Observed StandardStepper values at 1s: $valuesObserved');
      expect(value, greaterThanOrEqualTo(12.0));
      expect(value, lessThanOrEqualTo(16.0)); // definitely not accelerated yet
    });

    testWidgets('Holding for 2.5 seconds accelerates the ticks after 2 seconds', (WidgetTester tester) async {
      double value = 10.0;
      final List<double> valuesObserved = [];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return StandardStepper(
                  value: value,
                  onChanged: (v) {
                    valuesObserved.add(v);
                    setState(() {
                      value = v;
                    });
                  },
                  min: 0.0,
                  max: 100.0,
                  step: 1.0,
                );
              },
            ),
          ),
        ),
      );

      await tester.runAsync(() async {
        final gesture = await tester.startGesture(tester.getCenter(find.text('+')));
        
        // Wait 2.5s
        for (int i = 0; i < 125; i++) {
          await tester.pump(const Duration(milliseconds: 20));
          await Future.delayed(const Duration(milliseconds: 20));
        }

        await gesture.up();
      });

      await tester.pumpAndSettle();

      debugPrint('Observed StandardStepper values at 2.5s: $valuesObserved');
      // If acceleration worked, the final value should be much higher (e.g. >= 22)
      expect(value, greaterThanOrEqualTo(22.0));
    });

    testWidgets('Timers are canceled on widget disposal (no leaks)', (WidgetTester tester) async {
      double value = 10.0;
      int callCount = 0;
      StateSetter? parentSetState;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                parentSetState = setState;
                if (value == 99.0) {
                  return const SizedBox.shrink();
                }
                return StandardStepper(
                  value: value,
                  onChanged: (v) {
                    callCount++;
                    setState(() {
                      value = v;
                    });
                  },
                  min: 0.0,
                  max: 100.0,
                  step: 1.0,
                );
              },
            ),
          ),
        ),
      );

      await tester.runAsync(() async {
        // Start timers
        await tester.startGesture(tester.getCenter(find.text('+')));
        
        // Let it run for 100ms (immediate call will happen)
        await Future.delayed(const Duration(milliseconds: 100));
        await tester.pump();
        
        expect(callCount, 1);
        expect(value, 11.0);

        // Now dispose the widget by setting value to 99.0 in the parent State
        parentSetState!(() {
          value = 99.0;
        });
        await tester.pump();

        // Widget is now disposed (replaced by SizedBox.shrink)
        expect(find.byType(StandardStepper), findsNothing);

        // Wait another 1 second in real time to see if any timer callbacks still execute and change value
        await Future.delayed(const Duration(seconds: 1));
        await tester.pump();
      });

      // The callCount should still be 1 (meaning onChanged was not called after disposal)
      expect(callCount, 1);
    });
  });

  group('VerticalSpinner Touch Acceleration & Lifecycle Tests', () {
    testWidgets('Tap increments by exactly 1 unit', (WidgetTester tester) async {
      int value = 10;
      int callCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return VerticalSpinner(
                  value: value,
                  onChanged: (v) {
                    callCount++;
                    setState(() {
                      value = v;
                    });
                  },
                  min: 0,
                  max: 100,
                  wrap: false,
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('10'), findsOneWidget);

      await tester.runAsync(() async {
        final gesture = await tester.startGesture(tester.getCenter(find.text('+')));
        await Future.delayed(const Duration(milliseconds: 100));
        await gesture.up();
      });

      await tester.pumpAndSettle();

      expect(value, 11);
      expect(callCount, 1);
    });

    testWidgets('Holding for 1 second uses slow ticks (200ms)', (WidgetTester tester) async {
      int value = 10;
      final List<int> valuesObserved = [];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return VerticalSpinner(
                  value: value,
                  onChanged: (v) {
                    valuesObserved.add(v);
                    setState(() {
                      value = v;
                    });
                  },
                  min: 0,
                  max: 100,
                  wrap: false,
                );
              },
            ),
          ),
        ),
      );

      await tester.runAsync(() async {
        final gesture = await tester.startGesture(tester.getCenter(find.text('+')));
        
        for (int i = 0; i < 42; i++) {
          await tester.pump(const Duration(milliseconds: 20));
          await Future.delayed(const Duration(milliseconds: 20));
        }

        await gesture.up();
      });

      await tester.pumpAndSettle();

      debugPrint('Observed spinner values at 1s: $valuesObserved');
      expect(value, greaterThanOrEqualTo(12));
      expect(value, lessThanOrEqualTo(16));
    });

    testWidgets('Holding for 2.5 seconds accelerates the ticks after 2 seconds', (WidgetTester tester) async {
      int value = 10;
      final List<int> valuesObserved = [];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return VerticalSpinner(
                  value: value,
                  onChanged: (v) {
                    valuesObserved.add(v);
                    setState(() {
                      value = v;
                    });
                  },
                  min: 0,
                  max: 100,
                  wrap: false,
                );
              },
            ),
          ),
        ),
      );

      await tester.runAsync(() async {
        final gesture = await tester.startGesture(tester.getCenter(find.text('+')));
        
        for (int i = 0; i < 125; i++) {
          await tester.pump(const Duration(milliseconds: 20));
          await Future.delayed(const Duration(milliseconds: 20));
        }

        await gesture.up();
      });

      await tester.pumpAndSettle();

      debugPrint('Observed spinner values at 2.5s: $valuesObserved');
      expect(value, greaterThanOrEqualTo(22));
    });

    testWidgets('Timers are canceled on widget disposal (no leaks)', (WidgetTester tester) async {
      int value = 10;
      int callCount = 0;
      StateSetter? parentSetState;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                parentSetState = setState;
                if (value == 99) {
                  return const SizedBox.shrink();
                }
                return VerticalSpinner(
                  value: value,
                  onChanged: (v) {
                    callCount++;
                    setState(() {
                      value = v;
                    });
                  },
                  min: 0,
                  max: 100,
                  wrap: false,
                );
              },
            ),
          ),
        ),
      );

      await tester.runAsync(() async {
        await tester.startGesture(tester.getCenter(find.text('+')));
        await Future.delayed(const Duration(milliseconds: 100));
        await tester.pump();
        
        expect(callCount, 1);
        expect(value, 11);

        parentSetState!(() {
          value = 99;
        });
        await tester.pump();

        expect(find.byType(VerticalSpinner), findsNothing);

        await Future.delayed(const Duration(seconds: 1));
        await tester.pump();
      });

      expect(callCount, 1);
    });
  });
}
