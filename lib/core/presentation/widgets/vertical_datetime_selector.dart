import 'dart:async';
import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../localization/app_localizations.dart';

/// Spinner vertical individual para números com suporte a aceleração de toque.
class VerticalSpinner extends StatefulWidget {
  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;
  final int step;
  final bool wrap;
  final String Function(int)? format;

  const VerticalSpinner({
    super.key,
    required this.value,
    required this.onChanged,
    required this.min,
    required this.max,
    this.step = 1,
    this.wrap = true,
    this.format,
  });

  @override
  State<VerticalSpinner> createState() => _VerticalSpinnerState();
}

class _VerticalSpinnerState extends State<VerticalSpinner> {
  Timer? _delayTimer;
  Timer? _periodicTimer;

  @override
  void dispose() {
    _cancelTimers();
    super.dispose();
  }

  void _cancelTimers() {
    _delayTimer?.cancel();
    _delayTimer = null;
    _periodicTimer?.cancel();
    _periodicTimer = null;
  }

  void _startTimer(bool isIncrement) {
    _cancelTimers();
    final startTime = DateTime.now();

    // Primeiro tick imediato
    _step(isIncrement);

    // Initial 500ms delay
    _delayTimer = Timer(const Duration(milliseconds: 500), () {
      // Slow periodic updates (200ms)
      _periodicTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) {
        final elapsed = DateTime.now().difference(startTime).inMilliseconds;
        if (elapsed > 2000) {
          // Accelerate to 50ms rapid ticks
          timer.cancel();
          _periodicTimer = Timer.periodic(const Duration(milliseconds: 50), (fastTimer) {
            _step(isIncrement);
          });
        } else {
          _step(isIncrement);
        }
      });
    });
  }

  void _step(bool isIncrement) {
    int newValue = widget.value;
    if (isIncrement) {
      newValue += widget.step;
      if (widget.wrap && newValue > widget.max) {
        newValue = widget.min;
      }
    } else {
      newValue -= widget.step;
      if (widget.wrap && newValue < widget.min) {
        newValue = widget.max;
      }
    }

    if (!widget.wrap) {
      if (newValue < widget.min) {
        newValue = widget.min;
      }
      if (newValue > widget.max) {
        newValue = widget.max;
      }
    }

    if (newValue != widget.value) {
      widget.onChanged(newValue);
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayVal = widget.format != null ? widget.format!(widget.value) : widget.value.toString();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Botão de incrementar (+) no topo
        GestureDetector(
          onTapDown: (_) => _startTimer(true),
          onTapUp: (_) => _cancelTimers(),
          onTapCancel: () => _cancelTimers(),
          child: Container(
            width: 44.0,
            height: 44.0,
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '+',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 20.0,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8.0),
        // Valor centralizado
        Container(
          constraints: const BoxConstraints(minWidth: 44.0),
          alignment: Alignment.center,
          child: Text(
            displayVal,
            style: TextStyle(
              color: AppColors.text,
              fontSize: 22.0,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 8.0),
        // Botão de decrementar (-) embaixo
        GestureDetector(
          onTapDown: (_) => _startTimer(false),
          onTapUp: (_) => _cancelTimers(),
          onTapCancel: () => _cancelTimers(),
          child: Container(
            width: 44.0,
            height: 44.0,
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '-',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 20.0,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Seletor de Hora com dois spins verticais (Horas, Minutos).
class VerticalTimeSelector extends StatefulWidget {
  final TimeOfDay initialTime;
  final ValueChanged<TimeOfDay> onChanged;

  const VerticalTimeSelector({
    super.key,
    required this.initialTime,
    required this.onChanged,
  });

  @override
  State<VerticalTimeSelector> createState() => _VerticalTimeSelectorState();
}

class _VerticalTimeSelectorState extends State<VerticalTimeSelector> {
  late int _hour;
  late int _minute;

  @override
  void initState() {
    super.initState();
    _hour = widget.initialTime.hour;
    _minute = widget.initialTime.minute;
  }

  @override
  void didUpdateWidget(covariant VerticalTimeSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTime != widget.initialTime) {
      _hour = widget.initialTime.hour;
      _minute = widget.initialTime.minute;
    }
  }

  void _updateHour(int newHour) {
    setState(() {
      _hour = newHour;
    });
    widget.onChanged(TimeOfDay(hour: _hour, minute: _minute));
  }

  void _updateMinute(int newMinute) {
    setState(() {
      _minute = newMinute;
    });
    widget.onChanged(TimeOfDay(hour: _hour, minute: _minute));
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        VerticalSpinner(
          value: _hour,
          min: 0,
          max: 23,
          onChanged: _updateHour,
          format: (val) => val.toString().padLeft(2, '0'),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            ':',
            style: TextStyle(
              fontSize: 32.0,
              fontWeight: FontWeight.bold,
              color: AppColors.text,
            ),
          ),
        ),
        VerticalSpinner(
          value: _minute,
          min: 0,
          max: 59,
          onChanged: _updateMinute,
          format: (val) => val.toString().padLeft(2, '0'),
        ),
      ],
    );
  }
}

/// Seletor de Data com três spins verticais (Dia, Mês, Ano).
class VerticalDateSelector extends StatefulWidget {
  final DateTime initialDate;
  final ValueChanged<DateTime> onChanged;

  const VerticalDateSelector({
    super.key,
    required this.initialDate,
    required this.onChanged,
  });

  @override
  State<VerticalDateSelector> createState() => _VerticalDateSelectorState();
}

class _VerticalDateSelectorState extends State<VerticalDateSelector> {
  late int _day;
  late int _month;
  late int _year;

  @override
  void initState() {
    super.initState();
    _day = widget.initialDate.day;
    _month = widget.initialDate.month;
    _year = widget.initialDate.year;
  }

  @override
  void didUpdateWidget(covariant VerticalDateSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialDate != widget.initialDate) {
      _day = widget.initialDate.day;
      _month = widget.initialDate.month;
      _year = widget.initialDate.year;
    }
  }

  int get _maxDay => DateTime(_year, _month + 1, 0).day;

  void _updateDay(int newDay) {
    setState(() {
      _day = newDay;
    });
    _notifyChange();
  }

  void _updateMonth(int newMonth) {
    setState(() {
      _month = newMonth;
      final limit = _maxDay;
      if (_day > limit) {
        _day = limit;
      }
    });
    _notifyChange();
  }

  void _updateYear(int newYear) {
    setState(() {
      _year = newYear;
      final limit = _maxDay;
      if (_day > limit) {
        _day = limit;
      }
    });
    _notifyChange();
  }

  void _notifyChange() {
    widget.onChanged(DateTime(_year, _month, _day));
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Dia
        VerticalSpinner(
          value: _day,
          min: 1,
          max: _maxDay,
          onChanged: _updateDay,
          format: (val) => val.toString().padLeft(2, '0'),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          child: Text(
            '/',
            style: TextStyle(
              fontSize: 24.0,
              fontWeight: FontWeight.bold,
              color: AppColors.text,
            ),
          ),
        ),
        // Mês
        VerticalSpinner(
          value: _month,
          min: 1,
          max: 12,
          onChanged: _updateMonth,
          format: (val) => val.toString().padLeft(2, '0'),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          child: Text(
            '/',
            style: TextStyle(
              fontSize: 24.0,
              fontWeight: FontWeight.bold,
              color: AppColors.text,
            ),
          ),
        ),
        // Ano
        VerticalSpinner(
          value: _year,
          min: 2000,
          max: 2100,
          onChanged: _updateYear,
          format: (val) => val.toString(),
          wrap: false,
        ),
      ],
    );
  }
}

