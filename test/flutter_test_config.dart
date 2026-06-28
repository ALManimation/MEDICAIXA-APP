import 'dart:async';
import 'dart:io';
import 'package:medicaixa_app/core/localization/app_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // Load pt.json directly from filesystem for widget tests
  final file = File('assets/lang/pt.json');
  if (file.existsSync()) {
    final jsonContent = file.readAsStringSync();
    AppLocalizations.loadTestStrings(jsonContent);
  }

  // Initialize date formatting for tests
  await initializeDateFormatting('pt', null);
  await initializeDateFormatting('pt_BR', null);
  await initializeDateFormatting('en', null);
  await initializeDateFormatting('es', null);

  await testMain();
}
