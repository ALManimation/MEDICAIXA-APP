## 2026-06-30T00:28:52Z
<USER_REQUEST>
You are teamwork_preview_worker. Your working directory is `/Users/almanimation/Downloads/Caixa Remedios/medicaixa_app/.agents/teamwork_preview_worker_inputs_2/`.
Your role is to implement and integrate the standardized custom stepper and vertical DateTime selectors (Milestone 6) in the MediCaixa App codebase.

MANDATORY INTEGRITY WARNING:
> DO NOT CHEAT. All implementations must be genuine. DO NOT
> hardcode test results, create dummy/facade implementations, or
> circumvent the intended task. A Forensic Auditor will independently
> verify your work. Integrity violations WILL be detected and your
> work WILL be rejected.

Please execute the following tasks:

### Task 1: Create StandardStepper Widget
File: `lib/core/presentation/widgets/standard_stepper.dart`
Create a stateful `StandardStepper` widget with:
- Standardized width of `170.0` (or constrained between 160px and 180px) and height of `48.0`.
- Outer border with `AppColors.border` and background `AppColors.surface`.
- Circular decrement (-) button on the left, centered value, and circular increment (+) button on the right using `GestureDetector`.
- Geste rate acceleration: Rapid touch increments by exactly one step (step size can be passed, default 1.0). If the user holds a button down (long press), use a combination of delay and periodic timers:
  - Initial delay of 500ms before starting periodic updates (slow ticks: 200ms interval).
  - If the button continues to be held for more than 2 seconds (measured via timestamp difference), speed up the interval to 50ms (rapid ticks).
- Clean resource cleanup: cancel all timers inside `dispose()`.
- Add an optional boolean `hasFractionButton` property. If `true`, render the "+ ½ (Meio Comprimido)" button directly below the stepper row. If the value is a fraction (e.g. 1.5), highlight the button with `AppColors.primary` background and white text. Clicking it toggles the fractional `.5` part of the quantity.

### Task 2: Create Vertical DateTime Selector & Dialog Helpers
File: `lib/core/presentation/widgets/vertical_datetime_selector.dart`
Create the following components:
- `VerticalSpinner`: a stateful widget representing a vertical spinner column. It should display a (+) button on top, the centered value, and a (-) button at the bottom. Implement the same touch acceleration logic as Task 1 (initial 500ms delay, then 200ms periodic timer, accelerating to 50ms after 2 seconds of holding).
- `VerticalTimeSelector`: a row containing two `VerticalSpinner` columns (one for Hours 0-23, one for Minutes 0-59) separated by a colon (`:`).
- `VerticalDateSelector`: a stateful widget containing three `VerticalSpinner` columns (Day, Month, Year). Ensure the day max range dynamically scales based on the currently selected month and year (e.g. `DateTime(year, month + 1, 0).day`) to prevent invalid dates.
- Modal Dialog wrapper helpers:
  - `Future<TimeOfDay?> showVerticalTimePicker(BuildContext context, {required TimeOfDay initialTime})`: Opens a Dialog with the `VerticalTimeSelector` and "Cancelar" and "Confirmar" buttons. Returns the selected time or null.
  - `Future<DateTime?> showVerticalDatePicker(BuildContext context, {required DateTime initialDate})`: Opens a Dialog with the `VerticalDateSelector` and "Cancelar" and "Confirmar" buttons. Returns the selected date or null.

### Task 3: Integrate StandardStepper in Screens
Replace all old steppers (such as `_buildLargeStepper`, `_buildMiniStepper`, custom gesture buttons) with the new `StandardStepper` in:
- `lib/features/alarms/presentation/wizard/steps/step_3_qty.dart` (ensure standard stepper with `hasFractionButton: true` is used where applicable).
- `lib/features/alarms/presentation/wizard/steps/step_4_days.dart` (cast stepper double value to int).
- `lib/features/alarms/presentation/wizard/steps/step_6_duration.dart` (cast stepper double value to int).
- `lib/features/alarms/presentation/snooze_modal.dart` (ensure standard stepper is used for setting snooze time or quantity, using `hasFractionButton: true` if fractional quantities are allowed).

### Task 4: Integrate Vertical DateTime Dialog Pickers
Replace all system-native `showDatePicker` and `showTimePicker` calls with our custom `showVerticalDatePicker` and `showVerticalTimePicker` respectively in:
- `lib/features/alarms/presentation/wizard/steps/step_5_time.dart`
- `lib/features/alarms/presentation/wizard/steps/step_7_summary.dart`
- `lib/features/alarms/presentation/wizard/steps/wizard_step_schedule.dart`
- `lib/features/reminders/presentation/reminder_form_screen.dart`
- `lib/features/settings/presentation/settings_screen.dart` (both local sleep/meal times and device settings).

Run `flutter analyze` and `flutter test` to ensure there are no lints, compilation warnings, or broken tests. Write a detailed handoff.md in your working directory.
</USER_REQUEST>
