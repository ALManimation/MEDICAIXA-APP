import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/constants/app_colors.dart';
import '../wizard_notifier.dart';

class WizardStep6Duration extends ConsumerStatefulWidget {
  const WizardStep6Duration({super.key});

  @override
  ConsumerState<WizardStep6Duration> createState() => _WizardStep6DurationState();
}

class _WizardStep6DurationState extends ConsumerState<WizardStep6Duration> {
  late TextEditingController _rotationController;

  @override
  void initState() {
    super.initState();
    final state = ref.read(wizardNotifierProvider);
    _rotationController = TextEditingController(text: state.siteRotationList);
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _decomposeDelay(int totalMins) {
    if (totalMins <= 0) return {'value': 24, 'unit': 'h'};
    if (totalMins % 1440 == 0) {
      return {'value': totalMins ~/ 1440, 'unit': 'd'};
    } else if (totalMins % 60 == 0) {
      return {'value': totalMins ~/ 60, 'unit': 'h'};
    } else {
      return {'value': totalMins, 'unit': 'm'};
    }
  }

  int _composeDelay(int value, String unit) {
    final multiplier = unit == 'd' ? 1440 : (unit == 'h' ? 60 : 1);
    return value * multiplier;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(wizardNotifierProvider);
    final notifier = ref.read(wizardNotifierProvider.notifier);

    final showPatchSection = state.type == 'adesivo' || state.type == 'injetavel';

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 1. Título Duração
          const Text(
            'Até quando você vai usar esse remédio?',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.text,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // 2. Row de Opções de Duração
          Row(
            children: [
              Expanded(
                child: _buildDurationCard(
                  id: 'continuous',
                  emoji: '♾️',
                  title: 'Uso contínuo (Para sempre)',
                  sub: 'Remédio de uso diário constante',
                  selectedMode: state.durationMode,
                  notifier: notifier,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildDurationCard(
                  id: 'days',
                  emoji: '📅',
                  title: 'Tratamento com prazo definido',
                  sub: 'O médico passou por alguns dias (Ex: Antibiótico)',
                  selectedMode: state.durationMode,
                  notifier: notifier,
                ),
              ),
            ],
          ),

          // 3. Painel de Prazo Definido (Stepper de Dias)
          if (state.durationMode == 'days') ...[
            const SizedBox(height: 16),
            _buildDurationDaysStepper(state.durationDays, notifier),
          ],

          // 4. Seção do Adesivo / Canetinha (Se aplicável)
          if (showPatchSection) ...[
            const SizedBox(height: 16),
            Divider(color: AppColors.border, thickness: 1.5, height: 32),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Configurações para Adesivo / Canetinha',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Card 1: Revezamento
            _buildRotationField(state.siteRotationList, notifier),
            const SizedBox(height: 16),

            // Card 2: Alerta de Remoção
            _buildRemovalField(state.requiresRemoval, state.removalDelayMins, notifier),
          ],
        ],
      ),
    );
  }

