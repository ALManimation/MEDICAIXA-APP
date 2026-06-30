import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/constants/app_colors.dart';
import '../../../../medications/data/medication_repository.dart';
import '../../../data/medication_search_service.dart';
import '../wizard_notifier.dart';

class WizardStep1Name extends ConsumerStatefulWidget {
  const WizardStep1Name({super.key});

  @override
  ConsumerState<WizardStep1Name> createState() => _WizardStep1NameState();
}

class _WizardStep1NameState extends ConsumerState<WizardStep1Name> {
  bool _showManualDosageInput = false;
  bool _selectedFromDropdown = false;
  late FocusNode _dosageFocusNode;
  late TextEditingController _dosageController;

  @override
  void initState() {
    super.initState();
    _dosageFocusNode = FocusNode();
    _dosageFocusNode.addListener(_onDosageFocusChange);
    _dosageController = TextEditingController();
  }

  @override
  void dispose() {
    _dosageFocusNode.removeListener(_onDosageFocusChange);
    _dosageFocusNode.dispose();
    _dosageController.dispose();
    super.dispose();
  }

  void _onDosageFocusChange() {
    if (!_dosageFocusNode.hasFocus) {
      // Focus lost (blur event) - format dosage if it is a pure number
      final state = ref.read(wizardNotifierProvider);
      final val = state.dosage.trim();
      if (val.isNotEmpty) {
        final numberMatch = RegExp(r'^(\d+(?:[.,]\d+)?)$').firstMatch(val);
        if (numberMatch != null) {
          final cleanNum = numberMatch.group(1)!.replaceAll(',', '.');
          String updatedDosage = val;
          if (state.type == 'dose' || state.type == 'gota') {
            updatedDosage = '${cleanNum}ml';
          } else if (state.type == 'comprimido' || state.type == 'capsula' || state.type == 'adesivo' || state.type == 'injetavel') {
            updatedDosage = '${cleanNum}mg';
          }
          if (updatedDosage != val) {
            ref.read(wizardNotifierProvider.notifier).updateState(
              (s) => s.copyWith(dosage: updatedDosage),
            );
          }
        }
      }
    }
  }

