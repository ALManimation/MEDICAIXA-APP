import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'wizard_state.dart';
import '../../data/alarm_model.dart';
import '../../data/alarm_repository.dart';

part 'wizard_notifier.g.dart';

@riverpod
class WizardNotifier extends _$WizardNotifier {
  @override
  WizardState build() {
    return const WizardState();
  }

  void updateState(WizardState Function(WizardState) updates) {
    state = updates(state);
  }

  // A helper for step-specific validation (returns error message or null if valid)
  String? validateCurrentStep() {
    switch (state.step) {
      case 1:
        if (state.name.trim().isEmpty) return 'Qual é o nome do remédio?';
        if (state.type.isEmpty) return 'Escolha o formato do remédio!';
        // Dosage is optional in C++, but if set, we handle 'mg' or 'ml'
        break;
      case 2:
        if (state.useMode.isEmpty) return 'Escolha como usar o remédio!';
        break;
      case 3:
        if (state.quantityMode.isEmpty) return 'Escolha a quantidade!';
        if (state.quantityMode == 'dynamic') {
          if (state.dynamicParamSelected.isEmpty) return 'Informe o aparelho de teste!';
          if (state.dynamicRules.isEmpty) return 'Adicione pelo menos uma faixa de dose!';
        } else if (state.quantityMode == 'taper') {
          if (state.taperStages.length < 2) return 'Configure pelo menos 2 etapas de desmame!';
        }
        break;
      case 4:
        if (state.daysMode.isEmpty) return 'Escolha os dias do tratamento!';
        if (state.daysMode == 'weekdays' && state.weekdays.isEmpty) {
          return 'Selecione pelo menos um dia da semana!';
        }
        break;
      case 5:
        if (state.timePreset.isEmpty) return 'Escolha o horário!';
        break;
      case 6:
        if (state.durationMode.isEmpty) return 'Escolha a duração!';
        break;
    }
    return null;
  }

  bool nextStep() {
    final error = validateCurrentStep();
    if (error != null) {
      // Retorna false e a UI deve exibir o erro (ex: Snackbar)
      return false;
    }

    // Lógica condicional de pulo de passos
    if (state.step == 2 && state.useMode == 'prn') {
      state = state.copyWith(step: 7);
      return true;
    }

    if (state.step < 7) {
      state = state.copyWith(step: state.step + 1);
      return true;
    }
    
    return true; // Step 7 = save
  }

  void prevStep() {
    if (state.step == 7 && state.useMode == 'prn') {
      state = state.copyWith(step: 2);
    } else if (state.step > 1) {
      state = state.copyWith(step: state.step - 1);
    }
  }

  void reset() {
    state = const WizardState();
  }

