# Project: MediCaixa Intelligent Voice and Chat Assistant

## Architecture
- **Features**: Chat (`lib/features/chat/`), Alarms (`lib/features/alarms/`), Medications (`lib/features/medications/`), Settings (`lib/features/settings/`).
- **Data Flow**:
  - Offline-first: LLM queries SQLite (via Drift) locally.
  - Hybrid LLM Service (`lib/features/chat/domain/services/llm_service.dart`): transparent fallback to Gemini Cloud API if local AICore / Foundation Models are not available.
  - Actions execute on SQLite using specific repository patterns (e.g. `AlarmRepository`, `MedicationRepository`).
  - Voice Pipeline (`lib/features/chat/services/voice_service.dart`): Speech-to-Text and Text-to-Speech integration.

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| 1 | Exploration & Design | Analyze existing codebase and prepare detailed design patterns | None | DONE |
| 2 | Hybrid LLM Service | Create LlmService with local/cloud fallbacks | M1 | DONE |
| 3 | Offline Intent Motor | Medical System Prompt, action parser, Drift command runner | M2 | DONE |
| 4 | Voice Pipeline | STT/TTS integration and Push-to-Talk service | M3 | DONE |
| 5 | Voice & Chat UI/UX | Chat drawer/modal panel, floating trigger, MD3 dark theme, "Thinking..." indicator | M4 | DONE |
| 6 | Verification & Hardening | E2E tests, adversarial coverage, audit validation | M5 | DONE |

## Interface Contracts
### `LlmService` ↔ Local / Cloud
- `Future<bool> isLocalAvailable()`
- `Future<String> generateResponse(String prompt, {List<ChatMessage> history, Map<String, dynamic>? context})`
### Action Parser ↔ Drift Database
- Output JSON format: `{ "message": String, "actions": [ { "type": "add_alarm"|"remove_alarm"|"mark_taken"|"snooze_alarm", "params": { ... } } ] }`

## Code Layout
- `lib/features/chat/data/`
- `lib/features/chat/domain/`
- `lib/features/chat/presentation/`
- `lib/features/chat/services/`
