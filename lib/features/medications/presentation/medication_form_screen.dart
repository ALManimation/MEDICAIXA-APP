import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/database/database.dart';
import '../data/medication_repository.dart';

class MedicationFormScreen extends ConsumerStatefulWidget {
  final Medication? editMedication;
  
  const MedicationFormScreen({super.key, this.editMedication});

  @override
  ConsumerState<MedicationFormScreen> createState() => _MedicationFormScreenState();
}

class _MedicationFormScreenState extends ConsumerState<MedicationFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _dosageController;
  
  String _selectedType = 'comprimido';
  String _selectedColor = 'white';

  @override
  void initState() {
    super.initState();
    final m = widget.editMedication;
    _nameController = TextEditingController(text: m?.name ?? '');
    _dosageController = TextEditingController(text: m?.dosage ?? '');
    _selectedType = m?.type ?? 'comprimido';
    _selectedColor = m?.color ?? 'white';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dosageController.dispose();
    super.dispose();
  }

  void _save() async {
    if (!_formKey.currentState!.validate()) return;
    
    final repo = ref.read(medicationRepositoryProvider);
    final isEdit = widget.editMedication != null;
    
    final name = _nameController.text.trim();
    final dosage = _dosageController.text.trim();
    
    final med = Medication(
      name: name,
      color: _selectedColor,
      type: _selectedType,
      dosage: dosage.isEmpty ? null : dosage,
      pendingSync: false,
    );

    try {
      if (isEdit) {
        await repo.updateMedication(widget.editMedication!.name, med);
      } else {
        await repo.createMedication(med);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEdit ? 'Medicamento atualizado com sucesso!' : 'Medicamento cadastrado com sucesso!'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar medicamento: $e'),
            backgroundColor: AppColors.missed,
          ),
        );
      }
    }
  }

  void _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Medicamento'),
        content: const Text('Deseja mesmo excluir este medicamento do cadastro?'),
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

    if (confirmed == true) {
      final repo = ref.read(medicationRepositoryProvider);
      try {
        await repo.deleteMedication(widget.editMedication!.name);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Medicamento excluído com sucesso!'),
              backgroundColor: AppColors.success,
            ),
          );
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
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
    final isEdit = widget.editMedication != null;
    
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(isEdit ? 'Editar Medicamento' : 'Cadastrar Medicamento'),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Name
                TextFormField(
                  controller: _nameController,
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                  decoration: InputDecoration(
                    labelText: 'Nome do Medicamento',
                    hintText: 'Ex: Paracetamol, Ibuprofeno',
                    hintStyle: const TextStyle(color: AppColors.textMuted),
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'O nome é obrigatório';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // 2. Dosage
                TextFormField(
                  controller: _dosageController,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                  decoration: InputDecoration(
                    labelText: 'Dosagem padrão (Opcional)',
                    hintText: 'Ex: 500mg, 1 comprimido',
                    hintStyle: const TextStyle(color: AppColors.textMuted),
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // 3. Type Selection
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Forma de Apresentação (Tipo)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: _selectedType,
                          dropdownColor: AppColors.surface,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          style: const TextStyle(color: Colors.white, fontSize: 15),
                          items: const [
                            DropdownMenuItem(value: 'comprimido', child: Text('Comprimido')),
                            DropdownMenuItem(value: 'capsula', child: Text('Cápsula')),
                            DropdownMenuItem(value: 'gota', child: Text('Gotas')),
                            DropdownMenuItem(value: 'xarope', child: Text('Xarope')),
                            DropdownMenuItem(value: 'inalador', child: Text('Inalador')),
                            DropdownMenuItem(value: 'injetavel', child: Text('Injetável')),
                            DropdownMenuItem(value: 'pomada', child: Text('Pomada')),
                            DropdownMenuItem(value: 'outro', child: Text('Outro')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _selectedType = val;
                              });
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // 4. Color Picker
                const Text(
                  'Identificação Visual (Cor)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 12),
                _buildColorPicker(),
                const SizedBox(height: 40),

                // 5. Save and Delete buttons
                Row(
                  children: [
                    if (isEdit) ...[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _delete,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.missed,
                            side: const BorderSide(color: AppColors.missed),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.delete_rounded),
                          label: const Text('EXCLUIR', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 16),
                    ],
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          isEdit ? 'SALVAR ALTERAÇÕES' : 'CADASTRAR',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildColorPicker() {
    final colors = [
      {'id': 'white', 'color': const Color(0xFFFFFFFF)},
      {'id': 'red', 'color': const Color(0xFFFF0000)},
      {'id': 'green', 'color': const Color(0xFF00FF00)},
      {'id': 'blue', 'color': const Color(0xFF0000FF)},
      {'id': 'yellow', 'color': const Color(0xFFFFFF00)},
      {'id': 'magenta', 'color': const Color(0xFFFF00FF)},
      {'id': 'cyan', 'color': const Color(0xFF00FFFF)},
      {'id': 'orange', 'color': const Color(0xFFFFA500)},
      {'id': 'purple', 'color': const Color(0xFF800080)},
      {'id': 'pink', 'color': const Color(0xFFFFC0CB)},
      {'id': 'teal', 'color': const Color(0xFF008080)},
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: colors.map((c) {
        final isSelected = _selectedColor == c['id'];
        final colorVal = c['color'] as Color;
        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedColor = c['id'] as String;
            });
          },
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: colorVal,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? Colors.white.withOpacity(0.8) : Colors.transparent,
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: isSelected
                ? Icon(
                    Icons.check_rounded,
                    color: c['id'] == 'white' || c['id'] == 'yellow' ? Colors.black : Colors.white,
                    size: 20,
                  )
                : null,
          ),
        );
      }).toList(),
    );
  }
}
