import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/database/database.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/providers/locale_provider.dart';
import '../../pairing/domain/connection_state.dart';
import '../../pairing/presentation/pairing_notifier.dart';
import '../../pairing/presentation/pairing_screen.dart';
import '../../dashboard/presentation/dashboard_notifier.dart';
import '../data/settings_repository.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _nameController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _saveName(Setting currentSettings) async {
    final newName = _nameController.text.trim();
    if (newName.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    final repo = ref.read(settingsRepositoryProvider);
    await repo.updatePatientName(newName);

    setState(() {
      _isLoading = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nome do paciente salvo!'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  void _loadBackupFixture() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final jsonContent = await rootBundle.loadString('test/fixtures/sample_backup.json');
      await ref.read(dashboardNotifierProvider.notifier).loadSampleData(jsonContent);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Backup de teste carregado com 25 alarmes e 6 lembretes! 🎉'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar fixture: $e'),
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

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseProvider);
    final repo = ref.read(settingsRepositoryProvider);
    final connState = ref.watch(pairingNotifierProvider);
    final currentLocale = ref.watch(appLocaleProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurações'),
      ),
      body: StreamBuilder<Setting?>(
        stream: db.select(db.settings).watchSingleOrNull(),
        builder: (context, snapshot) {
          final settings = snapshot.data;
          if (settings == null) {
            return const Center(child: CircularProgressIndicator());
          }

          if (_nameController.text.isEmpty && settings.patientName.isNotEmpty) {
            _nameController.text = settings.patientName;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Patient Name Section
                _buildSectionHeader('Dados do Paciente'),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        TextField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Nome do Paciente',
                            hintText: 'Ex: Carolina',
                            border: OutlineInputBorder(),
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
                            child: const Text('Salvar Nome'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Hardware adjustments (Volume & Brilho)
                _buildSectionHeader('Ajustes da MediCaixa'),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
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
                                    'Volume do Alto-falante: ${settings.speakerVolume}%',
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
                                    'Brilho do Display OLED: ${settings.brightness}%',
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
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Language selection
                _buildSectionHeader('Idioma do Aplicativo'),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Selecione a linguagem:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(value: 'pt', label: Text('Português')),
                              ButtonSegment(value: 'en', label: Text('English')),
                              ButtonSegment(value: 'es', label: Text('Español')),
                            ],
                            selected: {currentLocale},
                            onSelectionChanged: (newSelection) async {
                              final code = newSelection.first;
                              await ref.read(appLocaleProvider.notifier).changeLocale(code);
                              await repo.updateSettings(settings.copyWith(language: code));
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Connection status
                _buildSectionHeader('Conexão com MediCaixa'),
                const SizedBox(height: 8),
                Card(
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
                                ? 'Conectado via rede local'
                                : 'Modo Standalone (Desconectado)',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            connState.status == ConnectionStatus.connected
                                ? 'Endereço IP: ${connState.ip}\nFirmware: ${connState.firmwareVersion}'
                                : 'O app está salvando tudo localmente no SQLite.',
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
                                  ? 'Alterar Caixinha / Parear'
                                  : 'Conectar com MediCaixa',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Developer Options
                _buildSectionHeader('Opções de Desenvolvedor'),
                const SizedBox(height: 8),
                Card(
                  color: AppColors.surfaceVariant.withOpacity(0.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: AppColors.border),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.bug_report_rounded, color: AppColors.missed),
                            SizedBox(width: 8),
                            Text(
                              'Testes Offline (Fixture)',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Carregue a fixture com 25 alarmes e 6 lembretes reais para testar a interface com volume realista de dados.',
                          style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                        ),
                        const SizedBox(height: 16),
                        Center(
                          child: ElevatedButton.icon(
                            onPressed: _isLoading ? null : _loadBackupFixture,
                            icon: const Icon(Icons.file_download_rounded),
                            label: const Text('Carregar 25 Alarmes + 6 Lembretes'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.missed.withOpacity(0.2),
                              foregroundColor: Colors.white,
                              side: BorderSide(color: AppColors.missed),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}
