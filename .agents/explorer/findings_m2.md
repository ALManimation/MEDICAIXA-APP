# Architectural Design & Integration Specification — Milestone 2

This document details the data layer, repository structure, presentation layouts, and state management rules for Clock Sync, Voice Assistant, and Device Maintenance. This design bridges the gap between the Flutter application and the C++ hardware box (`MediCaixa`) endpoints.

---

## 1. Package Dependencies Setup
To implement these features, the following packages should be added to `pubspec.yaml` (in addition to existing `path_provider`):
- **`file_picker`**: For picking the backup `.json` file from local storage.
- **`share_plus`**: For triggering the native share sheet to export/download the backup on mobile and desktop platforms.
- **`flutter/services.dart`** (SDK standard): For clipboard copying support (`Clipboard.setData`).

---

## 2. Feature 1: Clock Sync

### A. Endpoints & Payloads
- **Fetch Time**: `GET /server_time`
  - *Response Schema (JSON)*:
    ```json
    {
      "year": 2026,
      "month": 6,
      "day": 28,
      "hour": 11,
      "minute": 10,
      "second": 51
    }
    ```
- **Set Time**: `POST /set_datetime`
  - *Request Schema (JSON)*:
    ```json
    {
      "year": 2026,
      "month": 6,
      "day": 28,
      "hour": 11,
      "minute": 10,
      "second": 51
    }
    ```
  - *Response Schema*: Plain text `"OK"`

### B. Class Structure (Data Layer)
Define the model `DeviceDateTime` inside `lib/features/settings/data/models/device_date_time.dart` to deserialize/serialize time data.

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'device_date_time.freezed.dart';
part 'device_date_time.g.dart';

@freezed
class DeviceDateTime with _$DeviceDateTime {
  const factory DeviceDateTime({
    required int year,
    required int month,
    required int day,
    required int hour,
    required int minute,
    required int second,
  }) = _DeviceDateTime;

  factory DeviceDateTime.fromJson(Map<String, dynamic> json) =>
      _$DeviceDateTimeFromJson(json);

  // Helper conversion to Dart's DateTime
  const DeviceDateTime._();
  DateTime toDateTime() => DateTime(year, month, day, hour, minute, second);

  // Helper conversion from Dart's DateTime
  factory DeviceDateTime.fromDateTime(DateTime dt) {
    return DeviceDateTime(
      year: dt.year,
      month: dt.month,
      day: dt.day,
      hour: dt.hour,
      minute: dt.minute,
      second: dt.second,
    );
  }
}
```

### C. Repository & API Client Additions
In `SettingsRepository` (or a dedicated `DeviceSettingsRepository`), append the following methods:

```dart
class SettingsRepository {
  // ... existing fields and methods ...

  Future<DeviceDateTime> fetchDeviceTime() async {
    if (!_isConnected()) {
      throw Exception('Dispositivo desconectado');
    }
    final response = await _dioClient.get('/server_time');
    if (response.statusCode == 200 && response.data is Map) {
      return DeviceDateTime.fromJson(response.data as Map<String, dynamic>);
    }
    throw Exception('Falha ao obter horário do dispositivo');
  }

  Future<void> updateDeviceTime(DeviceDateTime deviceTime) async {
    if (!_isConnected()) {
      throw Exception('Dispositivo desconectado');
    }
    final response = await _dioClient.post(
      '/set_datetime',
      data: deviceTime.toJson(),
    );
    if (response.statusCode != 200) {
      throw Exception('Erro ao definir horário no dispositivo');
    }
  }
}
```

### D. Riverpod State Management
```dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../data/settings_repository.dart';
import '../data/models/device_date_time.dart';

part 'device_time_notifier.g.dart';

@riverpod
class DeviceTimeNotifier extends _$DeviceTimeNotifier {
  @override
  FutureOr<DeviceDateTime?> build() async {
    final isConnected = ref.watch(pairingNotifierProvider).status == ConnectionStatus.connected;
    if (!isConnected) return null;
    return ref.read(settingsRepositoryProvider).fetchDeviceTime();
  }

