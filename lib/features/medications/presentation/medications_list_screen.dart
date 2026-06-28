import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
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
        return t('med_type_tablet');
      case 'capsula':
        return t('med_type_capsule');
      case 'gota':
        return t('med_type_drops');
      case 'xarope':
        return t('med_type_syrup');
      case 'inalador':
        return t('med_type_inhaler');
      case 'injetavel':
        return t('med_type_injectable');
      case 'pomada':
        return t('med_type_ointment');
      case 'outro':
      default:
        return t('med_type_other');
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
      final linkedAlarms = allAlarms.where((a) => a.medName == medName || a.name == medName).toList();
      if (linkedAlarms.isNotEmpty) {
        inUseList.add('• $medName (${linkedAlarms.length} alarme${linkedAlarms.length > 1 ? 's' : ''})');
      }
    }

    final buildContext = context;

    if (inUseList.isNotEmpty && buildContext.mounted) {
      showDialog(
        context: buildContext,
        builder: (dialogCtx) => AlertDialog(
          title: Text(t('dialog_delete_blocked_title')),
          content: Text(
            t('dialog_delete_blocked_desc', [inUseList.join('\n')])
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

    // Confirmar exclusão
    if (buildContext.mounted) {
      final confirmed = await showDialog<bool>(
        context: buildContext,
        builder: (dialogCtx) => AlertDialog(
          title: Text(t('dialog_confirm_delete_title')),
          content: Text(t('dialog_confirm_delete_meds_desc', [_selectedMeds.length])),
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

      if (confirmed == true) {
        try {
          for (final name in _selectedMeds) {
            await medRepo.deleteMedication(name);
          }
          if (buildContext.mounted) {
            ScaffoldMessenger.of(buildContext).showSnackBar(
              SnackBar(
                content: Text(t('meds_deleted_success')),
                backgroundColor: AppColors.success,
              ),
            );
            _clearSelection();
          }
        } catch (e) {
          if (buildContext.mounted) {
            ScaffoldMessenger.of(buildContext).showSnackBar(
              SnackBar(
                content: Text(t('meds_delete_error', [e])),
                backgroundColor: AppColors.missed,
              ),
            );
          }
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
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t('nav_meds'),
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: AppColors.text,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              t('meds_subtitle'),
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.textMuted,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
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
                            _isSelectionMode ? t('cancel_btn') : t('meds_select'),
                            style: TextStyle(
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
                        ? '1 ${t('meds_count_singular')}'
                        : t('meds_count_plural', [allMeds.length]),
                    style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                  ),
                ),

                // 3. Search Box
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: TextField(
                    controller: _searchController,
                    style: TextStyle(color: AppColors.text),
                    decoration: InputDecoration(
                      labelText: t('search_meds_placeholder'),
                      prefixIcon: Icon(Icons.search_rounded, color: AppColors.textMuted),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear_rounded, color: AppColors.textMuted),
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
                                  Icon(Icons.medication_rounded, size: 48, color: AppColors.textMuted),
                                  const SizedBox(height: 12),
                                  Text(
                                    _searchQuery.isNotEmpty
                                        ? t('meds_search_no_results')
                                        : t('meds_list_empty'),
                                    style: TextStyle(color: AppColors.textMuted, fontSize: 14),
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
                                          ? color.withValues(alpha: 0.08)
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
                                                      style: TextStyle(
                                                        color: AppColors.text,
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
                                                      style: TextStyle(
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
                                                style: TextStyle(
                                                  color: AppColors.textMuted,
                                                  fontSize: 12.5,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (!_isSelectionMode && med.pendingSync)
                                          Icon(
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
                border: Border(top: BorderSide(color: AppColors.border, width: 1)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _clearSelection,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.text,
                        side: BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(t('meds_clear_selection')),
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
                      child: Text(t('btn_delete_count_fmt', [_selectedMeds.length])),
                    ),
                  ),
                ],
              ),
            )
          : null,
    );
  }
}