  void loadAlarmForEdit(AlarmModel alarm) {
    // 1. Basic properties
    final name = alarm.name;
    final type = alarm.type;
    final dosage = alarm.dosage ?? '';
    final color = alarm.color;

    // 2. Use mode
    String useMode = 'continuous';
    int prnMaxDailyDoses = 0;
    int prnMinIntervalHours = 0;

    if (alarm.isPrn == true) {
      useMode = 'prn';
      prnMaxDailyDoses = alarm.prnMaxDailyDoses ?? 0;
      prnMinIntervalHours = alarm.prnMinIntervalHours ?? 0;
    } else if (alarm.startDate != null && alarm.startDate!.isNotEmpty && alarm.durationDays > 0) {
      useMode = 'temporary';
    }

    // 3. Quantity Mode
    String quantityMode = 'fixed';
    final double fixedQuantity = alarm.quantity;
    final List<double> asymmetricDoses = alarm.daysQuantity;
    String dynamicParamSelected = 'Glicose';
    final List<WizardDynamicRule> dynamicRules = [];

    if (alarm.isDynamic == true) {
      quantityMode = 'dynamic';
      if (alarm.dynamicInstruction != null) {
        final inst = alarm.dynamicInstruction!;
        final spaceIdx = inst.indexOf(' ');
        if (spaceIdx != -1) {
          dynamicParamSelected = inst.substring(0, spaceIdx);
          final rulesPart = inst.substring(spaceIdx + 1);
          final rulesList = rulesPart.split(';');
          for (final ruleStr in rulesList) {
            final cleanRule = ruleStr.trim();
            if (cleanRule.isEmpty) continue;
            
            final colonIdx = cleanRule.indexOf(':');
            if (colonIdx != -1) {
              final cond = cleanRule.substring(0, colonIdx).trim();
              final doseAndUnit = cleanRule.substring(colonIdx + 1).trim();
              
              String op = 'maior';
              String limit = '';
              if (cond.startsWith('>=')) {
                op = 'maior_igual';
                limit = cond.substring(2);
              } else if (cond.startsWith('>')) {
                op = 'maior';
                limit = cond.substring(1);
              } else if (cond.startsWith('<=')) {
                op = 'menor_igual';
                limit = cond.substring(2);
              } else if (cond.startsWith('<')) {
                op = 'menor';
                limit = cond.substring(1);
              } else if (cond.startsWith('=')) {
                op = 'igual';
                limit = cond.substring(1);
              }
              
              final numMatch = RegExp(r'^(\d+(?:\.\d+)?)').firstMatch(doseAndUnit);
              double dose = 1.0;
              if (numMatch != null) {
                dose = double.tryParse(numMatch.group(1)!) ?? 1.0;
              }
              
              dynamicRules.add(WizardDynamicRule(
                operation: op,
                limit: limit,
                dose: dose,
              ));
            }
          }
        }
      }
    } else if (alarm.taperStages != null && alarm.taperStages!.isNotEmpty) {
      quantityMode = 'taper';
    } else {
      // Check if asymmetric
      bool hasAsymmetric = false;
      for (final q in alarm.daysQuantity) {
        if (q > 0 && q != alarm.quantity) {
          hasAsymmetric = true;
          break;
        }
      }
      if (hasAsymmetric) {
        quantityMode = 'asymmetric';
      }
    }

    // 4. Days Mode
    String daysMode = 'weekdays';
    int intervalDays = 8;
    final Set<int> weekdays = {};
    int alternatingDays = 2;
    int cycleOnDays = 21;
    int cycleOffDays = 7;
    int monthlyDay = 1;

    if (alarm.dayOfMonth != null && alarm.dayOfMonth! > 0) {
      daysMode = 'monthly';
      monthlyDay = alarm.dayOfMonth!;
    } else if (alarm.intervalHours != null && alarm.intervalHours! > 0) {
      daysMode = 'interval';
      intervalDays = alarm.intervalHours!;
    } else if (alarm.cycleOnDays != null && alarm.cycleOnDays! > 0) {
      daysMode = 'cycle';
      cycleOnDays = alarm.cycleOnDays!;
      cycleOffDays = alarm.cycleOffDays ?? 7;
    } else if ((alarm.intervalDays != null && alarm.intervalDays! > 0) || (alarm.adjustIntervalDays != null && alarm.adjustIntervalDays! > 0)) {
      daysMode = 'alternating';
      alternatingDays = alarm.intervalDays ?? alarm.adjustIntervalDays!;
    } else {
      final activeDays = alarm.days.where((d) => d).length;
      if (activeDays == 7) {
        daysMode = 'everyday';
      } else {
        daysMode = 'weekdays';
        for (int i = 0; i < 7; i++) {
          if (alarm.days[i]) {
            final int w = i == 0 ? 7 : i;
            weekdays.add(w);
          }
        }
      }
    }

    // 5. Time preset and custom times
    final customTimes = ['${alarm.hour.toString().padLeft(2, '0')}:${alarm.minute.toString().padLeft(2, '0')}'];
    const timePreset = 'custom';

    // 6. Duration Mode
    final durationMode = alarm.durationDays > 0 ? 'days' : 'continuous';
    final durationDays = alarm.durationDays > 0 ? alarm.durationDays : 7;

    String startDateMode = 'today';
    DateTime? customStartDate;
    if (alarm.startDate != null && alarm.startDate!.isNotEmpty) {
      try {
        final parsedDate = DateTime.parse(alarm.startDate!);
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final tomorrow = today.add(const Duration(days: 1));
        final dateToCheck = DateTime(parsedDate.year, parsedDate.month, parsedDate.day);
        
        if (dateToCheck.isAtSameMomentAs(today)) {
          startDateMode = 'today';
        } else if (dateToCheck.isAtSameMomentAs(tomorrow)) {
          startDateMode = 'tomorrow';
        } else {
          startDateMode = 'custom';
          customStartDate = parsedDate;
        }
      } catch (_) {
        startDateMode = 'today';
      }
    }

    state = WizardState(
      step: 1, // Start editing at step 1
      name: name,
      type: type,
      dosage: dosage,
      color: color,
      useMode: useMode,
      prnMaxDailyDoses: prnMaxDailyDoses,
      prnMinIntervalHours: prnMinIntervalHours,
      quantityMode: quantityMode,
      fixedQuantity: fixedQuantity,
      asymmetricDoses: asymmetricDoses,
      dynamicParamSelected: dynamicParamSelected,
      dynamicRules: dynamicRules,
      taperStages: alarm.taperStages ?? [],
      taperLoop: alarm.taperLoop ?? false,
      daysMode: daysMode,
      intervalDays: intervalDays,
      weekdays: weekdays,
      alternatingDays: alternatingDays,
      cycleOnDays: cycleOnDays,
      cycleOffDays: cycleOffDays,
      monthlyDay: monthlyDay,
      timePreset: timePreset,
      customTimes: customTimes,
      durationMode: durationMode,
      durationDays: durationDays,
      startDateMode: startDateMode,
      customStartDate: customStartDate,
      instruction: alarm.specialInstruction ?? '',
      requiresRemoval: alarm.requiresRemoval ?? false,
      removalDelayMins: alarm.removalDelayMins ?? 24,
      siteRotationList: alarm.siteRotationList ?? '',
      editingAlarmId: alarm.id,
    );
  }

