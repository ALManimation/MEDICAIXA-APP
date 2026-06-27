import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/database/database.dart';
import '../data/medication_repository.dart';
import 'medication_form_screen.dart';

class MedicationsListScreen extends ConsumerStatefulWidget {
  const MedicationsListScreen({super.key});

  @override
  ConsumerState<MedicationsListScreen> createState() => _MedicationsListScreenState();
}

class _MedicationsListScreenState extends ConsumerState<MedicationsListScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  IconData _getTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'comprimido':
        return Icons.medication_rounded;
      case 'capsula':
        return Icons.medication_liquid_rounded;
      case 'gota':
        return Icons.water_drop_rounded;
      case 'xarope':
        return Icons.opacity_rounded;
      case 'inalador':
        return Icons.air_rounded;
      case 'injetavel':
        return Icons.vaccines_rounded;
      case 'pomada':
        return Icons.clean_hands_rounded;
      case 'outro':
      default:
        return Icons.healing_rounded;
    }
  }

  String _formatType(String type) {
    switch (type.toLowerCase()) {
      case 'comprimido':
        return 'Comprimido';
      case 'capsula':
        return 'Cápsula';
      case 'gota':
        return 'Gotas';
      case 'xarope':
        return 'Xarope';
      case 'inalador':
        return 'Inalador';
      case 'injetavel':
        return 'Injetável';
      case 'pomada':
        return 'Pomada';
      case 'outro':
      default:
        return 'Outro';
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(medicationRepositoryProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Medicamentos Cadastrados'),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const MedicationFormScreen()),
          );
        },
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        tooltip: 'Novo Medicamento',
        child: const Icon(Icons.add_rounded),
      ),
      body: Column(
        children: [
          // Search box
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Pesquisar medicamentos...',
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textMuted),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, color: AppColors.textMuted),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // Medications List
          Expanded(
            child: StreamBuilder<List<Medication>>(
              stream: repo.watchAllMedications(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                var list = snapshot.data ?? [];
                if (_searchQuery.isNotEmpty) {
                  list = list.where((m) => m.name.toLowerCase().contains(_searchQuery)).toList();
                }

                if (list.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.medication_rounded, size: 48, color: AppColors.textMuted),
                        const SizedBox(height: 12),
                        Text(
                          _searchQuery.isNotEmpty ? 'Nenhum medicamento correspondente.' : 'Nenhum medicamento cadastrado.',
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 14),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final med = list[index];
                    final color = AppColors.getAlarmColor(med.color);
                    final typeIcon = _getTypeIcon(med.type);
                    final typeLabel = _formatType(med.type);
                    
                    return Card(
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(typeIcon, color: color, size: 22),
                        ),
                        title: Text(
                          med.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        subtitle: Text(
                          '${med.dosage != null ? "${med.dosage} · " : ""}$typeLabel',
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (med.pendingSync)
                              const Padding(
                                padding: EdgeInsets.only(right: 8.0),
                                child: Icon(Icons.cloud_upload_rounded, color: AppColors.pending, size: 18),
                              ),
                            const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                          ],
                        ),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => MedicationFormScreen(editMedication: med),
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
