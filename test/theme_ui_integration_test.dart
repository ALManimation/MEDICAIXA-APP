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

class MockDioClient implements DioClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('pt_BR', null);
  });

  testWidgets('Changing theme updates the UI colors on screen', (WidgetTester tester) async {
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

    // Verify initial theme is Dark and AppColors is dark background
    expect(AppColors.background, const Color(0xFF111827));
    
    final container = ProviderScope.containerOf(tester.element(find.byType(MediCaixaApp)));
    expect(container.read(appThemeNotifierProvider), ThemeMode.dark);

    // Now change the theme to light
    await container.read(appThemeNotifierProvider.notifier).setThemeMode(ThemeMode.light);
    await tester.pumpAndSettle();

    // Verify AppColors background is updated to Light theme background
    expect(AppColors.background, const Color(0xFFF3F4F6));
    
    // Find decorated boxes on screen and verify that the light theme colors are applied
    final decoratedBoxFinder = find.byType(DecoratedBox);
    final decoratedBoxes = tester.widgetList<DecoratedBox>(decoratedBoxFinder);
    
    bool foundUpdatedSurface = false;
    for (final box in decoratedBoxes) {
      final decoration = box.decoration;
      if (decoration is BoxDecoration && decoration.color == const Color(0xFFFFFFFF)) {
        foundUpdatedSurface = true;
      }
    }
    
    expect(foundUpdatedSurface, isTrue, reason: 'Dashboard header card should rebuild and display light surface color (0xFFFFFFFF)');
    
    await db.close();
  });
}
