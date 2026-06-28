
class TaperStage {
  final double quantity;
  final int durationDays;

  const TaperStage({
    required this.quantity,
    required this.durationDays,
  });

  factory TaperStage.fromJson(Map<String, dynamic> json) {
    return TaperStage(
      quantity: (json['quantity'] as num).toDouble(),
      durationDays: json['duration_days'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'quantity': quantity,
      'duration_days': durationDays,
    };
  }

  TaperStage copyWith({
    double? quantity,
    int? durationDays,
  }) {
    return TaperStage(
      quantity: quantity ?? this.quantity,
      durationDays: durationDays ?? this.durationDays,
    );
  }
}

class AlarmModel {
  final int id;
  final int hour;
  final int minute;
  final String name;
  final String medName;
  final bool enabled;
  final bool active;
  final List<bool> days;
  final String status;
  final String color;
  final double quantity;
  final List<double> daysQuantity;
  final String type;
  final String? dosage;
  final String? lastStatus;
  final String? lastStatusDate;
  final int snoozeMin;
  final String? startDate;
  final int durationDays;
  final String? createdDate;

  // Ciclo
  final int? cycleOnDays;
  final int? cycleOffDays;
  final int? cycleCurrentDay;
  final bool? cycleIsPaused;

  // PRN
  final bool? isPrn;
  final int? prnMinIntervalHours;
  final int? prnMaxDailyDoses;
  final int? prnDosesToday;

  // Pause
  final int? pauseUntil;

  // Dynamic Dose
  final bool? isDynamic;
  final String? dynamicInstruction;

  // Taper (Desmame)
  final int? taperStageCount;
  final int? taperCurrentStage;
  final int? taperDayInStage;
  final List<TaperStage>? taperStages;
  final bool? taperLoop;

  // Special Instruction
  final String? specialInstruction;

  // Adjustment
  final double? adjustStep;
  final int? adjustIntervalDays;
  final double? adjustLimit;

  // Removal & Rotation
  final bool? requiresRemoval;
  final int? removalDelayMins;
  final String? siteRotationList;
  final int? currentSiteIndex;

  // Date and Time Grouping
  final int? dayOfMonth;
  final int? groupId;
  final int? intervalHours;
  final int? intervalDays;
  final int? intervalCountdown;

  // Sync Control (local only)
  final int? lastModified;
  final bool pendingSync;
  final bool isGhost;

  // Computed/Render fields
  final int? doseNum;
  final int? doseTotal;

  const AlarmModel({
    required this.id,
    required this.hour,
    required this.minute,
    required this.name,
    required this.medName,
    required this.enabled,
    required this.active,
    required this.days,
    required this.status,
    required this.color,
    required this.quantity,
    required this.daysQuantity,
    required this.type,
    this.dosage,
    this.lastStatus,
    this.lastStatusDate,
    required this.snoozeMin,
    this.startDate,
    required this.durationDays,
    this.createdDate,
    this.cycleOnDays,
    this.cycleOffDays,
    this.cycleCurrentDay,
    this.cycleIsPaused,
    this.isPrn,
    this.prnMinIntervalHours,
    this.prnMaxDailyDoses,
    this.prnDosesToday,
    this.pauseUntil,
    this.isDynamic,
    this.dynamicInstruction,
    this.taperStageCount,
    this.taperCurrentStage,
    this.taperDayInStage,
    this.taperStages,
    this.taperLoop,
    this.specialInstruction,
    this.adjustStep,
    this.adjustIntervalDays,
    this.adjustLimit,
    this.requiresRemoval,
    this.removalDelayMins,
    this.siteRotationList,
    this.currentSiteIndex,
    this.dayOfMonth,
    this.groupId,
    this.intervalHours,
    this.intervalDays,
    this.intervalCountdown,
    this.lastModified,
    this.pendingSync = false,
    this.isGhost = false,
    this.doseNum,
    this.doseTotal,
  });

