# Voice and Chat Assistant Design Report (Milestone 1 Handoff)

This report details the database models, reference C++ assistant logic, and architectural proposal for implementing the Voice and Chat Assistant in the MediCaixa Flutter App.

---

## 1. Observation

During our technical investigation, we analyzed the local Drift database files in the Flutter app, the C++ reference project, and its configuration files. Below are the key direct observations:

### A. Local SQLite Schema (Drift)
Located in `lib/core/database/database.dart`, we observed the definitions for `Alarms`, `Reminders`, `Settings`, `HistoryEvents`, and `Medications`:
*   **Alarms Table (`Alarms`)**:
    *   `id`: `IntColumn` (Primary Key, unique uint8_t 0-255 mapped to ESP32).
    *   `hour` / `minute`: `IntColumn` (Hour/Minute of execution).
    *   `name` / `medName`: `TextColumn` (Alarm name and medication name).
    *   `days`: `TextColumn` (JSON serialized `List<bool>` of size 7).
    *   `status`: `TextColumn` (`PENDENTE`, `TOMANDO`, `SNOOZED`).
    *   `quantity`: `RealColumn` (dosage quantity).
    *   `daysQuantity`: `TextColumn` (JSON serialized `List<double>` for varying daily quantities).
    *   `dosage`: `TextColumn.nullable()`.
    *   `lastStatus` / `lastStatusDate`: `TextColumn.nullable()` (Brazilian format `DD/MM/YYYY` as per Rule 39).
    *   `snoozeMin`: `IntColumn` (Snooze interval).
    *   `startDate` / `durationDays`: `TextColumn.nullable()` / `IntColumn` (Dated alarms support).
    *   `isPrn` / `isDynamic` / `requiresRemoval`: Advanced therapy config columns.
*   **Medications Table (`Medications`)**:
    *   `name`: `TextColumn` (Primary Key).
    *   `color` / `type` / `dosage`: Layout properties (`comprimido`, `capsula`, etc.) and visual identifiers.
*   **Settings Table (`Settings`)**:
    *   `geminiApiKey`: `TextColumn.nullable()` (Persistent storage for Gemini developer token).
    *   `patientName`: `TextColumn` (Defaults to `'Paciente'`).

### B. C++ Reference Action Dispatcher
In `/Users/almanimation/Downloads/Caixa Remedios/Versoes/08.90 C++ Xiaozhi/components/action_handler/src/action_handler.cpp`, we observed the parsing and dispatch logic for MCP tool calls from the Xiaozhi WebSocket server:
*   **Central Dispatcher** (Lines 104–142):
    ```cpp
    if (strcmp(tool, "dismiss_alarm") == 0) {
        handle_dismiss_alarm(params, session_id, mcp_id);
    } else if (strcmp(tool, "skip_alarm") == 0) {
        handle_skip_alarm(params, session_id, mcp_id);
    } else if (strcmp(tool, "snooze_alarm") == 0) {
        handle_snooze_alarm(params, session_id, mcp_id);
    } else if (strcmp(tool, "add_alarm") == 0) {
        handle_add_alarm(params, session_id, mcp_id);
    ...
    ```
*   **Action Handlers**:
    *   `dismiss_alarm`: Extracts `alarm_id` (int) and optional `quantity` (float).
    *   `skip_alarm`: Extracts `alarm_id` (int).
    *   `snooze_alarm`: Extracts `alarm_id` (int) and `minutes` (int, default 10).
    *   `add_alarm`: Extracts `name` (string), `hour` (int), `minute` (int), `quantity` (double), `days` (array of bool), `color` (string), `type` (string), `dosage` (string), `start_date` (string, "YYYY-MM-DD"), `duration_days` (int).
    *   `update_alarm_time`: Extracts `alarm_id` (int), `hour` (int), `minute` (int).
    *   `remove_alarm`: Extracts `alarm_id` (int).
    *   `toggle_alarm`: Extracts `alarm_id` (int) and `enabled` (bool, optional).
    *   `add_reminder`: Extracts `title` (string), `description` (string), `has_time` (bool), `hour` (int), `minute` (int), `period` (string), `interval` (int), `start_date` (string), `notify_days_before` (int), `color` (string).
    *   `complete_reminder`: Extracts `reminder_id` (int).

### C. System Prompt & Context Serialization
*   **System Prompt**: Found in `/Users/almanimation/Downloads/Caixa Remedios/Versoes/08.90 C++ Xiaozhi/README.md` (Lines 135–161). It defines:
    *   **Posture**: Objective, direct, brief (1-2 sentences), no small talk.
    *   **Personalization**: Must greet the patient using the `patient_name` field.
    *   **Core Directive**: Always call `get_device_context` at the start of a conversation.
*   **Device Context**: Handled by `VoiceClient::serialize_device_context()` in `components/voice_client/src/voice_client.cpp` (Lines 1466-1658). It exports:
    *   `patient_name` (string)
    *   `device_current_time` (string: "YYYY-MM-DD HH:MM:SS")
    *   `alarms` (array of active/inactive alarms with dynamic states, days, special instructions)
    *   `medications` (array of medication descriptions)
    *   `reminders` (array of active reminders)
    *   `alarm_active` (boolean, if a proactive alarm is ringing)
    *   `proactive_instruction` (proactive voice alert injection prompt)

