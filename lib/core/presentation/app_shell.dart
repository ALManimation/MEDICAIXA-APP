import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../localization/app_localizations.dart';
import '../constants/app_colors.dart';
import '../providers/theme_provider.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/alarms/presentation/wizard/alarm_wizard_screen.dart';
import '../../features/reminders/presentation/reminder_form_screen.dart';
import '../../features/medications/presentation/medication_form_screen.dart';
import 'widgets/multi_action_fab.dart';
import '../../features/medications/presentation/medications_list_screen.dart';
import 'package:medicaixa_app/features/reports/presentation/reports_screen.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const DashboardScreen(),
    const MedicationsListScreen(),
    const ReportsScreen(),
    const SettingsScreen(),
  ];

  void _openAlarmWizard(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const AlarmWizardScreen(),
      ),
    );
  }

  void _openReminderForm(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const ReminderFormScreen(),
      ),
    );
  }

  void _openMedicationForm(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const MedicationFormScreen(),
      ),
    );
  }

  void _scanQrCode(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(t('nav_qr_scan_soon')),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(appThemeNotifierProvider);
    final isDesktop = MediaQuery.of(context).size.width >= 800;

    if (isDesktop) {
      // Desktop Layout: 2 Columns (NavigationRail + Content)
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _currentIndex,
              backgroundColor: AppColors.surface,
              indicatorColor: AppColors.primary.withValues(alpha: 0.2),
              onDestinationSelected: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              labelType: NavigationRailLabelType.all,
              destinations: [
                NavigationRailDestination(
                  icon: const Icon(Icons.dashboard_outlined),
                  selectedIcon: Icon(Icons.dashboard_rounded, color: AppColors.primary),
                  label: Text(t('nav_home')),
                ),
                NavigationRailDestination(
                  icon: const Icon(Icons.medication_outlined),
                  selectedIcon: Icon(Icons.medication_rounded, color: AppColors.primary),
                  label: Text(t('nav_meds')),
                ),
                NavigationRailDestination(
                  icon: const Icon(Icons.bar_chart_outlined),
                  selectedIcon: Icon(Icons.bar_chart_rounded, color: AppColors.primary),
                  label: Text(t('nav_stats')),
                ),
                NavigationRailDestination(
                  icon: const Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings_rounded, color: AppColors.primary),
                  label: Text(t('nav_settings')),
                ),
              ],
            ),
            VerticalDivider(thickness: 1, width: 1, color: AppColors.border),
            Expanded(
              child: Stack(
                children: [
                  _screens[_currentIndex],
                  MultiActionFab(
                    onAddAlarm: () => _openAlarmWizard(context),
                    onAddReminder: () => _openReminderForm(context),
                    onAddMedication: () => _openMedicationForm(context),
                    onScanQr: () => _scanQrCode(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    } else {
      // Mobile Layout: BottomNavigationBar
      return Scaffold(
        body: Stack(
          children: [
            _screens[_currentIndex],
            MultiActionFab(
              onAddAlarm: () => _openAlarmWizard(context),
              onAddReminder: () => _openReminderForm(context),
              onAddMedication: () => _openMedicationForm(context),
              onScanQr: () => _scanQrCode(context),
            ),
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          backgroundColor: AppColors.surface,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.textMuted,
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          items: [
            BottomNavigationBarItem(
              icon: const Icon(Icons.dashboard_outlined),
              activeIcon: const Icon(Icons.dashboard_rounded),
              label: t('nav_home'),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.medication_outlined),
              activeIcon: const Icon(Icons.medication_rounded),
              label: t('nav_meds'),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.bar_chart_outlined),
              activeIcon: const Icon(Icons.bar_chart_rounded),
              label: t('nav_stats'),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.settings_outlined),
              activeIcon: const Icon(Icons.settings_rounded),
              label: t('nav_settings'),
            ),
          ],
        ),
      );
    }
  }
}
