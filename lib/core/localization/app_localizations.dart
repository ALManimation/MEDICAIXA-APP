import 'dart:convert';
import 'package:flutter/services.dart';

class AppLocalizations {
  static String _locale = 'pt';
  static Map<String, dynamic> _localizedStrings = {};

  static String get locale => _locale;

  static Future<void> load(String languageCode) async {
    _locale = languageCode;
    try {
      final jsonString = await rootBundle.loadString('assets/lang/$languageCode.json');
      _localizedStrings = json.decode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      // Fallback to pt if failed to load
      if (languageCode != 'pt') {
        await load('pt');
      }
    }
  }

  static String translate(String key, {List<dynamic>? args}) {
    // Try to find the key in "web" section first
    final webMap = _localizedStrings['web'] as Map<String, dynamic>?;
    dynamic value = webMap?[key];

    // If not found in "web", try in "lcd" section
    if (value == null) {
      final lcdMap = _localizedStrings['lcd'] as Map<String, dynamic>?;
      value = lcdMap?[key];
    }

    // If still not found, return the key itself
    if (value == null) {
      return key;
    }

    String result = value.toString();
    if (args != null && args.isNotEmpty) {
      for (final arg in args) {
        result = result.replaceFirst('%d', arg.toString()).replaceFirst('%s', arg.toString());
      }
    }
    return result;
  }
}

// Global translation helper function
String t(String key, [List<dynamic>? args]) {
  return AppLocalizations.translate(key, args: args);
}
