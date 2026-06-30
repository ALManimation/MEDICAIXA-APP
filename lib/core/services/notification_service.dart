import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:audioplayers/audioplayers.dart';
import 'package:medicaixa_app/core/database/database.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._internal();
  factory NotificationService() => instance;
  NotificationService._internal();

  AppDatabase? _db;
  set database(AppDatabase db) => _db = db;
  AppDatabase get database => _db ??= AppDatabase();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    // 1. Initialize Timezone Database
    await _configureLocalTimeZone();

    // 2. Configure Android Initialization Settings
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // 3. Configure Darwin (iOS / macOS) Initialization Settings
    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      requestCriticalPermission: true,
    );

    // 4. Combine Initialization Settings
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
      macOS: initializationSettingsDarwin,
    );

    // 5. Initialize the plugin
    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onDidReceiveNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: _onDidReceiveBackgroundNotificationResponse,
    );

    // 6. Request Android permissions if Android 13+ and create channel
    if (Platform.isAndroid) {
      final androidImplementation = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
              
      await androidImplementation?.requestNotificationsPermission();
      
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'medicaixa_alarms_channel',
        'MediCaixa Alarmes',
        description: 'Canal de notificações para alarmes de medicamentos',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        audioAttributesUsage: AudioAttributesUsage.alarm,
      );
      
      await androidImplementation?.createNotificationChannel(channel);
    }

    _initialized = true;
    debugPrint('NotificationService initialized successfully.');
  }

  Future<void> _configureLocalTimeZone() async {
    tz.initializeTimeZones();
    try {
      final timezoneInfo = await FlutterTimezone.getLocalTimezone();
      final String timeZoneName = timezoneInfo.identifier;
      tz.setLocalLocation(tz.getLocation(timeZoneName));
      debugPrint('Local timezone configured to: $timeZoneName');
    } catch (e) {
      debugPrint('Could not get local timezone: $e. Falling back to UTC.');
      tz.setLocalLocation(tz.UTC);
    }
  }

  // Handle tap on notification in foreground/background
  static void _onDidReceiveNotificationResponse(NotificationResponse details) {
    debugPrint('Notification tapped: id=${details.id}, payload=${details.payload}');
    // Here we can navigate to active alarm screen or handle user response.
  }

  // Handle background notification actions (must be static or top-level)
  @pragma('vm:entry-point')
  static void _onDidReceiveBackgroundNotificationResponse(NotificationResponse details) {
    debugPrint('Background notification action: id=${details.id}, action=${details.actionId}');
  }

  /// Schedule a notification for a specific time and days of week
  /// [id] Base ID of the alarm.
  /// [hour] hour (0-23)
  /// [minute] minute (0-59)
  /// [title] Notification title
  /// [body] Notification body
  /// [days] List of 7 booleans (Sun, Mon, Tue, Wed, Thu, Fri, Sat)
  /// [soundName] Optional custom sound filename in assets or native custom sound (sans extension)
  Future<void> scheduleWeeklyAlarm({
    required int id,
    required int hour,
    required int minute,
    required String title,
    required String body,
    required List<bool> days,
    String? soundName,
  }) async {
    await init(); // Ensure initialization

    // Cancel any existing notifications for this base alarm ID first
    await cancelAlarmNotifications(id);

    // Retrieve local settings
    int soundIndex = 0;
    bool vibration = true;
    try {
      final db = database;
      final settingsList = await db.select(db.settings).get();
      if (settingsList.isNotEmpty) {
        soundIndex = settingsList.first.localAlarmSound;
        vibration = settingsList.first.localVibrationEnabled;
      }
    } catch (e) {
      debugPrint('Error loading settings in scheduleWeeklyAlarm: $e');
    }

    String resolvedSound = 'alarm_alerta';
    switch (soundIndex) {
      case 0: resolvedSound = 'alarm_gentile'; break;
      case 1: resolvedSound = 'alarm_alerta'; break;
      case 2: resolvedSound = 'alarm_melodia'; break;
      case 3: resolvedSound = 'alarm_urgente'; break;
      case 4: resolvedSound = 'alarm_musical'; break;
    }

    final String darwinSound = '$resolvedSound.wav';
    final String androidSound = resolvedSound;

    final String channelId = 'medicaixa_alarms_v${soundIndex}_${vibration ? 'y' : 'n'}';

    if (Platform.isAndroid) {
      final androidImplementation = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      
      final channel = AndroidNotificationChannel(
        channelId,
        'MediCaixa Alarmes ($soundIndex)',
        description: 'Canal de notificações para alarmes de medicamentos',
        importance: Importance.max,
        playSound: true,
        enableVibration: vibration,
        sound: RawResourceAndroidNotificationSound(androidSound),
        audioAttributesUsage: AudioAttributesUsage.alarm,
      );
      
      await androidImplementation?.createNotificationChannel(channel);
    }

    final androidDetails = AndroidNotificationDetails(
      channelId,
      'MediCaixa Alarmes',
      channelDescription: 'Canal de notificações para alarmes de medicamentos',
      importance: Importance.max,
      priority: Priority.max,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      sound: RawResourceAndroidNotificationSound(androidSound),
      playSound: true,
      enableVibration: vibration,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
    );

    // iOS Critical Alerts: bypasses Ring/Silent switch and Do Not Disturb.
    // Requires the critical-alerts entitlement.
    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
      presentBadge: true,
      sound: darwinSound,
      categoryIdentifier: 'medicaixa_alarm_category',
      interruptionLevel: InterruptionLevel.critical,
    );

    // macOS Time-Sensitive Notifications:
    // macOS does not support standard iOS Critical Alerts during local development
    // without special provisioning profiles. Thus, macOS uses `InterruptionLevel.timeSensitive`
    // which allows the alarm to bypass Focus Modes/Do Not Disturb cleanly, ensuring
    // the user is notified even when macOS is in a quiet/work state.
    final macosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
      presentBadge: true,
      sound: darwinSound,
      categoryIdentifier: 'medicaixa_alarm_category',
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
      macOS: macosDetails,
    );

    final now = tz.TZDateTime.now(tz.local);

    // If no specific days are selected, or all are false, default to daily
    final bool hasActiveDays = days.contains(true);
    if (!hasActiveDays) {
      // Schedule once or daily
      final scheduleTime = _nextInstanceOfTime(hour, minute, now);
      try {
        await _notificationsPlugin.zonedSchedule(
          id, // Single notification
          title,
          body,
          scheduleTime,
          notificationDetails,
          androidScheduleMode: AndroidScheduleMode.alarmClock,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.time,
        );
        debugPrint('Scheduled daily/once alarm notification for $hour:$minute with ID: $id');
      } catch (e, stackTrace) {
        debugPrint('Error scheduling daily/once notification for $id: $e\n$stackTrace');
      }
      return;
    }

    // Schedule for each selected day of the week
    // Dart weekdays: 1 = Mon, 2 = Tue, ..., 7 = Sun.
    // days parameter: 0 = Sun, 1 = Mon, 2 = Tue, ..., 6 = Sat.
    for (int dayIndex = 0; dayIndex < 7; dayIndex++) {
      if (days[dayIndex]) {
        // Convert days index (0=Sun, 1=Mon, ..., 6=Sat) to timezone ISO weekday (1=Mon, ..., 7=Sun)
        final int isoWeekday = dayIndex == 0 ? 7 : dayIndex; 
        
        final scheduleTime = _nextInstanceOfWeekdayTime(isoWeekday, hour, minute, now);
        final notificationId = 100000 + id * 7 + dayIndex;

        try {
          await _notificationsPlugin.zonedSchedule(
            notificationId,
            title,
            body,
            scheduleTime,
            notificationDetails,
            androidScheduleMode: AndroidScheduleMode.alarmClock,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
          );
          debugPrint('Scheduled weekly alarm notification for weekday $dayIndex at $hour:$minute with ID: $notificationId');
        } catch (e, stackTrace) {
          debugPrint('Error scheduling notification for weekday $dayIndex: $e\n$stackTrace');
        }
      }
    }
  }

  /// Cancels all notifications scheduled for a specific alarm ID
  Future<void> cancelAlarmNotifications(int alarmId) async {
    await init();
    // Cancel the base notification (daily/once)
    await _notificationsPlugin.cancel(alarmId);
    
    // Cancel weekly day-specific notifications
    for (int dayIndex = 0; dayIndex < 7; dayIndex++) {
      await _notificationsPlugin.cancel(100000 + alarmId * 7 + dayIndex);
    }
    debugPrint('Cancelled all scheduled notifications for alarm ID: $alarmId');
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await init();
    await _notificationsPlugin.cancelAll();
    debugPrint('Cancelled all notifications.');
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute, tz.TZDateTime now) {
    tz.TZDateTime scheduledDate =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = tz.TZDateTime(
        tz.local,
        scheduledDate.year,
        scheduledDate.month,
        scheduledDate.day + 1,
        scheduledDate.hour,
        scheduledDate.minute,
      );
    }
    return scheduledDate;
  }

  tz.TZDateTime _nextInstanceOfWeekdayTime(
      int weekday, int hour, int minute, tz.TZDateTime now) {
    tz.TZDateTime scheduledDate = _nextInstanceOfTime(hour, minute, now);
    while (scheduledDate.weekday != weekday) {
      scheduledDate = tz.TZDateTime(
        tz.local,
        scheduledDate.year,
        scheduledDate.month,
        scheduledDate.day + 1,
        scheduledDate.hour,
        scheduledDate.minute,
      );
    }
    return scheduledDate;
  }

  /// Configure iOS AVAudioSession to playback and force sound to speaker
  Future<void> configureAudioSessionForPlayback() async {
    try {
      await AudioPlayer.global.setAudioContext(
        AudioContext(
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
            options: {
              AVAudioSessionOptions.mixWithOthers,
            },
          ),
          android: const AudioContextAndroid(
            isSpeakerphoneOn: true,
            stayAwake: true,
            contentType: AndroidContentType.music,
            usageType: AndroidUsageType.alarm,
            audioFocus: AndroidAudioFocus.gainTransient,
          ),
        ),
      );
      debugPrint('Global AudioContext configured successfully (playback).');
    } catch (e) {
      debugPrint('Error configuring AudioContext: $e');
    }
  }
}
