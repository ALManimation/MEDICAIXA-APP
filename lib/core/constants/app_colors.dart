import 'package:flutter/material.dart';

/// Paleta de cores do app MediCaixa.
/// Replica exatamente o colorMap da Web UI (index.html).
/// ATENÇÃO: Não usar referências a AppColors dentro de widgets `const`.
class AppColors {
  AppColors._();

  // Core Theme Colors (Dark Mode — from Web UI CSS variables)
  static const Color background = Color(0xFF111827);     // --bg-color dark
  static const Color surface = Color(0xFF1F2937);         // --surface-color dark
  static const Color surfaceVariant = Color(0xFF374151);  // --border-color dark
  static const Color primary = Color(0xFF34D399);         // --primary-color dark
  static const Color primaryDark = Color(0xFF10B981);     // --primary-dark dark
  static const Color onPrimary = Colors.white;
  static const Color secondary = Color(0xFF00ACC1);
  static const Color onSecondary = Colors.black;
  static const Color text = Color(0xFFF9FAFB);           // --text-main dark
  static const Color textMuted = Color(0xFF9CA3AF);       // --text-muted dark
  static const Color border = Color(0xFF374151);          // --border-color dark

  // Status Colors
  static const Color success = Color(0xFF10B981);
  static const Color pending = Color(0xFFFB8C00);
  static const Color missed = Color(0xFFEF4444);

  // Health Banner Colors (dark mode — from Web UI CSS)
  static const Color healthOk = Color(0xFF34D399);
  static const Color healthOkBg = Color(0xFF064E3B);
  static const Color healthOkBorder = Color(0xFF065F46);
  static const Color healthWarn = Color(0xFFFBBF24);
  static const Color healthWarnBg = Color(0xFF422006);
  static const Color healthWarnBorder = Color(0xFF78350F);
  static const Color healthRisk = Color(0xFFFB923C);
  static const Color healthRiskBg = Color(0xFF431407);
  static const Color healthRiskBorder = Color(0xFF7C2D12);
  static const Color healthDanger = Color(0xFFF87171);
  static const Color healthDangerBg = Color(0xFF450A0A);
  static const Color healthDangerBorder = Color(0xFF7F1D1D);

  // Period Colors (from Web UI)
  static const Color morningColor = Color(0xFFD97706);    // amber/sun
  static const Color afternoonColor = Color(0xFF2563EB);  // blue/cloud
  static const Color nightColor = Color(0xFF4B5563);      // gray/moon

  // MediCaixa Firmware Color Map — 15 colors matching the Web UI COLOR_HEX map
  static const Map<String, Color> alarmColors = {
    'white': Color(0xFFFFFFFF),
    'red': Color(0xFFFF0000),
    'green': Color(0xFF00FF00),
    'blue': Color(0xFF0000FF),
    'yellow': Color(0xFFFFFF00),
    'magenta': Color(0xFFFF00FF),
    'cyan': Color(0xFF00FFFF),
    'orange': Color(0xFFFFA500),
    'purple': Color(0xFF800080),
    'pink': Color(0xFFFFC0CB),
    'brown': Color(0xFFA52A2A),
    'chartreuse': Color(0xFF7FFF00),
    'teal': Color(0xFF008080),
    'coral': Color(0xFFFF7F50),
    'gold': Color(0xFFFFD700),
  };

  /// Returns the alarm color for a given name, falling back to primary green.
  static Color getAlarmColor(String? colorName) {
    if (colorName == null || colorName.isEmpty) return primary;
    return alarmColors[colorName.toLowerCase()] ?? primary;
  }
}
