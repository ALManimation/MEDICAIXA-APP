
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

  static const Object _sentinel = Object();

  AlarmModel copyWith({
    Object? id = _sentinel,
    Object? hour = _sentinel,
    Object? minute = _sentinel,
    Object? name = _sentinel,
    Object? medName = _sentinel,
    Object? enabled = _sentinel,
    Object? active = _sentinel,
    Object? days = _sentinel,
    Object? status = _sentinel,
    Object? color = _sentinel,
    Object? quantity = _sentinel,
    Object? daysQuantity = _sentinel,
    Object? type = _sentinel,
    Object? dosage = _sentinel,
    Object? lastStatus = _sentinel,
    Object? lastStatusDate = _sentinel,
    Object? snoozeMin = _sentinel,
    Object? startDate = _sentinel,
    Object? durationDays = _sentinel,
    Object? createdDate = _sentinel,
    Object? cycleOnDays = _sentinel,
    Object? cycleOffDays = _sentinel,
    Object? cycleCurrentDay = _sentinel,
    Object? cycleIsPaused = _sentinel,
    Object? isPrn = _sentinel,
    Object? prnMinIntervalHours = _sentinel,
    Object? prnMaxDailyDoses = _sentinel,
    Object? prnDosesToday = _sentinel,
    Object? pauseUntil = _sentinel,
    Object? isDynamic = _sentinel,
    Object? dynamicInstruction = _sentinel,
    Object? taperStageCount = _sentinel,
    Object? taperCurrentStage = _sentinel,
    Object? taperDayInStage = _sentinel,
    Object? taperStages = _sentinel,
    Object? taperLoop = _sentinel,
    Object? specialInstruction = _sentinel,
    Object? adjustStep = _sentinel,
    Object? adjustIntervalDays = _sentinel,
    Object? adjustLimit = _sentinel,
    Object? requiresRemoval = _sentinel,
    Object? removalDelayMins = _sentinel,
    Object? siteRotationList = _sentinel,
    Object? currentSiteIndex = _sentinel,
    Object? dayOfMonth = _sentinel,
    Object? groupId = _sentinel,
    Object? intervalHours = _sentinel,
    Object? intervalDays = _sentinel,
    Object? intervalCountdown = _sentinel,
    Object? lastModified = _sentinel,
    Object? pendingSync = _sentinel,
    Object? isGhost = _sentinel,
    Object? doseNum = _sentinel,
    Object? doseTotal = _sentinel,
  }) {
    return AlarmModel(
      id: id == _sentinel ? this.id : id as int,
      hour: hour == _sentinel ? this.hour : hour as int,
      minute: minute == _sentinel ? this.minute : minute as int,
      name: name == _sentinel ? this.name : name as String,
      medName: medName == _sentinel ? this.medName : medName as String,
      enabled: enabled == _sentinel ? this.enabled : enabled as bool,
      active: active == _sentinel ? this.active : active as bool,
      days: days == _sentinel ? this.days : days as List<bool>,
      status: status == _sentinel ? this.status : status as String,
      color: color == _sentinel ? this.color : color as String,
      quantity: quantity == _sentinel ? this.quantity : quantity as double,
      daysQuantity: daysQuantity == _sentinel ? this.daysQuantity : daysQuantity as List<double>,
      type: type == _sentinel ? this.type : type as String,
      dosage: dosage == _sentinel ? this.dosage : dosage as String?,
      lastStatus: lastStatus == _sentinel ? this.lastStatus : lastStatus as String?,
      lastStatusDate: lastStatusDate == _sentinel ? this.lastStatusDate : lastStatusDate as String?,
      snoozeMin: snoozeMin == _sentinel ? this.snoozeMin : snoozeMin as int,
      startDate: startDate == _sentinel ? this.startDate : startDate as String?,
      durationDays: durationDays == _sentinel ? this.durationDays : durationDays as int,
      createdDate: createdDate == _sentinel ? this.createdDate : createdDate as String?,
      cycleOnDays: cycleOnDays == _sentinel ? this.cycleOnDays : cycleOnDays as int?,
      cycleOffDays: cycleOffDays == _sentinel ? this.cycleOffDays : cycleOffDays as int?,
      cycleCurrentDay: cycleCurrentDay == _sentinel ? this.cycleCurrentDay : cycleCurrentDay as int?,
      cycleIsPaused: cycleIsPaused == _sentinel ? this.cycleIsPaused : cycleIsPaused as bool?,
      isPrn: isPrn == _sentinel ? this.isPrn : isPrn as bool?,
      prnMinIntervalHours: prnMinIntervalHours == _sentinel ? this.prnMinIntervalHours : prnMinIntervalHours as int?,
      prnMaxDailyDoses: prnMaxDailyDoses == _sentinel ? this.prnMaxDailyDoses : prnMaxDailyDoses as int?,
      prnDosesToday: prnDosesToday == _sentinel ? this.prnDosesToday : prnDosesToday as int?,
      pauseUntil: pauseUntil == _sentinel ? this.pauseUntil : pauseUntil as int?,
      isDynamic: isDynamic == _sentinel ? this.isDynamic : isDynamic as bool?,
      dynamicInstruction: dynamicInstruction == _sentinel ? this.dynamicInstruction : dynamicInstruction as String?,
      taperStageCount: taperStageCount == _sentinel ? this.taperStageCount : taperStageCount as int?,
      taperCurrentStage: taperCurrentStage == _sentinel ? this.taperCurrentStage : taperCurrentStage as int?,
      taperDayInStage: taperDayInStage == _sentinel ? this.taperDayInStage : taperDayInStage as int?,
      taperStages: taperStages == _sentinel ? this.taperStages : taperStages as List<TaperStage>?,
      taperLoop: taperLoop == _sentinel ? this.taperLoop : taperLoop as bool?,
      specialInstruction: specialInstruction == _sentinel ? this.specialInstruction : specialInstruction as String?,
      adjustStep: adjustStep == _sentinel ? this.adjustStep : adjustStep as double?,
      adjustIntervalDays: adjustIntervalDays == _sentinel ? this.adjustIntervalDays : adjustIntervalDays as int?,
      adjustLimit: adjustLimit == _sentinel ? this.adjustLimit : adjustLimit as double?,
      requiresRemoval: requiresRemoval == _sentinel ? this.requiresRemoval : requiresRemoval as bool?,
      removalDelayMins: removalDelayMins == _sentinel ? this.removalDelayMins : removalDelayMins as int?,
      siteRotationList: siteRotationList == _sentinel ? this.siteRotationList : siteRotationList as String?,
      currentSiteIndex: currentSiteIndex == _sentinel ? this.currentSiteIndex : currentSiteIndex as int?,
      dayOfMonth: dayOfMonth == _sentinel ? this.dayOfMonth : dayOfMonth as int?,
      groupId: groupId == _sentinel ? this.groupId : groupId as int?,
      intervalHours: intervalHours == _sentinel ? this.intervalHours : intervalHours as int?,
      intervalDays: intervalDays == _sentinel ? this.intervalDays : intervalDays as int?,
      intervalCountdown: intervalCountdown == _sentinel ? this.intervalCountdown : intervalCountdown as int?,
      lastModified: lastModified == _sentinel ? this.lastModified : lastModified as int?,
      pendingSync: pendingSync == _sentinel ? this.pendingSync : pendingSync as bool,
      isGhost: isGhost == _sentinel ? this.isGhost : isGhost as bool,
      doseNum: doseNum == _sentinel ? this.doseNum : doseNum as int?,
      doseTotal: doseTotal == _sentinel ? this.doseTotal : doseTotal as int?,
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
