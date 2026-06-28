import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/database/database.dart';
import '../../alarms/data/alarm_repository.dart';
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

    final buildContext = context;

    try {
      if (isEdit) {
        await repo.updateMedication(widget.editMedication!.name, med);
      } else {
        await repo.createMedication(med);
      }
      
      if (buildContext.mounted) {
        ScaffoldMessenger.of(buildContext).showSnackBar(
          SnackBar(
            content: Text(isEdit ? t('meds_updated_toast') : t('meds_added_toast')),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.of(buildContext).pop();
      }
    } catch (e) {
      if (buildContext.mounted) {
        ScaffoldMessenger.of(buildContext).showSnackBar(
          SnackBar(
            content: Text(t('meds_save_error', [e])),
            backgroundColor: AppColors.missed,
          ),
        );
      }
    }
  }

  void _delete() async {
    final editMed = widget.editMedication;
    if (editMed == null) return;

    final medName = editMed.name;
    final alarmRepo = ref.read(alarmRepositoryProvider);
    final allAlarms = await alarmRepo.getAllAlarms();

    final linkedAlarms = allAlarms.where((a) => a.medName == medName || a.name == medName).toList();
    final buildContext = context;

    if (!buildContext.mounted) return;

    if (linkedAlarms.isNotEmpty) {
      final inUseText = '• $medName (${linkedAlarms.length} alarme${linkedAlarms.length > 1 ? 's' : ''})';
      showDialog(
        context: buildContext,
        builder: (dialogCtx) => AlertDialog(
          title: Text(t('dialog_delete_blocked_title')),
          content: Text(
            t('dialog_delete_blocked_desc', [inUseText])
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: Text(t('ok_btn'), style: TextStyle(color: AppColors.primary)),
            ),
          ],
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: buildContext,
      builder: (dialogCtx) => AlertDialog(
        title: Text(t('med_delete_btn')),
        content: Text(t('dialog_delete_med_desc')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: Text(t('cancel_btn').toUpperCase(), style: TextStyle(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: Text(t('btn_delete_caps'), style: TextStyle(color: AppColors.missed)),
          ),
        ],
      ),
    );

    if (confirmed == true && buildContext.mounted) {
      final repo = ref.read(medicationRepositoryProvider);
      try {
        await repo.deleteMedication(editMed.name);
        if (buildContext.mounted) {
          ScaffoldMessenger.of(buildContext).showSnackBar(
            SnackBar(
              content: Text(t('med_deleted_toast')),
              backgroundColor: AppColors.success,
            ),
          );
          Navigator.of(buildContext).pop();
        }
      } catch (e) {
        if (buildContext.mounted) {
          ScaffoldMessenger.of(buildContext).showSnackBar(
            SnackBar(
              content: Text(t('med_delete_error', [e])),
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
        title: Text(isEdit ? t('edit_med_title') : t('new_med_title')),
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
                  style: TextStyle(color: AppColors.text, fontSize: 18),
                  decoration: InputDecoration(
                    labelText: t('med_name_label_clean'),
                    hintText: t('med_name_hint'),
                    hintStyle: TextStyle(color: AppColors.textMuted),
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return t('meds_name_required');
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // 2. Dosage
                TextFormField(
                  controller: _dosageController,
                  style: TextStyle(color: AppColors.text, fontSize: 15),
                  decoration: InputDecoration(
                    labelText: t('med_dosage_label_optional'),
                    hintText: t('med_dosage_placeholder'),
                    hintStyle: TextStyle(color: AppColors.textMuted),
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
                        Text(t('med_type_card_title'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: _selectedType,
                          dropdownColor: AppColors.surface,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          style: TextStyle(color: AppColors.text, fontSize: 15),
                          items: [
                            DropdownMenuItem(value: 'comprimido', child: Text(t('med_type_tablet'))),
                            DropdownMenuItem(value: 'capsula', child: Text(t('med_type_capsule'))),
                            DropdownMenuItem(value: 'gota', child: Text(t('med_type_drops'))),
                            DropdownMenuItem(value: 'xarope', child: Text(t('med_type_syrup'))),
                            DropdownMenuItem(value: 'inalador', child: Text(t('med_type_inhaler'))),
                            DropdownMenuItem(value: 'injetavel', child: Text(t('med_type_injectable'))),
                            DropdownMenuItem(value: 'pomada', child: Text(t('med_type_ointment'))),
                            DropdownMenuItem(value: 'outro', child: Text(t('med_type_other'))),
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
                Text(
                  t('meds_form_color_label'),
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.text),
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
                            side: BorderSide(color: AppColors.missed),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.delete_rounded),
                          label: Text(t('btn_delete_caps'), style: const TextStyle(fontWeight: FontWeight.bold)),
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
                          isEdit ? t('btn_save_changes_caps') : t('btn_register_caps'),
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
                color: isSelected ? Colors.white.withValues(alpha: 0.8) : Colors.transparent,
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
