import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medicaixa_app/core/presentation/widgets/vertical_datetime_selector.dart';

void main() {
  testWidgets('VerticalDateSelector adjusts max days dynamically when month changes (Jan 31 -> Feb 29 in bissexto)', (WidgetTester tester) async {
    DateTime selectedDate = DateTime(2024, 1, 31); // 2024 is leap year

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return VerticalDateSelector(
                initialDate: selectedDate,
                onChanged: (d) {
                  setState(() {
                    selectedDate = d;
                  });
                },
              );
            },
          ),
        ),
      ),
    );

    // Initial check: day 31, month 1, year 2024
    expect(find.text('31'), findsOneWidget);
    expect(find.text('01'), findsOneWidget);
    expect(find.text('2024'), findsOneWidget);

    // Month spinner has buttons '+' (index 1) and '-' (index 1)
    // Finding '+' buttons. Day '+' is index 0, Month '+' is index 1, Year '+' is index 2.
    final plusButtons = find.text('+');
    expect(plusButtons, findsNWidgets(3));

    // Tap month '+' to go from 01 (Jan) to 02 (Feb)
    await tester.tap(plusButtons.at(1));
    await tester.pump();

    // Since 2024 is leap year, February has 29 days. Day should clamp from 31 to 29.
    expect(selectedDate.month, 2);
    expect(selectedDate.day, 29);
    expect(selectedDate.year, 2024);

    expect(find.text('29'), findsOneWidget);
    expect(find.text('02'), findsOneWidget);
  });

  testWidgets('VerticalDateSelector adjusts max days dynamically when year changes (Feb 29 2024 -> Feb 28 2023)', (WidgetTester tester) async {
    DateTime selectedDate = DateTime(2024, 2, 29); // 2024 is leap year

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return VerticalDateSelector(
                initialDate: selectedDate,
                onChanged: (d) {
                  setState(() {
                    selectedDate = d;
                  });
                },
              );
            },
          ),
        ),
      ),
    );

    // Initial check: day 29, month 2, year 2024
    expect(find.text('29'), findsOneWidget);
    expect(find.text('02'), findsOneWidget);
    expect(find.text('2024'), findsOneWidget);

    // Year spinner '-' button: Day is index 0, Month is index 1, Year is index 2.
    final minusButtons = find.text('-');
    expect(minusButtons, findsNWidgets(3));

    // Tap year '-' to go from 2024 to 2023 (not leap year)
    await tester.tap(minusButtons.at(2));
    await tester.pump();

    // February 2023 has 28 days. Day should clamp from 29 to 28.
    expect(selectedDate.year, 2023);
    expect(selectedDate.month, 2);
    expect(selectedDate.day, 28);

    expect(find.text('28'), findsOneWidget);
    expect(find.text('2023'), findsOneWidget);
  });

  testWidgets('VerticalDateSelector adjusts max days dynamically from 31 to 30 (Mar 31 -> Apr 30)', (WidgetTester tester) async {
    DateTime selectedDate = DateTime(2024, 3, 31);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return VerticalDateSelector(
                initialDate: selectedDate,
                onChanged: (d) {
                  setState(() {
                    selectedDate = d;
                  });
                },
              );
            },
          ),
        ),
      ),
    );

    expect(find.text('31'), findsOneWidget);
    expect(find.text('03'), findsOneWidget);

    final plusButtons = find.text('+');
    // Tap month '+' to go from 03 (Mar) to 04 (Apr)
    await tester.tap(plusButtons.at(1));
    await tester.pump();

    // April has 30 days. Day should clamp to 30.
    expect(selectedDate.month, 4);
    expect(selectedDate.day, 30);

    expect(find.text('30'), findsOneWidget);
    expect(find.text('04'), findsOneWidget);
  });
}
