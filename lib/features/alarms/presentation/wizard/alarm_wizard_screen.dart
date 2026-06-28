import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/alarm_model.dart';
import '../../../dashboard/presentation/dashboard_notifier.dart';
import 'wizard_notifier.dart';

// Steps (we will create these files next)
import 'steps/step_1_name.dart';
import 'steps/step_2_mode.dart';
import 'steps/step_3_qty.dart';
import 'steps/step_4_days.dart';
import 'steps/step_5_time.dart';
import 'steps/step_6_duration.dart';
import 'steps/step_7_summary.dart';

class AlarmWizardScreen extends ConsumerStatefulWidget {
  final AlarmModel? editAlarm;
  const AlarmWizardScreen({super.key, this.editAlarm});

  @override
  ConsumerState<AlarmWizardScreen> createState() => _AlarmWizardScreenState();
}

class _AlarmWizardScreenState extends ConsumerState<AlarmWizardScreen> {
  late PageController _pageController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Starting at page index 0 which corresponds to Step 1
    _pageController = PageController(initialPage: 0);
    
    if (widget.editAlarm != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(wizardNotifierProvider.notifier).loadAlarmForEdit(widget.editAlarm!);
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(wizardNotifierProvider.notifier).reset();
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(wizardNotifierProvider);
    final notifier = ref.read(wizardNotifierProvider.notifier);

    // Sincronizar o PageView se o estado pular passos
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pageController.hasClients) {
        final targetPage = state.step - 1;
        if (_pageController.page?.round() != targetPage) {
          _pageController.animateToPage(
            targetPage,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: AppColors.text),
          onPressed: () {
            notifier.reset();
            Navigator.of(context).pop();
          },
        ),
        title: Column(
          children: [
            Text(
              state.editingAlarmId != null ? 'Editar Alarme — Passo ${state.step} de 7' : 'Passo ${state.step} de 7',
              style: TextStyle(
                color: AppColors.text,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            // Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: state.step / 7,
                backgroundColor: AppColors.surfaceVariant,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                minHeight: 4,
              ),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(), // Only navigate via buttons
                children: [
                  const WizardStep1Name(),
                  const WizardStep2Mode(),
                  const WizardStep3Qty(),
                  const WizardStep4Days(),
                  const WizardStep5Time(),
                  const WizardStep6Duration(),
                  const WizardStep7Summary(),
                ],
              ),
            ),
            
            // Footer Navigation
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.surfaceVariant)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Back Button
                  if (state.step > 1)
                    TextButton(
                      onPressed: _isSaving ? null : () => notifier.prevStep(),
                      child: Text('VOLTAR', style: TextStyle(color: AppColors.textMuted)),
                    )
                  else
                    const SizedBox.shrink(), // placeholder to keep flex alignment

                  // Next Button
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _isSaving
                        ? null
                        : () async {
                            if (state.step == 7) {
                              setState(() => _isSaving = true);
                              try {
                                await notifier.saveAlarm();
                                if (context.mounted) {
                                  ref.invalidate(dashboardNotifierProvider);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(state.editingAlarmId != null
                                          ? 'Alarme atualizado com sucesso!'
                                          : 'Remédio cadastrado com sucesso!'),
                                      backgroundColor: AppColors.success,
                                    ),
                                  );
                                  Navigator.of(context).pop();
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Erro ao salvar: $e'),
                                      backgroundColor: AppColors.missed,
                                    ),
                                  );
                                }
                              } finally {
                                if (context.mounted) {
                                  setState(() => _isSaving = false);
                                }
                              }
                            } else {
                              final success = notifier.nextStep();
                              if (!success) {
                                final error = notifier.validateCurrentStep();
                                if (error != null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(error)),
                                  );
                                }
                              }
                            }
                          },
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(
                            state.step == 7
                                ? (state.editingAlarmId != null ? 'SALVAR ALTERAÇÕES' : 'TUDO CERTO! GUARDAR')
                                : 'AVANÇAR',
                            style: const TextStyle(fontWeight: FontWeight.bold),
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
