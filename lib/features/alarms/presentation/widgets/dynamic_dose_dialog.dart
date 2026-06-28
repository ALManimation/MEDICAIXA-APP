import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/alarm_model.dart';
import '../../../../core/localization/app_localizations.dart';

class DynamicDoseDialog extends StatefulWidget {
  final AlarmModel alarm;

  const DynamicDoseDialog({super.key, required this.alarm});

  static Future<double?> show(BuildContext context, AlarmModel alarm) {
    return showDialog<double>(
      context: context,
      barrierDismissible: false,
      builder: (_) => DynamicDoseDialog(alarm: alarm),
    );
  }

  @override
  State<DynamicDoseDialog> createState() => _DynamicDoseDialogState();
}

class _DynamicDoseDialogState extends State<DynamicDoseDialog> {
  final _measuredValController = TextEditingController();
  final _qtyController = TextEditingController();
  String _parameterName = 'Valor';
  List<_Rule> _rules = [];
  int? _matchedRuleIndex;

  @override
  void initState() {
    super.initState();
    _parseInstruction(widget.alarm.dynamicInstruction);
    
    // Default qty: current weekday quantity or default quantity
    final now = DateTime.now();
    final wday = now.weekday % 7;
    final hasAsymmetric = widget.alarm.daysQuantity.any((q) => q > 0);
    final double defaultQty = (hasAsymmetric && wday < widget.alarm.daysQuantity.length && widget.alarm.daysQuantity[wday] > 0)
        ? widget.alarm.daysQuantity[wday]
        : widget.alarm.quantity;
        
    _qtyController.text = defaultQty == defaultQty.toInt() ? defaultQty.toInt().toString() : defaultQty.toStringAsFixed(1);
    _measuredValController.addListener(_onMeasuredValChanged);
  }

  @override
  void dispose() {
    _measuredValController.dispose();
    _qtyController.dispose();
    super.dispose();
  }

  void _parseInstruction(String? instruction) {
    if (instruction == null || instruction.trim().isEmpty) return;
    
    final match = RegExp(r'^([^<>0-9-]+)\s*(.*)$').firstMatch(instruction.trim());
    if (match == null) return;
    
    _parameterName = match.group(1)!.trim();
    final rulesStr = match.group(2)!.trim();
    final parts = rulesStr.split(';').map((p) => p.trim()).where((p) => p.isNotEmpty);
    
    final parsedRules = <_Rule>[];
    for (final part in parts) {
      final idxColon = part.indexOf(':');
      if (idxColon == -1) continue;
      final condPart = part.substring(0, idxColon).trim();
      final dosePart = part.substring(idxColon + 1).trim();
      
      String condition = '';
      double val1 = 0;
      double val2 = 0;
      
      if (condPart.startsWith('<')) {
        condition = '<';
        val1 = double.tryParse(condPart.substring(1).trim()) ?? 0;
      } else if (condPart.startsWith('>')) {
        condition = '>';
        val1 = double.tryParse(condPart.substring(1).trim()) ?? 0;
      } else if (condPart.contains('-')) {
        condition = '-';
        final vals = condPart.split('-').map((v) => v.trim()).toList();
        if (vals.length == 2) {
          val1 = double.tryParse(vals[0]) ?? 0;
          val2 = double.tryParse(vals[1]) ?? 0;
        }
      }
      
      final matchDose = RegExp(r'^([0-9.]+)\s*(.*)$').firstMatch(dosePart);
      if (matchDose == null) continue;
      final qty = double.tryParse(matchDose.group(1)!) ?? 0.0;
      final unit = matchDose.group(2)!.trim();
      
      parsedRules.add(_Rule(
        condition: condition,
        val1: val1,
        val2: val2,
        qty: qty,
        unit: unit,
        rawText: part,
      ));
    }
    setState(() {
      _rules = parsedRules;
    });
  }

  void _onMeasuredValChanged() {
    final valText = _measuredValController.text.trim().replaceAll(',', '.');
    if (valText.isEmpty) {
      setState(() {
        _matchedRuleIndex = null;
      });
      return;
    }
    final double? val = double.tryParse(valText);
    if (val == null) {
      setState(() {
        _matchedRuleIndex = null;
      });
      return;
    }

    int? matchedIdx;
    for (int i = 0; i < _rules.length; i++) {
      final r = _rules[i];
      bool matches = false;
      if (r.condition == '<' && val < r.val1) {
        matches = true;
      } else if (r.condition == '>' && val > r.val1) {
        matches = true;
      } else if (r.condition == '-' && val >= r.val1 && val <= r.val2) {
        matches = true;
      }
      if (matches) {
        matchedIdx = i;
        break; // Match first rule that satisfies (same logic as C++ / JS)
      }
    }

    setState(() {
      _matchedRuleIndex = matchedIdx;
      if (matchedIdx != null) {
        final suggested = _rules[matchedIdx].qty;
        _qtyController.text = suggested == suggested.toInt() ? suggested.toInt().toString() : suggested.toStringAsFixed(1);
      }
    });
  }

