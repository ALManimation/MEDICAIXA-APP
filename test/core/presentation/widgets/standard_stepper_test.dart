import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medicaixa_app/core/presentation/widgets/standard_stepper.dart';

void main() {
  testWidgets('StandardStepper increments and decrements value on tap', (WidgetTester tester) async {
    double value = 10.0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return StandardStepper(
                value: value,
                onChanged: (v) {
                  setState(() {
                    value = v;
                  });
                },
                min: 0.0,
                max: 20.0,
                step: 1.0,
              );
            },
          ),
        ),
      ),
    );

    // Verify initial value is displayed
    expect(find.text('10'), findsOneWidget);

    // Tap increment (+)
    await tester.tap(find.text('+'));
    await tester.pump();
    expect(value, 11.0);
    expect(find.text('11'), findsOneWidget);

    // Tap decrement (-)
    await tester.tap(find.text('-'));
    await tester.pump();
    expect(value, 10.0);
    expect(find.text('10'), findsOneWidget);
  });

  testWidgets('StandardStepper displays and toggles fraction button', (WidgetTester tester) async {
    double value = 1.0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return StandardStepper(
                value: value,
                onChanged: (v) {
                  setState(() {
                    value = v;
                  });
                },
                min: 0.0,
                max: 10.0,
                step: 1.0,
                hasFractionButton: true,
              );
            },
          ),
        ),
      ),
    );

    // Verify fraction button is displayed
    expect(find.text('+ ½ (Meio Comprimido)'), findsOneWidget);

    // Tap fraction button
    await tester.tap(find.text('+ ½ (Meio Comprimido)'));
    await tester.pump();
    expect(value, 1.5);
    expect(find.text('1.5'), findsOneWidget);

    // Tap fraction button again to toggle back
    await tester.tap(find.text('+ ½ (Meio Comprimido)'));
    await tester.pump();
    expect(value, 1.0);
    expect(find.text('1'), findsOneWidget);
  });
}