  Future<void> saveAlarm() async {
    final repo = ref.read(alarmRepositoryProvider);
    final isPrn = state.useMode == 'prn';

    if (state.editingAlarmId != null) {
      // In edit mode, we update the single alarm, keeping its ID
      final t = state.customTimes.isNotEmpty ? state.customTimes[0] : '08:00';
      final parts = t.split(':');
      int h = 8;
      int m = 0;
      if (parts.length == 2) {
        h = int.tryParse(parts[0]) ?? 8;
        m = int.tryParse(parts[1]) ?? 0;
      }

      final baseModel = constructAlarmModel(state.editingAlarmId!);
      final modelWithTime = baseModel.copyWith(hour: h, minute: m);

      await repo.updateAlarm(modelWithTime);
    } else {
      // In creation mode, we save one or multiple alarms
      final List<String> timesToSave;
      if (!isPrn && state.timePreset == 'custom' && state.daysMode != 'interval') {
        timesToSave = state.customTimes;
      } else {
        timesToSave = state.customTimes.isNotEmpty ? [state.customTimes[0]] : ['08:00'];
      }

      for (final t in timesToSave) {
        final parts = t.split(':');
        int h = 8;
        int m = 0;
        if (parts.length == 2) {
          h = int.tryParse(parts[0]) ?? 8;
          m = int.tryParse(parts[1]) ?? 0;
        }

        final baseModel = constructAlarmModel(0);
        final modelWithTime = baseModel.copyWith(hour: h, minute: m);

        await repo.createAlarm(modelWithTime);
      }
    }
  }