  AlarmModel copyWith({
    int? id,
    int? hour,
    int? minute,
    String? name,
    String? medName,
    bool? enabled,
    bool? active,
    List<bool>? days,
    String? status,
    String? color,
    double? quantity,
    List<double>? daysQuantity,
    String? type,
    String? dosage,
    String? lastStatus,
    String? lastStatusDate,
    int? snoozeMin,
    String? startDate,
    int? durationDays,
    String? createdDate,
    int? cycleOnDays,
    int? cycleOffDays,
    int? cycleCurrentDay,
    bool? cycleIsPaused,
    bool? isPrn,
    int? prnMinIntervalHours,
    int? prnMaxDailyDoses,
    int? prnDosesToday,
    int? pauseUntil,
    bool? isDynamic,
    String? dynamicInstruction,
    int? taperStageCount,
    int? taperCurrentStage,
    int? taperDayInStage,
    List<TaperStage>? taperStages,
    bool? taperLoop,
    String? specialInstruction,
    double? adjustStep,
    int? adjustIntervalDays,
    double? adjustLimit,
    bool? requiresRemoval,
    int? removalDelayMins,
    String? siteRotationList,
    int? currentSiteIndex,
    int? dayOfMonth,
    int? groupId,
    int? intervalHours,
    int? intervalDays,
    int? intervalCountdown,
    int? lastModified,
    bool? pendingSync,
    bool? isGhost,
    int? doseNum,
    int? doseTotal,
  }) {
    return AlarmModel(
      id: id ?? this.id,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      name: name ?? this.name,
      medName: medName ?? this.medName,
      enabled: enabled ?? this.enabled,
      active: active ?? this.active,
      days: days ?? this.days,
      status: status ?? this.status,
      color: color ?? this.color,
      quantity: quantity ?? this.quantity,
      daysQuantity: daysQuantity ?? this.daysQuantity,
      type: type ?? this.type,
      dosage: dosage ?? this.dosage,
      lastStatus: lastStatus ?? this.lastStatus,
      lastStatusDate: lastStatusDate ?? this.lastStatusDate,
      snoozeMin: snoozeMin ?? this.snoozeMin,
      startDate: startDate ?? this.startDate,
      durationDays: durationDays ?? this.durationDays,
      createdDate: createdDate ?? this.createdDate,
      cycleOnDays: cycleOnDays ?? this.cycleOnDays,
      cycleOffDays: cycleOffDays ?? this.cycleOffDays,
      cycleCurrentDay: cycleCurrentDay ?? this.cycleCurrentDay,
      cycleIsPaused: cycleIsPaused ?? this.cycleIsPaused,
      isPrn: isPrn ?? this.isPrn,
      prnMinIntervalHours: prnMinIntervalHours ?? this.prnMinIntervalHours,
      prnMaxDailyDoses: prnMaxDailyDoses ?? this.prnMaxDailyDoses,
      prnDosesToday: prnDosesToday ?? this.prnDosesToday,
      pauseUntil: pauseUntil ?? this.pauseUntil,
      isDynamic: isDynamic ?? this.isDynamic,
      dynamicInstruction: dynamicInstruction ?? this.dynamicInstruction,
      taperStageCount: taperStageCount ?? this.taperStageCount,
      taperCurrentStage: taperCurrentStage ?? this.taperCurrentStage,
      taperDayInStage: taperDayInStage ?? this.taperDayInStage,
      taperStages: taperStages ?? this.taperStages,
      taperLoop: taperLoop ?? this.taperLoop,
      specialInstruction: specialInstruction ?? this.specialInstruction,
      adjustStep: adjustStep ?? this.adjustStep,
      adjustIntervalDays: adjustIntervalDays ?? this.adjustIntervalDays,
      adjustLimit: adjustLimit ?? this.adjustLimit,
      requiresRemoval: requiresRemoval ?? this.requiresRemoval,
      removalDelayMins: removalDelayMins ?? this.removalDelayMins,
      siteRotationList: siteRotationList ?? this.siteRotationList,
      currentSiteIndex: currentSiteIndex ?? this.currentSiteIndex,
      dayOfMonth: dayOfMonth ?? this.dayOfMonth,
      groupId: groupId ?? this.groupId,
      intervalHours: intervalHours ?? this.intervalHours,
      intervalDays: intervalDays ?? this.intervalDays,
      intervalCountdown: intervalCountdown ?? this.intervalCountdown,
      lastModified: lastModified ?? this.lastModified,
      pendingSync: pendingSync ?? this.pendingSync,
      isGhost: isGhost ?? this.isGhost,
      doseNum: doseNum ?? this.doseNum,
      doseTotal: doseTotal ?? this.doseTotal,
    );
  }

