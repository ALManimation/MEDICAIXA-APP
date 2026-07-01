import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';

import 'package:medicaixa_app/core/constants/app_colors.dart';
import '../../../core/presentation/widgets/vertical_datetime_selector.dart';
import 'package:medicaixa_app/core/database/database.dart';
import 'package:medicaixa_app/core/providers/locale_provider.dart';
import 'package:medicaixa_app/core/providers/theme_provider.dart';
import 'package:medicaixa_app/core/localization/app_localizations.dart';
import 'package:medicaixa_app/features/pairing/domain/connection_state.dart';
import 'package:medicaixa_app/features/pairing/presentation/pairing_notifier.dart';
import 'package:medicaixa_app/features/pairing/presentation/pairing_screen.dart';
import 'package:medicaixa_app/features/dashboard/presentation/dashboard_notifier.dart';
import 'package:medicaixa_app/features/settings/data/settings_models.dart';
import 'package:medicaixa_app/features/settings/data/settings_repository.dart';
import 'package:medicaixa_app/features/settings/data/wifi_repository.dart';
import 'package:medicaixa_app/features/medications/data/medication_repository.dart';

Map<String, dynamic> _decodeJson(String source) {
  return json.decode(source) as Map<String, dynamic>;
}

const Map<String, Map<String, dynamic>> restoreKeysConfig = {
  'meds': {'label': 'Medicamentos', 'default': true, 'restart': false},
  'alarms': {'label': 'Alarmes', 'default': true, 'restart': false},
  'reminders': {'label': 'Lembretes', 'default': true, 'restart': false},
  'history': {'label': 'Histórico Médico', 'default': true, 'restart': false},
  'wifi': {'label': 'Rede Wi-Fi', 'default': false, 'restart': false},
  'settings': {'label': 'Ajustes Gerais', 'default': false, 'restart': false},
  'xiaozhi': {'label': 'Ajustes do Assistente (Xiaozhi)', 'default': false, 'restart': true},
  'chat_history': {'label': 'Histórico do Chat', 'default': false, 'restart': false},
  'logs': {'label': 'Logs do Sistema', 'default': false, 'restart': false},
};

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _nameController = TextEditingController();
  final _geminiKeyController = TextEditingController();
  final _wifiSsidController = TextEditingController();
  final _wifiPasswordController = TextEditingController();
  bool _showGeminiKey = false;
  bool _isLoading = false;

  AudioPlayer? _testAudioPlayer;
  StreamSubscription<void>? _testAudioSubscription;
  bool _isTestingSound = false;

  @override
  void dispose() {
    _nameController.dispose();
    _geminiKeyController.dispose();
    _wifiSsidController.dispose();
    _wifiPasswordController.dispose();
    _testAudioSubscription?.cancel();
    _testAudioPlayer?.stop();
    _testAudioPlayer?.dispose();
    super.dispose();
  }

  TimeOfDay? _parseTimeOfDay(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return null;
    final parts = timeStr.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  void _selectTime(BuildContext context, Setting currentSettings, String fieldName, String? currentValue) async {
    final initialTime = _parseTimeOfDay(currentValue) ?? const TimeOfDay(hour: 8, minute: 0);
    final picked = await showVerticalTimePicker(
      context,
      initialTime: initialTime,
    );
    if (picked != null) {
      final formatted = _formatTimeOfDay(picked);
      final repo = ref.read(settingsRepositoryProvider);
      Setting updated;
      switch (fieldName) {
        case 'sleepTime':
          updated = currentSettings.copyWith(sleepTime: Value(formatted));
          break;
        case 'wakeTime':
          updated = currentSettings.copyWith(wakeTime: Value(formatted));
          break;
        case 'breakfastTime':
          updated = currentSettings.copyWith(breakfastTime: Value(formatted));
          break;
        case 'lunchTime':
          updated = currentSettings.copyWith(lunchTime: Value(formatted));
          break;
        case 'dinnerTime':
          updated = currentSettings.copyWith(dinnerTime: Value(formatted));
          break;
        default:
          return;
      }
      await repo.updateSettings(updated);
    }
  }

  void _saveName(Setting currentSettings) async {
    final newName = _nameController.text.trim();
    if (newName.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    final repo = ref.read(settingsRepositoryProvider);
    final buildContext = context;
    await repo.updatePatientName(newName);

    setState(() {
      _isLoading = false;
    });

    if (buildContext.mounted) {
      ScaffoldMessenger.of(buildContext).showSnackBar(
        SnackBar(
          content: Text(t('settings_patient_saved_toast')),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  void _loadBackupFixture() async {
    setState(() {
      _isLoading = true;
    });

    final buildContext = context;

    try {
      final jsonContent = await rootBundle.loadString('test/fixtures/sample_backup.json');
      await ref.read(dashboardNotifierProvider.notifier).loadSampleData(jsonContent);

      final Map<String, dynamic> data = await compute(_decodeJson, jsonContent);
      if (data.containsKey('meds') && data['meds'] is List) {
        final medsList = data['meds'] as List;
        await ref.read(medicationRepositoryProvider).loadBackupFixture(medsList);
      }

      if (buildContext.mounted) {
        ScaffoldMessenger.of(buildContext).showSnackBar(
          SnackBar(
            content: Text(t('settings_fixture_loaded_toast')),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (buildContext.mounted) {
        ScaffoldMessenger.of(buildContext).showSnackBar(
          SnackBar(
            content: Text(t('settings_fixture_load_error', [e])),
            backgroundColor: AppColors.missed,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _downloadBackup() async {
    final buildContext = context;
    try {
      final backupStr = await ref.read(settingsRepositoryProvider).downloadBackupJson();
      final bytes = utf8.encode(backupStr);

      if (kIsWeb) return;

      if (Platform.isMacOS) {
        final outputFile = await FilePicker.saveFile(
          dialogTitle: t('backup_title'),
          fileName: 'medicaixa_backup.json',
          type: FileType.custom,
          allowedExtensions: ['json'],
        );
        if (outputFile != null) {
          final file = File(outputFile);
          await file.writeAsBytes(bytes);
          if (buildContext.mounted) {
            ScaffoldMessenger.of(buildContext).showSnackBar(
              SnackBar(content: Text(t('settings_backup_success_toast')), backgroundColor: AppColors.success),
            );
          }
        }
      } else {
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/medicaixa_backup.json');
        await file.writeAsBytes(bytes);

        // ignore: deprecated_member_use
        await Share.shareXFiles(
          [XFile(file.path, mimeType: 'application/json')],
          subject: t('backup_title'),
        );
      }
    } catch (e) {
      if (buildContext.mounted) {
        ScaffoldMessenger.of(buildContext).showSnackBar(
          SnackBar(content: Text(t('settings_backup_error', [e])), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _restoreBackup() async {
    final buildContext = context;
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (result == null || result.files.single.path == null) return;

      final path = result.files.single.path!;
      final file = File(path);
      final content = await file.readAsString();
      final Map<String, dynamic> rawMap = await compute(_decodeJson, content);

      final availableKeys = restoreKeysConfig.keys.where((k) => rawMap.containsKey(k)).toList();
      if (availableKeys.isEmpty) {
        if (buildContext.mounted) {
          ScaffoldMessenger.of(buildContext).showSnackBar(
            SnackBar(content: Text(t('restore_invalid')), backgroundColor: Colors.red),
          );
        }
        return;
      }

      if (buildContext.mounted) {
        final selectedKeys = await showDialog<List<String>>(
          context: buildContext,
          builder: (dialogCtx) {
            return _BackupRestoreKeysDialog(availableKeys: availableKeys);
          },
        );

        if (selectedKeys == null || selectedKeys.isEmpty) return;

        final partialBackup = <String, dynamic>{};
        var needsReboot = false;
        for (final key in selectedKeys) {
          partialBackup[key] = rawMap[key];
          if (restoreKeysConfig[key]?['restart'] == true) {
            needsReboot = true;
          }
        }

        if (buildContext.mounted) {
          showDialog(
            context: buildContext,
            barrierDismissible: false,
            builder: (dialogCtx) => PopScope(
              canPop: false,
              child: AlertDialog(
                content: Row(
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(width: 20),
                    Expanded(child: Text(t('restore_progress'))),
                  ],
                ),
              ),
            ),
          );
        }

        final repo = ref.read(settingsRepositoryProvider);
        final restoredCount = await repo.executeBackupRestore(partialBackup);

        if (buildContext.mounted) {
          Navigator.pop(buildContext);
        }

        if (needsReboot) {
          if (buildContext.mounted) {
            _showRebootOverlay(t('restore_status_done_restart', [selectedKeys.length]), 8);
          }
          await repo.restartDevice();
        } else {
          if (buildContext.mounted) {
            ScaffoldMessenger.of(buildContext).showSnackBar(
              SnackBar(content: Text(t('settings_backup_restore_success_toast', [restoredCount])), backgroundColor: AppColors.success),
            );
          }
        }
      }
    } catch (e) {
      if (buildContext.mounted) {
        ScaffoldMessenger.of(buildContext).showSnackBar(
          SnackBar(content: Text(t('settings_backup_restore_error', [e])), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showRebootOverlay(String message, int seconds) async {
    final buildContext = context;
    showDialog(
      context: buildContext,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return PopScope(
          canPop: false,
          child: AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 16),
                const CircularProgressIndicator(),
                const SizedBox(height: 24),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  t('restore_status_wait'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );

    await Future.delayed(Duration(seconds: seconds));

    if (buildContext.mounted) {
      Navigator.of(buildContext).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final connState = ref.watch(pairingNotifierProvider);
    final currentLocale = ref.watch(appLocaleProvider);
    final settingsAsync = ref.watch(watchSettingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(t('settings_title')),
      ),
      body: settingsAsync.when(
        data: (settings) {
          if (settings == null) {
            return const Center(child: CircularProgressIndicator());
          }

          if (_nameController.text.isEmpty && settings.patientName.isNotEmpty) {
            _nameController.text = settings.patientName;
          }
          if (_geminiKeyController.text.isEmpty && settings.geminiApiKey != null) {
            _geminiKeyController.text = settings.geminiApiKey!;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ================= AJUSTES LOCAIS =================
                _buildSectionHeader(t('settings_local_header')),
                const SizedBox(height: 8),

                // Dados do Paciente
                _buildPatientProfileCard(settings),
                const SizedBox(height: 12),

                // Cronograma de Sono & Refeições
                _buildSleepMealsCard(settings),
                const SizedBox(height: 12),

                // Idioma do App
                _buildAppConfigCard(currentLocale, settings),
                const SizedBox(height: 12),

                // Notificações e Sons do App
                _buildAppNotificationsCard(settings),
                const SizedBox(height: 24),

                // ================= AJUSTES DA CAIXINHA =================
                _buildSectionHeader(t('settings_device_header')),
                const SizedBox(height: 8),

                // Connection status / warning card
                if (connState.status == ConnectionStatus.connected) ...[
                  _buildConnectionStatusCard(connState),
                  const SizedBox(height: 12),
                ] else ...[
                  _buildConnectionWarningCard(context),
                  const SizedBox(height: 12),
                ],

                Opacity(
                  opacity: connState.status == ConnectionStatus.connected ? 1.0 : 0.55,
                  child: IgnorePointer(
                    ignoring: connState.status != ConnectionStatus.connected,
                    child: Column(
                      children: [
                        // Wi-Fi Config ExpansionTile
                        _buildWifiConfigTile(),
                        const SizedBox(height: 12),

                        // Sound & Display ExpansionTile
                        _buildSoundDisplayTile(settings),
                        const SizedBox(height: 12),

                        // Clock Sync Card
                        _buildClockSyncCard(),
                        const SizedBox(height: 12),

                        // Voice Assistant ExpansionTile
                        _buildVoiceAssistantTile(settings),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Device Maintenance ExpansionTile
                _buildMaintenanceTile(settings),

                const SizedBox(height: 32),

                // ================= OPÇÕES DE DESENVOLVEDOR =================
                _buildSectionHeader(t('settings_developer_header')),
                const SizedBox(height: 8),
                _buildDeveloperFixtureCard(),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text(t('settings_load_error', [err]))),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  Widget _buildPatientProfileCard(Setting settings) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: t('patient_name_label'),
                hintText: 'Ex: Carolina',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: _isLoading ? null : () => _saveName(settings),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: Text(t('patient_save_btn')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSleepMealsCard(Setting settings) {
    final repo = ref.read(settingsRepositoryProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                t('settings_sleep_schedule'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(t('settings_sleep_routine_desc')),
              value: settings.sleepScheduleEnabled,
              activeThumbColor: AppColors.primary,
              onChanged: (val) {
                repo.updateSettings(settings.copyWith(sleepScheduleEnabled: val));
              },
            ),
            if (settings.sleepScheduleEnabled) ...[
              const Divider(),
              Row(
                children: [
                  Expanded(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(t('settings_sleep_label'), style: TextStyle(fontSize: 14, color: AppColors.textMuted)),
                      subtitle: Text(
                        settings.sleepTime ?? t('not_defined'),
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.text),
                      ),
                      trailing: Icon(Icons.access_time_rounded, color: AppColors.primary),
                      onTap: () => _selectTime(context, settings, 'sleepTime', settings.sleepTime),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(t('settings_wake_label'), style: TextStyle(fontSize: 14, color: AppColors.textMuted)),
                      subtitle: Text(
                        settings.wakeTime ?? t('not_defined'),
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.text),
                      ),
                      trailing: Icon(Icons.access_time_rounded, color: AppColors.primary),
                      onTap: () => _selectTime(context, settings, 'wakeTime', settings.wakeTime),
                    ),
                  ),
                ],
              ),
            ],
            const Divider(),
            const SizedBox(height: 8),
            Text(
              t('settings_meals_header'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 4),
            Text(
              t('settings_meals_desc'),
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(t('settings_breakfast'), style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                    subtitle: Text(
                      settings.breakfastTime ?? '08:00',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.text),
                    ),
                    trailing: Icon(Icons.coffee_rounded, size: 18, color: AppColors.primary),
                    onTap: () => _selectTime(context, settings, 'breakfastTime', settings.breakfastTime ?? '08:00'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(t('settings_lunch'), style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                    subtitle: Text(
                      settings.lunchTime ?? '12:00',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.text),
                    ),
                    trailing: Icon(Icons.restaurant_rounded, size: 18, color: AppColors.primary),
                    onTap: () => _selectTime(context, settings, 'lunchTime', settings.lunchTime ?? '12:00'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(t('settings_dinner'), style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                    subtitle: Text(
                      settings.dinnerTime ?? '20:00',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.text),
                    ),
                    trailing: Icon(Icons.dinner_dining_rounded, size: 18, color: AppColors.primary),
                    onTap: () => _selectTime(context, settings, 'dinnerTime', settings.dinnerTime ?? '20:00'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppConfigCard(String currentLocale, Setting settings) {
    final themeMode = ref.watch(appThemeNotifierProvider);
    String normalizedLocale = currentLocale;
    if (normalizedLocale.contains('_')) {
      normalizedLocale = normalizedLocale.split('_')[0];
    }
    if (normalizedLocale.contains('-')) {
      normalizedLocale = normalizedLocale.split('-')[0];
    }
    if (normalizedLocale != 'en' && normalizedLocale != 'es') {
      normalizedLocale = 'pt';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t('language_label'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: normalizedLocale,
              dropdownColor: AppColors.surface,
              style: TextStyle(color: AppColors.text, fontSize: 16),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: [
                DropdownMenuItem<String>(
                  value: 'pt',
                  child: Text(
                    '🇧🇷 Português',
                    style: TextStyle(color: AppColors.text),
                  ),
                ),
                DropdownMenuItem<String>(
                  value: 'en',
                  child: Text(
                    '🇺🇸 English',
                    style: TextStyle(color: AppColors.text),
                  ),
                ),
                DropdownMenuItem<String>(
                  value: 'es',
                  child: Text(
                    '🇪🇸 Español',
                    style: TextStyle(color: AppColors.text),
                  ),
                ),
              ],
              onChanged: (value) async {
                if (value != null && context.mounted) {
                  await ref.read(appLocaleProvider.notifier).changeLocale(value);
                }
              },
            ),
            const SizedBox(height: 20),
            Text(
              t('appearance_label'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Center(
              child: SegmentedButton<ThemeMode>(
                segments: [
                  ButtonSegment(
                    value: ThemeMode.light,
                    icon: Icon(Icons.light_mode_rounded, color: AppColors.primary),
                    label: Text(t('theme_light')),
                  ),
                  ButtonSegment(
                    value: ThemeMode.dark,
                    icon: Icon(Icons.dark_mode_rounded, color: AppColors.primary),
                    label: Text(t('theme_dark')),
                  ),
                ],
                selected: {themeMode},
                onSelectionChanged: (newSelection) async {
                  final mode = newSelection.first;
                  await ref.read(appThemeNotifierProvider.notifier).setThemeMode(mode);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleSoundTest(int soundIndex, int volume) async {
    final buildContext = context;
    if (_isTestingSound) {
      _testAudioSubscription?.cancel();
      if (_testAudioPlayer != null) {
        await _testAudioPlayer!.stop();
      }
      setState(() {
        _isTestingSound = false;
      });
    } else {
      setState(() {
        _isTestingSound = true;
      });
      _testAudioPlayer ??= AudioPlayer();
      try {
        await _testAudioPlayer!.setReleaseMode(ReleaseMode.release);
        await _testAudioPlayer!.setVolume(volume / 100.0);
        
        String soundPath = 'sounds/alarm_alerta.wav';
        switch (soundIndex) {
          case 0: soundPath = 'sounds/alarm_gentile.wav'; break;
          case 1: soundPath = 'sounds/alarm_alerta.wav'; break;
          case 2: soundPath = 'sounds/alarm_melodia.wav'; break;
          case 3: soundPath = 'sounds/alarm_urgente.wav'; break;
          case 4: soundPath = 'sounds/alarm_musical.wav'; break;
        }
        
        _testAudioSubscription?.cancel();
        _testAudioSubscription = _testAudioPlayer!.onPlayerComplete.listen((_) {
          if (buildContext.mounted) {
            setState(() {
              _isTestingSound = false;
            });
          }
        });

        await _testAudioPlayer!.play(AssetSource(soundPath));
      } catch (e) {
        debugPrint('Error playing sound test: $e');
        if (buildContext.mounted) {
          setState(() {
            _isTestingSound = false;
          });
        }
      }
    }
  }

  Widget _buildAppNotificationsCard(Setting settings) {
    final repo = ref.read(settingsRepositoryProvider);

    final soundDropdown = DropdownButtonFormField<int>(
      initialValue: settings.localAlarmSound,
      dropdownColor: AppColors.surface,
      style: TextStyle(color: AppColors.text, fontSize: 16),
      decoration: const InputDecoration(
        labelText: 'Som do Alarme',
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      items: [
        DropdownMenuItem(value: 0, child: Text('Gentil', style: TextStyle(color: AppColors.text))),
        DropdownMenuItem(value: 1, child: Text('Alerta', style: TextStyle(color: AppColors.text))),
        DropdownMenuItem(value: 2, child: Text('Melodia', style: TextStyle(color: AppColors.text))),
        DropdownMenuItem(value: 3, child: Text('Urgente', style: TextStyle(color: AppColors.text))),
        DropdownMenuItem(value: 4, child: Text('Musical', style: TextStyle(color: AppColors.text))),
      ],
      onChanged: (val) async {
        if (val != null) {
          final updated = settings.copyWith(localAlarmSound: val);
          await repo.updateSettings(updated);
        }
      },
    );

    final durationDropdown = DropdownButtonFormField<int>(
      initialValue: settings.localAlarmDurationMins,
      dropdownColor: AppColors.surface,
      style: TextStyle(color: AppColors.text, fontSize: 16),
      decoration: const InputDecoration(
        labelText: 'Duração Limite',
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      items: [
        DropdownMenuItem(value: 1, child: Text('1 Minuto', style: TextStyle(color: AppColors.text))),
        DropdownMenuItem(value: 2, child: Text('2 Minutos', style: TextStyle(color: AppColors.text))),
        DropdownMenuItem(value: 5, child: Text('5 Minutos', style: TextStyle(color: AppColors.text))),
      ],
      onChanged: (val) async {
        if (val != null) {
          final updated = settings.copyWith(localAlarmDurationMins: val);
          await repo.updateSettings(updated);
        }
      },
    );

    final volumeSlider = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Volume do Alarme: ${settings.localAlarmVolume}%',
          style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w500),
        ),
        Slider(
          value: settings.localAlarmVolume.toDouble(),
          min: 0,
          max: 100,
          divisions: 100,
          activeColor: AppColors.primary,
          onChanged: (val) {
            repo.updateSettings(settings.copyWith(localAlarmVolume: val.toInt()));
          },
        ),
      ],
    );

    final vibrationSwitch = SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text('Vibrar ao tocar', style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w500)),
      value: settings.localVibrationEnabled,
      activeThumbColor: AppColors.primary,
      onChanged: (val) async {
        final updated = settings.copyWith(localVibrationEnabled: val);
        await repo.updateSettings(updated);
      },
    );

    final testButton = ElevatedButton.icon(
      onPressed: () => _toggleSoundTest(settings.localAlarmSound, settings.localAlarmVolume),
      icon: Icon(
        _isTestingSound ? Icons.stop_rounded : Icons.play_arrow_rounded,
        color: Colors.white,
      ),
      label: Text(_isTestingSound ? 'Parar Teste' : 'Testar Alarme'),
      style: ElevatedButton.styleFrom(
        backgroundColor: _isTestingSound ? AppColors.missed : AppColors.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );

    final width = MediaQuery.of(context).size.width;
    final isWide = width >= 800;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Notificações e Sons do App',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 16),
            if (isWide) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        soundDropdown,
                        const SizedBox(height: 16),
                        durationDropdown,
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        volumeSlider,
                        const SizedBox(height: 8),
                        vibrationSwitch,
                        const SizedBox(height: 16),
                        SizedBox(width: double.infinity, child: testButton),
                      ],
                    ),
                  ),
                ],
              ),
            ] else ...[
              soundDropdown,
              const SizedBox(height: 16),
              durationDropdown,
              const SizedBox(height: 16),
              volumeSlider,
              const SizedBox(height: 8),
              vibrationSwitch,
              const SizedBox(height: 16),
              SizedBox(width: double.infinity, child: testButton),
            ],
          ],
        ),
      ),
    );
  }


  Widget _buildConnectionStatusCard(ConnectionStateInfo connState) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                connState.status == ConnectionStatus.connected
                    ? Icons.cloud_done_rounded
                    : Icons.cloud_off_rounded,
                color: connState.status == ConnectionStatus.connected
                    ? AppColors.success
                    : AppColors.textMuted,
                size: 32,
              ),
              title: Text(
                connState.status == ConnectionStatus.connected
                    ? t('settings_conn_local_network')
                    : t('settings_conn_standalone'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                connState.status == ConnectionStatus.connected
                    ? t('settings_conn_details', [connState.ip, connState.firmwareVersion])
                    : t('settings_conn_standalone_desc'),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: ElevatedButton.icon(
                onPressed: () {
                  ref.read(pairingNotifierProvider.notifier).disconnect();
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const PairingScreen()),
                  );
                },
                icon: const Icon(Icons.settings_ethernet_rounded),
                label: Text(
                  connState.status == ConnectionStatus.connected
                      ? t('settings_change_pair_btn')
                      : t('settings_connect_box_btn'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionWarningCard(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.healthDangerBorder, width: 1.5),
      ),
      color: AppColors.healthDangerBg,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber_rounded, size: 28, color: AppColors.healthDanger),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    t('settings_box_locked_title'),
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.healthDanger),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              t('settings_box_locked_desc'),
              style: TextStyle(fontSize: 14, color: AppColors.textMuted),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () {
                  ref.read(pairingNotifierProvider.notifier).disconnect();
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const PairingScreen()),
                  );
                },
                icon: Icon(Icons.link_rounded, color: AppColors.primary),
                label: Text(
                  t('settings_connect_now_btn'),
                  style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWifiConfigTile() {
    final savedWifiAsync = ref.watch(savedWifiNetworksProvider);
    final wifiScanAsync = ref.watch(wifiScanProvider);
    final wifiActionState = ref.watch(wifiActionNotifierProvider);

    return ExpansionTile(
      leading: Icon(Icons.wifi_rounded, color: AppColors.primary),
      title: Text(t('settings_box_wifi_title'), style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(t('settings_box_wifi_desc')),
      backgroundColor: AppColors.surface,
      collapsedBackgroundColor: AppColors.surface,
      textColor: AppColors.text,
      collapsedTextColor: AppColors.text,
      iconColor: AppColors.primary,
      collapsedIconColor: AppColors.textMuted,
      childrenPadding: const EdgeInsets.all(16),
      children: [
        Text(
          t('settings_wifi_saved_title'),
          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textMuted, fontSize: 13),
        ),
        const SizedBox(height: 8),
        savedWifiAsync.when(
          data: (networks) {
            if (networks.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(t('settings_wifi_no_networks'), style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
              );
            }
            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: networks.length,
              itemBuilder: (ctx, index) {
                final net = networks[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.wifi_lock_rounded, color: AppColors.primary),
                  title: Text(net.ssid, style: const TextStyle(fontSize: 14)),
                  trailing: IconButton(
                    icon: Icon(Icons.delete_outline_rounded, color: AppColors.missed),
                    onPressed: wifiActionState.isLoading
                        ? null
                        : () async {
                            final confirm = await showDialog<bool>(
                              context: ctx,
                              builder: (dialogCtx) => AlertDialog(
                                title: Text(t('dialog_forget_network_title')),
                                content: Text(t('dialog_forget_network_desc', [net.ssid])),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(dialogCtx, false),
                                    child: Text(t('cancel_btn')),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(dialogCtx, true),
                                    child: Text(t('btn_remove'), style: TextStyle(color: AppColors.missed)),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true && ctx.mounted) {
                              final success = await ref
                                  .read(wifiActionNotifierProvider.notifier)
                                  .removeNetwork(net.ssid);
                              if (success && ctx.mounted) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(content: Text(t('settings_wifi_removed_toast')), backgroundColor: AppColors.success),
                                );
                              }
                            }
                          },
                  ),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, st) => Text(t('settings_wifi_load_error', [err]), style: const TextStyle(color: Colors.red, fontSize: 13)),
        ),
        const Divider(),
        const SizedBox(height: 12),
        Text(
          t('settings_wifi_add_title'),
          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textMuted, fontSize: 13),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Column(
                children: [
                  TextField(
                    controller: _wifiSsidController,
                    decoration: InputDecoration(
                      labelText: t('wifi_ssid_label'),
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _wifiPasswordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: t('wifi_pass_label'),
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: wifiActionState.isLoading
                  ? null
                  : () async {
                      final ssid = _wifiSsidController.text.trim();
                      final password = _wifiPasswordController.text;
                      if (ssid.isEmpty) return;
                      final buildContext = context;
                      final success = await ref
                          .read(wifiActionNotifierProvider.notifier)
                          .addNetwork(ssid, password);
                      if (success) {
                        _wifiSsidController.clear();
                        _wifiPasswordController.clear();
                        if (buildContext.mounted) {
                          ScaffoldMessenger.of(buildContext).showSnackBar(
                            SnackBar(content: Text(t('settings_wifi_save_success')), backgroundColor: AppColors.success),
                          );
                        }
                      }
                    },
              child: Text(t('save_btn')),
            ),
          ],
        ),
        const Divider(),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              t('settings_wifi_available_networks'),
              style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textMuted, fontSize: 13),
            ),
            IconButton(
              icon: Icon(Icons.refresh_rounded, color: AppColors.primary),
              onPressed: () {
                ref.invalidate(wifiScanProvider);
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        wifiScanAsync.when(
          data: (networks) {
            if (networks.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(t('settings_wifi_none_found'), style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
              );
            }
            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: networks.length,
              itemBuilder: (context, index) {
                final net = networks[index];
                final isSecure = net.isOpen == false;
                const IconData signalIcon = Icons.wifi_rounded;

                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(signalIcon, color: AppColors.textMuted),
                  title: Text(net.ssid, style: const TextStyle(fontSize: 14)),
                  subtitle: Text(t('settings_wifi_signal_fmt', [net.rssi ?? -100, net.channel ?? 1]), style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  trailing: isSecure ? Icon(Icons.lock_rounded, size: 16, color: AppColors.textMuted) : null,
                  onTap: () {
                    _wifiSsidController.text = net.ssid;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(t('settings_wifi_selected_hint', [net.ssid])),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, st) => Text(t('settings_wifi_scan_error', [err]), style: const TextStyle(color: Colors.red, fontSize: 13)),
        ),
      ],
    );
  }

  Widget _buildSoundDisplayTile(Setting settings) {
    final repo = ref.read(settingsRepositoryProvider);
    final soundAction = ref.watch(soundSettingsActionProvider);

    final currentRingtone = RingtoneType.fromIndex(settings.alarmSound);
    final currentInterval = AlarmSpacingInterval.fromMs(settings.alarmSpacingMs);

    return ExpansionTile(
      leading: Icon(Icons.tune_rounded, color: AppColors.primary),
      title: Text(t('settings_sound_display_header'), style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(t('settings_sound_display_subtitle')),
      backgroundColor: AppColors.surface,
      collapsedBackgroundColor: AppColors.surface,
      textColor: AppColors.text,
      collapsedTextColor: AppColors.text,
      iconColor: AppColors.primary,
      collapsedIconColor: AppColors.textMuted,
      childrenPadding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Icon(Icons.volume_up_rounded, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${t('volume_title')}: ${settings.speakerVolume}%',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Slider(
                    value: settings.speakerVolume.toDouble(),
                    min: 0,
                    max: 100,
                    divisions: 10,
                    onChanged: (val) {
                      repo.updateSettings(
                        settings.copyWith(speakerVolume: val.toInt()),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Icon(Icons.wb_sunny_rounded, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${t('brightness_title')}: ${settings.brightness}%',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Slider(
                    value: settings.brightness.toDouble(),
                    min: 0,
                    max: 100,
                    divisions: 10,
                    onChanged: (val) {
                      repo.updateSettings(
                        settings.copyWith(brightness: val.toInt()),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        const Divider(),
        const SizedBox(height: 12),
        Text(
          t('alarm_sound_title'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<RingtoneType>(
          initialValue: currentRingtone,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          dropdownColor: AppColors.surface,
          style: TextStyle(color: AppColors.text, fontSize: 16),
          items: RingtoneType.values.map((r) {
            String ringtoneLabel;
            switch (r) {
              case RingtoneType.gentile:
                ringtoneLabel = t('tone_gentle');
                break;
              case RingtoneType.alerta:
                ringtoneLabel = t('tone_alert');
                break;
              case RingtoneType.melodia:
                ringtoneLabel = t('tone_melody');
                break;
              case RingtoneType.urgente:
                ringtoneLabel = t('tone_urgent');
                break;
              case RingtoneType.musical:
                ringtoneLabel = t('tone_musical');
                break;
            }
            return DropdownMenuItem<RingtoneType>(
              value: r,
              child: Text(ringtoneLabel),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) {
              ref.read(soundSettingsActionProvider.notifier).saveSound(
                ringtoneIndex: val.index,
                repeatIntervalMs: settings.alarmSpacingMs,
              );
            }
          },
        ),
        const SizedBox(height: 16),
        Text(
          t('alarm_interval_label'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<AlarmSpacingInterval>(
          initialValue: currentInterval,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          dropdownColor: AppColors.surface,
          style: TextStyle(color: AppColors.text, fontSize: 16),
          items: AlarmSpacingInterval.values.map((i) {
            String intervalLabel;
            switch (i) {
              case AlarmSpacingInterval.oneSecond:
                intervalLabel = t('interval_1s');
                break;
              case AlarmSpacingInterval.threeSeconds:
                intervalLabel = t('interval_3s');
                break;
              case AlarmSpacingInterval.sixSeconds:
                intervalLabel = t('interval_6s');
                break;
              case AlarmSpacingInterval.tenSeconds:
                intervalLabel = t('interval_10s');
                break;
            }
            return DropdownMenuItem<AlarmSpacingInterval>(
              value: i,
              child: Text(intervalLabel),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) {
              ref.read(soundSettingsActionProvider.notifier).saveSound(
                ringtoneIndex: settings.alarmSound,
                repeatIntervalMs: val.ms,
              );
            }
          },
        ),
        const SizedBox(height: 20),
        Center(
          child: ElevatedButton.icon(
            onPressed: soundAction.isLoading
                ? null
                : () {
                    ref.read(soundSettingsActionProvider.notifier).testSoundTone(settings.alarmSound);
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.play_circle_outline_rounded, color: Colors.white),
            label: Text(t('test_sound_btn')),
          ),
        ),
      ],
    );
  }

  Widget _buildClockSyncCard() {
    final deviceTimeAsync = ref.watch(deviceTimeNotifierProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t('clock_title'), style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            deviceTimeAsync.when(
              data: (deviceTime) {
                if (deviceTime == null) {
                  return Text(t('settings_clock_offline_unavailable'), style: TextStyle(color: AppColors.textMuted));
                }
                final formatted = "${deviceTime.day.toString().padLeft(2, '0')}/${deviceTime.month.toString().padLeft(2, '0')}/${deviceTime.year} "
                                  "${deviceTime.hour.toString().padLeft(2, '0')}:${deviceTime.minute.toString().padLeft(2, '0')}:${deviceTime.second.toString().padLeft(2, '0')}";
                return Text(t('settings_clock_device_time', [formatted]), style: TextStyle(fontSize: 16, color: AppColors.text));
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Text(t('settings_load_error', [err]), style: const TextStyle(color: Colors.red)),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final buildContext = context;
                      await ref.read(deviceTimeNotifierProvider.notifier).syncWithPhoneTime();
                      if (buildContext.mounted) {
                        ScaffoldMessenger.of(buildContext).showSnackBar(
                          SnackBar(content: Text(t('settings_clock_sync_success')), backgroundColor: AppColors.success),
                        );
                      }
                    },
                    icon: const Icon(Icons.sync_rounded, color: Colors.white),
                    label: Text(t('clock_sync_btn')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final buildContext = context;
                      final now = DateTime.now();
                      final date = await showVerticalDatePicker(
                        buildContext,
                        initialDate: now,
                      );
                      if (date != null && buildContext.mounted) {
                        final time = await showVerticalTimePicker(
                          buildContext,
                          initialTime: TimeOfDay.now(),
                        );
                        if (time != null && buildContext.mounted) {
                          final combined = DateTime(date.year, date.month, date.day, time.hour, time.minute);
                          await ref.read(deviceTimeNotifierProvider.notifier).setManualDateTime(combined);
                          if (buildContext.mounted) {
                            ScaffoldMessenger.of(buildContext).showSnackBar(
                              SnackBar(content: Text(t('settings_clock_manual_success')), backgroundColor: AppColors.success),
                            );
                          }
                        }
                      }
                    },
                    icon: const Icon(Icons.edit_calendar_rounded, color: Colors.white),
                    label: Text(t('clock_manual_label')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceAssistantTile(Setting settings) {
    final statusAsync = ref.watch(voiceStatusStreamProvider);
    final repo = ref.read(settingsRepositoryProvider);

    Color getStatusColor(VoiceState state) {
      switch (state) {
        case VoiceState.connected:
          return const Color(0xFF10B981);
        case VoiceState.connecting:
          return const Color(0xFFF59E0B);
        case VoiceState.listening:
          return const Color(0xFF3B82F6);
        case VoiceState.thinking:
          return const Color(0xFF8B5CF6);
        case VoiceState.speaking:
          return const Color(0xFF06B6D4);
        case VoiceState.error:
          return const Color(0xFFEF4444);
        case VoiceState.disconnected:
        case VoiceState.uninitialized:
          return const Color(0xFF9CA3AF);
      }
    }

    String getStatusLabel(VoiceState state) {
      switch (state) {
        case VoiceState.connected:
          return t('voice_connected_label');
        case VoiceState.connecting:
          return t('voice_connecting_label');
        case VoiceState.listening:
          return t('voice_listening_label');
        case VoiceState.thinking:
          return t('voice_thinking_label');
        case VoiceState.speaking:
          return t('voice_speaking_label');
        case VoiceState.error:
          return t('voice_error_label');
        case VoiceState.disconnected:
          return t('voice_disconnected_label');
        case VoiceState.uninitialized:
          return t('voice_uninitialized_label');
      }
    }

    return ExpansionTile(
      leading: Icon(Icons.mic_rounded, color: AppColors.primary),
      title: Text(t('voice_title'), style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(t('settings_voice_subtitle')),
      backgroundColor: AppColors.surface,
      collapsedBackgroundColor: AppColors.surface,
      textColor: AppColors.text,
      collapsedTextColor: AppColors.text,
      iconColor: AppColors.primary,
      collapsedIconColor: AppColors.textMuted,
      childrenPadding: const EdgeInsets.all(16),
      children: [
        statusAsync.when(
          data: (status) {
            if (status == null) {
              return Text(t('settings_voice_standalone_info'), style: TextStyle(color: AppColors.textMuted));
            }
            final isConnecting = status.state == VoiceState.connecting;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _AnimatedStatusDot(
                      color: getStatusColor(status.state),
                      pulse: isConnecting,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(getStatusLabel(status.state), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Text(
                            t('settings_voice_status_fmt', [
                              status.connected ? t('settings_voice_connected_server') : t('settings_voice_no_connection')
                            ]),
                            style: TextStyle(color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (status.activationCode.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t('settings_voice_activation_code_label'), style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            SelectableText(
                              status.activationCode,
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: AppColors.primary),
                            ),
                            IconButton(
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: status.activationCode));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(t('settings_voice_copied_toast')), backgroundColor: AppColors.success),
                                );
                              },
                              icon: Icon(Icons.copy_rounded, color: AppColors.primary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          t('settings_voice_pair_instruction'),
                          style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Text(t('settings_load_error', [err]), style: const TextStyle(color: Colors.red)),
        ),
        const SizedBox(height: 20),
        Text(
          t('wake_word_title'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: settings.wakeWord,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          dropdownColor: AppColors.surface,
          style: TextStyle(color: AppColors.text, fontSize: 16),
          items: const [
            DropdownMenuItem(value: 'jarvis', child: Text('Jarvis (Caixinha)')),
            DropdownMenuItem(value: 'hey_kira', child: Text('Hey Kira')),
            DropdownMenuItem(value: 'sofia', child: Text('Sofia')),
            DropdownMenuItem(value: 'hey_wanda', child: Text('Hey Wanda')),
          ],
          onChanged: (val) {
            if (val != null) {
              repo.updateSettings(settings.copyWith(wakeWord: val));
            }
          },
        ),
        const SizedBox(height: 20),
        Text(
          t('gemini_title'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          t('settings_voice_gemini_desc'),
          style: TextStyle(fontSize: 12, color: AppColors.textMuted),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _geminiKeyController,
                obscureText: !_showGeminiKey,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  labelText: t('gemini_label'),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _showGeminiKey ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                      color: AppColors.textMuted,
                    ),
                    onPressed: () {
                      setState(() {
                        _showGeminiKey = !_showGeminiKey;
                      });
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                final key = _geminiKeyController.text.trim();
                repo.updateSettings(settings.copyWith(geminiApiKey: Value(key.isEmpty ? null : key)));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(t('settings_voice_gemini_saved_toast')),
                    backgroundColor: AppColors.success,
                  ),
                );
              },
              child: Text(t('save_btn')),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMaintenanceTile(Setting settings) {
    return ExpansionTile(
      leading: Icon(Icons.construction_rounded, color: AppColors.primary),
      title: Text(t('settings_maintenance_title'), style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(t('settings_maintenance_desc')),
      backgroundColor: AppColors.surface,
      collapsedBackgroundColor: AppColors.surface,
      textColor: AppColors.text,
      collapsedTextColor: AppColors.text,
      iconColor: AppColors.primary,
      collapsedIconColor: AppColors.textMuted,
      childrenPadding: const EdgeInsets.all(16),
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.refresh_rounded, color: AppColors.primary),
          title: Text(t('settings_relaunch_wizard_title'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          subtitle: Text(t('settings_relaunch_wizard_desc'), style: const TextStyle(fontSize: 12)),
          trailing: Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
          onTap: () async {
            final buildContext = context;
            final confirm = await showDialog<bool>(
              context: buildContext,
              builder: (dialogCtx) => AlertDialog(
                title: Text(t('settings_relaunch_wizard_title')),
                content: Text(t('settings_relaunch_wizard_confirm')),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogCtx, false),
                    child: Text(t('cancel_btn')),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(dialogCtx, true),
                    child: Text(t('btn_continue')),
                  ),
                ],
              ),
            );
            if (confirm == true && buildContext.mounted) {
              final repo = ref.read(settingsRepositoryProvider);
              await repo.updateSettings(settings.copyWith(alarmWizardEnabled: true));
              ref.read(pairingNotifierProvider.notifier).disconnect();
              if (buildContext.mounted) {
                Navigator.of(buildContext).pushReplacement(
                  MaterialPageRoute(builder: (_) => const PairingScreen()),
                );
              }
            }
          },
        ),
        const Divider(),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.download_rounded, color: AppColors.primary),
          title: Text(t('settings_backup_title'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          subtitle: Text(t('settings_backup_desc'), style: const TextStyle(fontSize: 12)),
          trailing: Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
          onTap: () => _downloadBackup(),
        ),
        const Divider(),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.upload_rounded, color: AppColors.primary),
          title: Text(t('settings_restore_title'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          subtitle: Text(t('settings_restore_desc'), style: const TextStyle(fontSize: 12)),
          trailing: Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
          onTap: () => _restoreBackup(),
        ),
        const Divider(),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.delete_forever_rounded, color: AppColors.missed),
          title: Text(t('settings_reset_data_title'), style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.missed, fontSize: 14)),
          subtitle: Text(t('settings_reset_data_desc'), style: const TextStyle(fontSize: 12)),
          trailing: Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
          onTap: () async {
            final buildContext = context;
            final payload = await showDialog<Map<String, bool>>(
              context: buildContext,
              builder: (dialogCtx) => _DeviceResetDialog(onConfirm: (payload) {}),
            );

            if (payload == null) return;

            if (buildContext.mounted) {
              showDialog(
                context: buildContext,
                barrierDismissible: false,
                builder: (dialogCtx) => PopScope(
                  canPop: false,
                  child: AlertDialog(
                    content: Row(
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(width: 20),
                        Expanded(child: Text(t('settings_executing_reset'))),
                      ],
                    ),
                  ),
                ),
              );
            }

            final success = await ref
                .read(deviceResetNotifierProvider.notifier)
                .resetDevicePartitions(payload);

            if (buildContext.mounted) {
              Navigator.pop(buildContext);
            }

            if (success) {
              final needsReboot = payload['factory'] == true ||
                                  payload['wifi'] == true ||
                                  payload['settings'] == true ||
                                  payload['xiaozhi'] == true;
              final isWifiOrFactory = payload['factory'] == true || payload['wifi'] == true;

              if (needsReboot && buildContext.mounted) {
                _showRebootOverlay('${t('settings_reset_success_toast')}\n${t('reset_modal_warning_reboot')}', 8);
                if (isWifiOrFactory) {
                  await Future.delayed(const Duration(seconds: 8));
                  if (buildContext.mounted) {
                    Navigator.of(buildContext).pushReplacement(
                      MaterialPageRoute(builder: (_) => const PairingScreen()),
                    );
                  }
                }
              } else {
                if (buildContext.mounted) {
                  ScaffoldMessenger.of(buildContext).showSnackBar(
                    SnackBar(content: Text(t('settings_reset_success_toast')), backgroundColor: AppColors.success),
                  );
                }
                if (isWifiOrFactory && buildContext.mounted) {
                  Navigator.of(buildContext).pushReplacement(
                    MaterialPageRoute(builder: (_) => const PairingScreen()),
                  );
                }
              }
            }
          },
        ),
        const Divider(),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.restart_alt_rounded, color: AppColors.primary),
          title: Text(t('settings_reboot_device_title'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          subtitle: Text(t('settings_reboot_device_desc'), style: const TextStyle(fontSize: 12)),
          trailing: Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
          onTap: () async {
            final buildContext = context;
            final connState = ref.read(pairingNotifierProvider);
            if (connState.status != ConnectionStatus.connected) {
              ScaffoldMessenger.of(buildContext).showSnackBar(
                SnackBar(
                  content: Text(t('settings_device_offline_reboot_error')),
                  backgroundColor: AppColors.missed,
                ),
              );
              return;
            }
            final confirm = await showDialog<bool>(
              context: buildContext,
              builder: (dialogCtx) => AlertDialog(
                title: Text(t('settings_reboot_device_title')),
                content: Text(t('settings_reboot_device_confirm')),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogCtx, false),
                    child: Text(t('cancel_btn')),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(dialogCtx, true),
                    child: Text(t('btn_reboot')),
                  ),
                ],
              ),
            );
            if (confirm == true && buildContext.mounted) {
              _showRebootOverlay(t('settings_reset_rebooting').split('\n').last, 8);
              await ref.read(settingsRepositoryProvider).restartDevice();
            }
          },
        ),
      ],
    );
  }

  Widget _buildDeveloperFixtureCard() {
    final isLightTheme = ref.watch(appThemeNotifierProvider) == ThemeMode.light;
    return Card(
      color: isLightTheme ? AppColors.surface : AppColors.surfaceVariant.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bug_report_rounded, color: AppColors.missed),
                const SizedBox(width: 8),
                Text(
                  t('settings_offline_tests'),
                  style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.text),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              t('settings_fixture_desc'),
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            const SizedBox(height: 16),
            Center(
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _loadBackupFixture,
                icon: const Icon(Icons.file_download_rounded),
                label: Text(t('settings_fixture_btn')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.missed.withValues(alpha: 0.2),
                  foregroundColor: AppColors.missed,
                  side: BorderSide(color: AppColors.missed),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedStatusDot extends StatefulWidget {
  final Color color;
  final bool pulse;

  const _AnimatedStatusDot({required this.color, required this.pulse});

  @override
  State<_AnimatedStatusDot> createState() => _AnimatedStatusDotState();
}

class _AnimatedStatusDotState extends State<_AnimatedStatusDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    if (widget.pulse) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _AnimatedStatusDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pulse && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.pulse && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final scale = 1.0 + (_controller.value * 0.25);
        final opacity = 0.5 + ((1.0 - _controller.value) * 0.5);
        return Stack(
          alignment: Alignment.center,
          children: [
            if (widget.pulse)
              Container(
                width: 16 * scale,
                height: 16 * scale,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color.withValues(alpha: opacity * 0.4),
                ),
              ),
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.color,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _BackupRestoreKeysDialog extends StatefulWidget {
  final List<String> availableKeys;

  const _BackupRestoreKeysDialog({required this.availableKeys});

  @override
  State<_BackupRestoreKeysDialog> createState() => _BackupRestoreKeysDialogState();
}

class _BackupRestoreKeysDialogState extends State<_BackupRestoreKeysDialog> {
  final Map<String, bool> _selections = {};

  @override
  void initState() {
    super.initState();
    for (final key in widget.availableKeys) {
      _selections[key] = restoreKeysConfig[key]?['default'] ?? false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(t('settings_restore_title')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t('restore_modal_desc')),
            const SizedBox(height: 12),
            ...widget.availableKeys.map((key) {
              final label = _getPartitionLabel(key);
              return CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(label),
                value: _selections[key],
                onChanged: (val) {
                  setState(() {
                    _selections[key] = val ?? false;
                  });
                },
              );
            }),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(t('cancel_btn')),
        ),
        TextButton(
          onPressed: _selections.containsValue(true)
              ? () => Navigator.pop(
                    context,
                    _selections.entries.where((e) => e.value).map((e) => e.key).toList(),
                  )
              : null,
          child: Text(t('settings_restore_title')),
        ),
      ],
    );
  }

  String _getPartitionLabel(String key) {
    switch (key) {
      case 'alarms': return t('restore_alarms');
      case 'reminders': return t('restore_reminders');
      case 'meds': return t('restore_meds');
      case 'logs': return t('reset_logs_label');
      case 'history': return t('restore_history');
      case 'chat':
      case 'chat_history': return t('restore_chat_history');
      case 'settings': return t('restore_settings');
      case 'wifi': return t('restore_wifi');
      case 'xiaozhi': return t('restore_xiaozhi');
      default: return key;
    }
  }
}

class _DeviceResetDialog extends StatefulWidget {
  final Function(Map<String, bool> payload) onConfirm;

  const _DeviceResetDialog({required this.onConfirm});

  @override
  State<_DeviceResetDialog> createState() => _DeviceResetDialogState();
}

class _DeviceResetDialogState extends State<_DeviceResetDialog> {
  final _confirmController = TextEditingController();
  bool _isFactoryReset = false;

  final Map<String, bool> _partitions = {
    'alarms': false,
    'reminders': false,
    'meds': false,
    'logs': false,
    'history': false,
    'chat': false,
    'settings': false,
    'wifi': false,
    'xiaozhi': false,
  };

  @override
  void dispose() {
    _confirmController.dispose();
    super.dispose();
  }

  void _onFactoryResetChanged(bool? val) {
    setState(() {
      _isFactoryReset = val ?? false;
      if (_isFactoryReset) {
        _partitions.updateAll((key, value) => true);
      } else {
        _partitions.updateAll((key, value) => false);
      }
    });
  }

  bool get _isValidConfirmation => _confirmController.text.trim().toUpperCase() == t('reset_modal_confirm_word').toUpperCase();

  bool get _hasSelection => _isFactoryReset || _partitions.containsValue(true);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.red),
          const SizedBox(width: 8),
          Text(t('settings_reset_data_title'), style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              t('reset_modal_desc'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(t('reset_factory_label'), style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              value: _isFactoryReset,
              onChanged: _onFactoryResetChanged,
              activeColor: Colors.red,
            ),
            const Divider(),
            ..._partitions.keys.map((key) {
              final labelName = _getPartitionLabel(key);
              return CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(labelName),
                value: _partitions[key],
                onChanged: _isFactoryReset
                    ? null
                    : (val) {
                        setState(() {
                          _partitions[key] = val ?? false;
                        });
                      },
              );
            }),
            const SizedBox(height: 16),
            Text(t('reset_modal_confirm_phrase').replaceAll('<b>', '').replaceAll('</b>', '')),
            const SizedBox(height: 8),
            TextField(
              controller: _confirmController,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                hintText: t('reset_modal_confirm_phrase').replaceAll('<b>', '').replaceAll('</b>', '').replaceAll(':', ''),
              ),
              inputFormatters: [
                UpperCaseTextFormatter(),
              ],
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t('cancel_btn')),
        ),
        ElevatedButton(
          onPressed: (_hasSelection && _isValidConfirmation)
              ? () {
                  final payload = <String, bool>{
                    'factory': _isFactoryReset,
                    ..._partitions,
                  };
                  Navigator.of(context).pop(payload);
                }
              : null,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
          child: Text(t('reset_confirm_btn')),
        ),
      ],
    );
  }

  String _getPartitionLabel(String key) {
    switch (key) {
      case 'alarms': return t('restore_alarms');
      case 'reminders': return t('restore_reminders');
      case 'meds': return t('restore_meds');
      case 'logs': return t('reset_logs_label');
      case 'history': return t('restore_history');
      case 'chat': return t('restore_chat_history');
      case 'settings': return t('restore_settings');
      case 'wifi': return t('restore_wifi');
      case 'xiaozhi': return t('restore_xiaozhi');
      default: return key;
    }
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