  Future<void> syncWithPhoneTime() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final now = DateTime.now();
      final deviceTime = DeviceDateTime.fromDateTime(now);
      await ref.read(settingsRepositoryProvider).updateDeviceTime(deviceTime);
      return deviceTime;
    });
  }

  Future<void> setManualDateTime(DateTime selectedDateTime) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final deviceTime = DeviceDateTime.fromDateTime(selectedDateTime);
      await ref.read(settingsRepositoryProvider).updateDeviceTime(deviceTime);
      return deviceTime;
    });
  }

  Future<void> refreshTime() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => ref.read(settingsRepositoryProvider).fetchDeviceTime());
  }
}
```

### E. Presentation / Pickers Layout
Render the current device time and trigger date/time pickers in a dedicated `Card` within `settings_screen.dart`:

1. **State Subscription**:
   `final deviceTimeAsync = ref.watch(deviceTimeNotifierProvider);`
2. **Display & Actions Widget**:
   ```dart
   Card(
     child: Padding(
       padding: const EdgeInsets.all(16.0),
       child: Column(
         crossAxisAlignment: CrossAxisAlignment.start,
         children: [
           const Text('Sincronização de Relógio (RTC)', style: TextStyle(fontWeight: FontWeight.bold)),
           const SizedBox(height: 12),
           deviceTimeAsync.when(
             data: (deviceTime) {
               if (deviceTime == null) {
                 return const Text('Indisponível no modo offline', style: TextStyle(color: AppColors.textMuted));
               }
               final formatted = "${deviceTime.day.toString().padLeft(2, '0')}/${deviceTime.month.toString().padLeft(2, '0')}/${deviceTime.year} "
                                 "${deviceTime.hour.toString().padLeft(2, '0')}:${deviceTime.minute.toString().padLeft(2, '0')}:${deviceTime.second.toString().padLeft(2, '0')}";
               return Text('Hora na Medicaixa: $formatted', style: const TextStyle(fontSize: 16, color: Colors.white));
             },
             loading: () => const CircularProgressIndicator(),
             error: (err, stack) => Text('Erro ao carregar: $err', style: const TextStyle(color: Colors.red)),
           ),
           const SizedBox(height: 16),
           Row(
             children: [
               Expanded(
                 child: ElevatedButton.icon(
                   onPressed: () => ref.read(deviceTimeNotifierProvider.notifier).syncWithPhoneTime(),
                   icon: const Icon(Icons.sync_rounded),
                   label: const Text('Sincronizar Celular'),
                 ),
               ),
               const SizedBox(width: 12),
               Expanded(
                 child: ElevatedButton.icon(
                   onPressed: () async {
                     final now = DateTime.now();
                     final date = await showDatePicker(
                       context: context,
                       initialDate: now,
                       firstDate: DateTime(2025),
                       lastDate: DateTime(2035),
                     );
                     if (date != null && context.mounted) {
                       final time = await showTimePicker(
                         context: context,
                         initialTime: TimeOfDay.now(),
                       );
                       if (time != null) {
                         final combined = DateTime(date.year, date.month, date.day, time.hour, time.minute);
                         ref.read(deviceTimeNotifierProvider.notifier).setManualDateTime(combined);
                       }
                     }
                   },
                   icon: const Icon(Icons.edit_calendar_rounded),
                   label: const Text('Ajuste Manual'),
                 ),
               ),
             ],
           ),
         ],
       ),
     ),
   );
   ```

---

## 3. Feature 2: Voice Assistant Status Monitor

### A. Endpoint & Payload
- **Fetch Status**: `GET /voice_status`
  - *Response Schema (JSON)*:
    ```json
    {
      "state": "desconectado|conectando|conectado|ouvindo|pensando|falando|erro|não inicializado",
      "connected": true,
      "activation_code": "ACTIVATION_KEY",
      "has_credentials": true,
      "wake_word": "jarvis"
    }
    ```

### B. Class Structure (Domain & Data Layer)
Map the response text to a structured Dart model and enum.

```dart
enum VoiceState {
  disconnected,
  connecting,
  connected,
  listening,
  thinking,
  speaking,
  error,
  uninitialized;

  static VoiceState fromString(String raw) {
    switch (raw.toLowerCase()) {
      case 'conectando':
        return VoiceState.connecting;
      case 'conectado':
        return VoiceState.connected;
      case 'ouvindo':
        return VoiceState.listening;
      case 'pensando':
        return VoiceState.thinking;
      case 'falando':
        return VoiceState.speaking;
      case 'erro':
        return VoiceState.error;
      case 'não inicializado':
      case 'nao inicializado':
        return VoiceState.uninitialized;
      case 'desconectado':
      default:
        return VoiceState.disconnected;
    }
  }

  String get label {
    switch (this) {
      case VoiceState.connecting:
        return 'Conectando...';
      case VoiceState.connected:
        return 'Conectado';
      case VoiceState.listening:
        return 'Ouvindo...';
      case VoiceState.thinking:
        return 'Pensando...';
      case VoiceState.speaking:
        return 'Falando...';
      case VoiceState.error:
        return 'Erro de Conexão';
      case VoiceState.uninitialized:
        return 'Não Inicializado';
      case VoiceState.disconnected:
      default:
        return 'Desconectado';
    }
  }
}