  factory AlarmModel.fromJson(Map<String, dynamic> json) {
    // Helper to parse double quantity
    double parseDouble(dynamic val) {
      if (val == null) return 0.0;
      return (val as num).toDouble();
    }

    // Parse days list (always 7 elements)
    List<bool> parseDays(dynamic list) {
      if (list == null || list is! List) return List.filled(7, true);
      return list.map((e) => e == true).toList();
    }

    // Parse days quantity list
    List<double> parseDaysQuantity(dynamic list) {
      if (list == null || list is! List) return List.filled(7, 0.0);
      return list.map((e) => parseDouble(e)).toList();
    }

    return AlarmModel(
      id: json['id'] as int,
      hour: json['hour'] as int,
      minute: json['minute'] as int,
      name: json['name'] as String? ?? '',
      medName: json['med_name'] as String? ?? json['name'] as String? ?? '',
      enabled: json['enabled'] == true,
      active: json['active'] == true,
      days: parseDays(json['days']),
      status: json['status'] as String? ?? 'PENDENTE',
      color: json['color'] as String? ?? 'blue',
      quantity: parseDouble(json['quantity']),
      daysQuantity: parseDaysQuantity(json['days_quantity']),
      type: json['type'] as String? ?? 'comprimido',
      dosage: json['dosage'] as String?,
      lastStatus: json['last_status'] as String?,
      lastStatusDate: json['last_status_date'] as String?,
      snoozeMin: json['snooze_min'] as int? ?? 0,
      startDate: json['start_date'] as String?,
      durationDays: json['duration_days'] as int? ?? 0,
      createdDate: json['created_date'] as String?,

      // Cycle
      cycleOnDays: json['cycle_on_days'] as int?,
      cycleOffDays: json['cycle_off_days'] as int?,
      cycleCurrentDay: json['cycle_current_day'] as int?,
      cycleIsPaused: json['cycle_is_paused'] as bool?,

      // PRN
      isPrn: json['is_prn'] as bool?,
      prnMinIntervalHours: json['prn_min_interval_hours'] as int?,
      prnMaxDailyDoses: json['prn_max_daily_doses'] as int?,
      prnDosesToday: json['prn_doses_today'] as int?,

      // Pause
      pauseUntil: json['pause_until'] as int?,

      // Dynamic
      isDynamic: json['is_dynamic'] as bool?,
      dynamicInstruction: json['dynamic_instruction'] as String?,

      // Taper
      taperStageCount: json['taper_stage_count'] as int?,
      taperCurrentStage: json['taper_current_stage'] as int?,
      taperDayInStage: json['taper_day_in_stage'] as int?,
      taperStages: json['taper_stages'] != null && json['taper_stages'] is List
          ? (json['taper_stages'] as List).map((e) => TaperStage.fromJson(e as Map<String, dynamic>)).toList()
          : null,
      taperLoop: json['taper_loop'] as bool?,

      // Special
      specialInstruction: json['special_instruction'] as String?,

      // Adjust
      adjustStep: json['adjust_step'] != null ? parseDouble(json['adjust_step']) : null,
      adjustIntervalDays: json['adjust_interval_days'] as int?,
      adjustLimit: json['adjust_limit'] != null ? parseDouble(json['adjust_limit']) : null,

      // Removal
      requiresRemoval: json['requires_removal'] as bool?,
      removalDelayMins: json['removal_delay_mins'] as int?,
      siteRotationList: json['site_rotation_list'] as String?,
      currentSiteIndex: json['current_site_index'] as int?,

      // Grouping
      dayOfMonth: json['day_of_month'] as int?,
      groupId: json['group_id'] as int?,
      intervalHours: json['interval_hours'] as int?,
      intervalDays: json['interval_days'] as int?,
      intervalCountdown: json['interval_countdown'] as int?,

      // Local only
      lastModified: json['last_modified'] as int?,
      pendingSync: json['pending_sync'] == true,
      isGhost: json['is_ghost'] == true,
    );
  }

