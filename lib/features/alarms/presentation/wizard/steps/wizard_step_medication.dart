import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/constants/app_colors.dart';
import '../../../../medications/data/medication_model.dart';
import '../../../../medications/data/medication_repository.dart';
import '../alarm_wizard_notifier.dart';

class WizardStepMedication extends ConsumerStatefulWidget {
  final VoidCallback onNext;

  const WizardStepMedication({
    super.key,
    required this.onNext,
  });

  @override
  ConsumerState<WizardStepMedication> createState() => _WizardStepMedicationState();
}

class _WizardStepMedicationState extends ConsumerState<WizardStepMedication> {
  final _searchController = TextEditingController();
  List<MedicationModel> _results = [];
  Timer? _debounceTimer;
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    // Load pre-selected name if editing or returning
    final wizard = ref.read(alarmWizardNotifierProvider);
    if (wizard.alarm.name.isNotEmpty) {
      _searchController.text = wizard.alarm.name;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer?.cancel();
    if (query.trim().length < 2) {
      setState(() {
        _results = [];
        _searching = false;
      });
      return;
    }

    setState(() {
      _searching = true;
    });

    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      final repo = ref.read(medicationRepositoryProvider);
      final list = await repo.search(query);
      if (context.mounted) {
        setState(() {
          _results = list;
          _searching = false;
        });
      }
    });
  }

  void _selectMedication(String name, String type, String dosage, String? category, String? instruction) {
    final notifier = ref.read(alarmWizardNotifierProvider.notifier);
    notifier.updateMedication(
      name,
      type,
      dosage,
      _getColorForCategory(category),
      instruction,
    );
    widget.onNext();
  }

  String _getColorForCategory(String? category) {
    if (category == null) return 'blue';
    switch (category.toLowerCase()) {
      case 'vitamina':
      case 'suplemento':
        return 'green';
      case 'psiquiatrico':
        return 'purple';
      case 'analgesico':
      case 'anti-inflamatorio':
        return 'cyan';
      case 'cardiovascular':
        return 'magenta';
      case 'hormonio':
        return 'pink';
      default:
        return 'blue';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Qual medicamento deseja agendar?',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Busque no banco nacional da ANVISA ou digite o nome completo.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 14),
        ),
        const SizedBox(height: 24),

        // Search Input
        TextField(
          controller: _searchController,
          onChanged: _onSearchChanged,
          decoration: InputDecoration(
            hintText: 'Ex: Losartana, Dipirona, Omega 3...',
            prefixIcon: const Icon(Icons.search_rounded),
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
        const SizedBox(height: 16),

        // Results or Manual Option
        Expanded(
          child: _searching
              ? const Center(child: CircularProgressIndicator())
              : _searchController.text.trim().length >= 2 && _results.isEmpty
                  ? _buildManualOption()
                  : _results.isEmpty
                      ? _buildEmptyState()
                      : _buildResultsList(),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 48,
            color: AppColors.textMuted.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 12),
          Text(
            'Digite o nome do remédio para iniciar a busca.',
            style: TextStyle(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildManualOption() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Não encontramos este medicamento na busca.',
            style: TextStyle(color: AppColors.textMuted),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              _selectMedication(
                _searchController.text.trim(),
                'comprimido',
                '',
                null,
                null,
              );
            },
            icon: const Icon(Icons.add_rounded),
            label: Text('Usar "${_searchController.text}"'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsList() {
    return ListView.builder(
      itemCount: _results.length + 1,
      itemBuilder: (context, index) {
        if (index == _results.length) {
          // Add custom manual add row at the end
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: AppColors.border,
              child: const Icon(Icons.add_rounded, color: Colors.white),
            ),
            title: Text('Adicionar "${_searchController.text}" manualmente'),
            onTap: () {
              _selectMedication(
                _searchController.text.trim(),
                'comprimido',
                '',
                null,
                null,
              );
            },
          );
        }

        final med = _results[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppColors.surfaceVariant,
              child: Icon(
                _getTypeIcon(med.type),
                color: AppColors.primary,
              ),
            ),
            title: Text(
              med.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '${med.dosage} · ${med.generic}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () {
              _selectMedication(
                med.name,
                med.type,
                med.dosage,
                med.category,
                med.instruction,
              );
            },
          ),
        );
      },
    );
  }

  IconData _getTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'capsula':
        return Icons.medical_services_rounded;
      case 'gota':
        return Icons.opacity_rounded;
      case 'dose':
        return Icons.local_drink_rounded;
      case 'comprimido':
      default:
        return Icons.medication_rounded;
    }
  }
}