/// Abre um Dialog modal com o VerticalTimeSelector.
Future<TimeOfDay?> showVerticalTimePicker(
  BuildContext context, {
  required TimeOfDay initialTime,
}) {
  TimeOfDay selectedTime = initialTime;
  return showDialog<TimeOfDay>(
    context: context,
    builder: (context) {

      final confirmText = t('confirm_btn') == 'confirm_btn' ? 'Confirmar' : t('confirm_btn');
      final cancelText = t('cancel_btn') == 'cancel_btn' ? 'Cancelar' : t('cancel_btn');

      return AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
        title: Text(
          t('alarm_time_label') == 'alarm_time_label' ? 'Selecionar Horário' : t('alarm_time_label'),
          style: TextStyle(
            color: AppColors.text,
            fontWeight: FontWeight.bold,
            fontSize: 18.0,
          ),
        ),
        content: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: VerticalTimeSelector(
            initialTime: initialTime,
            onChanged: (time) {
              selectedTime = time;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: Text(
              cancelText,
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(selectedTime),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
            ),
            child: Text(confirmText),
          ),
        ],
      );
    },
  );
}

/// Abre um Dialog modal com o VerticalDateSelector.
Future<DateTime?> showVerticalDatePicker(
  BuildContext context, {
  required DateTime initialDate,
}) {
  DateTime selectedDate = initialDate;
  return showDialog<DateTime>(
    context: context,
    builder: (context) {

      final confirmText = t('confirm_btn') == 'confirm_btn' ? 'Confirmar' : t('confirm_btn');
      final cancelText = t('cancel_btn') == 'cancel_btn' ? 'Cancelar' : t('cancel_btn');

      return AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
        title: Text(
          t('alarm_start_date') == 'alarm_start_date' ? 'Selecionar Data' : t('alarm_start_date'),
          style: TextStyle(
            color: AppColors.text,
            fontWeight: FontWeight.bold,
            fontSize: 18.0,
          ),
        ),
        content: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: VerticalDateSelector(
            initialDate: initialDate,
            onChanged: (date) {
              selectedDate = date;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: Text(
              cancelText,
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(selectedDate),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
            ),
            child: Text(confirmText),
          ),
        ],
      );
    },
  );
}