  void _updateType(String newType) {
    final notifier = ref.read(wizardNotifierProvider.notifier);
    notifier.updateState((s) {
      String dosage = s.dosage.trim();
      if (dosage.isNotEmpty) {
        final numberMatch = RegExp(r'^(\d+(?:[.,]\d+)?)$').firstMatch(dosage);
        if (numberMatch != null) {
          final cleanNum = numberMatch.group(1)!.replaceAll(',', '.');
          if (newType == 'dose' || newType == 'gota') {
            dosage = '${cleanNum}ml';
          } else if (newType == 'comprimido' || newType == 'capsula' || newType == 'adesivo' || newType == 'injetavel') {
            dosage = '${cleanNum}mg';
          }
        }
      }
      return s.copyWith(type: newType, dosage: dosage);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(wizardNotifierProvider);
    final notifier = ref.read(wizardNotifierProvider.notifier);

    // Watch the suggested dosages for the current medication name
    final suggestedDosagesAsync = ref.watch(medicationDosagesProvider(state.name));

    // Listen to changes in medication dosages to auto-select the first one
    ref.listen<AsyncValue<List<String>>>(medicationDosagesProvider(state.name), (previous, next) {
      next.whenData((dosages) {
        if (dosages.isNotEmpty) {
          if (!dosages.contains(state.dosage)) {
            Future.microtask(() {
              if (context.mounted) {
                ref.read(wizardNotifierProvider.notifier).updateState(
                  (s) => s.copyWith(dosage: dosages.first),
                );
              }
            });
          }
        }
      });
    });

    // Synchronize manual controller value when changed externally
    if (_dosageController.text != state.dosage && !_dosageFocusNode.hasFocus) {
      _dosageController.text = state.dosage;
    }

    final suggestedDosages = suggestedDosagesAsync.valueOrNull ?? [];
    final hasSuggestions = suggestedDosages.isNotEmpty;
    final showButtons = hasSuggestions && !_showManualDosageInput;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 1. Nome do remédio
          Text(
            'Qual é o nome do remédio?',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.text,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Autocomplete<MedicationAnvisa>(
            initialValue: TextEditingValue(text: state.name),
            optionsBuilder: (TextEditingValue textEditingValue) async {
              if (_selectedFromDropdown) {
                return const Iterable<MedicationAnvisa>.empty();
              }
              if (textEditingValue.text.length < 2) {
                return const Iterable<MedicationAnvisa>.empty();
              }
              final results = await ref.read(
                searchMedicationsProvider(textEditingValue.text).future,
              );
              return results;
            },
            displayStringForOption: (MedicationAnvisa option) => option.name,
            onSelected: (MedicationAnvisa selection) async {
              _selectedFromDropdown = true;
              setState(() {
                _showManualDosageInput = false;
              });
              final medRepo = ref.read(medicationRepositoryProvider);
              final savedMed = await medRepo.getMedicationByName(selection.name);
              final resolvedColor = savedMed?.color ?? ref.read(wizardNotifierProvider).color;
              notifier.updateState((s) => s.copyWith(
                name: selection.name,
                type: selection.type,
                dosage: selection.dosage,
                color: resolvedColor,
              ));
            },
            fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
              return TextField(
                controller: controller,
                focusNode: focusNode,
                onChanged: (val) async {
                  _selectedFromDropdown = false;
                  final medRepo = ref.read(medicationRepositoryProvider);
                  final savedMed = await medRepo.getMedicationByName(val);
                  final resolvedColor = savedMed?.color ?? ref.read(wizardNotifierProvider).color;
                  notifier.updateState((s) => s.copyWith(
                    name: val,
                    color: resolvedColor,
                  ));
                },
                onEditingComplete: onEditingComplete,
                style: TextStyle(color: AppColors.text, fontSize: 18),
                decoration: InputDecoration(
                  hintText: 'Digite o nome do remédio',
                  hintStyle: TextStyle(color: AppColors.textMuted),
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
              );
            },
            optionsViewBuilder: (context, onSelected, options) {
              return Align(
                alignment: Alignment.topLeft,
                child: Material(
                  elevation: 4,
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 250, maxWidth: 300),
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: options.length,
                      itemBuilder: (context, index) {
                        final option = options.elementAt(index);
                        return ListTile(
                          title: Text(option.name, style: TextStyle(color: AppColors.text)),
                          subtitle: Text('${option.type} • ${option.dosage}', style: TextStyle(color: AppColors.textMuted)),
                          onTap: () => onSelected(option),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),

          // 2. Como é esse remédio
          Text(
            'Como é esse remédio?',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.text,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          _buildTypeGrid(state.type),
          const SizedBox(height: 24),

          // 3. Força / Dosagem
          Text(
            'Qual é a força dele? (Dose na caixa)',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.text,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Exemplo: 50mg, 500mg, 100UI/ml, etc. Se não souber, pode deixar em branco.',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textMuted,
            ),
            textAlign: TextAlign.center,
          ),
          _buildDosageField(state.dosage, suggestedDosages, showButtons, (val) {
            notifier.updateState((s) => s.copyWith(dosage: val));
          }, () {
            setState(() {
              _showManualDosageInput = true;
            });
          }),
          const SizedBox(height: 24),

          // 4. Cor
          Text(
            'Escolha uma cor para identificar este remédio:',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.text,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Isso ajudará a diferenciar visualmente os cartões no painel.',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textMuted,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          _buildColorPicker(state.color, (c) {
            notifier.updateState((s) => s.copyWith(color: c));
          }),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildTypeGrid(String selectedType) {
    final types = [
      {'id': 'comprimido', 'label': 'Comprimido', 'icon': Icons.medication, 'sub': 'Dá para partir se precisar'},
      {'id': 'capsula', 'label': 'Cápsula', 'icon': Icons.medication_liquid, 'sub': 'Gelatina (dose inteira)'},
      {'id': 'gota', 'label': 'Gotinhas', 'icon': Icons.water_drop, 'sub': 'Líquido em gotas'},
      {'id': 'dose', 'label': 'Líquido', 'icon': Icons.science, 'sub': 'Xarope ou Dose (ml)'},
      {'id': 'adesivo', 'label': 'Adesivo', 'icon': Icons.healing, 'sub': 'De colar na pele'},
      {'id': 'injetavel', 'label': 'Injetável', 'icon': Icons.vaccines, 'sub': 'Injeção ou canetinha'},
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        int crossAxisCount = 2;
        double childAspectRatio = 1.5;

        if (width >= 900) {
          crossAxisCount = 6;
          childAspectRatio = 1.15;
        } else if (width >= 600) {
          crossAxisCount = 3;
          childAspectRatio = 1.35;
        } else {
          crossAxisCount = 2;
          childAspectRatio = 1.45;
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: childAspectRatio,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: types.length,
          itemBuilder: (context, index) {
            final t = types[index];
            final isSelected = selectedType == t['id'];
            return GestureDetector(
              onTap: () => _updateType(t['id'] as String),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
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
                      t['icon'] as IconData,
                      color: isSelected ? AppColors.primary : AppColors.textMuted,
                      size: 24,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      t['label'] as String,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.text,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 2),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2.0),
                      child: Text(
                        t['sub'] as String,
                        style: TextStyle(
                          fontSize: 9,
                          color: AppColors.textMuted,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
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
    );
  }

  Widget _buildDosageField(
    String currentDosage,
    List<String> suggestedDosages,
    bool showButtons,
    Function(String) onChanged,
    Function() onShowManual,
  ) {
    if (showButtons) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 16),
          Text(
            'Escolha a dosagem do remédio:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: suggestedDosages.map((dose) {
              final isSelected = currentDosage == dose;
              return ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isSelected ? AppColors.primary : AppColors.surface,
                  foregroundColor: isSelected ? Colors.black : AppColors.text,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(
                      color: isSelected ? AppColors.primary : AppColors.border,
                      width: 1.5,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onPressed: () => onChanged(dose),
                child: Text(
                  dose,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: onShowManual,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              alignment: Alignment.center,
              child: Text(
                'Digitar outra dose...',
                style: TextStyle(
                  color: AppColors.text,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 16),
          TextField(
            focusNode: _dosageFocusNode,
            controller: _dosageController,
            onChanged: onChanged,
            style: TextStyle(color: AppColors.text, fontSize: 18),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              hintText: 'Ex: 50mg',
              hintStyle: TextStyle(color: AppColors.textMuted),
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.border, width: 1.5),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.border, width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.primary, width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          ),
        ],
      );
    }
  }

  Widget _buildColorPicker(String selectedColor, Function(String) onSelect) {
    const colors = AppColors.alarmColors;

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: colors.entries.map((e) {
        final isSelected = selectedColor.toLowerCase() == e.key.toLowerCase();
        return GestureDetector(
          onTap: () => onSelect(e.key),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: e.value,
              shape: BoxShape.circle,
              border: isSelected
                  ? Border.all(
                      color: Colors.white,
                      width: 3,
                    )
                  : Border.all(
                      color: Colors.transparent,
                      width: 3,
                    ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
