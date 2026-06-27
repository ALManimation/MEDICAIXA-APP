import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/database/database.dart';
import '../../alarms/data/alarm_repository.dart';
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
  
  bool _isSelectionMode = false;
  final Set<String> _selectedMeds = {};

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

  void _toggleSelection(String name) {
    setState(() {
      if (_selectedMeds.contains(name)) {
        _selectedMeds.remove(name);
      } else {
        _selectedMeds.add(name);
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedMeds.clear();
      _isSelectionMode = false;
    });
  }

  Future<void> _deleteSelected() async {
    if (_selectedMeds.isEmpty) return;

    final alarmRepo = ref.read(alarmRepositoryProvider);
    final medRepo = ref.read(medicationRepositoryProvider);
    
    // Obter todos os alarmes cadastrados
    final allAlarms = await alarmRepo.getAllAlarms();

    final List<String> inUseList = [];

    for (final medName in _selectedMeds) {
      final linkedAlarms = allAlarms.where((a) => a.name == medName).toList();
      if (linkedAlarms.isNotEmpty) {
        inUseList.add('• $medName (${linkedAlarms.length} alarme${linkedAlarms.length > 1 ? 's' : ''})');
      }
    }

    if (inUseList.isNotEmpty && mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Não é possível excluir'),
          content: Text(
            'Não é possível excluir medicamentos em uso por alarmes:\n\n'
            '${inUseList.join('\n')}\n\n'
            'Exclua os alarmes primeiro.'
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK', style: TextStyle(color: AppColors.primary)),
            ),
          ],
        ),
      );
      return;
    }

    // Confirmar exclusão
    if (mounted) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirmar Exclusão'),
          content: Text('Excluir ${_selectedMeds.length} medicamento(s)?\n\nEsta ação não pode ser desfeita.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('CANCELAR', style: TextStyle(color: AppColors.textMuted)),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('EXCLUIR', style: TextStyle(color: AppColors.missed)),
            ),
          ],
        ),
      );

      if (confirmed == true && mounted) {
        try {
          for (final name in _selectedMeds) {
            await medRepo.deleteMedication(name);
          }
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Medicamentos excluídos com sucesso!'),
              backgroundColor: AppColors.success,
            ),
          );
          _clearSelection();
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao excluir: $e'),
              backgroundColor: AppColors.missed,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(medicationRepositoryProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: StreamBuilder<List<Medication>>(
          stream: repo.watchAllMedications(),
          builder: (context, snapshot) {
            final allMeds = snapshot.data ?? [];
            var filteredList = allMeds;
            if (_searchQuery.isNotEmpty) {
              filteredList = allMeds.where((m) => m.name.toLowerCase().contains(_searchQuery)).toList();
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Header Fiel ao index.html
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Remédios',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Gerenciar Medicamentos',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                      if (allMeds.isNotEmpty)
                        TextButton(
                          onPressed: () {
                            setState(() {
                              if (_isSelectionMode) {
                                _clearSelection();
                              } else {
                                _isSelectionMode = true;
                              }
                            });
                          },
                          child: Text(
                            _isSelectionMode ? 'Cancelar' : 'Selecionar',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // 2. Count label (ex: 29 medicamentos)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Text(
                    allMeds.length == 1
                        ? '1 medicamento'
                        : '${allMeds.length} medicamentos',
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                  ),
                ),

                // 3. Search Box
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
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

                const SizedBox(height: 10),

                // 4. Medications List (Pill Cards style)
                Expanded(
                  child: snapshot.connectionState == ConnectionState.waiting
                      ? const Center(child: CircularProgressIndicator())
                      : filteredList.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.medication_rounded, size: 48, color: AppColors.textMuted),
                                  const SizedBox(height: 12),
                                  Text(
                                    _searchQuery.isNotEmpty
                                        ? 'Nenhum medicamento correspondente.'
                                        : 'Nenhum medicamento cadastrado.',
                                    style: const TextStyle(color: AppColors.textMuted, fontSize: 14),
                                  ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(24, 8, 24, 100),
                              itemCount: filteredList.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 16),
                              itemBuilder: (context, index) {
                                final med = filteredList[index];
                                final color = AppColors.getAlarmColor(med.color);
                                final typeLabel = _formatType(med.type);
                                final isSelected = _selectedMeds.contains(med.name);

                                return GestureDetector(
                                  onTap: () {
                                    if (_isSelectionMode) {
                                      _toggleSelection(med.name);
                                    } else {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => MedicationFormScreen(editMedication: med),
                                        ),
                                      );
                                    }
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? color.withOpacity(0.08)
                                          : AppColors.surface,
                                      borderRadius: BorderRadius.circular(30),
                                      border: Border.all(
                                        color: color,
                                        width: 2.5,
                                      ),
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                                    child: Row(
                                      children: [
                                        if (_isSelectionMode) ...[
                                          Icon(
                                            isSelected
                                                ? Icons.check_circle_rounded
                                                : Icons.radio_button_unchecked_rounded,
                                            color: color,
                                            size: 24,
                                          ),
                                          const SizedBox(width: 16),
                                        ],
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                                textBaseline: TextBaseline.alphabetic,
                                                children: [
                                                  Flexible(
                                                    child: Text(
                                                      med.name,
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 16,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  if (med.dosage != null && med.dosage!.isNotEmpty) ...[
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      med.dosage!,
                                                      style: const TextStyle(
                                                        color: AppColors.textMuted,
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                typeLabel,
                                                style: const TextStyle(
                                                  color: AppColors.textMuted,
                                                  fontSize: 12.5,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (!_isSelectionMode && med.pendingSync)
                                          const Icon(
                                            Icons.cloud_upload_rounded,
                                            color: AppColors.pending,
                                            size: 20,
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                ),
              ],
            );
          },
        ),
      ),
      
      // Bottom Bar for Multi-Delete Actions
      bottomSheet: _isSelectionMode && _selectedMeds.isNotEmpty
          ? Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: const Border(top: BorderSide(color: AppColors.border, width: 1)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _clearSelection,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Limpar Seleção'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _deleteSelected,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.missed,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text('Excluir (${_selectedMeds.length})'),
                    ),
                  ),
                ],
              ),
            )
          : null,
    );
  }
}
