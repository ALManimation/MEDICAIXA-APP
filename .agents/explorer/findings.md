# Detailed Investigation Findings — Settings & ESP32 Integration

This document outlines the findings of the read-only exploration of the `medicaixa_app` codebase, comparing the current Settings page implementation with the ESP32 C++ reference project to identify how missing hardware and network functionalities can be integrated.

---

## 1. Feature Files Location

The **Settings** feature files are located at:
- **Presentation Layer**: `lib/features/settings/presentation/settings_screen.dart`
  - Currently displays widgets for patient name configuration, sound volume & screen brightness sliders, sleep schedule toggles & meal times, wake word dropdown, Gemini API Key text field, language selector segmented button, connection status widget, and developer fixture loader.
- **Data Layer**: `lib/features/settings/data/settings_repository.dart`
  - Defines the `SettingsRepository` class. It manages loading/updating the `Setting` Drift database records, checking connection status, updating patient name on ESP32, sending configurations via `/save_settings`, and pulling remote settings via GET `/settings`.
- **Domain Layer**:
  - There is currently no settings domain layer in the Flutter app. The repository directly returns the database generated Drift entity `Setting`.

---

## 2. Connection State Management (Connected vs. Standalone)

Connection state is managed via Riverpod:
- **Provider**: `pairingNotifierProvider` (defined in `lib/features/pairing/presentation/pairing_notifier.dart`) which exposes `ConnectionStateInfo` (defined in `lib/features/pairing/domain/connection_state.dart`).
- **ConnectionStatus Enum**:
  - `disconnected` (standalone mode, no device IP saved or unreachable)
  - `searching` (looking for MediCaixa on the local network via mDNS)
  - `connecting` (validating the base IP)
  - `connected` (successful ping/handshake with `/api/status`)
  - `error` (handshake failed)
- **Mechanism**:
  - When the app launches, the notifier checks `connectionRepositoryProvider.getSavedDeviceIp()`.
  - If a device IP is found in the local Drift `Settings` table, the repository performs a handshake ping: `GET /api/status`.
  - If the status is returned (containing `firmware_version`), it updates the status to `connected` and configures `DioClient` with the saved base URL.
  - Otherwise, it falls back to `disconnected` (Standalone mode).
  - Standalone mode stores everything locally in the Drift/SQLite database, and synchronization with the physical box is completely bypassed.

---

## 3. HTTP Clients and ESP32 Communication

Network requests are managed via `DioClient` in `lib/core/network/dio_client.dart`.

### Key Constraints & Characteristics:
1. **Serialization of Requests**: ESP32 DRAM is limited (~270KB). To prevent overwhelming the ESP32, all outgoing HTTP requests are serialized sequentially using a custom `RequestLock` synchronizer (`dio_client.dart` lines 6-20).
2. **Timeouts**: All requests have connect, receive, and send timeouts set to **5000ms** (`AppConstants.requestTimeoutMs`).
3. **API Clients**:
  - `AlarmApiClient` (`lib/features/alarms/data/alarm_api_client.dart`): Handles endpoints `/alarms`, `/add`, `/update`, `/remove`, `/toggle`, `/pause`, `/snooze`, `/mark_taken`, `/mark_skipped`, `/take_prn`.
  - `MedicationApiClient` (`lib/features/medications/data/medication_api_client.dart`): Handles endpoints `/meds_list`, `/meds_add`, `/meds_update`, `/meds_remove`.
  - `ReminderApiClient` (`lib/features/reminders/data/reminder_api_client.dart`): Handles endpoints `/api/reminders`, `/api/reminders/update`, `/api/reminders/remove`, `/api/reminders/toggle`, `/api/reminders/complete`.

---

## 4. C++ Reference Project & Web Server Analysis

The C++ reference project is located in `../Versoes/08.90 C++ Xiaozhi/`.
The relevant files examined:
- **C++ Web Server Implementation**: `components/web_server/src/web_server.cpp`
- **Web UI**: `littlefs_data/www/index.html`

The C++ project implements a series of settings, network, and maintenance API handlers that are **completely missing** from the current Flutter application:

