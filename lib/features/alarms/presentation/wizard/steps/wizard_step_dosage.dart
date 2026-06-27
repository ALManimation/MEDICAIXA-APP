import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/constants/app_colors.dart';
import '../alarm_wizard_notifier.dart';

class WizardStepDosage extends ConsumerStatefulWidget {
  final VoidCallback onNext;

  const WizardStepDosage({
    super.key,
    required this.onNext,
  });

  @override
  ConsumerState<WizardStepDosage> createState() => _WizardStepDosageState();
}

class _WizardStepDosageState extends ConsumerState<WizardStepDosage> {
  final _dosageController = TextEditingController();
  String _selectedType = 'comprimido';
  double _quantity = 1.0;

  final List<Map<String, dynamic>> _types = [
    {'id': 'comprimido', 'label': 'Comprimido', 'icon': Icons.medication_rounded},
    {'id': 'capsula', 'label': 'Cápsula', 'icon': Icons.medical_services_rounded},
    {'id': 'gota', 'label': 'Gota', 'icon': Icons.opacity_rounded},
    {'id': 'dose', 'label': 'Dose Líquida', 'icon': Icons.local_drink_rounded},
  ];

  @override
  void initState() {
    super.initState();
    final wizard = ref.read(alarmWizardNotifierProvider);
    _selectedType = wizard.alarm.type;
    _quantity = wizard.alarm.quantity;
    _dosageController.text = wizard.alarm.dosage ?? '';
  }

  @override
  void dispose() {
    _dosageController.dispose();
    super.dispose();
  }

  void _updateNotifier() {
    ref.read(alarmWizardNotifierProvider.notifier).updateDosage(
          _quantity,
          _selectedType,
          _dosageController.text.trim(),
        );
  }

  void _adjustQuantity(double amount) {
    setState(() {
      _quantity = (_quantity + amount).clamp(0.5, 100.0);
    });
    _updateNotifier();
  }

  String _formatQuantity(double qty) {
    if (qty == qty.toInt()) {
      return qty.toInt().toString();
    }
    return qty.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Defina o tipo e a quantidade',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 24),

        // Type Grid Selection
        const Text(
          'Tipo de medicamento',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 2.2,
          ),
          itemCount: _types.length,
          itemBuilder: (context, index) {
            final type = _types[index];
            final isSelected = type['id'] == _selectedType;
            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedType = type['id'] as String;
                });
                _updateNotifier();
              },
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary.withOpacity(0.1) : AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : AppColors.border,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      type['icon'] as IconData,
                      color: isSelected ? AppColors.primary : AppColors.textMuted,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      type['label'] as String,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : AppColors.text,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),

        const SizedBox(height: 32),

        // Quantity Selector
        const Text(
          'Quantidade da dose',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Minus button
              IconButton(
                onPressed: () => _adjustQuantity(-0.5),
                icon: Icon(Icons.remove_circle_outline_rounded, size: 28, color: AppColors.primary),
              ),
              // Quantity value
              Column(
                children: [
                  Text(
                    _formatQuantity(_quantity),
                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  Text(
                    _selectedType + (_quantity > 1 ? 's' : ''),
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                ],
              ),
              // Plus button
              IconButton(
                onPressed: () => _adjustQuantity(0.5),
                icon: Icon(Icons.add_circle_outline_rounded, size: 28, color: AppColors.primary),
              ),
            ],
          ),
        ),

        const SizedBox(height: 32),

        // Dosage Text Input
        const Text(
          'Dosagem (opcional)',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _dosageController,
          onChanged: (_) => _updateNotifier(),
          decoration: InputDecoration(
            hintText: 'Ex: 50mg, 10ml, 5mcg...',
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: AppColors.primary),
            ),
          ),
        ),

        const Spacer(),
        ElevatedButton(
          onPressed: () {
            _updateNotifier();
            widget.onNext();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 56),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: const Text(
            'Avançar',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
