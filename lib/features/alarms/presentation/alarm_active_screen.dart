import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/constants/app_colors.dart';
import '../../dashboard/presentation/dashboard_notifier.dart';
import '../data/alarm_model.dart';
import '../data/alarm_repository.dart';
import '../../settings/data/settings_repository.dart';
import 'widgets/dynamic_dose_dialog.dart';

class AlarmActiveScreen extends ConsumerStatefulWidget {
  final List<AlarmModel> activeAlarms;

  const AlarmActiveScreen({
    super.key,
    required this.activeAlarms,
  });

  @override
  ConsumerState<AlarmActiveScreen> createState() => _AlarmActiveScreenState();
}

class _AlarmActiveScreenState extends ConsumerState<AlarmActiveScreen>
    with SingleTickerProviderStateMixin {
  late AudioPlayer _audioPlayer;
  late AnimationController _pulsingController;
  int _currentAlarmIndex = 0;
  static const _appNapChannel = MethodChannel('com.medicaixa.app/app_nap');

  Timer? _timeoutTimer;
  Timer? _vibrationTimer;
  Timer? _fallbackVibrationTimer;
  int _localAlarmSound = 0;
  int _localAlarmVolume = 70;
  bool _localVibrationEnabled = true;
  int _localAlarmDurationMins = 2;
  bool _soundPlayingSucceeded = false;
  bool _vibrationLoopStarted = false;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _pulsingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    _initAlarmState();
    _startAppNapPrevention();
  }

  void _maybeStartVibrationLoop() {
    if (!mounted) return;
    if (!_localVibrationEnabled) return;
    if (_vibrationLoopStarted) return;
    _vibrationLoopStarted = true;
    _startVibrationLoop();
  }

  Future<void> _initAlarmState() async {
    try {
      final repo = ref.read(settingsRepositoryProvider);
      final settings = await repo.getSettings();
      _localAlarmSound = settings.localAlarmSound;
      _localAlarmVolume = settings.localAlarmVolume;
      _localVibrationEnabled = settings.localVibrationEnabled;
      _localAlarmDurationMins = settings.localAlarmDurationMins;

      await _audioPlayer.setVolume(_localAlarmVolume / 100.0);
    } catch (e) {
      debugPrint('Error loading settings in AlarmActiveScreen: $e');
    }

    _maybeStartVibrationLoop();

    await _playAlarmSound();

    if (mounted) {
      _startTimeoutTimer();
      _maybeStartVibrationLoop();
    }
  }

  void _startTimeoutTimer() {
    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(Duration(minutes: _localAlarmDurationMins), () async {
      if (!mounted) return;
      
      final repo = ref.read(alarmRepositoryProvider);
      for (int i = _currentAlarmIndex; i < widget.activeAlarms.length; i++) {
        final alarm = widget.activeAlarms[i];
        final minutes = alarm.snoozeMin > 0 ? alarm.snoozeMin : 10;
        await repo.snoozeAlarm(alarm.id, minutes);
      }
      
      if (!mounted) return;
      ref.invalidate(dashboardNotifierProvider);
      
      _audioPlayer.stop();
      _stopAppNapPrevention();
    });
  }

  void _startVibrationLoop() {
    if (!_localVibrationEnabled) return;
    _vibrateAndSchedule();
  }

  void _vibrateAndSchedule() {
    if (!mounted || !_localVibrationEnabled) return;
    try {
      HapticFeedback.vibrate();
    } catch (e) {
      debugPrint('HapticFeedback.vibrate failed: $e');
    }
    _vibrationTimer?.cancel();
    _vibrationTimer = Timer(const Duration(seconds: 2), _vibrateAndSchedule);
  }

  Future<void> _startAppNapPrevention() async {
    if (Platform.isMacOS) {
      try {
        await _appNapChannel.invokeMethod('start');
        debugPrint('App Nap prevention started.');
      } catch (e) {
        debugPrint('Failed to start App Nap prevention: $e');
      }
    }
  }

  Future<void> _stopAppNapPrevention() async {
    if (Platform.isMacOS) {
      try {
        await _appNapChannel.invokeMethod('stop');
        debugPrint('App Nap prevention stopped.');
      } catch (e) {
        debugPrint('Failed to stop App Nap prevention: $e');
      }
    }
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    _vibrationTimer?.cancel();
    _fallbackVibrationTimer?.cancel();
    _audioPlayer.dispose();
    _pulsingController.dispose();
    _stopAppNapPrevention();
    super.dispose();
  }

  Future<void> _playAlarmSound() async {
    try {
      await NotificationService.instance.configureAudioSessionForPlayback();
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.setVolume(_localAlarmVolume / 100.0);
    } catch (e) {
      debugPrint('Error configuring audio session/release mode/volume: $e');
    }

    _soundPlayingSucceeded = false;

    // Use sound choices corresponding to generated buzzer melody files
    String soundPath = 'sounds/alarm_alerta.wav';
    switch (_localAlarmSound) {
      case 0: soundPath = 'sounds/alarm_gentile.wav'; break;
      case 1: soundPath = 'sounds/alarm_alerta.wav'; break;
      case 2: soundPath = 'sounds/alarm_melodia.wav'; break;
      case 3: soundPath = 'sounds/alarm_urgente.wav'; break;
      case 4: soundPath = 'sounds/alarm_musical.wav'; break;
    }

    try {
      await _audioPlayer.play(AssetSource(soundPath));
      debugPrint('Playing local asset sound: $soundPath');
      _soundPlayingSucceeded = true;
      _maybeStartVibrationLoop();
    } catch (assetError) {
      debugPrint('Could not play local asset: $assetError. Trying remote URL fallback.');
      try {
        await _audioPlayer.play(UrlSource(
          'https://actions.google.com/sounds/v1/alarms/digital_watch_alarm_long.ogg',
        ));
        _soundPlayingSucceeded = true;
        _maybeStartVibrationLoop();
      } catch (remoteError) {
        debugPrint('Could not play remote URL fallback sound: $remoteError');
      }
    }

    if (!_soundPlayingSucceeded) {
      debugPrint('All audio players failed. Falling back to system vibration and system sound.');
      _triggerPeriodicVibration();
    }
  }

  void _triggerPeriodicVibration() {
    _vibrateFallbackAndSchedule();
  }

  void _vibrateFallbackAndSchedule() async {
    if (!mounted) return;
    if (_localVibrationEnabled) {
      try {
        await HapticFeedback.vibrate();
      } catch (e) {
        debugPrint('HapticFeedback.vibrate failed: $e');
      }
    }
    try {
      await SystemSound.play(SystemSoundType.alert);
    } catch (e) {
      debugPrint('SystemSound.play failed: $e');
    }
    if (!mounted) return;
    _fallbackVibrationTimer?.cancel();
    _fallbackVibrationTimer = Timer(const Duration(seconds: 2), _vibrateFallbackAndSchedule);
  }

  IconData _getMedicationIcon(String type) {
    switch (type.toLowerCase()) {
      case 'comprimido':
        return Icons.circle_outlined;
      case 'capsula':
        return Icons.hexagon_outlined;
      case 'gota':
        return Icons.water_drop_rounded;
      case 'xarope':
        return Icons.wine_bar_rounded;
      case 'inalador':
        return Icons.air_rounded;
      case 'injetavel':
        return Icons.vaccines_rounded;
      case 'pomada':
        return Icons.clean_hands_rounded;
      default:
        return Icons.medication_rounded;
    }
  }

  Future<void> _markTaken(AlarmModel alarm) async {
    final repo = ref.read(alarmRepositoryProvider);
    double? customQty;
    if (alarm.isDynamic == true) {
      customQty = await DynamicDoseDialog.show(context, alarm);
      if (!context.mounted) return;
      if (customQty == null) return; // User cancelled
    }
    await repo.markTaken(alarm.id, customQty: customQty);
    if (!context.mounted) return;
    ref.invalidate(dashboardNotifierProvider);
  }

  Future<void> _markSkipped(AlarmModel alarm) async {
    final repo = ref.read(alarmRepositoryProvider);
    await repo.markSkipped(alarm.id);
    if (!context.mounted) return;
    ref.invalidate(dashboardNotifierProvider);
  }

  Future<void> _snooze(AlarmModel alarm, int minutes) async {
    final repo = ref.read(alarmRepositoryProvider);
    await repo.snoozeAlarm(alarm.id, minutes);
    if (!context.mounted) return;
    ref.invalidate(dashboardNotifierProvider);
  }

  @override
  void didUpdateWidget(covariant AlarmActiveScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.activeAlarms.length != oldWidget.activeAlarms.length) {
      setState(() {
        _currentAlarmIndex = 0;
      });
      _startTimeoutTimer();
      _playAlarmSound();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.activeAlarms.isEmpty) return const SizedBox.shrink();

    // Clamp the index with safety to prevent RangeErrors during reactive rebuilds
    final safeIndex = _currentAlarmIndex.clamp(0, widget.activeAlarms.length - 1);
    final alarm = widget.activeAlarms[safeIndex];
    final alarmColor = AppColors.getAlarmColor(alarm.color);

    // Calculate current dose quantity based on weekday
    final now = DateTime.now();
    final wday = now.weekday % 7;
    final hasAsymmetric = alarm.daysQuantity.any((q) => q > 0);
    final double qtyToShow = (hasAsymmetric && wday < alarm.daysQuantity.length && alarm.daysQuantity[wday] > 0)
        ? alarm.daysQuantity[wday]
        : alarm.quantity;
    final qtyStr = qtyToShow == qtyToShow.toInt() ? qtyToShow.toInt().toString() : qtyToShow.toStringAsFixed(1);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _pulsingController,
          builder: (context, child) {
            return Container(
              width: double.infinity,
              height: double.infinity,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    alarmColor.withValues(alpha: 0.25 * (1.0 - _pulsingController.value)),
                    Colors.black,
                  ],
                  radius: 1.2,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
              child: child,
            );
          },
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Header
              Column(
                children: [
                  const SizedBox(height: 20),
                  Text(
                    'HORA DO MEDICAMENTO',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3.0,
                      color: alarmColor,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${alarm.hour.toString().padLeft(2, '0')}:${alarm.minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(
                      fontSize: 64,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),

              // Med Card info
              Column(
                children: [
                  AnimatedBuilder(
                    animation: _pulsingController,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: 1.0 + (_pulsingController.value * 0.08),
                        child: child,
                      );
                    },
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: alarmColor.withValues(alpha: 0.15),
                        border: Border.all(color: alarmColor, width: 3.5),
                        boxShadow: [
                          BoxShadow(
                            color: alarmColor.withValues(alpha: 0.3),
                            blurRadius: 30,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Icon(
                        _getMedicationIcon(alarm.type),
                        size: 60,
                        color: alarmColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  Text(
                    alarm.medName.isNotEmpty ? alarm.medName : alarm.name,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Dose: $qtyStr ${alarm.type}${alarm.dosage != null && alarm.dosage!.isNotEmpty ? ' (${alarm.dosage})' : ''}',
                    style: TextStyle(
                      fontSize: 18,
                      color: AppColors.textMuted,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (alarm.specialInstruction != null && alarm.specialInstruction!.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.info_outline_rounded, size: 16, color: alarmColor),
                          const SizedBox(width: 8),
                          Text(
                            alarm.specialInstruction!,
                            style: const TextStyle(fontSize: 13, color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (alarm.requiresRemoval == true && alarm.siteRotationList != null && alarm.siteRotationList!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      child: Builder(
                        builder: (context) {
                          final sites = alarm.siteRotationList!.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
                          final nextSite = sites.isNotEmpty ? sites[(alarm.currentSiteIndex ?? 0) % sites.length] : '';
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.place_rounded, size: 16, color: alarmColor),
                              const SizedBox(width: 8),
                              Text(
                                'Aplicar em: $nextSite',
                                style: const TextStyle(fontSize: 13, color: Colors.white70),
                              ),
                            ],
                          );
                        }
                      ),
                    ),
                  ],
                ],
              ),

              // Action buttons
              Column(
                children: [
                  // Button: Tomei
                  ElevatedButton(
                    onPressed: () => _markTaken(alarm),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 64),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(32),
                      ),
                      elevation: 8,
                      shadowColor: AppColors.success.withValues(alpha: 0.4),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_rounded, size: 28),
                        SizedBox(width: 12),
                        Text(
                          'MARCAR COMO TOMADO',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1.2),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Buttons: Adiar and Pular
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _snooze(alarm, alarm.snoozeMin > 0 ? alarm.snoozeMin : 10),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.pending,
                            minimumSize: const Size(0, 56),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                            side: BorderSide(color: AppColors.pending, width: 2),
                          ),
                          icon: const Icon(Icons.snooze_rounded),
                          label: const Text(
                            'ADIAR 10 MIN',
                            style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.0),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _markSkipped(alarm),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.missed,
                            minimumSize: const Size(0, 56),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                            side: BorderSide(color: AppColors.missed, width: 2),
                          ),
                          icon: const Icon(Icons.close_rounded),
                          label: const Text(
                            'PULAR DOSE',
                            style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.0),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