class VoiceStatus {
  final VoiceState state;
  final bool connected;
  final String activationCode;
  final bool hasCredentials;
  final String wakeWord;

  VoiceStatus({
    required this.state,
    required this.connected,
    required this.activationCode,
    required this.hasCredentials,
    required this.wakeWord,
  });

  factory VoiceStatus.fromJson(Map<String, dynamic> json) {
    return VoiceStatus(
      state: VoiceState.fromString(json['state']?.toString() ?? 'desconectado'),
      connected: json['connected'] == true,
      activationCode: json['activation_code']?.toString() ?? '',
      hasCredentials: json['has_credentials'] == true,
      wakeWord: json['wake_word']?.toString() ?? 'sophia',
    );
  }
}
```

### C. Periodical Polling with Riverpod StreamProvider
By utilizing a Riverpod `StreamProvider.autoDispose`, we trigger automatic, periodic fetching (every 5 seconds) as long as the widget is active. Once the Settings screen is disposed or popped, the subscription ceases, avoiding unnecessary load on both the cellular/wifi interface and the ESP32.

```dart
@riverpod
Stream<VoiceStatus?> voiceStatusStream(VoiceStatusStreamRef ref) async* {
  final settingsRepo = ref.watch(settingsRepositoryProvider);
  final isConnected = ref.watch(pairingNotifierProvider).status == ConnectionStatus.connected;

  if (!isConnected) {
    yield null; // Offline mode yields null status
    return;
  }

  while (true) {
    try {
      final response = await ref.read(dioClientProvider).get('/voice_status');
      if (response.statusCode == 200 && response.data is Map) {
        yield VoiceStatus.fromJson(response.data as Map<String, dynamic>);
      }
    } catch (e) {
      yield VoiceStatus(
        state: VoiceState.error,
        connected: false,
        activationCode: '',
        hasCredentials: false,
        wakeWord: 'sophia',
      );
    }
    await Future.delayed(const Duration(seconds: 5));
  }
}
```

### D. Presentation Widget & Status Dot Color Logic
Render color dots, pulse animation on connecting, and activation code card:

```dart
class VoiceAssistantStatusWidget extends ConsumerWidget {
  const VoiceAssistantStatusWidget({super.key});

