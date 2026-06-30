import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medicaixa_app/core/presentation/widgets/vertical_datetime_selector.dart';

void main() {
  testWidgets('VerticalSpinner wraps around when enabled', (WidgetTester tester) async {
    int value = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return VerticalSpinner(
                value: value,
                onChanged: (v) {
                  setState(() {
                    value = v;
                  });
                },
                min: 0,
                max: 3,
                wrap: true,
              );
            },
          ),
        ),
      ),
    );

    expect(find.text('0'), findsOneWidget);

    // Increment 0 -> 1 -> 2 -> 3 -> 0 (wrap)
    await tester.tap(find.text('+'));
    await tester.pump();
    expect(value, 1);

    await tester.tap(find.text('+'));
    await tester.pump();
    await tester.tap(find.text('+'));
    await tester.pump();
    expect(value, 3);

    await tester.tap(find.text('+'));
    await tester.pump();
    expect(value, 0); // Wraps around to min

    // Decrement 0 -> 3 (wrap)
    await tester.tap(find.text('-'));
    await tester.pump();
    expect(value, 3); // Wraps around to max
  });

  testWidgets('VerticalTimeSelector updates time correctly', (WidgetTester tester) async {
    TimeOfDay time = const TimeOfDay(hour: 12, minute: 30);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return VerticalTimeSelector(
                initialTime: time,
                onChanged: (t) {
                  setState(() {
                    time = t;
                  });
                },
              );
            },
          ),
        ),
      ),
    );

    // Increment hour from 12 to 13
    final plusButtons = find.text('+');
    expect(plusButtons, findsNWidgets(2));

    await tester.tap(plusButtons.first);
    await tester.pump();
    expect(time.hour, 13);
    expect(time.minute, 30);

    // Increment minute from 30 to 31
    await tester.tap(plusButtons.last);
    await tester.pump();
    expect(time.hour, 13);
    expect(time.minute, 31);
  });
}
