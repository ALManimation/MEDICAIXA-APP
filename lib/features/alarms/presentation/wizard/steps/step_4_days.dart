import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/constants/app_colors.dart';
import '../wizard_notifier.dart';
import '../wizard_state.dart';

class WizardStep4Days extends ConsumerWidget {
  const WizardStep4Days({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(wizardNotifierProvider);
    final notifier = ref.read(wizardNotifierProvider.notifier);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 1. Título
          Text(
            'Em quais dias você precisa usar esse remédio?',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.text,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // 2. Grid Responsivo de Modos
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final int crossAxisCount = width >= 800 ? 6 : (width >= 500 ? 3 : 2);
              final double childAspectRatio = width >= 800 ? 1.2 : (width >= 500 ? 1.3 : 1.15);

              final modes = [
                {'id': 'everyday', 'icon': '📅', 'title': 'Todos os dias', 'sub': 'Sem faltar nenhum dia'},
                {'id': 'interval', 'icon': '⏰', 'title': 'De horas em horas', 'sub': 'Ex: de 8 em 8h, 12 em 12h'},
                {'id': 'weekdays', 'icon': '🗓️', 'title': 'Dias específicos', 'sub': 'Ex: Segundas, quartas e sextas'},
                {'id': 'alternating', 'icon': '🔄', 'title': 'Espaçamento de dias', 'sub': 'Ex: Dia sim, dia não (48h)'},
                {'id': 'cycle', 'icon': '🌙', 'title': 'Uso com Pausa (Ciclo)', 'sub': 'Tomo por X dias e folgo Y dias'},
                {'id': 'monthly', 'icon': '📆', 'title': 'Uma vez por mês', 'sub': 'Sempre no mesmo dia do mês'},
              ];

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  childAspectRatio: childAspectRatio,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: modes.length,
                itemBuilder: (context, index) {
                  final m = modes[index];
                  final isSelected = state.daysMode == m['id'];

                  return GestureDetector(
                    onTap: () {
                      notifier.updateState((s) => s.copyWith(daysMode: m['id']!));
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
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
                                  color: AppColors.primary.withValues(alpha: 0.12),
                                  blurRadius: 6,
                                  spreadRadius: 1,
                                )
                              ]
                            : null,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(m['icon']!, style: const TextStyle(fontSize: 24)),
                          const SizedBox(height: 6),
                          Text(
                            m['title']!,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppColors.text,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 2),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4.0),
                            child: Text(
                              m['sub']!,
                              style: TextStyle(
                                fontSize: 9.5,
                                color: AppColors.textMuted,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),

          const SizedBox(height: 32),

          // 3. Conteúdo Dinâmico com base no Modo Selecionado
          if (state.daysMode == 'interval') _buildIntervalSection(state, notifier),
          if (state.daysMode == 'weekdays') _buildWeekdaysSection(state, notifier),
          if (state.daysMode == 'alternating') _buildAlternatingSection(state, notifier),
          if (state.daysMode == 'cycle') _buildCycleSection(state, notifier),
          if (state.daysMode == 'monthly') _buildMonthlySection(state, notifier),
        ],
      ),
    );
  }

