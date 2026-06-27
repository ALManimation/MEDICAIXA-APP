import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/localization/app_localizations.dart';

import 'package:intl/date_symbol_data_local.dart';
import 'package:mcp_toolkit/mcp_toolkit.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load default portuguese translations on startup
  await AppLocalizations.load('pt');
  
  // Initialize date formatting for intl package
  await initializeDateFormatting('pt_BR', null);

  await MCPToolkitBinding.instance.bootstrapFlutter(
    runApp: () => runApp(
      const ProviderScope(
        child: MediCaixaApp(),
      ),
    ),
  );
}
