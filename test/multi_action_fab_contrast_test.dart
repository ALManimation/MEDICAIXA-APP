import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/native.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:medicaixa_app/app.dart';
import 'package:medicaixa_app/core/database/database.dart';
import 'package:medicaixa_app/core/providers/core_providers.dart';
import 'package:medicaixa_app/core/providers/theme_provider.dart';
import 'package:medicaixa_app/core/constants/app_colors.dart';
import 'package:medicaixa_app/core/network/dio_client.dart';
import 'package:medicaixa_app/core/presentation/widgets/multi_action_fab.dart';

class MockDioClient implements DioClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('pt_BR', null);
  });

  testWidgets('MultiActionFab option labels must not have hardcoded white text on white surfaces in Light Theme', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final db = AppDatabase.connect(NativeDatabase.memory());
    
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          dioClientProvider.overrideWithValue(MockDioClient()),
        ],
        child: const MediCaixaApp(),
      ),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(tester.element(find.byType(MediCaixaApp)));

    // Switch to light theme
    await container.read(appThemeNotifierProvider.notifier).setThemeMode(ThemeMode.light);
    await tester.pumpAndSettle();

    // Verify AppColors surface is white
    expect(AppColors.surface, const Color(0xFFFFFFFF));

    // Tap main FAB button to open the menu options
    final fabButtonFinder = find.descendant(
      of: find.byType(MultiActionFab),
      matching: find.byIcon(Icons.add_rounded),
    );
    expect(fabButtonFinder, findsOneWidget);
    await tester.tap(fabButtonFinder);
    await tester.pumpAndSettle();

    // Find the text label widgets in the MultiActionFab
    // In portuguese, one of the labels is "Novo Alarme" or similar. Let's find any Text widget that is part of the fab options.
    // The option labels are: "Novo Alarme", "Novo Lembrete", "Novo Remédio" or similar.
    final alarmLabelFinder = find.text('Novo Alarme');
    expect(alarmLabelFinder, findsOneWidget);

    final Text alarmLabelText = tester.widget<Text>(alarmLabelFinder);
    final TextStyle? style = alarmLabelText.style;
    
    expect(style, isNotNull);
    
    // Check contrast: style.color should not be Colors.white when the surface is white.
    // We expect this assertion to FAIL because in multi_action_fab.dart:215, the text color is hardcoded to Colors.white.
    expect(style!.color, isNot(Colors.white), reason: 'Text color must not be white on a white AppColors.surface container in Light Theme');

    await db.close();
  });
}
