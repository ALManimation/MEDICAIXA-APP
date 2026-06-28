# Settings Screen UI Reorganization Design

This document details the architectural layout, connection state guard, and presentation recommendations for reorganizing the Settings Screen (`lib/features/settings/presentation/settings_screen.dart`).

---

## 1. Local Settings ("Ajustes Locais") vs. Device Settings ("Ajustes da Caixinha")

The settings will be split into two main sections using clear visually-distinct group headers.

### A. Ajustes Locais (Local/App Configuration)
These configurations control the local mobile app's behavior, data, or patient data stored in the local Drift SQLite database. They operate normally in standalone (offline) mode.
*   **Dados do Paciente (Patient Profile Card)**:
    *   Text Field: Patient Name (e.g., "Carolina").
    *   Action: Saves to the local settings table (and queues for sync if online).
*   **Rotinas de Horários Úteis (Meal & Sleep Times)**:
    *   Useful routine timings (Wake, Sleep, Breakfast, Lunch, Dinner).
    *   Action: Used to pre-calculate quick alarms in the creation wizard.
*   **Configurações do App (App Customization Card)**:
    *   App Language Selector (Segmented buttons for Pt, En, Es).
    *   Saved Medications list navigator (direct link to `MedicationsListScreen`).
*   **Opções de Desenvolvedor (Developer Card)**:
    *   Offline Fixture Loader (Load 25 sample alarms & 6 reminders).

### B. Ajustes da Caixinha (MediCaixa Device Settings)
These settings adjust the physical ESP32 box. They depend directly on LAN network availability and require communication with the C++ backend endpoints.
*   **Conexão com MediCaixa (Connection Controller Card)**:
    *   Status indicator: Connected vs Standalone (with IP address, device name, and firmware version).
    *   Action: Trigger reconnection / scan / disconnect.
*   **Configurações de Rede Wi-Fi**:
    *   Saved Wi-Fi profiles list, SSID scanning list, add new network.
*   **Ajustes de Som e Tela (Sound & Display)**:
    *   Speaker Volume slider, OLED brightness slider, Alarm ringtone melody selection dropdown, silences repetition interval, and sound test triggers.
*   **Sincronização do Relógio (RTC Sync)**:
    *   Retrieve device date/time and sync with mobile's epoch or custom inputs.
*   **Assistente de Voz (Xiaozhi Client)**:
    *   Connection state dot, wake word selector, voice activation pairing card, and Gemini API Key entry.
*   **Manutenção do Dispositivo (Maintenance)**:
    *   JSON Backup download, JSON Restore upload, partition checklist wipe, and reboot commands.

---

## 2. Connection State Visual Guard

When the app operates in Standalone (offline) mode, or is disconnected from the MediCaixa box (monitored by `pairingNotifierProvider` returning `ConnectionStateInfo`), we must prevent users from interacting with hardware-specific components.

### Implementation Blueprint
1.  **Read Connection State**:
    Watch the `pairingNotifierProvider` in the Settings screen:
    ```dart
    final connState = ref.watch(pairingNotifierProvider);
    final bool isConnected = connState.status == ConnectionStatus.connected;
    ```
2.  **Display Connection Warning Card**:
    When `!isConnected`, render an info card at the top of the **Ajustes da Caixinha** section:
    *   **Border & Background**: High contrast orange amber border (`Border.all(color: AppColors.missed, width: 1.5)`) and dark translucent warning background.
    *   **Icon**: Alert icon (`Icons.warning_amber_rounded`, size: 28, color: AppColors.missed). Note: No `const` is applied due to the reference to `AppColors` properties.
    *   **Content**: "Para alterar as configurações físicas da caixinha (como volume, Wi-Fi e sincronização), você precisa se conectar à sua MediCaixa."
    *   **Action Button**: Text button "Conectar Agora" that navigates directly to the Pairing Screen.
3.  **Dimming & Disabling (Opacity + IgnorePointer)**:
    Rather than manually disabling every single slider, textfield, dropdown, and button conditionally, wrap the entire Device Settings widget tree in a combined layout guard:
    ```dart
    Opacity(
      opacity: isConnected ? 1.0 : 0.55,
      child: IgnorePointer(
        ignoring: !isConnected,
        child: Column(
          children: [
            // Wi-Fi Config
            // Sound & Display
            // Clock Sync
            // Voice Assistant
            // Device Maintenance
          ],
        ),
      ),
    )
    ```
    *   `IgnorePointer` ensures no touch events reach the underlying widgets, effectively disabling sliders, dropdowns, list tiles, and buttons.
    *   `Opacity` set to `0.55` matches the C++ Web UI visual style, making it clear to the user that the hardware features are temporarily read-only/unavailable.

