import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/database/database.dart';
import '../../../../../core/providers/core_providers.dart';
import '../wizard_notifier.dart';
import '../wizard_state.dart';

class WizardStep5Time extends ConsumerWidget {
  const WizardStep5Time({super.key});

  // Helper method to adjust time string by adding/subtracting minutes
  String _adjustTime(String? timeStr, int offsetMinutes, String defaultTime) {
    final target = (timeStr == null || timeStr.trim().isEmpty) ? defaultTime : timeStr;
    final parts = target.split(':');
    if (parts.length != 2) return defaultTime;
    final hour = int.tryParse(parts[0]) ?? 8;
    final minute = int.tryParse(parts[1]) ?? 0;

    final totalMinutes = (hour * 60 + minute + offsetMinutes + 1440) % 1440;
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    return "${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(wizardNotifierProvider);
    final notifier = ref.read(wizardNotifierProvider.notifier);
    final db = ref.read(databaseProvider);

    return StreamBuilder<Setting?>(
      stream: db.select(db.settings).watchSingleOrNull(),
      builder: (context, snapshot) {
        final settings = snapshot.data;

        // Calculate dynamic times based on patient settings
        final wakeTimeStr = _adjustTime(settings?.wakeTime, 5, '07:00');
        final sleepTimeStr = _adjustTime(settings?.sleepTime, -10, '23:00');

        final breakfastTime = settings?.breakfastTime ?? '08:00';
        final breakfastBeforeStr = _adjustTime(breakfastTime, -30, '08:00');
        final breakfastAfterStr = _adjustTime(breakfastTime, 30, '08:00');

        final lunchTime = settings?.lunchTime ?? '12:00';
        final lunchBeforeStr = _adjustTime(lunchTime, -30, '12:00');
        final lunchAfterStr = _adjustTime(lunchTime, 30, '12:00');

        final dinnerTime = settings?.dinnerTime ?? '20:00';
        final dinnerBeforeStr = _adjustTime(dinnerTime, -30, '20:00');
        final dinnerAfterStr = _adjustTime(dinnerTime, 30, '20:00');

        // Presets list definition (always show all 8 presets, matching C++)
        final presets = [
          {'id': 'wake', 'icon': '🌅', 'title': 'Logo ao acordar', 'time': wakeTimeStr},
          {'id': 'sleep', 'icon': '🌙', 'title': 'Antes de deitar', 'time': sleepTimeStr},
          {'id': 'breakfast_before', 'icon': '🍳', 'title': 'Antes do Café', 'time': breakfastBeforeStr},
          {'id': 'breakfast_after', 'icon': '☕', 'title': 'Depois do Café', 'time': breakfastAfterStr},
          {'id': 'lunch_before', 'icon': '🍲', 'title': 'Antes do Almoço', 'time': lunchBeforeStr},
          {'id': 'lunch_after', 'icon': '🍽️', 'title': 'Depois do Almoço', 'time': lunchAfterStr},
          {'id': 'dinner_before', 'icon': '🍕', 'title': 'Antes do Jantar', 'time': dinnerBeforeStr},
          {'id': 'dinner_after', 'icon': '🥣', 'title': 'Depois do Jantar', 'time': dinnerAfterStr},
        ];

        final isIntervalMode = state.daysMode == 'interval';
        final titleText = isIntervalMode
            ? 'Que horas vai ser o seu PRIMEIRO remédio de hoje?'
            : 'A que horas a caixinha deve apitar?';

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 1. Título
              Text(
                titleText,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // 2. Grid de Presets
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final isMobile = width < 600;

                  int crossAxisCount = 2;
                  double childAspectRatio = 1.35;

                  if (width >= 900) {
                    crossAxisCount = 4;
                    childAspectRatio = 2.4;
                  } else if (width >= 600) {
                    crossAxisCount = 3;
                    childAspectRatio = 2.0;
                  }

                  return Column(
                    children: [
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          childAspectRatio: childAspectRatio,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemCount: presets.length,
                        itemBuilder: (context, index) {
                          return _buildPresetCard(presets[index], state, notifier, isMobile);
                        },
                      ),
                      const SizedBox(height: 8),

                      // Card para escolha customizada (Escolher outro horário)
                      GestureDetector(
                        onTap: () {
                          notifier.updateState((s) => s.copyWith(timePreset: 'custom'));
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: state.timePreset == 'custom' ? AppColors.primary : AppColors.border,
                              width: 1.5,
                            ),
                            boxShadow: state.timePreset == 'custom'
                                ? [
                                    BoxShadow(
                                      color: AppColors.primary.withOpacity(0.12),
                                      blurRadius: 6,
                                      spreadRadius: 1,
                                    )
                                  ]
                                : null,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('🕒', style: TextStyle(fontSize: 26)),
                              const SizedBox(width: 12),
                              Text(
                                'Escolher outro horário específico',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.text,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),

              // 3. Inputs customizados de horas se "custom" estiver selecionado
              if (state.timePreset == 'custom') ...[
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      // Lista de Linhas de Horário
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: state.customTimes.length,
                        itemBuilder: (context, idx) {
                          final timeVal = state.customTimes[idx];

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Botão Seletor de Hora
                                GestureDetector(
                                  onTap: () async {
                                    final parts = timeVal.split(':');
                                    int initialHour = 8;
                                    int initialMinute = 0;
                                    if (parts.length == 2) {
                                      initialHour = int.tryParse(parts[0]) ?? 8;
                                      initialMinute = int.tryParse(parts[1]) ?? 0;
                                    }

                                    final selectedTime = await showTimePicker(
                                      context: context,
                                      initialTime: TimeOfDay(hour: initialHour, minute: initialMinute),
                                    );

                                    if (selectedTime != null) {
                                      final newHoursStr = selectedTime.hour.toString().padLeft(2, '0');
                                      final newMinutesStr = selectedTime.minute.toString().padLeft(2, '0');
                                      final newTimeStr = "$newHoursStr:$newMinutesStr";

                                      final updatedTimes = List<String>.from(state.customTimes);
                                      updatedTimes[idx] = newTimeStr;
                                      notifier.updateState((s) => s.copyWith(customTimes: updatedTimes));
                                    }
                                  },
                                  child: Container(
                                    width: 140,
                                    height: 55,
                                    decoration: BoxDecoration(
                                      color: AppColors.surface,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: AppColors.border, width: 1.5),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      timeVal,
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.text,
                                      ),
                                    ),
                                  ),
                                ),

                                // Botão de Excluir Horário (se houver mais de 1)
                                if (state.customTimes.length > 1) ...[
                                  const SizedBox(width: 10),
                                  GestureDetector(
                                    onTap: () {
                                      final updatedTimes = List<String>.from(state.customTimes);
                                      updatedTimes.removeAt(idx);
                                      notifier.updateState((s) => s.copyWith(customTimes: updatedTimes));
                                    },
                                    child: Container(
                                      width: 45,
                                      height: 55,
                                      decoration: BoxDecoration(
                                        color: AppColors.missed.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: AppColors.missed.withOpacity(0.4), width: 1.5),
                                      ),
                                      alignment: Alignment.center,
                                      child: Icon(
                                        Icons.close_rounded,
                                        color: AppColors.missed,
                                        size: 24,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),

                      // Botão de Adicionar outro horário (Escondido em modo Intervalo)
                      if (!isIntervalMode) ...[
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: () {
                            final lastTime = state.customTimes.isNotEmpty
                                ? state.customTimes[state.customTimes.length - 1]
                                : '08:00';
                            final parts = lastTime.split(':');
                            int h = 8;
                            int m = 0;
                            if (parts.length == 2) {
                              h = int.tryParse(parts[0]) ?? 8;
                              m = int.tryParse(parts[1]) ?? 0;
                            }

                            final nextH = (h + 4) % 24;
                            final nextTime =
                                "${nextH.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}";

                            final updatedTimes = List<String>.from(state.customTimes)..add(nextTime);
                            notifier.updateState((s) => s.copyWith(customTimes: updatedTimes));
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.text,
                            side: BorderSide(color: AppColors.border, width: 1.5),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          icon: const Icon(Icons.add, size: 18, color: AppColors.primary),
                          label: const Text(
                            'Adicionar outro horário',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ],
        ),
      );
    },
  );
}

  Widget _buildPresetCard(
    Map<String, String> p,
    WizardState state,
    WizardNotifier notifier,
    bool isMobile,
  ) {
    final isSelected = state.timePreset == p['id'];

    return GestureDetector(
      onTap: () {
        notifier.updateState((s) => s.copyWith(
              timePreset: p['id']!,
              customTimes: [p['time']!],
            ));
      },
      child: Container(
        padding: EdgeInsets.symmetric(
          vertical: isMobile ? 8 : 10,
          horizontal: isMobile ? 8 : 12,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.12),
                    blurRadius: 6,
                    spreadRadius: 1,
                  )
                ]
              : null,
        ),
        child: isMobile
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(p['icon']!, style: const TextStyle(fontSize: 22)),
                  const SizedBox(height: 4),
                  Text(
                    p['title']!,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: AppColors.text,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "Cerca de ${p['time']}",
                    style: const TextStyle(
                      fontSize: 9.5,
                      color: AppColors.textMuted,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              )
            : Row(
                children: [
                  Text(p['icon']!, style: const TextStyle(fontSize: 28)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          p['title']!,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: AppColors.text,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Cerca de ${p['time']}",
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
