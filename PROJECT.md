# Project: MediCaixa App Settings Reorganization and Integration

## Architecture
- **Features**: Settings feature is located at `lib/features/settings/`.
- **Data Flow**:
  - Presentation (`settings_screen.dart`) interacts with `SettingsRepository` and new API clients to fetch network, voice status, and maintenance features from ESP32.
  - All communication is routed through `DioClient` with serialized request queueing to prevent crashing the ESP32 (DRAM limits).
  - SQLite (Drift) is used offline-first for settings persistence.

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|---|---|---|---|
| 1 | Exploration & Planning | Analyze requirements & codebase | None | DONE |
| 2 | Settings & C++ Box Integrations | Reorganize UI, Wi-Fi, Sound, RTC, Voice, Maintenance APIs | None | DONE |
| 3 | E2E Verification & Audit | Test compilation, functional verification & integrity audit | M2 | DONE |
| 4 | ReportsScreen & Adherence Analytics | Implement CustomPainter charts, ReportsScreen layout, Drift queries, and unit tests | M3 | DONE |
| 5 | Complete Multilingual Translation | Map hardcoded strings, dynamic date/calendar locale, Drift SQLite settings persistence & tests | M4 | DONE |

## Interface Contracts
### Wi-Fi API Client
- `Future<List<WifiNetwork>> scanWifi()` -> `GET /wifi_scan`
- `Future<List<String>> getSavedWifi()` -> `GET /wifi_list`
- `Future<void> addWifi(String ssid, String password)` -> `POST /wifi_add`
- `Future<void> removeWifi(String ssid)` -> `POST /wifi_remove`

### Clock API Client
- `Future<DateTime> getServerTime()` -> `GET /server_time`
- `Future<void> setDateTime(DateTime dateTime)` -> `POST /set_datetime`

### Voice Status Client
- `Future<VoiceStatus>` -> `GET /voice_status`

### Maintenance API Client
- `Future<void> testSound(int index)` -> `POST /test_sound`
- `Future<Map<String, dynamic>> downloadBackup()` -> `GET /backup`
- `Future<void> restoreBackup(Map<String, dynamic> data)` -> `POST /restore`
- `Future<void> resetDevice(Map<String, bool> partitions)` -> `POST /reset`
- `Future<void> restartDevice()` -> `POST /restart`

## Code Layout
- `lib/features/settings/data/settings_repository.dart`
- `lib/features/settings/presentation/settings_screen.dart`
- `lib/features/reports/presentation/reports_screen.dart`
- `lib/features/reports/presentation/reports_notifier.dart`
- `lib/features/reports/presentation/widgets/`