---

## 3. Recommended Presentation for Device Settings

To avoid a long, scrolling, cluttered Settings screen, we recommend grouping the box features into dedicated collapsible `ExpansionTile` panels or compact individual cards.

### A. Wi-Fi Configuration Widget (`ExpansionTile`)
*   **Header**: Leading Wi-Fi icon (`Icons.wifi_rounded`, color: AppColors.primary), Title: "Rede Wi-Fi da Caixinha", Subtitle: "Gerencie as conexões de rede do dispositivo".
*   **Body**:
    1.  **Saved Networks List**:
        Query `GET /wifi_list` on expand and render saved profiles. For each profile, show a `ListTile` with a trailing trash button (`Icons.delete_outline_rounded`, color: AppColors.missed) sending a `POST /wifi_remove` request.
    2.  **Available Networks Scanner**:
        *   Button: "Buscar Redes Disponíveis" (`Icons.radar_rounded`).
        *   Spinner: Show `CircularProgressIndicator` during `GET /wifi_scan` execution.
        *   List: Render found SSIDs sorted by signal strength (`rssi` representation).
        *   Interactive Selection: Tapping a network from the scanned list opens a password prompt dialog. Submitting triggers `POST /wifi_add` with `{"ssid": "...", "password": "..."}`.

### B. Adjusts of Sound & Display Widget (`ExpansionTile`)
*   **Header**: Leading volume icon (`Icons.tune_rounded`, color: AppColors.primary), Title: "Sons e Tela", Subtitle: "Ajuste o som do alarme e o brilho do visor".
*   **Body**:
    *   **Speaker Volume Slider**: Range `0` to `100` (`speakerVolume`).
    *   **Display Brightness Slider**: Range `0` to `100` (`brightness`).
    *   **Alarm Ringtone Dropdown**:
        *   Options: "Gentil", "Alerta (Padrão)", "Melodia", "Urgente", "Musical" (mapped to indices `0`, `1`, `2`, `3`, `4`).
    *   **Alarm Spacing Dropdown**:
        *   Options: "1 segundo (insistente)", "3 segundos (padrão)", "6 segundos", "10 segundos (suave)" (mapped to milliseconds `1000`, `3000`, `6000`, `10000`).
    *   **Sound Test Action (`Row`)**:
        *   Button: "Testar Som" (`Icons.play_circle_outline_rounded`). When clicked, triggers `POST /test_sound` with payload `{"index": currentSelectedRingtone}`.

### C. Clock Sync Widget (`Card` / `Row`)
*   **Structure**: Compact card showing current sync status.
*   **Fields**:
    *   **Live Clock Display**: Shows the time retrieved from `GET /server_time` (formatted as `HH:mm:ss - dd/MM/yyyy`).
    *   **Synchronize Button**: "Sincronizar com Celular" (`Icons.sync_rounded`). Sends the mobile device's system time broken down into `year`, `month`, `day`, `hour`, `minute`, `second` parameters via `POST /set_datetime`.
    *   **Manual Adjustments Picker**: "Ajuste Manual" (`Icons.edit_calendar_rounded`). Prompts a custom date-time wizard dialog (DatePicker -> TimePicker) then uploads chosen parameters.

### D. Voice Assistant & IA Widget (`ExpansionTile`)
*   **Header**: Leading mic icon (`Icons.mic_rounded`, color: AppColors.primary), Title: "Assistente de Voz (Xiaozhi)", Subtitle: "Controle por voz e Inteligência Artificial".
*   **Body**:
    1.  **State Indicator Row**:
        *   Display a colored dot `Container(width: 12, height: 12, decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle))` next to state description text (fetched via periodic calls to `GET /voice_status`).
        *   *State to Color Mapping*:
            *   "desconectado": `Colors.grey`
            *   "conectando": `Colors.amber`
            *   "conectado": `Colors.green`
            *   "ouvindo": `Colors.blue`
            *   "pensando": `Colors.purple`
            *   "falando": `Colors.cyan`
            *   "erro": `Colors.red`
    2.  **Activation Pairing Code Card**:
        *   If `activation_code` is returned, show a dotted border card highlighting the code in large letters (e.g. `X K 8 L 9`). Include guidance instructions: "Acesse **xiaozhi.me** para parear sua caixinha."
    3.  **Wake Word Dropdown**:
        *   Select: "Jarvis (Caixinha)", "Hei Kira", "Sofia", "Hei Wanda" (mapped to `jarvis`, `heykira`, `sophia`, `heywanda`). Saves via POST parameter `wake_word`.
    4.  **Gemini API Key Field**:
        *   Password-obscured text field for Google AI Studio key (`gemini_api_key`). Saves key to ESP32 configuration files.