  Color _getStatusColor(VoiceState state) {
    switch (state) {
      case VoiceState.connected:
        return const Color(0xFF10B981); // Green
      case VoiceState.connecting:
        return const Color(0xFFF59E0B); // Yellow/Amber
      case VoiceState.listening:
        return const Color(0xFF3B82F6); // Blue
      case VoiceState.thinking:
        return const Color(0xFF8B5CF6); // Purple
      case VoiceState.speaking:
        return const Color(0xFF06B6D4); // Cyan
      case VoiceState.error:
        return const Color(0xFFEF4444); // Red
      case VoiceState.disconnected:
      case VoiceState.uninitialized:
      default:
        return const Color(0xFF9CA3AF); // Grey
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(voiceStatusStreamProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: statusAsync.when(
          data: (status) {
            if (status == null) {
              return const Text('Modo Standalone (Sem Assistente de Voz)', style: TextStyle(color: AppColors.textMuted));
            }
            final isConnecting = status.state == VoiceState.connecting;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Status do Assistente de Voz', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    // Status Dot Indicator
                    _AnimatedStatusDot(
                      color: _getStatusColor(status.state),
                      pulse: isConnecting,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(status.state.label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Text('Palavra de Ativação: ${status.wakeWord}', style: const TextStyle(color: AppColors.textMuted)),
                        ],
                      ),
                    ),
                  ],
                ),
                if (status.activationCode.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _buildActivationCodeCard(context, status.activationCode),
                ],
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Text('Erro ao obter status de voz: $err', style: const TextStyle(color: Colors.red)),
        ),
      ),
    );
  }

  Widget _buildActivationCodeCard(BuildContext context, String code) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Código de Ativação do Assistente', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.between,
            children: [
              SelectableText(
                code,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: AppColors.primary),
              ),
              IconButton(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: code));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Código copiado para a área de transferência!'), backgroundColor: AppColors.success),
                  );
                },
                icon: const Icon(Icons.copy_rounded, color: AppColors.primary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Custom animated pulse dot for connecting state
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
                  color: widget.color.withOpacity(opacity * 0.4),
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
```

---

## 4. Feature 3: Maintenance Suite

### A. Onboarding Reset Flow
Lets the user reset the application's wizard status and saved configurations locally so they can run the pairing/configuration checklist again.
1. **Local Settings Update**:
   - Updates `Setting` row field `alarmWizardEnabled` to `true` (or sets a dedicated onboarding complete flag).
   - Wipes saved device IP from configuration database.
   - Triggers `ref.read(pairingNotifierProvider.notifier).disconnect();` to transition Riverpod status to standalone/disconnected.
2. **Navigation**:
   - Re-routes the application shell to the `PairingScreen` to enforce onboarding step-by-step setup.

### B. Download / Export Backup (`GET /backup`)
Sends request to `GET /backup` to obtain the ESP32 backup payload, then handles sharing/saving cross-platform.

#### Data Fetching Method:
```dart
Future<String> downloadBackupJson() async {
  if (!_isConnected()) throw Exception('Dispositivo offline');
  final response = await _dioClient.get('/backup');
  if (response.statusCode == 200) {
    // Check if response is a Map or String and normalize to JSON string format
    if (response.data is Map) {
      return jsonEncode(response.data);
    }
    return response.data.toString();
  }
  throw Exception('Falha ao baixar backup');
}
```

#### Flutter File Save/Share Handler:
```dart
Future<void> handleBackupDownload(BuildContext context, WidgetRef ref) async {
  try {
    final backupStr = await ref.read(settingsRepositoryProvider).downloadBackupJson();
    
    if (kIsWeb) {
      // Direct web download trigger (unsupported or falls back to desktop)
      return;
    }

    final bytes = utf8.encode(backupStr);
    
    if (Platform.isMacOS) {
      // macOS File Picker save dialog
      final outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Salvar Backup Medicaixa',
        fileName: 'medicaixa_backup.json',
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (outputFile != null) {
        final file = File(outputFile);
        await file.writeAsBytes(bytes);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Backup salvo com sucesso!'), backgroundColor: AppColors.success),
          );
        }
      }
    } else {
      // Mobile platform (Android & iOS) Share sheet
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/medicaixa_backup.json');
      await file.writeAsBytes(bytes);
      
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/json')],
        subject: 'Backup Medicaixa',
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao exportar backup: $e'), backgroundColor: Colors.red),
      );
    }
  }
}
```

### C. Partial Restore Backup Picker & Upload (`POST /restore`)
Uses `file_picker` to read a local backup JSON file, presents checkable restoration partition keys, constructs a partial backup map, sends it to `POST /restore`, and triggers a restart sequence if necessary.

#### Restore Keys Metadata:
```dart
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
```

#### Upload Endpoint Logic:
```dart
Future<int> executeBackupRestore(Map<String, dynamic> partialBackup) async {
  if (!_isConnected()) throw Exception('Dispositivo offline');
  final response = await _dioClient.post(
    '/restore',
    data: partialBackup,
  );
  if (response.statusCode == 200 && response.data is Map) {
    final data = response.data as Map;
    return (data['restored_files'] as num?)?.toInt() ?? 0;
  }
  throw Exception('Restauração falhou no dispositivo');
}

Future<void> restartDevice() async {
  await _dioClient.post('/restart');
}
```

#### Selection Picker Dialog Flow (UI):
1. **File Selection**:
   ```dart
   FilePickerResult? result = await FilePicker.platform.pickFiles(
     type: FileType.custom,
     allowedExtensions: ['json'],
   );
   if (result == null) return;
   final file = File(result.files.single.path!);
   final content = await file.readAsString();
   final rawMap = jsonDecode(content) as Map<String, dynamic>;
   ```
2. **Display Selection Dialog**:
   Present a checkbox list of elements present in the parsed map:
   `rawMap.containsKey(key)`
3. **Execute and Restart Loading Dialog**:
   - Filters `rawMap` down to selected keys.
   - Shows blocking circular progress dialog stating: `"Restaurando dados..."`.
   - Sends filtered JSON to repository.
   - If any selected key triggers `restart: true` (like `xiaozhi`), the spinner overlay switches to `"Reiniciando Medicaixa..."` and blocks UI for 8 seconds, calling `restartDevice()`. Then calls `location.reload` / pushes Settings screen again.

---

## 5. Device Reset & Factory Reset Dialog

### A. Endpoint & Payload
- **Call**: `POST /reset`
  - *Request Payload (JSON)*:
    ```json
    {
      "factory": false,
      "alarms": true,
      "reminders": false,
      "meds": false,
      "logs": false,
      "history": false,
      "chat": false,
      "settings": false,
      "wifi": false,
      "xiaozhi": false
    }
    ```
  - *Response Schema*: Plain text `"OK"`

### B. "APAGAR" Validation & Factory Reset Logic
To guarantee security against accidental clicks, a confirmation dialog layout with uppercase string matching is structured as follows.

```dart
class DeviceResetDialog extends StatefulWidget {
  final VoidCallback onResetConfirmed;