### D. pubspec.yaml Dependencies
Inspecting `/Users/almanimation/Downloads/Caixa Remedios/medicaixa_app/pubspec.yaml` shows the app contains `mcp_toolkit` ^3.0.0 and `audioplayers` ^6.8.1, but lacks `google_generative_ai`, `speech_to_text`, and `flutter_tts`.

---

## 2. Logic Chain

1.  **Database Integration**: Since the Flutter application relies on Drift as its local SQLite engine, the `CommandExecutor` must bypass raw SQL or HTTP requests and directly call the respective Flutter repositories (e.g. `AlarmRepository.markTaken`, `AlarmRepository.snoozeAlarm`, `AlarmRepository.createAlarm`) using dynamic Riverpod providers.
2.  **Standalone Mode (Rule 13/14)**: The assistant must operate completely offline if no cloud connection is available. Therefore, the `LlmService` requires a hybrid strategy: a `GeminiLlmService` when internet and a valid `geminiApiKey` are available, falling back to a rule-based `LocalLlmService` (regex intent matcher) for basic voice commands (like "snooze", "take", "list") when offline.
3.  **Strict Prompt Alignment**: The system prompt for the Gemini agent must match the C++ version, reinforcing direct and patient-name-centric replies.
4.  **4-Tab Constraint (Rule 36)**: Since we cannot add a 5th navigation tab to the bottom bar, the Assistant interface should be implemented as a Floating Assistant Sheet (animated modal drawer) triggered by a Microphone FAB on the Dashboard or a button inside the App Shell header.

---

## 3. Caveats

*   **API Key Requirement**: The `GeminiLlmService` relies on a valid API key. If the key is not set in `Settings.geminiApiKey`, the app must proactively guide the user to the Settings tab to configure it, while keeping local voice controls active via the rule-based local parser.
*   **STT Platform Permissions**: Native OS permissions for microphone access (iOS/macOS entitlements, Android permissions) are mandatory. The `VoiceService` must handle permission requests gracefully.
*   **Timezone & Locales**: Rule 39 enforces the Brazilian date format (`DD/MM/YYYY`) for alarm logs. The context generation must output `device_current_time` in standard ISO string format to guide the LLM, but translate queries using Brazilian locale formatting.

---

## 4. Conclusion

We propose a modular, Riverpod-managed architecture for the voice/chat assistant consisting of the following key interfaces and components:

```
┌────────────────────────────────────────────────────────┐
│                   VoiceAssistantUI                     │
│  (Floating bottom drawer, waves visualization, chat)    │
└───────────▲───────────────────────────────▲────────────┘
            │                               │
┌───────────▼──────────┐        ┌───────────▼────────────┐
│     VoiceService     │        │       LlmService       │
│  (speech_to_text /   │        │  (Gemini API / Hybrid  │
│     flutter_tts)     │        │     Local Intent)      │
└──────────────────────┘        └───────────▲────────────┘
                                            │ Function Calls
                                ┌───────────▼────────────┐
                                │     ActionParser       │
                                │           &            │
                                │    CommandExecutor     │
                                └───────────▲────────────┘
                                            │ Repo Calls
                                ┌───────────▼────────────┐
                                │  Repositories (Drift)  │
                                │   (Alarm, Medication)  │
                                └────────────────────────┘
```

### Proposed Components

1.  **LlmService**:
    *   `LlmResponse query(String userMessage, LlmContext context)`
    *   Maps LLM function call triggers to `McpAction` models.
2.  **ActionParser & CommandExecutor**:
    *   Converts JSON schema inputs into structured repository parameters.
    *   Handles local transactions and registers success/error log events via the `HistoryRepository` or `SystemLogs`.
3.  **VoiceService**:
    *   Abstracts STT (`speech_to_text`) and TTS (`flutter_tts`).
    *   Plays sound tones via `audioplayers` mirroring ESP32 sound frequencies (e.g. dual 1200Hz tone for success).
4.  **UI/UX**:
    *   Floating Action Button (FAB) on the Dashboard overlaying the standard view.
    *   Bottom drawer with pulsing microphone, dynamic wave animation, and text input fallback.

### Required `pubspec.yaml` Additions
```yaml
dependencies:
  google_generative_ai: ^0.4.0
  speech_to_text: ^6.6.0
  flutter_tts: ^4.2.0
```

---

## 5. Verification Method

1.  **Unit Tests**: Verify the `ActionParser` parses all action schemas (`dismiss_alarm`, `snooze_alarm`, `add_alarm`) from the simulated Gemini function calling payload format.
2.  **Mock Repository Verification**: Test the `CommandExecutor` using a mock database repository to verify that calling actions updates the simulated Drift database states correctly (e.g., confirming `dismiss_alarm` updates `lastStatus` to `TOMANDO` and calls `markTaken`).
3.  **Build Verification**: After adding the dependencies, run `flutter analyze` and `flutter test` to ensure package resolution is correct and standard behaviors are unmodified.
