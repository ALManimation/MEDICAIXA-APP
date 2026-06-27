import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/providers/locale_provider.dart';
import 'core/theme/app_theme.dart';
import 'features/pairing/presentation/pairing_screen.dart';

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

    return MaterialApp(
      title: 'MediCaixa',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme, // Material 3 Dark theme by default
      themeMode: ThemeMode.dark,
      locale: Locale(locale),
      scrollBehavior: AppScrollBehavior(),
      home: const PairingScreen(),
    );
  }
}