### A. Wi-Fi Configuration
- **GET `/wifi_list`**: Lists saved networks.
  - *Response*: JSON array of SSIDs: `[{"ssid": "MyWiFi"}]`.
- **GET `/wifi_scan`**: Scans for networks and returns the list.
  - *Response*: JSON array of objects:
    ```json
    [
      {"ssid": "Network1", "rssi": -65, "channel": 6, "open": false},
      {"ssid": "GuestNetwork", "rssi": -80, "channel": 11, "open": true}
    ]
    ```
- **POST `/wifi_add`**: Adds a network credential and triggers connection.
  - *Request Payload*: `{"ssid": "SSID_NAME", "password": "WIFI_PASSWORD"}`
  - *Response*: `"OK"` (text/plain).
- **POST `/wifi_remove`**: Removes saved Wi-Fi network.
  - *Request Payload*: `{"ssid": "SSID_NAME"}`
  - *Response*: `"OK"` (text/plain).

### B. Sound Settings
- **POST `/test_sound`**: Triggers a buzzer tone test on the device.
  - *Request Payload*: `{"index": 1}` (where `index` is an integer from 0 to 4 representing a specific tone: Alert, Confirmation, etc.).
  - *Response*: `"OK"` (text/plain).

### C. Clock Synchronization (RTC)
- **GET `/server_time`**: Returns the current RTC time from the ESP32.
  - *Response*: `{"year": 2026, "month": 6, "day": 28, "hour": 11, "minute": 7, "second": 22}`
- **POST `/set_datetime`**: Overrides/synchronizes the device RTC.
  - *Request Payload*: `{"year": YYYY, "month": MM, "day": DD, "hour": HH, "minute": MM, "second": SS}`
  - *Response*: `"OK"` (text/plain).

### D. Voice Assistant Status
- **GET `/voice_status`**: Queries the Xiaozhi voice assistant module status.
  - *Response*:
    ```json
    {
      "state": "desconectado|conectando|conectado|ouvindo|pensando|falando|erro|não inicializado",
      "connected": true,
      "activation_code": "ACTIVATION_KEY_HERE",
      "has_credentials": true,
      "wake_word": "jarvis"
    }
    ```

### E. Device Maintenance
- **GET `/backup`**: Exports the entire device data state.
  - *Response*: A single JSON object structured as follows:
    ```json
    {
      "settings": {},
      "alarms": [],
      "meds": [],
      "wifi": [],
      "xiaozhi": {},
      "logs": [],
      "chat_history": [],
      "reminders": [],
      "history": [],
      "backup_date": "YYYY-MM-DD HH:MM:SS",
      "firmware_version": "v0.91.0-cpp"
    }
    ```
- **POST `/restore`**: Restores sections of the backup on the device.
  - *Request Payload*: The filtered backup JSON. The client select which keys to restore (e.g. `alarms`, `reminders`, `meds`, `wifi`, `settings`, `xiaozhi`, `chat_history`, `logs`).
  - *Response*: `{"restored_files": 4, "status": "OK"}`.
- **POST `/restart`**: Restarts the ESP32 after a 1 second delay.
  - *Response*: `"OK"` (text/plain).
- **POST `/reset`**: Resets specific device files or performs factory reset.
  - *Request Payload*:
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
  - *Response*: `"OK"` (text/plain).

---

## 5. Summary of Gaps in the Flutter Application

The current Flutter settings implementation does not connect to the C++ endpoints for Wi-Fi management, RTC sync, Voice Assistant pair status, buzzer testing, backup/restore, reset, or restart. 

To bridge this gap, the following modules must be introduced:
1. **Network / Wi-Fi Service**: Fetch saved SSIDs (`/wifi_list`), search for available networks (`/wifi_scan`), and connect the device to networks (`/wifi_add`, `/wifi_remove`).
2. **Device Time Sync**: Align box date/time with mobile device's system time (`/set_datetime`).
3. **Voice Assistant Monitor**: Read connection states, activation codes, and wake word credentials (`/voice_status`).
4. **Maintenance Repository**:
   - Sound test execution (`/test_sound`).
   - Backup download (`/backup`) and file restore (`/restore`).
   - Hard/Soft resets (`/reset`) and reboot trigger (`/restart`).
