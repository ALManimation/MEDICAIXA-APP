import 'dart:ui';
import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';

class MultiActionFab extends StatefulWidget {
  final VoidCallback onAddAlarm;
  final VoidCallback onAddReminder;
  final VoidCallback onAddMedication;
  final VoidCallback onScanQr;

  const MultiActionFab({
    super.key,
    required this.onAddAlarm,
    required this.onAddReminder,
    required this.onAddMedication,
    required this.onScanQr,
  });

  @override
  State<MultiActionFab> createState() => _MultiActionFabState();
}

class _MultiActionFabState extends State<MultiActionFab> with SingleTickerProviderStateMixin {
  bool _isOpen = false;
  late AnimationController _animationController;
  late Animation<double> _animateIcon;
  late Animation<double> _translateButton;

  double _x = 16.0;
  double _y = 16.0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _animateIcon = Tween<double>(begin: 0.0, end: 0.125).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOut,
      ),
    );
    _translateButton = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOut,
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _isOpen = !_isOpen;
      if (_isOpen) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.bottomRight,
      children: [
        // Backdrop Blur & Tint when menu is open
        if (_isOpen) ...[
          Positioned.fill(
            child: GestureDetector(
              onTap: _toggle,
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 4.0, sigmaY: 4.0),
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.4),
                  ),
                ),
              ),
            ),
          ),
        ],

        // Menu Options (Vertical layout above the main FAB)
        Positioned(
          right: _x,
          bottom: _y,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (_isOpen) ...[
                // 1. Scan QR Option (Disabled/Soon)
                _buildFabOption(
                  label: 'Escanear QR',
                  icon: Icons.qr_code_scanner_rounded,
                  color: AppColors.secondary,
                  onPressed: () {
                    _toggle();
                    widget.onScanQr();
                  },
                ),
                const SizedBox(height: 12),

                // 2. Add Medication Option
                _buildFabOption(
                  label: 'Cadastrar Remédio',
                  icon: Icons.medication_rounded,
                  color: AppColors.primary,
                  onPressed: () {
                    _toggle();
                    widget.onAddMedication();
                  },
                ),
                const SizedBox(height: 12),

                // 3. Add Reminder Option
                _buildFabOption(
                  label: 'Novo Lembrete',
                  icon: Icons.push_pin_rounded,
                  color: AppColors.secondary,
                  onPressed: () {
                    _toggle();
                    widget.onAddReminder();
                  },
                ),
                const SizedBox(height: 12),

                // 4. Add Alarm Option
                _buildFabOption(
                  label: 'Novo Alarme',
                  icon: Icons.alarm_rounded,
                  color: AppColors.primary,
                  onPressed: () {
                    _toggle();
                    widget.onAddAlarm();
                  },
                ),
                const SizedBox(height: 16),
              ],

              // Main FAB Button
              GestureDetector(
                onTap: _toggle,
                onPanUpdate: (details) {
                  final screenSize = MediaQuery.of(context).size;
                  setState(() {
                    _x = (_x - details.delta.dx).clamp(16.0, screenSize.width - 72.0);
                    _y = (_y - details.delta.dy).clamp(16.0, screenSize.height - 120.0);
                  });
                },
                child: RotationTransition(
                  turns: _animateIcon,
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        _isOpen ? Icons.close_rounded : Icons.add_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFabOption({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ScaleTransition(
      scale: _translateButton,
      child: FadeTransition(
        opacity: _translateButton,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Label
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Button
            GestureDetector(
              onTap: onPressed,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