  AlarmModel constructAlarmModel(int nextId) {
    // 1. Basic
    final String finalMedName = state.name.trim();
    String finalDosage = state.dosage.trim();
    
    // Auto-append unit to dosage if missing
    if (finalDosage.isNotEmpty && RegExp(r'^\d+([.,]\d+)?$').hasMatch(finalDosage)) {
      finalDosage = finalDosage.replaceAll(',', '.');
      if (state.type == 'dose' || state.type == 'gota' || state.type == 'ml') {
        finalDosage += 'ml';
      } else {
        finalDosage += 'mg'; // comprimido, capsula etc
      }
    }

    final bool isPrn = state.useMode == 'prn';
    
    // Days logic
    List<bool> finalDays = List.filled(7, true);
    if (!isPrn) {
      if (state.daysMode == 'weekdays') {
        finalDays = List.generate(7, (i) {
          // No flutter weekday 1=Mon...7=Sun. No C++ days array 0=Sun..6=Sat.
          // Mapeamento: C++ 0(Sun)->Flutter 7. 
          // O WizardState vai usar 1=Mon, 2=Tue, 3=Wed, 4=Thu, 5=Fri, 6=Sat, 7=Sun
          // Array do AlarmModel tem 7 posições [Dom, Seg, Ter, Qua, Qui, Sex, Sab].
          // Então:
          // Flutter i=0 -> Dom (weekday=7)
          // Flutter i=1 -> Seg (weekday=1)
          // i=2 -> Ter(2), etc.
          final int w = i == 0 ? 7 : i; 
          return state.weekdays.contains(w);
        });
      }
    }

    // Date/Time
    String? finalStartDate;
    if (state.startDateMode == 'today') {
      final now = DateTime.now();
      finalStartDate = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    } else if (state.startDateMode == 'tomorrow') {
      final now = DateTime.now().add(const Duration(days: 1));
      finalStartDate = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    } else if (state.startDateMode == 'custom' && state.customStartDate != null) {
      final d = state.customStartDate!;
      finalStartDate = "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
    }

    final int duration = (state.durationMode == 'days') ? state.durationDays : 0;
    
    // Cycle logic
    int? cycleOn, cycleOff;
    if (state.daysMode == 'cycle') {
      cycleOn = state.cycleOnDays;
      cycleOff = state.cycleOffDays;
    }

    // Interval logic
    final int? intervalDays = state.daysMode == 'alternating' ? state.alternatingDays : null;

    int? dayOfMonth;
    if (state.daysMode == 'monthly') dayOfMonth = state.monthlyDay;

    // Time (pegar o primeiro de customTimes por enquanto)
    int hour = 8;
    int minute = 0;
    if (state.customTimes.isNotEmpty) {
      final parts = state.customTimes[0].split(':');
      if (parts.length == 2) {
        hour = int.tryParse(parts[0]) ?? 8;
        minute = int.tryParse(parts[1]) ?? 0;
      }
    }

    return AlarmModel(
      id: nextId,
      name: finalMedName,
      medName: finalMedName,
      dosage: finalDosage,
      type: state.type,
      color: state.color,
      enabled: true,
      active: true,
      status: 'PENDENTE',
      hour: hour,
      minute: minute,
      days: finalDays,
      quantity: state.fixedQuantity,
      daysQuantity: state.quantityMode == 'asymmetric' ? state.asymmetricDoses : List.filled(7, 0.0),
      snoozeMin: 0,
      durationDays: duration,
      startDate: finalStartDate,
      
      // PRN
      isPrn: isPrn,
      prnMaxDailyDoses: isPrn ? state.prnMaxDailyDoses : null,
      prnMinIntervalHours: isPrn ? state.prnMinIntervalHours : null,
      
      // Cycles/Intervals
      cycleOnDays: cycleOn,
      cycleOffDays: cycleOff,
      intervalHours: state.daysMode == 'interval' ? state.intervalDays : null, 
      intervalDays: intervalDays,
      dayOfMonth: dayOfMonth,

      // Dynamics
      isDynamic: state.quantityMode == 'dynamic',
      dynamicInstruction: () {
        if (state.quantityMode != 'dynamic') return null;
        final param = state.dynamicParamSelected.trim();
        if (param.isEmpty) return null;
        
        String unit = 'comp';
        if (state.type == 'gota') {
          unit = 'gotas';
        } else if (state.type == 'dose') {
          unit = param == 'Glicose' ? 'U' : 'ml';
        } else if (state.type == 'injetavel' && param == 'Glicose') {
          unit = 'U';
        }

        final parts = <String>[];
        for (final rule in state.dynamicRules) {
          if (rule.limit.trim().isNotEmpty) {
            final opChar = rule.operation == 'maior' ? '>' : '<';
            final doseStr = rule.dose.toStringAsFixed(rule.dose.truncateToDouble() == rule.dose ? 0 : 1);
            parts.add('$opChar${rule.limit.trim()}: $doseStr$unit');
          }
        }
        return parts.isNotEmpty ? '$param ${parts.join('; ')}' : null;
      }(),

      // Taper
      taperStageCount: state.quantityMode == 'taper' ? state.taperStages.length : null,
      taperStages: state.quantityMode == 'taper' ? state.taperStages : null,
      taperLoop: state.quantityMode == 'taper' ? state.taperLoop : null,
      
      specialInstruction: state.instruction,
      
      adjustIntervalDays: null,
      
      requiresRemoval: state.requiresRemoval,
      removalDelayMins: state.removalDelayMins,
      siteRotationList: state.siteRotationList,
    );
  }
}
