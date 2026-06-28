import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/native.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:medicaixa_app/core/database/database.dart';
import 'package:medicaixa_app/core/providers/core_providers.dart';
import 'package:medicaixa_app/core/presentation/app_shell.dart';
import 'package:medicaixa_app/features/dashboard/presentation/dashboard_screen.dart';
import 'package:medicaixa_app/features/reports/presentation/reports_screen.dart';
import 'package:medicaixa_app/features/history/presentation/history_screen.dart';
import 'package:medicaixa_app/features/pairing/domain/connection_state.dart';
import 'package:medicaixa_app/features/pairing/presentation/pairing_notifier.dart';

class FakePairingNotifier extends PairingNotifier {
  @override
  ConnectionStateInfo build() {
    return const ConnectionStateInfo.disconnected();
  }
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('pt_BR', null);
  });

  group('ReportsScreen and Navigation UI Tests', () {
    late AppDatabase db;
    bool isDbClosed = false;

    setUp(() {
      db = AppDatabase.connect(NativeDatabase.memory());
      isDbClosed = false;
    });

    tearDown(() async {
      if (!isDbClosed) {
        await db.close();
      }
      await Future.delayed(const Duration(seconds: 1));
    });

    testWidgets('Verify AppShell contains ReportsScreen tab and navigates correctly (Mobile Layout)', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            pairingNotifierProvider.overrideWith(() => FakePairingNotifier()),
          ],
          child: const MaterialApp(
            home: AppShell(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Confirm we start on the Dashboard
      expect(find.byType(DashboardScreen), findsOneWidget);

      // Verify bottom tab bar has the 'Relatórios' icon / text
      final reportsTabFinder = find.text('Relatórios');
      expect(reportsTabFinder, findsWidgets);

      // Tap 'Relatórios' tab to navigate to ReportsScreen
      await tester.tap(reportsTabFinder.first);
      await tester.pumpAndSettle();

      // Verify that ReportsScreen is now active and rendered
      expect(find.byType(ReportsScreen), findsOneWidget);
      expect(find.text('Relatórios de Adesão'), findsOneWidget);
      expect(find.text('Adesão Geral (7 dias)'), findsOneWidget);
      expect(find.text('Adesão Diária (7 dias)'), findsOneWidget);
      expect(find.text('Sequência (30 dias)'), findsOneWidget);
      expect(find.text('Distribuição por Período (7 dias)'), findsOneWidget);
      expect(find.text('Calendário de Adesão (30 dias)'), findsOneWidget);

      // Settle drift streams and timers before tearing down
      await db.close();
      isDbClosed = true;
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('Verify AppShell contains ReportsScreen tab and navigates correctly (Desktop Layout)', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            pairingNotifierProvider.overrideWith(() => FakePairingNotifier()),
          ],
          child: const MaterialApp(
            home: AppShell(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify side navigation rail has the 'Relatórios' icon / text
      final reportsTabFinder = find.text('Relatórios');
      expect(reportsTabFinder, findsWidgets);

      // Tap 'Relatórios' destination to navigate to ReportsScreen
      await tester.tap(reportsTabFinder.first);
      await tester.pumpAndSettle();

      // Verify that ReportsScreen is now active and rendered
      expect(find.byType(ReportsScreen), findsOneWidget);
      expect(find.text('Relatórios de Adesão'), findsOneWidget);

      // Settle drift streams and timers before tearing down
      await db.close();
      isDbClosed = true;
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('Verify Dashboard History button opens HistoryScreen (Mobile Layout)', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            pairingNotifierProvider.overrideWith(() => FakePairingNotifier()),
          ],
          child: const MaterialApp(
            home: AppShell(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find the History button on the Dashboard Header
      final historyButtonFinder = find.byIcon(Icons.history_rounded);
      expect(historyButtonFinder, findsOneWidget);

      // Tap the History button
      await tester.tap(historyButtonFinder);
      await tester.pumpAndSettle();

      // Verify that HistoryScreen is pushed and active
      expect(find.byType(HistoryScreen), findsOneWidget);
      expect(find.text('Histórico & Logs'), findsOneWidget);
      expect(find.text('Eventos'), findsOneWidget);
      expect(find.text('Logs do Sistema'), findsOneWidget);

      // Settle drift streams and timers before tearing down
      await db.close();
      isDbClosed = true;
      await tester.pump(const Duration(seconds: 2));
    });
  });
}