  const DeviceResetDialog({super.key, required this.onResetConfirmed});

  @override
  State<DeviceResetDialog> createState() => _DeviceResetDialogState();
}

class _DeviceResetDialogState extends State<DeviceResetDialog> {
  final _confirmController = TextEditingController();
  bool _isFactoryReset = false;
  
  // Set partition targets
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
        // Checking all and disabling selection
        _partitions.updateAll((key, value) => true);
      } else {
        _partitions.updateAll((key, value) => false);
      }
    });
  }

  bool get _isValidConfirmation => _confirmController.text.trim().toUpperCase() == 'APAGAR';

  bool get _hasSelection => _isFactoryReset || _partitions.containsValue(true);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.red),
          SizedBox(width: 8),
          Text('Resetar Medicaixa', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Atenção! Esta ação apagará permanentemente os dados selecionados do dispositivo físico.',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            // Factory Reset Checkbox
            CheckboxListTile(
              title: const Text('RESET DE FÁBRICA (Tudo)', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              value: _isFactoryReset,
              onChanged: _onFactoryResetChanged,
              activeColor: Colors.red,
            ),
            const Divider(),
            // Partition Grid/List
            ..._partitions.keys.map((key) {
              final labelName = _getPartitionLabel(key);
              return CheckboxListTile(
                title: Text(labelName),
                value: _partitions[key],
                onChanged: _isFactoryReset
                    ? null // Disabled if Factory reset is checked
                    : (val) {
                        setState(() {
                          _partitions[key] = val ?? false;
                        });
                      },
              );
            }),
            const SizedBox(height: 16),
            const Text('Digite APAGAR abaixo para confirmar o procedimento:'),
            const SizedBox(height: 8),
            TextField(
              controller: _confirmController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Digite APAGAR',
              ),
              inputFormatters: [
                UpperCaseTextFormatter(), // Force uppercase characters in textfield
              ],
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: (_hasSelection && _isValidConfirmation)
              ? () {
                  Navigator.of(context).pop();
                  _executeReset();
                }
              : null,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
          child: const Text('Confirmar e Apagar'),
        ),
      ],
    );
  }

  String _getPartitionLabel(String key) {
    switch (key) {
      case 'alarms': return 'Alarmes';
      case 'reminders': return 'Lembretes';
      case 'meds': return 'Medicamentos';
      case 'logs': return 'Logs de Dose';
      case 'history': return 'Histórico Médico';
      case 'chat': return 'Histórico do Chat';
      case 'settings': return 'Ajustes Gerais';
      case 'wifi': return 'Rede Wi-Fi';
      case 'xiaozhi': return 'Configurações de Voz';
      default: return key;
    }
  }

  void _executeReset() {
    final payload = <String, bool>{
      'factory': _isFactoryReset,
      ..._partitions,
    };
    // Dispatch network request via provider:
    // ref.read(deviceResetProvider.notifier).reset(payload);
  }
}

// TextInputFormatter to auto-convert inputs to uppercase
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
```

### C. Reset State Provider (Riverpod)
Manages the loading/rebooting state overlays after executing the reset trigger.

```dart
@riverpod
class DeviceResetNotifier extends _$DeviceResetNotifier {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  Future<void> resetDevicePartitions(Map<String, bool> payload) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final response = await ref.read(dioClientProvider).post(
        '/reset',
        data: payload,
      );
      if (response.statusCode != 200) {
        throw Exception('Falha ao resetar partições no dispositivo');
      }

      // Check if reboot is needed based on selected components
      final needsReboot = payload['factory'] == true ||
                          payload['wifi'] == true ||
                          payload['settings'] == true ||
                          payload['xiaozhi'] == true;
      
      if (needsReboot) {
        // Trigger restart endpoint
        await ref.read(dioClientProvider).post('/restart').catchError((_) => null);
        
        // Wait 8 seconds to allow ESP32 to restart and enter Access Point mode
        await Future.delayed(const Duration(seconds: 8));

        // If Wi-Fi or factory was erased, we lose connection, so wipe IP and redirect
        if (payload['factory'] == true || payload['wifi'] == true) {
          await ref.read(pairingNotifierProvider.notifier).useStandalone();
        }
      }
    });
  }
}
```

Whenever `DeviceResetNotifier` transitions to loading, the presentation layer displays a full-screen loading overlay (`reboot-overlay` equivalent) using an `AnimatedDialog` with details matching the current action.
