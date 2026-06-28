import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/constants/app_colors.dart';
import '../alarm_wizard_notifier.dart';

class WizardStepOptions extends ConsumerStatefulWidget {
  final VoidCallback onSave;

  const WizardStepOptions({
    super.key,
    required this.onSave,
  });

  @override
  ConsumerState<WizardStepOptions> createState() => _WizardStepOptionsState();
}

class _WizardStepOptionsState extends ConsumerState<WizardStepOptions> {
  String _selectedColor = 'blue';
  String? _specialInstruction;
  int _snoozeMin = 0;
  int _durationDays = 0;

  // PRN fields
  bool _isPrn = false;
  int _prnIntervalHours = 4;
  int _prnMaxDoses = 4;

  // Cycle fields
  bool _useCycle = false;
  int _cycleOn = 21;
  final int _cycleOff = 7;

  final List<String> _colors = [
    'blue',
    'red',
    'green',
    'yellow',
    'orange',
    'purple',
    'pink',
    'magenta',
    'cyan',
    'brown'
  ];

  final List<Map<String, String?>> _instructions = [
    {'value': null, 'label': 'Nenhuma instrução especial'},
    {'value': 'empty_stomach', 'label': 'Em jejum'},
    {'value': 'with_food', 'label': 'Com comida'},
    {'value': 'sublingual', 'label': 'Sublingual'},
    {'value': 'before_sleep', 'label': 'Antes de dormir'},
  ];

  @override
  void initState() {
    super.initState();
    final wizard = ref.read(alarmWizardNotifierProvider);
    _selectedColor = wizard.alarm.color;
    _specialInstruction = wizard.alarm.specialInstruction;
    _snoozeMin = wizard.alarm.snoozeMin;
    _durationDays = wizard.alarm.durationDays;
    _isPrn = wizard.alarm.isPrn ?? false;
    _prnIntervalHours = wizard.alarm.prnMinIntervalHours ?? 4;
    _prnMaxDoses = wizard.alarm.prnMaxDailyDoses ?? 4;
    _useCycle = (wizard.alarm.cycleOnDays ?? 0) > 0;
    _cycleOn = wizard.alarm.cycleOnDays ?? 21;
  }

  void _updateNotifier() {
    ref.read(alarmWizardNotifierProvider.notifier).updateOptions(
          color: _selectedColor,
          specialInstruction: _specialInstruction,
          snoozeMin: _snoozeMin,
          startDate: _durationDays > 0 ? DateTime.now().toIso8601String().substring(0, 10) : null,
          durationDays: _durationDays,
          cycleOnDays: _useCycle ? _cycleOn : null,
          cycleOffDays: _useCycle ? _cycleOff : null,
          isPrn: _isPrn,
          prnMinIntervalHours: _isPrn ? _prnIntervalHours : null,
          prnMaxDailyDoses: _isPrn ? _prnMaxDoses : null,
        );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Personalização e Avançado',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 24),

        // Scrollable Options Content
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              // Colors Grid Selection
              const Text(
                'Cor do alarme',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _colors.map((c) {
                  final isSelected = c == _selectedColor;
                  final colorVal = AppColors.getAlarmColor(c);
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedColor = c;
                      });
                      _updateNotifier();
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
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: colorVal.withValues(alpha: 0.6),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                )
                              ]
                            : [],
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 24),

              // Special Instruction Dropdown
              const Text(
                'Instruções de uso',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                initialValue: _specialInstruction,
                dropdownColor: AppColors.surface,
                decoration: InputDecoration(
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
                ),
                items: _instructions.map((inst) {
                  return DropdownMenuItem<String?>(
                    value: inst['value'],
                    child: Text(inst['label'] ?? ''),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() {
                    _specialInstruction = val;
                  });
                  _updateNotifier();
                },
              ),

              const SizedBox(height: 24),

              // Duration settings
              const Text(
                'Duração do tratamento',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<int>(
                      title: const Text('Contínuo', style: TextStyle(fontSize: 14)),
                      value: 0,
                      // ignore: deprecated_member_use
                      groupValue: _durationDays == 0 ? 0 : 1,
                      // ignore: deprecated_member_use
                      onChanged: (_) {
                        setState(() {
                          _durationDays = 0;
                        });
                        _updateNotifier();
                      },
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<int>(
                      title: const Text('Temporário', style: TextStyle(fontSize: 14)),
                      value: 1,
                      // ignore: deprecated_member_use
                      groupValue: _durationDays == 0 ? 0 : 1,
                      // ignore: deprecated_member_use
                      onChanged: (_) {
                        setState(() {
                          _durationDays = 7; // Default 7 days
                        });
                        _updateNotifier();
                      },
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
              if (_durationDays > 0) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text('Duração em dias: ', style: TextStyle(color: AppColors.textMuted)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Slider(
                        value: _durationDays.toDouble(),
                        min: 1,
                        max: 90,
                        divisions: 90,
                        label: '$_durationDays dias',
                        onChanged: (val) {
                          setState(() {
                            _durationDays = val.toInt();
                          });
                          _updateNotifier();
                        },
                      ),
                    ),
                    Text('$_durationDays dias', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ],

              const SizedBox(height: 24),

              // SOS / PRN Toggle
              SwitchListTile(
                title: const Text('Medicamento SOS (Sob Demanda / PRN)', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Habilita doses manuais sem horário fixo obrigatório'),
                value: _isPrn,
                onChanged: (val) {
                  setState(() {
                    _isPrn = val;
                  });
                  _updateNotifier();
                },
                contentPadding: EdgeInsets.zero,
              ),
              if (_isPrn) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Intervalo mín. (horas)', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<int>(
                            initialValue: _prnIntervalHours,
                            dropdownColor: AppColors.surface,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: AppColors.surfaceVariant,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            ),
                            items: [1, 2, 4, 6, 8, 12].map((h) => DropdownMenuItem(value: h, child: Text('$h h'))).toList(),
                            onChanged: (val) {
                              setState(() {
                                _prnIntervalHours = val ?? 4;
                              });
                              _updateNotifier();
                            },
                          )
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Máx. doses diárias', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<int>(
                            initialValue: _prnMaxDoses,
                            dropdownColor: AppColors.surface,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: AppColors.surfaceVariant,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            ),
                            items: [1, 2, 3, 4, 6, 8].map((d) => DropdownMenuItem(value: d, child: Text('$d doses'))).toList(),
                            onChanged: (val) {
                              setState(() {
                                _prnMaxDoses = val ?? 4;
                              });
                              _updateNotifier();
                            },
                          )
                        ],
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 24),

              // Cycle Toggle
              SwitchListTile(
                title: const Text('Uso cíclico (ex: anticoncepcional)', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Programa dias de pausa automáticos'),
                value: _useCycle,
                onChanged: (val) {
                  setState(() {
                    _useCycle = val;
                  });
                  _updateNotifier();
                },
                contentPadding: EdgeInsets.zero,
              ),
              if (_useCycle) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Dias ativos: $_cycleOn dias', style: const TextStyle(color: Colors.white)),
                    Expanded(
                      child: Slider(
                        value: _cycleOn.toDouble(),
                        min: 7,
                        max: 84,
                        divisions: 11,
                        label: '$_cycleOn dias',
                        onChanged: (val) {
                          setState(() {
                            _cycleOn = val.toInt();
                          });
                          _updateNotifier();
                        },
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    'Esquema: $_cycleOn dias tomando + 7 dias de pausa.',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                ),
              ]
            ],
          ),
        ),

        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () {
            _updateNotifier();
            widget.onSave();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.success,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 56),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: const Text(
            'Salvar e Programar',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