  Widget _buildDurationCard({
    required String id,
    required String emoji,
    required String title,
    required String sub,
    required String selectedMode,
    required WizardNotifier notifier,
  }) {
    final isSelected = selectedMode == id;

    return GestureDetector(
      onTap: () {
        notifier.updateState((s) => s.copyWith(durationMode: id));
      },
      child: Container(
        height: 140,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
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
            Text(emoji, style: const TextStyle(fontSize: 32)),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
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
              sub,
              style: const TextStyle(
                fontSize: 9.5,
                color: AppColors.textMuted,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDurationDaysStepper(int currentDays, WizardNotifier notifier) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
      child: Column(
        children: [
          const Text(
            'Por quantos dias o médico mandou tomar?',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.text,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Decrement Button
              IconButton(
                onPressed: currentDays > 1
                    ? () {
                        notifier.updateState((s) => s.copyWith(durationDays: currentDays - 1));
                      }
                    : null,
                icon: const Icon(Icons.remove, size: 24),
                style: IconButton.styleFrom(
                  side: BorderSide(
                    color: currentDays > 1 ? AppColors.primary : AppColors.border,
                    width: 1.5,
                  ),
                  padding: const EdgeInsets.all(12),
                ),
              ),
              const SizedBox(width: 24),
              // Value display
              SizedBox(
                width: 80,
                child: Text(
                  '$currentDays',
                  style: const TextStyle(
                    fontSize: 38,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 24),
              // Increment Button
              IconButton(
                onPressed: currentDays < 365
                    ? () {
                        notifier.updateState((s) => s.copyWith(durationDays: currentDays + 1));
                      }
                    : null,
                icon: const Icon(Icons.add, size: 24),
                style: IconButton.styleFrom(
                  side: BorderSide(
                    color: currentDays < 365 ? AppColors.primary : AppColors.border,
                    width: 1.5,
                  ),
                  padding: const EdgeInsets.all(12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Dias Totais',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRotationField(String currentList, WizardNotifier notifier) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quais locais do corpo você deseja revezar?',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _rotationController,
            onChanged: (val) {
              notifier.updateState((s) => s.copyWith(siteRotationList: val));
            },
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.text,
            ),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              hintText: 'Braço Esquerdo, Braço Direito, Coxa',
              hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
              contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              filled: true,
              fillColor: AppColors.background,
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
          const SizedBox(height: 8),
          const Text(
            'Escreva os locais separados por vírgula para revezamento automático',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRemovalField(bool requiresRemoval, int removalDelayMins, WizardNotifier notifier) {
    final decomposed = _decomposeDelay(removalDelayMins);
    final delayVal = decomposed['value'] as int;
    final delayUnit = decomposed['unit'] as String;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Lembra de tirar o adesivo velho?',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text,
                ),
              ),
              Switch(
                value: requiresRemoval,
                activeColor: AppColors.primary,
                onChanged: (val) {
                  notifier.updateState((s) => s.copyWith(
                        requiresRemoval: val,
                        removalDelayMins: val ? _composeDelay(24, 'h') : 0,
                      ));
                },
              ),
            ],
          ),
          if (requiresRemoval) ...[
            const SizedBox(height: 16),
            const Text(
              'Avisar para retirar após:',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                // Mini stepper for delay value
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border, width: 1.5),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: delayVal > 1
                            ? () {
                                final newVal = delayVal - 1;
                                notifier.updateState((s) => s.copyWith(
                                      removalDelayMins: _composeDelay(newVal, delayUnit),
                                    ));
                              }
                            : null,
                        icon: const Icon(Icons.remove, size: 16),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        constraints: const BoxConstraints(),
                      ),
                      SizedBox(
                        width: 40,
                        child: Text(
                          '$delayVal',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.text,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      IconButton(
                        onPressed: delayVal < 168
                            ? () {
                                final newVal = delayVal + 1;
                                notifier.updateState((s) => s.copyWith(
                                      removalDelayMins: _composeDelay(newVal, delayUnit),
                                    ));
                              }
                            : null,
                        icon: const Icon(Icons.add, size: 16),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Dropdown for unit selection
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border, width: 1.5),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: delayUnit,
                        dropdownColor: AppColors.surface,
                        icon: const Icon(Icons.arrow_drop_down, color: AppColors.textMuted),
                        style: const TextStyle(
                          color: AppColors.text,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                        items: const [
                          DropdownMenuItem(value: 'h', child: Text('Horas')),
                          DropdownMenuItem(value: 'd', child: Text('Dias')),
                          DropdownMenuItem(value: 'm', child: Text('Minutos')),
                        ],
                        onChanged: (unit) {
                          if (unit != null) {
                            notifier.updateState((s) => s.copyWith(
                                  removalDelayMins: _composeDelay(delayVal, unit),
                                ));
                          }
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
