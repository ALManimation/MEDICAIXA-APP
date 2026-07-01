import '../../../core/constants/app_colors.dart';

class ReminderModel {
  final int id;
  final String title;
  final String description;
  final bool enabled;
  final bool hasTime;
  final int? hour;
  final int? minute;
  final String period; // day, week, month, year, or "" (once)
  final int interval;
  final String startDate; // "YYYY-MM-DD"
  final int notifyDaysBefore;
  final String? lastCompletedDate; // "DD/MM/YYYY" or null
  final String color;

  // Local sync fields
  final int? lastModified;
  final bool pendingSync;

  const ReminderModel({
    required this.id,
    required this.title,
    required this.description,
    required this.enabled,
    required this.hasTime,
    this.hour,
    this.minute,
    required this.period,
    required this.interval,
    required this.startDate,
    required this.notifyDaysBefore,
    this.lastCompletedDate,
    required this.color,
    this.lastModified,
    this.pendingSync = false,
  });

  factory ReminderModel.fromJson(Map<String, dynamic> json) {
    final rawColor = (json['color'] as String? ?? 'blue').toLowerCase();
    final validatedColor = AppColors.alarmColors.containsKey(rawColor) ? rawColor : 'blue';
    return ReminderModel(
      id: json['id'] as int,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      enabled: json['enabled'] == true,
      hasTime: json['has_time'] == true,
      hour: json['hour'] as int?,
      minute: json['minute'] as int?,
      period: json['period'] as String? ?? '',
      interval: json['interval'] as int? ?? 0,
      startDate: json['start_date'] as String? ?? '',
      notifyDaysBefore: json['notify_days_before'] as int? ?? 0,
      lastCompletedDate: json['last_completed_date'] as String?,
      color: validatedColor,
      lastModified: json['last_modified'] as int?,
      pendingSync: json['pending_sync'] == true,
    );
  }

  Map<String, dynamic> toJson({bool includeLocalFields = false}) {
    final Map<String, dynamic> data = {
      'id': id,
      'title': title,
      'description': description,
      'enabled': enabled,
      'has_time': hasTime,
      'period': period,
      'interval': interval,
      'start_date': startDate,
      'notify_days_before': notifyDaysBefore,
      'color': color,
    };

    if (hour != null) data['hour'] = hour;
    if (minute != null) data['minute'] = minute;
    if (lastCompletedDate != null) data['last_completed_date'] = lastCompletedDate;

    if (includeLocalFields) {
      if (lastModified != null) data['last_modified'] = lastModified;
      data['pending_sync'] = pendingSync;
    }

    return data;
  }

  static const Object _sentinel = Object();

  ReminderModel copyWith({
    Object? id = _sentinel,
    Object? title = _sentinel,
    Object? description = _sentinel,
    Object? enabled = _sentinel,
    Object? hasTime = _sentinel,
    Object? hour = _sentinel,
    Object? minute = _sentinel,
    Object? period = _sentinel,
    Object? interval = _sentinel,
    Object? startDate = _sentinel,
    Object? notifyDaysBefore = _sentinel,
    Object? lastCompletedDate = _sentinel,
    Object? color = _sentinel,
    Object? lastModified = _sentinel,
    Object? pendingSync = _sentinel,
  }) {
    return ReminderModel(
      id: id == _sentinel ? this.id : id as int,
      title: title == _sentinel ? this.title : title as String,
      description: description == _sentinel ? this.description : description as String,
      enabled: enabled == _sentinel ? this.enabled : enabled as bool,
      hasTime: hasTime == _sentinel ? this.hasTime : hasTime as bool,
      hour: hour == _sentinel ? this.hour : hour as int?,
      minute: minute == _sentinel ? this.minute : minute as int?,
      period: period == _sentinel ? this.period : period as String,
      interval: interval == _sentinel ? this.interval : interval as int,
      startDate: startDate == _sentinel ? this.startDate : startDate as String,
      notifyDaysBefore: notifyDaysBefore == _sentinel ? this.notifyDaysBefore : notifyDaysBefore as int,
      lastCompletedDate: lastCompletedDate == _sentinel ? this.lastCompletedDate : lastCompletedDate as String?,
      color: color == _sentinel ? this.color : color as String,
      lastModified: lastModified == _sentinel ? this.lastModified : lastModified as int?,
      pendingSync: pendingSync == _sentinel ? this.pendingSync : pendingSync as bool,
    );
  }
}