  Map<String, dynamic> toJson({bool includeLocalFields = false}) {
    final Map<String, dynamic> data = {
      'id': id,
      'hour': hour,
      'minute': minute,
      'name': name,
      'med_name': medName,
      'enabled': enabled,
      'active': active,
      'days': days,
      'status': status,
      'color': color,
      'quantity': quantity,
      'days_quantity': daysQuantity,
      'type': type,
      'snooze_min': snoozeMin,
      'duration_days': durationDays,
    };

    if (dosage != null) data['dosage'] = dosage;
    if (lastStatus != null) data['last_status'] = lastStatus;
    if (lastStatusDate != null) data['last_status_date'] = lastStatusDate;
    if (startDate != null) data['start_date'] = startDate;
    if (createdDate != null) data['created_date'] = createdDate;

    // Cycle
    if (cycleOnDays != null && cycleOnDays! > 0) {
      data['cycle_on_days'] = cycleOnDays;
      data['cycle_off_days'] = cycleOffDays;
      data['cycle_current_day'] = cycleCurrentDay;
      data['cycle_is_paused'] = cycleIsPaused;
    }

    // PRN
    if (isPrn == true) {
      data['is_prn'] = true;
      data['prn_min_interval_hours'] = prnMinIntervalHours;
      data['prn_max_daily_doses'] = prnMaxDailyDoses;
      data['prn_doses_today'] = prnDosesToday;
    }

    // Pause
    if (pauseUntil != null && pauseUntil! > 0) {
      data['pause_until'] = pauseUntil;
    }

    // Dynamic
    if (isDynamic == true) {
      data['is_dynamic'] = true;
      data['dynamic_instruction'] = dynamicInstruction;
    }

    // Taper
    if (taperStageCount != null && taperStageCount! > 0) {
      data['taper_stage_count'] = taperStageCount;
      data['taper_current_stage'] = taperCurrentStage;
      data['taper_day_in_stage'] = taperDayInStage;
      data['taper_stages'] = taperStages?.map((e) => e.toJson()).toList();
      data['taper_loop'] = taperLoop;
    }

    // Special
    if (specialInstruction != null && specialInstruction!.isNotEmpty) {
      data['special_instruction'] = specialInstruction;
    }

    // Adjust
    if (adjustStep != null) {
      data['adjust_step'] = adjustStep;
      data['adjust_interval_days'] = adjustIntervalDays;
      data['adjust_limit'] = adjustLimit;
    }

    // Removal
    if (requiresRemoval == true) {
      data['requires_removal'] = true;
      data['removal_delay_mins'] = removalDelayMins;
      data['site_rotation_list'] = siteRotationList;
      data['current_site_index'] = currentSiteIndex;
    }

    // Grouping
    if (dayOfMonth != null && dayOfMonth! > 0) data['day_of_month'] = dayOfMonth;
    if (groupId != null && groupId! > 0) data['group_id'] = groupId;
    if (intervalHours != null && intervalHours! > 0) data['interval_hours'] = intervalHours;
    if (intervalDays != null && intervalDays! > 0) data['interval_days'] = intervalDays;
    if (intervalCountdown != null) data['interval_countdown'] = intervalCountdown;

    if (includeLocalFields) {
      if (lastModified != null) data['last_modified'] = lastModified;
      data['pending_sync'] = pendingSync;
      data['is_ghost'] = isGhost;
    }

    return data;
  }
}
