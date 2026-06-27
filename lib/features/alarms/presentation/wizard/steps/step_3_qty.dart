import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/constants/app_colors.dart';
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
          const Text(
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
              int crossAxisCount = width >= 700 ? 4 : 2;
              double childAspectRatio = width >= 700 ? 1.25 : 1.15;

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
                                  color: AppColors.primary.withOpacity(0.12),
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
                            style: const TextStyle(
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
                              style: const TextStyle(
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
          const Text(
            'Escolha a quantidade de cada tomada:',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textMuted),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          _buildLargeStepper(
            value: qty,
            onChanged: (v) {
              notifier.updateState((s) => s.copyWith(fixedQuantity: v));
            },
            min: 0.5,
            max: 50.0,
            step: 0.5,
          ),
          if (isComp) ...[
            const SizedBox(height: 12),
            _buildFractionButton(
              value: qty,
              onChanged: (v) {
                notifier.updateState((s) => s.copyWith(fixedQuantity: v));
              },
            ),
          ],
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
          const Text(
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
                  width: 130,
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
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.text,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildMiniStepper(
                        value: val,
                        onChanged: (v) {
                          final newDoses = List<double>.from(doses);
                          newDoses[i] = v;
                          notifier.updateState((s) => s.copyWith(asymmetricDoses: newDoses));
                        },
                        min: 0,
                        max: 50,
                        step: 1.0,
                      ),
                      if (isComp)
                        _buildFractionButton(
                          value: val,
                          onChanged: (v) {
                            final newDoses = List<double>.from(doses);
                            newDoses[i] = v;
                            notifier.updateState((s) => s.copyWith(asymmetricDoses: newDoses));
                          },
                          mini: true,
                        ),
                      const SizedBox(height: 6),
                      Text(
                        '$typeLabel(s)',
                        style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
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
          const Text(
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
                    style: const TextStyle(color: AppColors.text, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Outro...',
                      hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.border, width: 1.5),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.border, width: 1.5),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),
          const Text(
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
                      _buildMiniStepper(
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
                        minWidth: 40,
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 2.0),
                        child: Text(
                          'por',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      _buildMiniStepper(
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
                        minWidth: 40,
                      ),
                    ],
                  );
                } else {
                  final val = double.tryParse(rule.limit) ?? 150.0;
                  limitWidget = _buildMiniStepper(
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
                    minWidth: 40,
                  );
                }

                return Container(
                  width: 145,
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
                          const Text(
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
                          const Text(
                            'do que',
                            style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                          ),
                          const SizedBox(height: 6),
                          limitWidget,
                          const SizedBox(height: 10),
                          const Text(
                            'Tomar',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.text,
                            ),
                          ),
                          const SizedBox(height: 6),
                          _buildMiniStepper(
                            value: rule.dose,
                            onChanged: (v) {
                              final newRules = List<WizardDynamicRule>.from(rules);
                              newRules[index] = rule.copyWith(dose: v);
                              notifier.updateState((s) => s.copyWith(dynamicRules: newRules));
                            },
                            min: 0,
                            max: 50,
                            step: 1.0,
                          ),
                          if (isComp)
                            _buildFractionButton(
                              value: rule.dose,
                              onChanged: (v) {
                                final newRules = List<WizardDynamicRule>.from(rules);
                                newRules[index] = rule.copyWith(dose: v);
                                notifier.updateState((s) => s.copyWith(dynamicRules: newRules));
                              },
                              mini: true,
                            ),
                          const SizedBox(height: 4),
                          Text(
                            '$typeLabel(s)',
                            style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
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
                            child: const Icon(
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
                side: const BorderSide(color: AppColors.primary),
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
          const Text(
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
                  width: 135,
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
                          const Text(
                            'Tomar',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.text,
                            ),
                          ),
                          const SizedBox(height: 6),
                          _buildMiniStepper(
                            value: stage.quantity,
                            onChanged: (v) {
                              final newStages = List<TaperStage>.from(stages);
                              newStages[index] = stage.copyWith(quantity: v);
                              notifier.updateState((s) => s.copyWith(taperStages: newStages));
                            },
                            min: 0,
                            max: 50,
                            step: 1.0,
                          ),
                          if (isComp)
                            _buildFractionButton(
                              value: stage.quantity,
                              onChanged: (v) {
                                final newStages = List<TaperStage>.from(stages);
                                newStages[index] = stage.copyWith(quantity: v);
                                notifier.updateState((s) => s.copyWith(taperStages: newStages));
                              },
                              mini: true,
                            ),
                          const SizedBox(height: 4),
                          Text(
                            '$typeLabel(s)',
                            style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Por',
                            style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                          ),
                          const SizedBox(height: 6),
                          _buildMiniStepper(
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
                          const Text(
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
                            child: const Icon(
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
                side: const BorderSide(color: AppColors.primary),
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
              const Expanded(
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

  // --- REUSABLE CONTROL WIDGETS ---

  Widget _buildLargeStepper({
    required double value,
    required Function(double) onChanged,
    required double min,
    required double max,
    required double step,
  }) {
    final displayVal = value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 1);
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
            child: const Text(
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
            displayVal,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 38,
              fontWeight: FontWeight.w800,
            ),
          ),
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
            child: const Text(
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

  Widget _buildMiniStepper({
    required double value,
    required Function(double) onChanged,
    required double min,
    required double max,
    required double step,
    double minWidth = 32,
  }) {
    final displayVal = value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 1);
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: () {
            if (value > min) onChanged(value - step);
          },
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primary, width: 1.5),
            ),
            alignment: Alignment.center,
            child: const Text(
              '-',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Container(
          constraints: BoxConstraints(minWidth: minWidth),
          alignment: Alignment.center,
          child: Text(
            displayVal,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 6),
        GestureDetector(
          onTap: () {
            if (value < max) onChanged(value + step);
          },
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primary, width: 1.5),
            ),
            alignment: Alignment.center,
            child: const Text(
              '+',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFractionButton({
    required double value,
    required Function(double) onChanged,
    bool mini = false,
  }) {
    final hasHalf = value % 1 != 0;
    final borderSide = hasHalf
        ? BorderSide(color: AppColors.primary, width: mini ? 1.2 : 2.0)
        : BorderSide(
            color: AppColors.primary.withOpacity(0.4),
            width: mini ? 1.0 : 1.5,
          );

    return GestureDetector(
      onTap: () {
        final newQty = hasHalf ? value.truncateToDouble() : value.truncateToDouble() + 0.5;
        onChanged(newQty);
      },
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        padding: EdgeInsets.symmetric(
          vertical: mini ? 4.0 : 6.0,
          horizontal: mini ? 8.0 : 12.0,
        ),
        decoration: BoxDecoration(
          color: hasHalf ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(mini ? 4 : 8),
          border: Border.fromBorderSide(borderSide),
        ),
        child: Text(
          mini ? '+ ½ (Meio)' : '+ ½ (Meio Comprimido)',
          style: TextStyle(
            color: hasHalf ? Colors.white : AppColors.primary,
            fontSize: mini ? 9 : 11,
            fontWeight: FontWeight.bold,
          ),
        ),
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