### E. Device Maintenance Widget (`ExpansionTile`)
*   **Header**: Leading tools icon (`Icons.construction_rounded`, color: AppColors.primary), Title: "Manutenção da Caixinha", Subtitle: "Backup, restauração e reconfiguração de fábrica".
*   **Body**:
    1.  **Backup Export Card**:
        *   Button: "Baixar Backup do Dispositivo" (`Icons.download_rounded`). GETs `/backup` and triggers Flutter's local file download or shares payload.
    2.  **Restore Backup Import Card**:
        *   Button: "Restaurar Backup" (`Icons.upload_rounded`). Launches file picker. Parses JSON, opens a dialog displaying checkbox categories (Alarmes, Lembretes, Medicamentos, Wi-Fi, etc.), and uploads chosen sub-selection payload via `POST /restore`.
    3.  **Device Reset (Dangerous Area Card)**:
        *   Button: "Resetar Dados" (`Icons.delete_forever_rounded`, color: AppColors.missed).
        *   **Validation Guard Dialog**: Prompts user with checkboxes for each data block. To confirm, the user MUST type the word "APAGAR" in a confirmation text input field. The execution button only activates when the text matches exactly, sending a selective reset payload to `POST /reset`.
    4.  **Reboot Device Card**:
        *   Button: "Reiniciar Caixinha" (`Icons.restart_alt_rounded`). Issues `POST /restart` and displays a dialog informing that connection will recover in ~10 seconds.

---

## 4. UI Blueprint Outline (Pseudo-code structure)

Here is how the structural layout in `settings_screen.dart` will be modified:

```dart
// Watch the pairing status
final connState = ref.watch(pairingNotifierProvider);
final bool isConnected = connState.status == ConnectionStatus.connected;

return SingleChildScrollView(
  padding: const EdgeInsets.all(16.0),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // ================= LOCAL SETTINGS =================
      _buildSectionHeader('Ajustes Locais'),
      const SizedBox(height: 8),
      
      // Patient Profile Card
      _buildPatientProfileCard(settings),
      const SizedBox(height: 12),
      
      // Routine Useful Times Card
      _buildUsefulTimesCard(settings),
      const SizedBox(height: 12),
      
      // App Customization Card (Language, Saved Meds)
      _buildAppConfigCard(currentLocale, settings),
      const SizedBox(height: 24),
      
      // ================= DEVICE SETTINGS =================
      _buildSectionHeader('Ajustes da Caixinha'),
      const SizedBox(height: 8),
      
      // 1. Connection Guard Warning Card (Displayed only when offline)
      if (!isConnected)
        _buildConnectionWarningCard(context),
        
      const SizedBox(height: 12),
      
      // 2. Hardware Settings with Opacity Guard
      Opacity(
        opacity: isConnected ? 1.0 : 0.55,
        child: IgnorePointer(
          ignoring: !isConnected,
          child: Column(
            children: [
              // Wi-Fi configuration ExpansionTile
              _buildWifiConfigTile(),
              const SizedBox(height: 12),
              
              // Sound & Display ExpansionTile
              _buildSoundDisplayTile(settings),
              const SizedBox(height: 12),
              
              // Clock Sync Card
              _buildClockSyncCard(),
              const SizedBox(height: 12),
              
              // Voice Assistant & IA ExpansionTile
              _buildVoiceAssistantTile(settings),
              const SizedBox(height: 12),
              
              // Device Maintenance & Reset ExpansionTile
              _buildMaintenanceTile(),
            ],
          ),
        ),
      ),
      
      const SizedBox(height: 32),
      
      // ================= DEVELOPER OPTIONS =================
      _buildSectionHeader('Opções de Desenvolvedor'),
      const SizedBox(height: 8),
      _buildDeveloperFixtureCard(),
    ],
  ),
);
```
