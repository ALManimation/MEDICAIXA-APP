import 'package:flutter/foundation.dart';
import '../../data/alarm_model.dart'; // Para TaperStage se necessário, ou copiamos

class WizardDynamicRule {
  final String operation; // 'maior', 'menor', 'igual', 'menor_igual', 'maior_igual'
  final String limit;
  final double dose;
  
  const WizardDynamicRule({
    required this.operation,
    required this.limit,
    required this.dose,
  });

  WizardDynamicRule copyWith({
    String? operation,
    String? limit,
    double? dose,
  }) {
    return WizardDynamicRule(
      operation: operation ?? this.operation,
      limit: limit ?? this.limit,
      dose: dose ?? this.dose,
    );
  }
}

class WizardState {
  final int step;
  
  // Step 1
  final String name;
  final String type; // 'comprimido', 'gota', 'capsula', 'adesivo', 'injetavel', 'ml', 'spray', 'pomada'
  final String dosage;
  final String color; // 'blue', 'green', 'red', 'yellow', 'purple', 'orange', 'pink', 'teal', 'white'
  
  // Step 2
  final String useMode; // 'continuous', 'temporary', 'prn'
  final int prnMaxDailyDoses;
  final int prnMinIntervalHours;
  
  // Step 3
  final String quantityMode; // 'fixed', 'asymmetric', 'dynamic', 'taper'
  final double fixedQuantity;
  final List<double> asymmetricDoses; // array de 7 (para horários diferentes se necessário, ou 1 por horário no array de horários)
  // Wait, in C++, asymmetricDoses was mapped 1:1 with _wizardCustomTimes?
  // C++ uses _wizardAsymmetricDoses = [0, 0, 0, 0, 0, 0, 0]; (max 7 times)
  final String dynamicParamSelected;
  final List<WizardDynamicRule> dynamicRules;
  final List<TaperStage> taperStages;
  final bool taperLoop;
  
  // Step 4
  final String daysMode; // 'everyday', 'interval', 'weekdays', 'alternating', 'cycle', 'monthly'
  final int intervalDays;
  final Set<int> weekdays; // 1=Mon, 7=Sun
  final int alternatingDays;
  final int cycleOnDays;
  final int cycleOffDays;
  final int monthlyDay;
  
  // Step 5
  final String timePreset; // 'custom', 'wake', 'sleep', 'meals'
  final List<String> customTimes; // ex: ['08:00', '20:00']
  
  // Step 6
  final String durationMode; // 'continuous', 'days'
  final int durationDays;
  final String startDateMode; // 'today', 'tomorrow', 'custom'
  final DateTime? customStartDate;
  final String instruction; // 'em jejum', 'após refeição', etc
  final bool requiresRemoval;
  final int removalDelayMins;
  final String siteRotationList;

  const WizardState({
    this.step = 1,
    this.name = '',
    this.type = '',
    this.dosage = '',
    this.color = 'blue',
    this.useMode = '',
    this.prnMaxDailyDoses = 0,
    this.prnMinIntervalHours = 0,
    this.quantityMode = '',
    this.fixedQuantity = 1.0,
    this.asymmetricDoses = const [0, 0, 0, 0, 0, 0, 0],
    this.dynamicParamSelected = 'Glicose',
    this.dynamicRules = const [],
    this.taperStages = const [],
    this.taperLoop = false,
    this.daysMode = '',
    this.intervalDays = 8,
    this.weekdays = const {},
    this.alternatingDays = 2,
    this.cycleOnDays = 21,
    this.cycleOffDays = 7,
    this.monthlyDay = 1,
    this.timePreset = '',
    this.customTimes = const ['08:00'],
    this.durationMode = '',
    this.durationDays = 7,
    this.startDateMode = 'today',
    this.customStartDate,
    this.instruction = '',
    this.requiresRemoval = false,
    this.removalDelayMins = 24,
    this.siteRotationList = '',
  });

  WizardState copyWith({
    int? step,
    String? name,
    String? type,
    String? dosage,
    String? color,
    String? useMode,
    int? prnMaxDailyDoses,
    int? prnMinIntervalHours,
    String? quantityMode,
    double? fixedQuantity,
    List<double>? asymmetricDoses,
    String? dynamicParamSelected,
    List<WizardDynamicRule>? dynamicRules,
    List<TaperStage>? taperStages,
    bool? taperLoop,
    String? daysMode,
    int? intervalDays,
    Set<int>? weekdays,
    int? alternatingDays,
    int? cycleOnDays,
    int? cycleOffDays,
    int? monthlyDay,
    String? timePreset,
    List<String>? customTimes,
    String? durationMode,
    int? durationDays,
    String? startDateMode,
    DateTime? customStartDate,
    String? instruction,
    bool? requiresRemoval,
    int? removalDelayMins,
    String? siteRotationList,
  }) {
    return WizardState(
      step: step ?? this.step,
      name: name ?? this.name,
      type: type ?? this.type,
      dosage: dosage ?? this.dosage,
      color: color ?? this.color,
      useMode: useMode ?? this.useMode,
      prnMaxDailyDoses: prnMaxDailyDoses ?? this.prnMaxDailyDoses,
      prnMinIntervalHours: prnMinIntervalHours ?? this.prnMinIntervalHours,
      quantityMode: quantityMode ?? this.quantityMode,
      fixedQuantity: fixedQuantity ?? this.fixedQuantity,
      asymmetricDoses: asymmetricDoses ?? this.asymmetricDoses,
      dynamicParamSelected: dynamicParamSelected ?? this.dynamicParamSelected,
      dynamicRules: dynamicRules ?? this.dynamicRules,
      taperStages: taperStages ?? this.taperStages,
      taperLoop: taperLoop ?? this.taperLoop,
      daysMode: daysMode ?? this.daysMode,
      intervalDays: intervalDays ?? this.intervalDays,
      weekdays: weekdays ?? this.weekdays,
      alternatingDays: alternatingDays ?? this.alternatingDays,
      cycleOnDays: cycleOnDays ?? this.cycleOnDays,
      cycleOffDays: cycleOffDays ?? this.cycleOffDays,
      monthlyDay: monthlyDay ?? this.monthlyDay,
      timePreset: timePreset ?? this.timePreset,
      customTimes: customTimes ?? this.customTimes,
      durationMode: durationMode ?? this.durationMode,
      durationDays: durationDays ?? this.durationDays,
      startDateMode: startDateMode ?? this.startDateMode,
      customStartDate: customStartDate ?? this.customStartDate,
      instruction: instruction ?? this.instruction,
      requiresRemoval: requiresRemoval ?? this.requiresRemoval,
      removalDelayMins: removalDelayMins ?? this.removalDelayMins,
      siteRotationList: siteRotationList ?? this.siteRotationList,
    );
  }
}
