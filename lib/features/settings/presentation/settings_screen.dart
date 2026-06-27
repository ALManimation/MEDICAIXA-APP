import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;
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
  final _geminiKeyController = TextEditingController();
  bool _showGeminiKey = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _geminiKeyController.dispose();
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
    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: AppColors.surface,
              onSurface: AppColors.text,
            ),
          ),
          child: child!,
        );
      },
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

  List<Map<String, String>> _getProhibitedRanges(Setting settings) {
    if (settings.prohibitedRanges == null) return [];
    try {
      final decoded = json.decode(settings.prohibitedRanges!) as List;
      return decoded.map((e) => Map<String, String>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _addProhibitedRange(Setting settings, String from, String to) async {
    final ranges = _getProhibitedRanges(settings);
    final exists = ranges.any((r) => r['from'] == from && r['to'] == to);
    if (exists) return;
    
    ranges.add({'from': from, 'to': to});
    final repo = ref.read(settingsRepositoryProvider);
    final updated = settings.copyWith(prohibitedRanges: Value(json.encode(ranges)));
    await repo.updateSettings(updated);
  }

  Future<void> _removeProhibitedRange(Setting settings, int index) async {
    final ranges = _getProhibitedRanges(settings);
    if (index < 0 || index >= ranges.length) return;
    ranges.removeAt(index);
    final repo = ref.read(settingsRepositoryProvider);
    final updated = settings.copyWith(prohibitedRanges: Value(json.encode(ranges)));
    await repo.updateSettings(updated);
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
          if (_geminiKeyController.text.isEmpty && settings.geminiApiKey != null) {
            _geminiKeyController.text = settings.geminiApiKey!;
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

                // Sleep & Meals Section
                _buildSectionHeader('Cronograma de Sono & Refeições'),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Sleep Schedule Switch
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'Cronograma de Sono',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: const Text('Silencia ou ajusta notificações de alarmes durante o sono'),
                          value: settings.sleepScheduleEnabled,
                          activeColor: AppColors.primary,
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
                                  title: const Text('Dormir', style: TextStyle(fontSize: 14, color: AppColors.textMuted)),
                                  subtitle: Text(
                                    settings.sleepTime ?? 'Não definido',
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                  trailing: const Icon(Icons.access_time_rounded, color: AppColors.primary),
                                  onTap: () => _selectTime(context, settings, 'sleepTime', settings.sleepTime),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Acordar', style: TextStyle(fontSize: 14, color: AppColors.textMuted)),
                                  subtitle: Text(
                                    settings.wakeTime ?? 'Não definido',
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                  trailing: const Icon(Icons.access_time_rounded, color: AppColors.primary),
                                  onTap: () => _selectTime(context, settings, 'wakeTime', settings.wakeTime),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const Divider(),
                        const SizedBox(height: 8),
                        const Text(
                          'Horários das Refeições',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Balizam os atalhos "Antes do café", "Depois do almoço", etc. no alarme.',
                          style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            // Café
                            Expanded(
                              child: ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Café da Manhã', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                                subtitle: Text(
                                  settings.breakfastTime ?? '08:00',
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                                trailing: const Icon(Icons.coffee_rounded, size: 18, color: AppColors.primary),
                                onTap: () => _selectTime(context, settings, 'breakfastTime', settings.breakfastTime ?? '08:00'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Almoço
                            Expanded(
                              child: ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Almoço', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                                subtitle: Text(
                                  settings.lunchTime ?? '12:00',
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                                trailing: const Icon(Icons.restaurant_rounded, size: 18, color: AppColors.primary),
                                onTap: () => _selectTime(context, settings, 'lunchTime', settings.lunchTime ?? '12:00'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Jantar
                            Expanded(
                              child: ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Jantar', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                                subtitle: Text(
                                  settings.dinnerTime ?? '20:00',
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                                trailing: const Icon(Icons.dinner_dining_rounded, size: 18, color: AppColors.primary),
                                onTap: () => _selectTime(context, settings, 'dinnerTime', settings.dinnerTime ?? '20:00'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Voice Assistant Section
                _buildSectionHeader('Assistente de Voz & IA'),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Palavra de Ativação (Wake Word)',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Center(
                          child: DropdownButtonFormField<String>(
                            value: settings.wakeWord,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            dropdownColor: AppColors.surface,
                            style: const TextStyle(color: Colors.white, fontSize: 16),
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
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Chave de API do Gemini',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Necessária para a conversa por voz da caixinha com IA funcionar.',
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
                                  labelText: 'Gemini API Key',
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
                                  const SnackBar(
                                    content: Text('Chave API salva com sucesso!'),
                                    backgroundColor: AppColors.success,
                                  ),
                                );
                              },
                              child: const Text('Salvar'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Prohibited Ranges Section
                _buildSectionHeader('Faixas Horárias Proibidas'),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Bloquear Horários de Alarmes',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Evita que alarmes toquem nesses períodos. Ex: reuniões diárias ou descanso.',
                          style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                        ),
                        const SizedBox(height: 16),
                        
                        // List of ranges
                        () {
                          final ranges = _getProhibitedRanges(settings);
                          if (ranges.isEmpty) {
                            return Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                color: AppColors.background.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Center(
                                child: Text(
                                  'Nenhuma faixa de bloqueio ativa',
                                  style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                                ),
                              ),
                            );
                          }
                          return ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: ranges.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final range = ranges[index];
                              final from = range['from'] ?? '';
                              final to = range['to'] ?? '';
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceVariant.withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.block_rounded, color: AppColors.missed, size: 16),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Bloqueio: De $from até $to',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                        ),
                                      ],
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_rounded, color: AppColors.missed, size: 20),
                                      onPressed: () => _removeProhibitedRange(settings, index),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        }(),
                        
                        const SizedBox(height: 16),
                        Center(
                          child: TextButton.icon(
                            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Adicionar Novo Bloqueio'),
                            onPressed: () async {
                              final fromTime = await showTimePicker(
                                context: context,
                                initialTime: const TimeOfDay(hour: 12, minute: 0),
                                helpText: 'HORÁRIO DE INÍCIO DO BLOQUEIO',
                              );
                              if (fromTime == null) return;
                              
                              if (!context.mounted) return;
                              final toTime = await showTimePicker(
                                context: context,
                                initialTime: const TimeOfDay(hour: 13, minute: 0),
                                helpText: 'HORÁRIO DE FIM DO BLOQUEIO',
                              );
                              if (toTime == null) return;
                              
                              final fromStr = _formatTimeOfDay(fromTime);
                              final toStr = _formatTimeOfDay(toTime);
                              await _addProhibitedRange(settings, fromStr, toStr);
                            },
                          ),
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
