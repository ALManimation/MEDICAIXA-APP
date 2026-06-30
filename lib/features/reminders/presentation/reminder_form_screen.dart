import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:medicaixa_app/features/dashboard/presentation/dashboard_notifier.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/presentation/widgets/vertical_datetime_selector.dart';
import '../data/reminder_model.dart';
import '../data/reminder_repository.dart';

class ReminderFormScreen extends ConsumerStatefulWidget {
  final ReminderModel? editReminder;
  
  const ReminderFormScreen({super.key, this.editReminder});

  @override
  ConsumerState<ReminderFormScreen> createState() => _ReminderFormScreenState();
}

class _ReminderFormScreenState extends ConsumerState<ReminderFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descController;
  late TextEditingController _intervalController;
  
  bool _hasTime = false;
  TimeOfDay _selectedTime = const TimeOfDay(hour: 8, minute: 0);
  
  String _selectedPeriod = ''; // '' = vez única, 'day', 'week', 'month', 'year'
  DateTime _selectedStartDate = DateTime.now();
  int _notifyDaysBefore = 0;
  String _selectedColor = 'blue';

  @override
  void initState() {
    super.initState();
    final r = widget.editReminder;
    _titleController = TextEditingController(text: r?.title ?? '');
    _descController = TextEditingController(text: r?.description ?? '');
    _intervalController = TextEditingController(text: r?.interval.toString() ?? '1');
    
    if (r != null) {
      _hasTime = r.hasTime;
      if (r.hasTime && r.hour != null && r.minute != null) {
        _selectedTime = TimeOfDay(hour: r.hour!, minute: r.minute!);
      }
      _selectedPeriod = r.period;
      _notifyDaysBefore = r.notifyDaysBefore;
      _selectedColor = AppColors.alarmColors.containsKey(r.color.toLowerCase()) ? r.color : 'blue';
      try {
        _selectedStartDate = DateTime.parse(r.startDate);
      } catch (_) {
        _selectedStartDate = DateTime.now();
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _intervalController.dispose();
    super.dispose();
  }

  void _selectStartDate() async {
    final picked = await showVerticalDatePicker(
      context,
      initialDate: _selectedStartDate,
    );
    if (picked != null) {
      setState(() {
        _selectedStartDate = picked;
      });
    }
  }

  void _selectTime() async {
    final picked = await showVerticalTimePicker(
      context,
      initialTime: _selectedTime,
    );
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  void _save() async {
    if (!_formKey.currentState!.validate()) return;
    
    final repo = ref.read(reminderRepositoryProvider);
    final isEdit = widget.editReminder != null;
    
    final title = _titleController.text.trim();
    final description = _descController.text.trim();
    final interval = int.tryParse(_intervalController.text) ?? 1;
    final startDateStr = DateFormat('yyyy-MM-dd').format(_selectedStartDate);
    
    final model = ReminderModel(
      id: isEdit ? widget.editReminder!.id : 0,
      title: title,
      description: description,
      enabled: isEdit ? widget.editReminder!.enabled : true,
      hasTime: _hasTime,
      hour: _hasTime ? _selectedTime.hour : null,
      minute: _hasTime ? _selectedTime.minute : null,
      period: _selectedPeriod,
      interval: _selectedPeriod.isEmpty ? 0 : interval,
      startDate: startDateStr,
      notifyDaysBefore: _notifyDaysBefore,
      lastCompletedDate: isEdit ? widget.editReminder!.lastCompletedDate : null,
      color: _selectedColor,
    );

    final buildContext = context;

    try {
      if (isEdit) {
        await repo.updateReminder(model);
      } else {
        await repo.createReminder(model);
      }
      
      ref.invalidate(dashboardNotifierProvider);
      
      if (buildContext.mounted) {
        ScaffoldMessenger.of(buildContext).showSnackBar(
          SnackBar(
            content: Text(isEdit ? 'Lembrete atualizado com sucesso!' : 'Lembrete criado com sucesso!'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.of(buildContext).pop();
      }
    } catch (e) {
      if (buildContext.mounted) {
        ScaffoldMessenger.of(buildContext).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar lembrete: $e'),
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
        title: const Text('Excluir Lembrete'),
        content: const Text('Deseja mesmo excluir este lembrete? Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('CANCELAR', style: TextStyle(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('EXCLUIR', style: TextStyle(color: AppColors.missed)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final repo = ref.read(reminderRepositoryProvider);
      final buildContext = context;
      try {
        await repo.deleteReminder(widget.editReminder!.id);
        ref.invalidate(dashboardNotifierProvider);
        if (buildContext.mounted) {
          ScaffoldMessenger.of(buildContext).showSnackBar(
            SnackBar(
              content: const Text('Lembrete excluído com sucesso!'),
              backgroundColor: AppColors.success,
            ),
          );
          Navigator.of(buildContext).pop();
        }
      } catch (e) {
        if (buildContext.mounted) {
          ScaffoldMessenger.of(buildContext).showSnackBar(
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
    final isEdit = widget.editReminder != null;
    
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(isEdit ? 'Editar Lembrete' : 'Novo Lembrete'),
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
                // 1. Title
                TextFormField(
                  controller: _titleController,
                  style: TextStyle(color: AppColors.text, fontSize: 18),
                  decoration: InputDecoration(
                    labelText: 'Título do Lembrete',
                    hintText: 'Ex: Consulta Cardiológica, Exame de Sangue',
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
                      return 'O título é obrigatório';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // 2. Description
                TextFormField(
                  controller: _descController,
                  maxLines: 3,
                  style: TextStyle(color: AppColors.text, fontSize: 15),
                  decoration: InputDecoration(
                    labelText: 'Descrição / Detalhes (Opcional)',
                    hintText: 'Ex: Trazer exames antigos, ir em jejum',
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

                // 3. Time configuration
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Column(
                      children: [
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Definir Hora Específica', style: TextStyle(fontWeight: FontWeight.bold)),
                          value: _hasTime,
                          activeThumbColor: AppColors.primary,
                          onChanged: (val) {
                            setState(() {
                              _hasTime = val;
                            });
                          },
                        ),
                        if (_hasTime) ...[
                          const Divider(),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text('Horário do Lembrete', style: TextStyle(color: AppColors.textMuted)),
                            subtitle: Text(
                              '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.text),
                            ),
                            trailing: Icon(Icons.access_time_rounded, color: AppColors.primary),
                            onTap: _selectTime,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // 4. Recurrence configuration
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Frequência', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: _selectedPeriod,
                          dropdownColor: AppColors.surface,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          style: TextStyle(color: AppColors.text, fontSize: 15),
                          items: const [
                            DropdownMenuItem(value: '', child: Text('Vez única (Sem repetição)')),
                            DropdownMenuItem(value: 'day', child: Text('A cada X Dias')),
                            DropdownMenuItem(value: 'week', child: Text('A cada X Semanas')),
                            DropdownMenuItem(value: 'month', child: Text('A cada X Meses')),
                            DropdownMenuItem(value: 'year', child: Text('A cada X Anos')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _selectedPeriod = val;
                              });
                            }
                          },
                        ),
                        if (_selectedPeriod.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _intervalController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: _selectedPeriod == 'day'
                                  ? 'Intervalo em dias'
                                  : _selectedPeriod == 'week'
                                      ? 'Intervalo em semanas'
                                      : _selectedPeriod == 'month'
                                          ? 'Intervalo em meses'
                                          : 'Intervalo em anos',
                              border: const OutlineInputBorder(),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Informe o intervalo';
                              }
                              final n = int.tryParse(val);
                              if (n == null || n <= 0) {
                                return 'O intervalo deve ser um número maior que 0';
                              }
                              return null;
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // 5. Start date & Notification lead time
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Column(
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text('Data de Início', style: TextStyle(color: AppColors.textMuted)),
                          subtitle: Text(
                            DateFormat('dd/MM/yyyy').format(_selectedStartDate),
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.text),
                          ),
                          trailing: Icon(Icons.calendar_month_rounded, color: AppColors.primary),
                          onTap: _selectStartDate,
                        ),
                        const Divider(),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text('Aviso Prévio (Dias)', style: TextStyle(color: AppColors.textMuted)),
                          subtitle: const Text('Mostrar lembrete quantos dias antes da data?'),
                          trailing: DropdownButton<int>(
                            value: _notifyDaysBefore,
                            dropdownColor: AppColors.surface,
                            style: TextStyle(color: AppColors.text, fontSize: 16),
                            items: List.generate(8, (i) {
                              return DropdownMenuItem(
                                value: i,
                                child: Text(i == 0 ? 'No dia' : '$i dias antes'),
                              );
                            }),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _notifyDaysBefore = val;
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // 6. Color Picker
                const Text(
                  'Identificação Visual (Cor)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 12),
                _buildColorPicker(),
                const SizedBox(height: 40),

                // 7. Save and Delete buttons
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
                          isEdit ? 'SALVAR ALTERAÇÕES' : 'CRIAR LEMBRETE',
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
    final colors = AppColors.alarmColors.entries.toList();

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: colors.map((entry) {
        final colorId = entry.key;
        final colorVal = entry.value;
        final isSelected = _selectedColor == colorId;
        final useBlackIcon = colorId == 'white' ||
            colorId == 'yellow' ||
            colorId == 'gold' ||
            colorId == 'chartreuse';
        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedColor = colorId;
            });
          },
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: colorVal,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? Colors.white : Colors.transparent,
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
                    color: useBlackIcon ? Colors.black : Colors.white,
                    size: 20,
                  )
                : null,
          ),
        );
      }).toList(),
    );
  }
}
