import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/native.dart';
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
  group('AppThemeNotifier Tests', () {
    late AppDatabase db;
    late ProviderContainer container;

    setUp(() {
      db = AppDatabase.connect(NativeDatabase.memory());
      container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          dioClientProvider.overrideWithValue(MockDioClient()),
        ],
      );
    });

    tearDown(() async {
      await db.close();
      container.dispose();
    });

    test('Initial theme state defaults to dark', () {
      final state = container.read(appThemeNotifierProvider);
      
      expect(state, ThemeMode.dark);
      expect(AppColors.background, const Color(0xFF111827)); // Dark mode color
    });

    test('setThemeMode updates state, AppColors, and database', () async {
      final notifier = container.read(appThemeNotifierProvider.notifier);
      
      // Change to light mode
      await notifier.setThemeMode(ThemeMode.light);
      
      var state = container.read(appThemeNotifierProvider);
      expect(state, ThemeMode.light);
      expect(AppColors.background, const Color(0xFFF3F4F6)); // Light mode color
      
      // Verify database contains the update
      final settingsList = await db.select(db.settings).get();
      expect(settingsList.first.themeMode, 'light');
      
      // Change back to dark mode
      await notifier.setThemeMode(ThemeMode.dark);
      
      state = container.read(appThemeNotifierProvider);
      expect(state, ThemeMode.dark);
      expect(AppColors.background, const Color(0xFF111827)); // Dark mode color
    });
  });
}
