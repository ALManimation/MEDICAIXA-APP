// ignore_for_file: prefer_const_declarations
import 'package:flutter/material.dart';

/// Paleta de cores do app MediCaixa.
/// Replica exatamente o colorMap da Web UI (index.html).
/// ATENÇÃO: Não usar referências a AppColors dentro de widgets `const`.
class AppColors {
  AppColors._();

  // Core Theme Colors
  static Color background = const Color(0xFF111827);     // --bg-color dark
  static Color surface = const Color(0xFF1F2937);         // --surface-color dark
  static Color surfaceVariant = const Color(0xFF374151);  // --border-color dark
  static Color primary = const Color(0xFF34D399);         // --primary-color dark
  static Color primaryDark = const Color(0xFF10B981);     // --primary-dark dark
  static Color onPrimary = Colors.white;
  static Color secondary = const Color(0xFF00ACC1);
  static Color onSecondary = Colors.black;
  static Color text = const Color(0xFFF9FAFB);           // --text-main dark
  static Color textMuted = const Color(0xFF9CA3AF);       // --text-muted dark
  static Color border = const Color(0xFF374151);          // --border-color dark

  // Status Colors
  static Color success = const Color(0xFF10B981);
  static Color pending = const Color(0xFFFB8C00);
  static Color missed = const Color(0xFFEF4444);

  // Health Banner Colors
  static Color healthOk = const Color(0xFF34D399);
  static Color healthOkBg = const Color(0xFF064E3B);
  static Color healthOkBorder = const Color(0xFF065F46);
  static Color healthWarn = const Color(0xFFFBBF24);
  static Color healthWarnBg = const Color(0xFF422006);
  static Color healthWarnBorder = const Color(0xFF78350F);
  static Color healthRisk = const Color(0xFFFB923C);
  static Color healthRiskBg = const Color(0xFF431407);
  static Color healthRiskBorder = const Color(0xFF7C2D12);
  static Color healthDanger = const Color(0xFFF87171);
  static Color healthDangerBg = const Color(0xFF450A0A);
  static Color healthDangerBorder = const Color(0xFF7F1D1D);

  static void setTheme(bool isDark) {
    if (isDark) {
      background = const Color(0xFF111827);
      surface = const Color(0xFF1F2937);
      surfaceVariant = const Color(0xFF374151);
      primary = const Color(0xFF34D399);
      primaryDark = const Color(0xFF10B981);
      onPrimary = Colors.white;
      secondary = const Color(0xFF00ACC1);
      onSecondary = Colors.black;
      text = const Color(0xFFF9FAFB);
      textMuted = const Color(0xFF9CA3AF);
      border = const Color(0xFF374151);
      success = const Color(0xFF10B981);
      pending = const Color(0xFFFB8C00);
      missed = const Color(0xFFEF4444);
      healthOk = const Color(0xFF34D399);
      healthOkBg = const Color(0xFF064E3B);
      healthOkBorder = const Color(0xFF065F46);
      healthWarn = const Color(0xFFFBBF24);
      healthWarnBg = const Color(0xFF422006);
      healthWarnBorder = const Color(0xFF78350F);
      healthRisk = const Color(0xFFFB923C);
      healthRiskBg = const Color(0xFF431407);
      healthRiskBorder = const Color(0xFF7C2D12);
      healthDanger = const Color(0xFFF87171);
      healthDangerBg = const Color(0xFF450A0A);
      healthDangerBorder = const Color(0xFF7F1D1D);
    } else {
      background = const Color(0xFFF3F4F6);
      surface = const Color(0xFFFFFFFF);
      surfaceVariant = const Color(0xFFE5E7EB);
      primary = const Color(0xFF10B981);
      primaryDark = const Color(0xFF059669);
      onPrimary = Colors.white;
      secondary = const Color(0xFF00ACC1);
      onSecondary = Colors.white;
      text = const Color(0xFF1F2937);
      textMuted = const Color(0xFF6B7280);
      border = const Color(0xFFE5E7EB);
      success = const Color(0xFF10B981);
      pending = const Color(0xFFFB8C00);
      missed = const Color(0xFFEF4444);
      healthOk = const Color(0xFF059669);
      healthOkBg = const Color(0xFFECFDF5);
      healthOkBorder = const Color(0xFF6EE7B7);
      healthWarn = const Color(0xFFB45309);
      healthWarnBg = const Color(0xFFFEFCE8);
      healthWarnBorder = const Color(0xFFFDE047);
      healthRisk = const Color(0xFFC2410C);
      healthRiskBg = const Color(0xFFFFF7ED);
      healthRiskBorder = const Color(0xFFFDBA74);
      healthDanger = const Color(0xFFB91C1C);
      healthDangerBg = const Color(0xFFFEF2F2);
      healthDangerBorder = const Color(0xFFFCA5A5);
    }
  }

  // Period Colors (from Web UI)
  static final Color morningColor = const Color(0xFFD97706);    // amber/sun
  static final Color afternoonColor = const Color(0xFF2563EB);  // blue/cloud
  static final Color nightColor = const Color(0xFF4B5563);      // gray/moon

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
