import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/localization/app_localizations.dart';
import 'core/services/notification_service.dart';

import 'package:intl/date_symbol_data_local.dart';
import 'package:mcp_toolkit/mcp_toolkit.dart';

void main() async {
  await MCPToolkitBinding.instance.bootstrapFlutter(
    runApp: () async {
      WidgetsFlutterBinding.ensureInitialized();

      // Initialize NotificationService & Timezones
      await NotificationService.instance.init();

      // Load default portuguese translations on startup
      await AppLocalizations.load('pt');
      
      // Initialize date formatting for intl package
      await initializeDateFormatting('pt_BR', null);
      await initializeDateFormatting('en', null);
      await initializeDateFormatting('es', null);
      await initializeDateFormatting('pt', null);

      runApp(
        const ProviderScope(
          child: MediCaixaApp(),
        ),
      );
    },
  );
}
