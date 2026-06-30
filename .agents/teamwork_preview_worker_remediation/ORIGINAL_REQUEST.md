## 2026-06-29T21:40:40-03:00

Please execute the following fixes:

### Fix 1: State Reset on Dialog Picker Rebuild
File: `lib/core/presentation/widgets/vertical_datetime_selector.dart`
- In `showVerticalTimePicker` and `showVerticalDatePicker`, the local variables `selectedTime` and `selectedDate` are currently declared inside the `showDialog` `builder: (context) { ... }` closure.
- Move their declarations (`TimeOfDay selectedTime = initialTime;` and `DateTime selectedDate = initialDate;`) outside the `showDialog` `builder` closure, placing them directly at the top of the `showVerticalTimePicker` and `showVerticalDatePicker` functions respectively (before calling `showDialog`). This ensures that these state variables survive if the dialog builder is re-evaluated during route rebuilds.

### Fix 2: Parent Container Overflows in Wizard Step 3
File: `lib/features/alarms/presentation/wizard/steps/step_3_qty.dart`
- Locate the daily dose container (around line 252) where the child is `StandardStepper`. Change the parent `Container(width: 130)` width parameter to `178` to comfortably fit the 170.0-wide `StandardStepper` without overflow.
- Locate the dynamic rule container (around line 506) where the child is `StandardStepper`. Change the parent `Container(width: 145)` width parameter to `178` to comfortably fit the 170.0-wide `StandardStepper` without overflow.

Verify the code compiles cleanly and passes all tests (`flutter test` and `flutter analyze`). Write a detailed handoff.md in your working directory.
