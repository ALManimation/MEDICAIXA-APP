import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../data/alarm_model.dart';
import '../../data/alarm_repository.dart';

part 'alarm_wizard_notifier.g.dart';

class WizardState {
  final int currentStep;
  final AlarmModel alarm;
  final bool isSaving;

  const WizardState({
    required this.currentStep,
    required this.alarm,
    required this.isSaving,
  });

  WizardState copyWith({
    int? currentStep,
    AlarmModel? alarm,
    bool? isSaving,
  }) {
    return WizardState(
      currentStep: currentStep ?? this.currentStep,
      alarm: alarm ?? this.alarm,
      isSaving: isSaving ?? this.isSaving,
    );
  }
}

@riverpod
class AlarmWizardNotifier extends _$AlarmWizardNotifier {
  late final AlarmRepository _repository;

  @override
  WizardState build() {
    _repository = ref.watch(alarmRepositoryProvider);

    final initialAlarm = AlarmModel(
      id: 0,
      hour: 8,
      minute: 0,
      name: '',
      medName: '',
      enabled: true,
      active: true,
      days: List.filled(7, true),
      status: 'PENDENTE',
      color: 'blue',
      quantity: 1.0,
      daysQuantity: List.filled(7, 0.0),
      type: 'comprimido',
      snoozeMin: 0,
      durationDays: 0,
    );

    return WizardState(
      currentStep: 0,
      alarm: initialAlarm,
      isSaving: false,
    );
  }

  void nextStep() {
    if (state.currentStep < 3) {
      state = state.copyWith(currentStep: state.currentStep + 1);
    }
  }

  void previousStep() {
    if (state.currentStep > 0) {
      state = state.copyWith(currentStep: state.currentStep - 1);
    }
  }

  void updateMedication(String name, String type, String dosage, String color, String? specialInstruction) {
    state = state.copyWith(
      alarm: state.alarm.copyWith(
        name: name,
        medName: name,
        type: type,
        dosage: dosage,
        color: color,
        specialInstruction: specialInstruction,
      ),
    );
  }

  void updateSchedule(int hour, int minute, List<bool> days) {
    state = state.copyWith(
      alarm: state.alarm.copyWith(
        hour: hour,
        minute: minute,
        days: days,
      ),
    );
  }

  void updateDosage(double quantity, String type, String dosage) {
    state = state.copyWith(
      alarm: state.alarm.copyWith(
        quantity: quantity,
        type: type,
        dosage: dosage,
      ),
    );
  }

  void updateOptions({
    required String color,
    String? specialInstruction,
    int? snoozeMin,
    String? startDate,
    required int durationDays,
    int? cycleOnDays,
    int? cycleOffDays,
    bool? isPrn,
    int? prnMinIntervalHours,
    int? prnMaxDailyDoses,
  }) {
    state = state.copyWith(
      alarm: state.alarm.copyWith(
        color: color,
        specialInstruction: specialInstruction,
        snoozeMin: snoozeMin,
        startDate: startDate,
        durationDays: durationDays,
        cycleOnDays: cycleOnDays,
        cycleOffDays: cycleOffDays,
        cycleCurrentDay: cycleOnDays != null && cycleOnDays > 0 ? 1 : null,
        cycleIsPaused: cycleOnDays != null && cycleOnDays > 0 ? false : null,
        isPrn: isPrn,
        prnMinIntervalHours: prnMinIntervalHours,
        prnMaxDailyDoses: prnMaxDailyDoses,
        prnDosesToday: isPrn == true ? 0 : null,
      ),
    );
  }

  Future<bool> saveAlarm() async {
    state = state.copyWith(isSaving: true);
    try {
      await _repository.createAlarm(state.alarm);
      return true;
    } catch (_) {
      return false;
    } finally {
      state = state.copyWith(isSaving: false);
    }
  }
}
