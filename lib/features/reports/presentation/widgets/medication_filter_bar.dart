import 'package:flutter/material.dart';
import 'package:medicaixa_app/core/constants/app_colors.dart';

import 'package:medicaixa_app/core/localization/app_localizations.dart';

class MedicationFilterBar extends StatelessWidget {
  final String selectedMedication;
  final List<String> availableMedications;
  final ValueChanged<String> onSelected;

  const MedicationFilterBar({
    super.key,
    required this.selectedMedication,
    required this.availableMedications,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        itemCount: availableMedications.length,
        itemBuilder: (context, index) {
          final med = availableMedications[index];
          final isSelected = med == selectedMedication;

          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              label: Text(
                med == 'Todos' ? t('stats_filter_all') : med,
                style: TextStyle(
                  color: isSelected ? Colors.white : AppColors.text,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              selected: isSelected,
              selectedColor: AppColors.primary,
              backgroundColor: AppColors.surfaceVariant,
              checkmarkColor: Colors.black,
              onSelected: (selected) {
                if (selected) {
                  onSelected(med);
                }
              },
            ),
          );
        },
      ),
    );
  }
}
