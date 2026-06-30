import 'dart:async';
import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';

/// Um stepper customizado e padronizado com aceleração de toque.
/// Usado para quantidades, dias de intervalo, e durações.
class StandardStepper extends StatefulWidget {
  final double value;
  final ValueChanged<double> onChanged;
  final double min;
  final double max;
  final double step;
  final bool hasFractionButton;

  const StandardStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0.0,
    this.max = 100.0,
    this.step = 1.0,
    this.hasFractionButton = false,
  });

  @override
  State<StandardStepper> createState() => _StandardStepperState();
}

class _StandardStepperState extends State<StandardStepper> {
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

    // Executa a primeira alteração imediatamente no toque
    _step(isIncrement);

    // Timer de delay inicial de 500ms
    _delayTimer = Timer(const Duration(milliseconds: 500), () {
      // Inicia ticks periódicos lentos (200ms)
      _periodicTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) {
        final elapsed = DateTime.now().difference(startTime).inMilliseconds;
        if (elapsed > 2000) {
          // Acelera para ticks rápidos (50ms)
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
    double newValue = widget.value;
    if (isIncrement) {
      newValue += widget.step;
    } else {
      newValue -= widget.step;
    }

    if (newValue < widget.min) {
      newValue = widget.min;
    }
    if (newValue > widget.max) {
      newValue = widget.max;
    }

    if (newValue != widget.value) {
      widget.onChanged(newValue);
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayVal = widget.value.toStringAsFixed(
      widget.value.truncateToDouble() == widget.value ? 0 : 1,
    );
    final hasHalf = widget.value % 1 != 0;

    final stepperRow = Container(
      width: 170.0,
      height: 48.0,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border, width: 1.5),
        borderRadius: BorderRadius.circular(24.0),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Botão de decrementar (-)
          GestureDetector(
            onTapDown: (_) => _startTimer(false),
            onTapUp: (_) => _cancelTimers(),
            onTapCancel: () => _cancelTimers(),
            child: Container(
              width: 40.0,
              height: 40.0,
              margin: const EdgeInsets.only(left: 4.0),
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
          // Valor centralizado
          Expanded(
            child: Center(
              child: Text(
                displayVal,
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 16.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          // Botão de incrementar (+)
          GestureDetector(
            onTapDown: (_) => _startTimer(true),
            onTapUp: (_) => _cancelTimers(),
            onTapCancel: () => _cancelTimers(),
            child: Container(
              width: 40.0,
              height: 40.0,
              margin: const EdgeInsets.only(right: 4.0),
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
        ],
      ),
    );

    if (!widget.hasFractionButton) {
      return stepperRow;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        stepperRow,
        const SizedBox(height: 8.0),
        GestureDetector(
          onTap: () {
            final newQty = hasHalf
                ? widget.value.truncateToDouble()
                : widget.value.truncateToDouble() + 0.5;
            widget.onChanged(newQty);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 12.0),
            decoration: BoxDecoration(
              color: hasHalf ? AppColors.primary : AppColors.surface,
              borderRadius: BorderRadius.circular(8.0),
              border: Border.all(
                color: hasHalf ? AppColors.primary : AppColors.primary.withValues(alpha: 0.4),
                width: 1.5,
              ),
            ),
            child: Text(
              '+ ½ (Meio Comprimido)',
              style: TextStyle(
                color: hasHalf ? Colors.white : AppColors.primary,
                fontSize: 11.0,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
