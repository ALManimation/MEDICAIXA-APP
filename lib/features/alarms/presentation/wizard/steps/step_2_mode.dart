import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/constants/app_colors.dart';
import '../wizard_notifier.dart';

class WizardStep2Mode extends ConsumerWidget {
  const WizardStep2Mode({super.key});

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
            'Como o médico mandou você usar esse remédio?',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.text,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // 2. Grid Responsivo de Cards de Modo
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final isWide = width >= 600;

              final cards = [
                _buildModeCard(
                  title: 'Tomar na rotina diária',
                  subtitle: 'Tem dia e hora certos para tomar',
                  icon: Icons.alarm,
                  isSelected: state.useMode == 'routine',
                  onTap: () {
                    notifier.updateState((s) => s.copyWith(useMode: 'routine'));
                  },
                ),
                _buildModeCard(
                  title: 'Só de vez em quando (Sob demanda)',
                  subtitle: 'Só tomo quando passar mal, sentir dor, falta de ar, etc.',
                  icon: Icons.warning_rounded,
                  isSelected: state.useMode == 'prn',
                  onTap: () {
                    notifier.updateState((s) => s.copyWith(useMode: 'prn'));
                  },
                ),
              ];

              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: cards[0]),
                    const SizedBox(width: 16),
                    Expanded(child: cards[1]),
                  ],
                );
              } else {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    cards[0],
                    const SizedBox(height: 16),
                    cards[1],
                  ],
                );
              }
            },
          ),

          // 3. Travas de Segurança (Apenas para PRN)
          if (state.useMode == 'prn') ...[
            const SizedBox(height: 32),
            Text(
              'Limites de segurança para o idoso:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.text,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Limite diário (Dose Máxima)
                  Text(
                    'Qual o máximo de vezes que pode tomar no mesmo dia?',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textMuted,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  _buildStepper(
                    value: state.prnMaxDailyDoses,
                    onChanged: (v) {
                      notifier.updateState((s) => s.copyWith(prnMaxDailyDoses: v));
                    },
                    min: 0,
                    max: 24,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '0 = Sem limite diário definido',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Divider(color: AppColors.border),
                  const SizedBox(height: 24),

                  // Intervalo Mínimo
                  Text(
                    'Tem que esperar quantas horas antes de repetir a dose?',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textMuted,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  _buildStepper(
                    value: state.prnMinIntervalHours,
                    onChanged: (v) {
                      notifier.updateState((s) => s.copyWith(prnMinIntervalHours: v));
                    },
                    min: 0,
                    max: 24,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '0 = Pode tomar sem tempo mínimo de espera',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildModeCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
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
            Icon(
              icon,
              color: isSelected ? AppColors.primary : AppColors.textMuted,
              size: 28,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.text,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Text(
                subtitle,
                style: TextStyle(
                  fontSize: 10,
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
  }

  Widget _buildStepper({
    required int value,
    required Function(int) onChanged,
    required int min,
    required int max,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: () {
            if (value > min) onChanged(value - 1);
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
        ),
        const SizedBox(width: 16),
        GestureDetector(
          onTap: () {
            if (value < max) onChanged(value + 1);
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
