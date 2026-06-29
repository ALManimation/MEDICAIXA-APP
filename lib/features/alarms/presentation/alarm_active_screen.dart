import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../core/constants/app_colors.dart';
import '../../dashboard/presentation/dashboard_notifier.dart';
import '../data/alarm_model.dart';
import '../data/alarm_repository.dart';
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

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _playAlarmSound();

    _pulsingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _pulsingController.dispose();
    super.dispose();
  }

  Future<void> _playAlarmSound() async {
    try {
      // Use a premium alarm sound URL with fallback
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.play(UrlSource(
        'https://actions.google.com/sounds/v1/alarms/digital_watch_alarm_long.ogg',
      ));
    } catch (e) {
      debugPrint('Could not play alarm sound: $e. Using system vibration.');
      // Fallback: trigger haptic feedback periodically
      _triggerPeriodicVibration();
    }
  }

  void _triggerPeriodicVibration() {
    Future.doWhile(() async {
      if (!context.mounted) return false;
      HapticFeedback.vibrate();
      await Future.delayed(const Duration(seconds: 2));
      return context.mounted;
    });
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
      if (customQty == null) return; // User cancelled
    }
    await repo.markTaken(alarm.id, customQty: customQty);
    ref.invalidate(dashboardNotifierProvider);
    _nextOrDismiss();
  }

  Future<void> _markSkipped(AlarmModel alarm) async {
    final repo = ref.read(alarmRepositoryProvider);
    await repo.markSkipped(alarm.id);
    ref.invalidate(dashboardNotifierProvider);
    _nextOrDismiss();
  }

  Future<void> _snooze(AlarmModel alarm, int minutes) async {
    final repo = ref.read(alarmRepositoryProvider);
    await repo.snoozeAlarm(alarm.id, minutes);
    ref.invalidate(dashboardNotifierProvider);
    _nextOrDismiss();
  }

  @override
  void didUpdateWidget(covariant AlarmActiveScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_currentAlarmIndex >= widget.activeAlarms.length) {
      setState(() {
        _currentAlarmIndex = widget.activeAlarms.isEmpty ? 0 : widget.activeAlarms.length - 1;
      });
    }
  }

  void _nextOrDismiss() {
    if (_currentAlarmIndex < widget.activeAlarms.length - 1) {
      setState(() {
        _currentAlarmIndex++;
      });
    } else {
      // All alarms processed, screen will be dismissed automatically by the activeAlarms stream provider
      _audioPlayer.stop();
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
