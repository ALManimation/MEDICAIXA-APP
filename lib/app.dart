import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/providers/locale_provider.dart';
import 'core/providers/theme_provider.dart';
import 'core/theme/app_theme.dart';
import 'core/presentation/app_shell.dart';
import 'core/services/alarm_engine.dart';
import 'features/alarms/presentation/alarm_active_screen.dart';

class AppScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
      };
}

class MediCaixaApp extends ConsumerWidget {
  const MediCaixaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch current locale
    final locale = ref.watch(appLocaleProvider);
    // Watch current theme mode
    final themeMode = ref.watch(appThemeNotifierProvider);

    // Initialize AlarmEngine at startup (Riverpod build)
    ref.read(alarmEngineProvider);

    return MaterialApp(
      title: 'MediCaixa',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      locale: Locale(locale),
      scrollBehavior: AppScrollBehavior(),
      home: const AppShell(),
      builder: (context, child) {
        return Stack(
          children: [
            if (child != null) child,
            Consumer(
              builder: (context, ref, _) {
                final activeAlarmsAsync = ref.watch(activeAlarmsProvider);
                return activeAlarmsAsync.when(
                  data: (activeAlarms) {
                    if (activeAlarms.isNotEmpty) {
                      return AlarmActiveScreen(activeAlarms: activeAlarms);
                    }
                    return const SizedBox.shrink();
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (e, s) {
                    debugPrint('Error loading active alarms: $e');
                    return const SizedBox.shrink();
                  },
                );
              },
            ),
          ],
        );
      },
    );
  }
}