  // --- 1. MODO DE HORAS EM HORAS ---
  Widget _buildIntervalSection(WizardState state, WizardNotifier notifier) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Text(
            'A caixinha deve apitar a cada:',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textMuted),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          _buildLargeStepper(
            value: state.intervalDays, // Usado no state para armazenar o intervalo em horas
            onChanged: (v) {
              notifier.updateState((s) => s.copyWith(intervalDays: v));
            },
            min: 2,
            max: 24,
            step: 2,
          ),
          const SizedBox(height: 12),
          Text(
            'Horas',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // --- 2. MODO DIAS ESPECÍFICOS (SEMANA) ---
  Widget _buildWeekdaysSection(WizardState state, WizardNotifier notifier) {
    final weekdaysNames = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];
    final weekdayValues = [1, 2, 3, 4, 5, 6, 7];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Selecione os dias da semana:',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textMuted),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final cols = width >= 450 ? 7 : 4;

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  childAspectRatio: width >= 450 ? 1.0 : 1.4,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: 7,
                itemBuilder: (context, index) {
                  final dayVal = weekdayValues[index];
                  final isSelected = state.weekdays.contains(dayVal);

                  return GestureDetector(
                    onTap: () {
                      final newWeekdays = Set<int>.from(state.weekdays);
                      if (newWeekdays.contains(dayVal)) {
                        newWeekdays.remove(dayVal);
                      } else {
                        newWeekdays.add(dayVal);
                      }
                      notifier.updateState((s) => s.copyWith(weekdays: newWeekdays));
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : AppColors.surface,
                        border: Border.all(
                          color: isSelected ? AppColors.primary : AppColors.border,
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        weekdaysNames[index],
                        style: TextStyle(
                          color: isSelected ? Colors.white : AppColors.text,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  // --- 3. MODO ESPAÇAMENTO DE DIAS (ALTERNADO) ---
  Widget _buildAlternatingSection(WizardState state, WizardNotifier notifier) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Text(
            'A caixinha deve apitar a cada:',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textMuted),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          _buildLargeStepper(
            value: state.alternatingDays,
            onChanged: (v) {
              notifier.updateState((s) => s.copyWith(alternatingDays: v));
            },
            min: 2,
            max: 90,
            step: 1,
          ),
          const SizedBox(height: 12),
          Text(
            'Dias',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Exemplo: 2 = Dia sim, dia não. 3 = A cada 3 dias.',
            style: TextStyle(fontSize: 11, color: AppColors.textMuted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // --- 4. MODO CICLOS (USO COM PAUSA) ---
  Widget _buildCycleSection(WizardState state, WizardNotifier notifier) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          // Stepper de Uso
          Text(
            'Tomo o remédio seguidamente por:',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textMuted),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          _buildLargeStepper(
            value: state.cycleOnDays,
            onChanged: (v) {
              notifier.updateState((s) => s.copyWith(cycleOnDays: v));
            },
            min: 1,
            max: 120,
            step: 1,
          ),
          const SizedBox(height: 8),
          Text(
            'Dias (Uso)',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 24),
          Divider(color: AppColors.border),
          const SizedBox(height: 24),

          // Stepper de Descanso
          Text(
            'Depois descanso (sem tomar) por:',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textMuted),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          _buildLargeStepper(
            value: state.cycleOffDays,
            onChanged: (v) {
              notifier.updateState((s) => s.copyWith(cycleOffDays: v));
            },
            min: 1,
            max: 120,
            step: 1,
          ),
          const SizedBox(height: 8),
          Text(
            'Dias (Descanso)',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // --- 5. MODO MENSAL FIXO ---
  Widget _buildMonthlySection(WizardState state, WizardNotifier notifier) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Text(
            'Em qual dia do mês você vai tomar?',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textMuted),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Todo o dia',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          _buildLargeStepper(
            value: state.monthlyDay,
            onChanged: (v) {
              notifier.updateState((s) => s.copyWith(monthlyDay: v));
            },
            min: 1,
            max: 31,
            step: 1,
          ),
          const SizedBox(height: 12),
          Text(
            'do mês',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // --- STEPS WIDGET HELPER ---
  Widget _buildLargeStepper({
    required int value,
    required Function(int) onChanged,
    required int min,
    required int max,
    required int step,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: () {
            if (value > min) onChanged(value - step);
          },
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primary, width: 2),
            ),
            alignment: Alignment.center,
            child: Text(
              '-',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Container(
          constraints: const BoxConstraints(minWidth: 80),
          alignment: Alignment.center,
          child: Text(
            '$value',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 38,
              fontWeight: FontWeight.w800,
            ),
          ),
          // Sem const pois depende de AppColors nas cores ao redor se aplicadas,
          // porém como Text aqui não usa AppColors, mantemos padrão seguro.
        ),
        const SizedBox(width: 16),
        GestureDetector(
          onTap: () {
            if (value < max) onChanged(value + step);
          },
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primary, width: 2),
            ),
            alignment: Alignment.center,
            child: Text(
              '+',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
