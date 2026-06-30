import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/presentation/widgets/vertical_datetime_selector.dart';
import '../wizard_notifier.dart';
import '../wizard_state.dart';

class WizardStep7Summary extends ConsumerWidget {
  const WizardStep7Summary({super.key});

  String _buildNaturalLanguageSummary(WizardState state) {
    final name = state.name.trim();
    final dosage = state.dosage.trim();
    final format = state.type.isEmpty ? 'Remédio' : state.type;
    final strengthText = dosage.isNotEmpty ? ' $dosage' : '';
    
    final colorMap = {
      'white': 'Branco',
      'red': 'Vermelho',
      'green': 'Verde',
      'blue': 'Azul',
      'yellow': 'Amarelo',
      'magenta': 'Magenta',
      'cyan': 'Ciano',
      'orange': 'Laranja',
      'purple': 'Roxo',
      'pink': 'Rosa',
      'brown': 'Marrom',
      'chartreuse': 'Chartreuse',
      'teal': 'Teal/Verde-azulado',
      'coral': 'Coral',
      'gold': 'Ouro/Dourado',
    };
    final colorText = colorMap[state.color] ?? state.color;
    
    String text = 'Medicamento: $name$strengthText ($format) · Cor: $colorText\n\n';

    if (state.useMode == 'prn') {
      text += 'Modo: Uso sob demanda (PRN)\n';
      if (state.prnMaxDailyDoses > 0) {
        text += 'Limite: máximo de ${state.prnMaxDailyDoses} tomadas por dia.\n';
      } else {
        text += 'Sem limite máximo de tomadas diárias.\n';
      }
      if (state.prnMinIntervalHours > 0) {
        text += 'Intervalo mínimo: ${state.prnMinIntervalHours} horas entre tomadas.\n';
      } else {
        text += 'Sem tempo de espera entre tomadas.\n';
      }
    } else {
      if (state.quantityMode == 'fixed') {
        final qtyStr = state.fixedQuantity.toStringAsFixed(state.fixedQuantity.truncateToDouble() == state.fixedQuantity ? 0 : 1);
        text += 'Dose: $qtyStr $format(s) por vez.\n';
      } else if (state.quantityMode == 'asymmetric') {
        text += 'Dose: Assimétrica (mosaico) dependendo do dia da semana.\n';
      } else if (state.quantityMode == 'dynamic') {
        text += 'Dose: Dinâmica, baseada no teste de ${state.dynamicParamSelected}.\n';
      } else if (state.quantityMode == 'taper') {
        text += 'Dose: Desmame / Titulação progressiva.\n';
      }

      if (state.daysMode == 'everyday') {
        text += 'Dias: Todos os dias.\n';
      } else if (state.daysMode == 'interval') {
        text += 'Dias: De ${state.intervalDays} em ${state.intervalDays} horas.\n';
      } else if (state.daysMode == 'weekdays') {
        final weekdaysMap = {1: 'Seg', 2: 'Ter', 3: 'Qua', 4: 'Qui', 5: 'Sex', 6: 'Sáb', 7: 'Dom'};
        final list = state.weekdays.map((d) => weekdaysMap[d] ?? '').join(', ');
        text += 'Dias: Apenas em $list.\n';
      } else if (state.daysMode == 'alternating') {
        text += 'Dias: A cada ${state.alternatingDays} dias.\n';
      } else if (state.daysMode == 'cycle') {
        text += 'Ciclo: Toma por ${state.cycleOnDays} dias e descansa por ${state.cycleOffDays} dias.\n';
      } else if (state.daysMode == 'monthly') {
        text += 'Dias: Todo dia ${state.monthlyDay} do mês.\n';
      }

      // Horários
      if (state.timePreset != 'custom' && state.timePreset.isNotEmpty) {
        final presetNames = {
          'wake': 'Logo ao acordar',
          'sleep': 'Antes de deitar',
          'breakfast_before': 'Antes do Café',
          'breakfast_after': 'Depois do Café',
          'lunch_before': 'Antes do Almoço',
          'lunch_after': 'Depois do Almoço',
          'dinner_before': 'Antes do Jantar',
          'dinner_after': 'Depois do Jantar',
        };
        final pName = presetNames[state.timePreset] ?? state.timePreset;
        final timeStr = state.customTimes.isNotEmpty ? state.customTimes[0] : '';
        text += 'Horário: $pName (~$timeStr).\n';
      } else {
        final tVal = state.customTimes.join(', ');
        text += 'Horário: Às $tVal.\n';
      }

      if (state.durationMode == 'continuous') {
        text += 'Duração: Uso Contínuo.\n';
      } else {
        text += 'Duração: Por ${state.durationDays} dias.\n';
      }
    }

    // Início
    final startDateStr = () {
      if (state.startDateMode == 'today') {
        final d = DateTime.now();
        return "${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}";
      } else if (state.startDateMode == 'tomorrow') {
        final d = DateTime.now().add(const Duration(days: 1));
        return "${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}";
      } else if (state.customStartDate != null) {
        final d = state.customStartDate!;
        return "${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}";
      }
      final d = DateTime.now();
      return "${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}";
    }();
    
    text += 'Início: $startDateStr.\n';

    if (state.instruction.isNotEmpty) {
      final recommendationMap = {
        'empty_stomach': 'Tomar em jejum (estômago vazio)',
        'with_food': 'Tomar junto com alimento (após comer)',
        'sublingual': 'Derreter debaixo da língua (sublingual)',
        'no_crush': 'Não amassar nem mastigar',
      };
      final rec = recommendationMap[state.instruction] ?? state.instruction;
      text += 'Instrução especial: $rec.';
    }

    return text;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(wizardNotifierProvider);
    final notifier = ref.read(wizardNotifierProvider.notifier);

    final recommendations = [
      {'id': 'empty_stomach', 'icon': '🍽️', 'title': 'Em jejum', 'sub': 'Estômago vazio'},
      {'id': 'with_food', 'icon': '🍲', 'title': 'Com alimento', 'sub': 'Após comer'},
      {'id': 'sublingual', 'icon': '👅', 'title': 'Sublingual', 'sub': 'Debaixo da língua'},
      {'id': 'no_crush', 'icon': '🚫', 'title': 'Não mastigar', 'sub': 'Não triturar'},
      {'id': '', 'icon': '🟢', 'title': 'Nenhuma', 'sub': 'Tanto faz'},
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isMobile = width < 500;

        // Start Date Formatting
        final formattedStartDate = () {
          if (state.startDateMode == 'today') {
            return 'Hoje';
          } else if (state.startDateMode == 'tomorrow') {
            return 'Amanhã';
          } else if (state.customStartDate != null) {
            final d = state.customStartDate!;
            return "${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}";
          }
          return 'Escolher data';
        }();

        // Dynamically build recommendation cards based on screen size
        final List<Widget> gridRows = [];
        if (width >= 800) {
          // On desktop, 5 items in a single row
          gridRows.add(
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: recommendations.map((r) {
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: _buildOptionCard(r, state.instruction, notifier, false),
                    ),
                  );
                }).toList(),
              ),
            ),
          );
        } else {
          // On mobile/tablet, 2 columns with the 5th spanning full width
          for (int i = 0; i < recommendations.length; i += 2) {
            if (i + 1 < recommendations.length) {
              gridRows.add(
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: _buildOptionCard(recommendations[i], state.instruction, notifier, isMobile)),
                      const SizedBox(width: 8),
                      Expanded(child: _buildOptionCard(recommendations[i + 1], state.instruction, notifier, isMobile)),
                    ],
                  ),
                ),
              );
            } else {
              gridRows.add(
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: _buildOptionCard(recommendations[i], state.instruction, notifier, isMobile)),
                    ],
                  ),
                ),
              );
            }
            gridRows.add(const SizedBox(height: 8));
          }
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 1. Data de início
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Você já vai começar a tomar hoje?',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.text,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: _buildDateBtn(
                      id: 'today',
                      label: 'Sim, hoje mesmo',
                      isSelected: state.startDateMode == 'today',
                      onTap: () {
                        notifier.updateState((s) => s.copyWith(startDateMode: 'today'));
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildDateBtn(
                      id: 'custom',
                      label: state.startDateMode == 'custom' ? formattedStartDate : 'Outro dia...',
                      isSelected: state.startDateMode == 'custom',
                      onTap: () async {
                        notifier.updateState((s) => s.copyWith(startDateMode: 'custom'));
                        final selected = await showVerticalDatePicker(
                          context,
                          initialDate: state.customStartDate ?? DateTime.now().add(const Duration(days: 1)),
                        );
                        if (selected != null) {
                          notifier.updateState((s) => s.copyWith(customStartDate: selected));
                        }
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),
              Divider(color: AppColors.border, thickness: 1.5, height: 32),

              // 2. Recomendações
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'O médico deixou alguma recomendação?',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.text,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              ...gridRows,

              const SizedBox(height: 20),
              Divider(color: AppColors.border, thickness: 1.5, height: 32),

              // 3. Resumo
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border, width: 1.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'RESUMO DO REMÉDIO',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _buildNaturalLanguageSummary(state),
                      style: TextStyle(
                        fontSize: 14.5,
                        color: AppColors.text,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDateBtn({
    required String id,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: 1.5,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppColors.primary : AppColors.text,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildOptionCard(
    Map<String, String> r,
    String selectedInstruction,
    WizardNotifier notifier,
    bool isMobile,
  ) {
    final isSelected = selectedInstruction == r['id'];

    return GestureDetector(
      onTap: () {
        notifier.updateState((s) => s.copyWith(instruction: r['id']!));
      },
      child: Container(
        constraints: BoxConstraints(
          minHeight: isMobile ? 80 : 105,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
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
        child: isMobile
            ? Row(
                children: [
                  Text(r['icon']!, style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r['title']!,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: AppColors.text,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          r['sub']!,
                          style: TextStyle(
                            fontSize: 9.5,
                            color: AppColors.textMuted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(r['icon']!, style: const TextStyle(fontSize: 26)),
                  const SizedBox(height: 6),
                  Text(
                    r['title']!,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: AppColors.text,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    r['sub']!,
                    style: TextStyle(
                      fontSize: 9.5,
                      color: AppColors.textMuted,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
      ),
    );
  }
}
