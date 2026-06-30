import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/presentation/widgets/standard_stepper.dart';
import '../wizard_notifier.dart';
import '../wizard_state.dart';
import '../../../data/alarm_model.dart'; // For TaperStage

class WizardStep3Qty extends ConsumerStatefulWidget {
  const WizardStep3Qty({super.key});

  @override
  ConsumerState<WizardStep3Qty> createState() => _WizardStep3QtyState();
}

class _WizardStep3QtyState extends ConsumerState<WizardStep3Qty> {
  late final TextEditingController _customParamController;

  @override
  void initState() {
    super.initState();
    final selected = ref.read(wizardNotifierProvider).dynamicParamSelected;
    final initialCustom = (selected != 'Glicose' && selected != 'Pressão') ? selected : '';
    _customParamController = TextEditingController(text: initialCustom);
  }

  @override
  void dispose() {
    _customParamController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(wizardNotifierProvider);
    final notifier = ref.read(wizardNotifierProvider.notifier);

    // Sync custom text controller when selected presets change
    ref.listen(wizardNotifierProvider.select((s) => s.dynamicParamSelected), (prev, next) {
      if (next == 'Glicose' || next == 'Pressão') {
        _customParamController.text = '';
      } else if (next != _customParamController.text) {
        _customParamController.text = next;
      }
    });

    // Auto-initialize default rules if empty
    if (state.quantityMode == 'dynamic' && state.dynamicRules.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final isPressao = state.dynamicParamSelected == 'Pressão';
        notifier.updateState((s) => s.copyWith(dynamicRules: [
          WizardDynamicRule(
            operation: 'menor',
            limit: isPressao ? '130/80' : '150',
            dose: 1.0,
          )
        ]));
      });
    }

    // Auto-initialize default taper stages if empty
    if (state.quantityMode == 'taper' && state.taperStages.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifier.updateState((s) => s.copyWith(taperStages: const [
          TaperStage(durationDays: 7, quantity: 1.0),
          TaperStage(durationDays: 7, quantity: 0.5),
        ]));
      });
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 1. Título
          Text(
            'Qual a quantidade que você toma por vez?',
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
              final int crossAxisCount = width >= 700 ? 4 : 2;
              final double childAspectRatio = width >= 700 ? 1.25 : 1.15;

              final modes = [
                {'id': 'fixed', 'icon': '🎯', 'title': 'Quantidade Fixa', 'sub': 'Sempre a mesma quantidade'},
                {'id': 'asymmetric', 'icon': '📅', 'title': 'Dose por Dia', 'sub': 'A dose muda conforme o dia da semana'},
                {'id': 'dynamic', 'icon': '🩸', 'title': 'Dose Dinâmica', 'sub': 'Depende de teste (Ex: Glicose)'},
                {'id': 'taper', 'icon': '📈', 'title': 'Desmame / Subida', 'sub': 'Aumentar ou diminuir aos poucos'},
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
                  final isSelected = state.quantityMode == m['id'];

                  return GestureDetector(
                    onTap: () {
                      notifier.updateState((s) => s.copyWith(quantityMode: m['id']!));
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
          if (state.quantityMode == 'fixed') _buildFixedQtySection(state, notifier),
          if (state.quantityMode == 'asymmetric') _buildAsymmetricSection(state.asymmetricDoses, state, notifier),
          if (state.quantityMode == 'dynamic') _buildDynamicSection(state, notifier),
          if (state.quantityMode == 'taper') _buildTaperSection(state, notifier),
        ],
      ),
    );
  }

  // --- 1. SEÇÃO DO MODO FIXO ---
  Widget _buildFixedQtySection(WizardState state, WizardNotifier notifier) {
    final qty = state.fixedQuantity;
    final isComp = state.type == 'comprimido';

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
            'Escolha a quantidade de cada tomada:',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textMuted),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          StandardStepper(
            value: qty,
            onChanged: (v) {
              notifier.updateState((s) => s.copyWith(fixedQuantity: v));
            },
            min: 0.5,
            max: 50.0,
            step: 0.5,
            hasFractionButton: isComp,
          ),
        ],
      ),
    );
  }

  // --- 2. SEÇÃO DO MODO ASSIMÉTRICO (DOSE POR DIA) ---
  Widget _buildAsymmetricSection(List<double> doses, WizardState state, WizardNotifier notifier) {
    final days = ['Domingo', 'Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado'];
    final isComp = state.type == 'comprimido';
    final typeLabel = state.type.isNotEmpty ? state.type : 'dose';

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
            'Defina a dose para cada dia:',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textMuted),
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(7, (i) {
                final val = doses[i];
                return Container(
                  width: 178,
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border, width: 1.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        days[i],
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.text,
                        ),
                      ),
                      const SizedBox(height: 12),
                      StandardStepper(
                        value: val,
                        onChanged: (v) {
                          final newDoses = List<double>.from(doses);
                          newDoses[i] = v;
                          notifier.updateState((s) => s.copyWith(asymmetricDoses: newDoses));
                        },
                        min: 0,
                        max: 50,
                        step: 1.0,
                        hasFractionButton: isComp,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$typeLabel(s)',
                        style: TextStyle(fontSize: 10, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  // --- 3. SEÇÃO DO MODO DINÂMICO ---
  Widget _buildDynamicSection(WizardState state, WizardNotifier notifier) {
    final selected = state.dynamicParamSelected;
    final rules = state.dynamicRules;
    final isPressao = selected == 'Pressão';
    final isComp = state.type == 'comprimido';
    final typeLabel = state.type.isNotEmpty ? state.type : 'dose';

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
            'Qual aparelho de teste você vai usar?',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textMuted),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    final isPressao = state.dynamicRules.isEmpty;
                    notifier.updateState((s) => s.copyWith(
                          dynamicParamSelected: 'Glicose',
                          dynamicRules: isPressao
                              ? [const WizardDynamicRule(operation: 'menor', limit: '150', dose: 1.0)]
                              : s.dynamicRules,
                        ));
                  },
                  child: Container(
                    height: 45,
                    decoration: BoxDecoration(
                      color: selected == 'Glicose' ? AppColors.primary : AppColors.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: selected == 'Glicose' ? AppColors.primary : AppColors.border,
                        width: 1.5,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Glicose',
                      style: TextStyle(
                        color: selected == 'Glicose' ? Colors.white : AppColors.text,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    final isPressao = state.dynamicRules.isEmpty;
                    notifier.updateState((s) => s.copyWith(
                          dynamicParamSelected: 'Pressão',
                          dynamicRules: isPressao
                              ? [const WizardDynamicRule(operation: 'menor', limit: '130/80', dose: 1.0)]
                              : s.dynamicRules,
                        ));
                  },
                  child: Container(
                    height: 45,
                    decoration: BoxDecoration(
                      color: selected == 'Pressão' ? AppColors.primary : AppColors.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: selected == 'Pressão' ? AppColors.primary : AppColors.border,
                        width: 1.5,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Pressão',
                      style: TextStyle(
                        color: selected == 'Pressão' ? Colors.white : AppColors.text,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 45,
                  child: TextFormField(
                    controller: _customParamController,
                    onChanged: (val) {
                      notifier.updateState((s) => s.copyWith(dynamicParamSelected: val));
                    },
                    style: TextStyle(color: AppColors.text, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Outro...',
                      hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: AppColors.border, width: 1.5),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: AppColors.border, width: 1.5),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: AppColors.primary, width: 1.5),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),
          Text(
            'Defina a regra da dose:',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textMuted),
          ),
          const SizedBox(height: 12),

          // Horizontal scroll of rule cards
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(rules.length, (index) {
                final rule = rules[index];

                // Build pressure vs other input steppers
                Widget limitWidget;
                if (isPressao) {
                  final parts = rule.limit.split('/');
                  final sysStr = parts.isNotEmpty ? parts[0] : '130';
                  final diaStr = parts.length > 1 ? parts[1] : '80';
                  final sysVal = double.tryParse(sysStr) ?? 130.0;
                  final diaVal = double.tryParse(diaStr) ?? 80.0;

                  limitWidget = Column(
                    children: [
                      StandardStepper(
                        value: sysVal,
                        onChanged: (v) {
                          final newLimit = '${v.toInt()}/$diaStr';
                          final newRules = List<WizardDynamicRule>.from(rules);
                          newRules[index] = rule.copyWith(limit: newLimit);
                          notifier.updateState((s) => s.copyWith(dynamicRules: newRules));
                        },
                        min: 50,
                        max: 250,
                        step: 10,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2.0),
                        child: Text(
                          'por',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      StandardStepper(
                        value: diaVal,
                        onChanged: (v) {
                          final newLimit = '$sysStr/${v.toInt()}';
                          final newRules = List<WizardDynamicRule>.from(rules);
                          newRules[index] = rule.copyWith(limit: newLimit);
                          notifier.updateState((s) => s.copyWith(dynamicRules: newRules));
                        },
                        min: 30,
                        max: 150,
                        step: 10,
                      ),
                    ],
                  );
                } else {
                  final val = double.tryParse(rule.limit) ?? 150.0;
                  limitWidget = StandardStepper(
                    value: val,
                    onChanged: (v) {
                      final newLimit = v.toInt().toString();
                      final newRules = List<WizardDynamicRule>.from(rules);
                      newRules[index] = rule.copyWith(limit: newLimit);
                      notifier.updateState((s) => s.copyWith(dynamicRules: newRules));
                    },
                    min: 1,
                    max: 999,
                    step: 10,
                  );
                }

                return Container(
                  width: 178,
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border, width: 1.5),
                  ),
                  child: Stack(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            'Se estiver',
                            style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildOpButton(
                                label: 'menor',
                                isActive: rule.operation == 'menor',
                                onTap: () {
                                  final newRules = List<WizardDynamicRule>.from(rules);
                                  newRules[index] = rule.copyWith(operation: 'menor');
                                  notifier.updateState((s) => s.copyWith(dynamicRules: newRules));
                                },
                              ),
                              const SizedBox(width: 4),
                              _buildOpButton(
                                label: 'maior',
                                isActive: rule.operation == 'maior',
                                onTap: () {
                                  final newRules = List<WizardDynamicRule>.from(rules);
                                  newRules[index] = rule.copyWith(operation: 'maior');
                                  notifier.updateState((s) => s.copyWith(dynamicRules: newRules));
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'do que',
                            style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                          ),
                          const SizedBox(height: 6),
                          limitWidget,
                          const SizedBox(height: 10),
                          Text(
                            'Tomar',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.text,
                            ),
                          ),
                          const SizedBox(height: 6),
                          StandardStepper(
                            value: rule.dose,
                            onChanged: (v) {
                              final newRules = List<WizardDynamicRule>.from(rules);
                              newRules[index] = rule.copyWith(dose: v);
                              notifier.updateState((s) => s.copyWith(dynamicRules: newRules));
                            },
                            min: 0,
                            max: 50,
                            step: 1.0,
                            hasFractionButton: isComp,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$typeLabel(s)',
                            style: TextStyle(fontSize: 10, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                      if (index > 0)
                        Positioned(
                          right: 0,
                          top: 0,
                          child: GestureDetector(
                            onTap: () {
                              final newRules = List<WizardDynamicRule>.from(rules);
                              newRules.removeAt(index);
                              notifier.updateState((s) => s.copyWith(dynamicRules: newRules));
                            },
                            child: Icon(
                              Icons.close,
                              size: 16,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              }),
            ),
          ),

          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                String prevLimit = '';
                if (rules.isNotEmpty) {
                  prevLimit = rules.last.limit;
                }
                if (prevLimit.isEmpty) {
                  prevLimit = isPressao ? '130/80' : '150';
                }
                final newRules = List<WizardDynamicRule>.from(rules);
                newRules.add(WizardDynamicRule(
                  operation: 'menor',
                  limit: prevLimit,
                  dose: 1.0,
                ));
                notifier.updateState((s) => s.copyWith(dynamicRules: newRules));
              },
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Adicionar Faixa de Dose', style: TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: BorderSide(color: AppColors.primary),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- 4. SEÇÃO DO MODO DESMAME (TAPERING) ---
  Widget _buildTaperSection(WizardState state, WizardNotifier notifier) {
    final stages = state.taperStages;
    if (stages.isEmpty) return const SizedBox.shrink();
    final isComp = state.type == 'comprimido';
    final typeLabel = state.type.isNotEmpty ? state.type : 'dose';

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
            'Etapas de dose do desmame:',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textMuted),
          ),
          const SizedBox(height: 12),

          // Timeline layout horizontal
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: List.generate(stages.length * 2 - 1, (i) {
                if (i % 2 != 0) {
                  // Render arrow/separator
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Depois',
                          style: TextStyle(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Icon(Icons.arrow_forward_rounded, size: 16, color: AppColors.primary),
                      ],
                    ),
                  );
                }

                final index = i ~/ 2;
                final stage = stages[index];

                return Container(
                  width: 178,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border, width: 1.5),
                  ),
                  child: Stack(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            'Tomar',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.text,
                            ),
                          ),
                          const SizedBox(height: 6),
                          StandardStepper(
                            value: stage.quantity,
                            onChanged: (v) {
                              final newStages = List<TaperStage>.from(stages);
                              newStages[index] = stage.copyWith(quantity: v);
                              notifier.updateState((s) => s.copyWith(taperStages: newStages));
                            },
                            min: 0,
                            max: 50,
                            step: 1.0,
                            hasFractionButton: isComp,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$typeLabel(s)',
                            style: TextStyle(fontSize: 10, color: AppColors.textMuted),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Por',
                            style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                          ),
                          const SizedBox(height: 6),
                          StandardStepper(
                            value: stage.durationDays.toDouble(),
                            onChanged: (v) {
                              final newStages = List<TaperStage>.from(stages);
                              newStages[index] = stage.copyWith(durationDays: v.toInt());
                              notifier.updateState((s) => s.copyWith(taperStages: newStages));
                            },
                            min: 1,
                            max: 365,
                            step: 1.0,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'dia(s)',
                            style: TextStyle(fontSize: 10, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                      if (index > 0)
                        Positioned(
                          right: 0,
                          top: 0,
                          child: GestureDetector(
                            onTap: () {
                              final newStages = List<TaperStage>.from(stages);
                              newStages.removeAt(index);
                              notifier.updateState((s) => s.copyWith(taperStages: newStages));
                            },
                            child: Icon(
                              Icons.close,
                              size: 16,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              }),
            ),
          ),

          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                final newStages = List<TaperStage>.from(stages);
                newStages.add(const TaperStage(durationDays: 7, quantity: 1.0));
                notifier.updateState((s) => s.copyWith(taperStages: newStages));
              },
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Adicionar Nova Dose', style: TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: BorderSide(color: AppColors.primary),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Checkbox(
                value: state.taperLoop,
                onChanged: (val) {
                  notifier.updateState((s) => s.copyWith(taperLoop: val ?? false));
                },
                activeColor: AppColors.primary,
              ),
              Expanded(
                child: Text(
                  'Repetir esse ciclo de doses infinitamente?',
                  style: TextStyle(color: AppColors.text, fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }



  Widget _buildOpButton({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isActive ? AppColors.primary : AppColors.border,
            width: 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: isActive ? Colors.white : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}