  String _getFriendlyRuleText(_Rule r, String medType) {
    String uText = r.unit;
    if (r.unit == 'comp') {
      uText = medType == 'capsula' ? t('med_type_capsule_short') :
              medType == 'adesivo' ? t('med_type_patch_short') :
              medType == 'injetavel' ? t('med_type_injection_short') : t('med_type_tablet_short');
    } else if (r.unit == 'gotas') {
      uText = t('med_type_drops_short');
    }

    final val1Str = r.val1 == r.val1.toInt() ? r.val1.toInt().toString() : r.val1.toString();
    final val2Str = r.val2 == r.val2.toInt() ? r.val2.toInt().toString() : r.val2.toString();
    final qtyStr = r.qty == r.qty.toInt() ? r.qty.toInt().toString() : r.qty.toString();

    if (r.condition == '<') {
      return t('dynamic_rule_less', [_parameterName, val1Str, qtyStr, uText]);
    } else if (r.condition == '>') {
      return t('dynamic_rule_greater', [_parameterName, val1Str, qtyStr, uText]);
    } else if (r.condition == '-') {
      return t('dynamic_rule_between', [_parameterName, val1Str, val2Str, qtyStr, uText]);
    }
    return r.rawText;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        t('dynamic_dose_title'),
        style: TextStyle(color: AppColors.text, fontWeight: FontWeight.bold, fontSize: 18),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t('medication_label_fmt', [widget.alarm.name]),
              style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w600, fontSize: 15),
            ),
            const SizedBox(height: 12),
            
            // Rules box
            if (_rules.isNotEmpty) ...[
              Text(
                t('dosage_table_label'),
                style: TextStyle(color: AppColors.textMuted, fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: List.generate(_rules.length, (idx) {
                    final isMatched = idx == _matchedRuleIndex;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        _getFriendlyRuleText(_rules[idx], widget.alarm.type),
                        style: TextStyle(
                          color: isMatched ? AppColors.success : AppColors.textMuted,
                          fontWeight: isMatched ? FontWeight.bold : FontWeight.normal,
                          fontSize: 13,
                        ),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Input: Measured Value
            Text(
              t('measured_value_label', [_parameterName]),
              style: TextStyle(color: AppColors.text, fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _measuredValController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(color: AppColors.text),
              decoration: InputDecoration(
                hintText: t('enter_measured_value_hint'),
                hintStyle: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.5)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: AppColors.primary),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Input: Actual Dose
            Text(
              t('dose_to_register_label'),
              style: TextStyle(color: AppColors.text, fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _qtyController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: TextStyle(color: AppColors.text),
                    decoration: InputDecoration(
                      hintText: t('final_dose_hint'),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: AppColors.primary),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  _formatType(widget.alarm.type),
                  style: TextStyle(color: AppColors.text, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: Text(t('cancel_btn'), style: TextStyle(color: AppColors.textMuted)),
        ),
        ElevatedButton(
          onPressed: () {
            final qty = double.tryParse(_qtyController.text.trim().replaceAll(',', '.'));
            if (qty == null || qty <= 0) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(t('invalid_dose_msg'))),
              );
              return;
            }
            Navigator.pop(context, qty);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.success,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: Text(t('confirm_dose_btn')),
        ),
      ],
    );
  }

  String _formatType(String type) {
    switch (type.toLowerCase()) {
      case 'comprimido':
        return t('med_type_tablet_short');
      case 'capsula':
        return t('med_type_capsule_short');
      case 'gota':
        return t('med_type_drops_short');
      case 'xarope':
        return 'ml';
      case 'adesivo':
        return t('med_type_patch_short');
      case 'injetavel':
        return t('med_type_injection_short');
      default:
        return t('med_type_dose_short');
    }
  }
}

class _Rule {
  final String condition;
  final double val1;
  final double val2;
  final double qty;
  final String unit;
  final String rawText;

  const _Rule({
    required this.condition,
    required this.val1,
    required this.val2,
    required this.qty,
    required this.unit,
    required this.rawText,
  });
}
