## 2026-06-30T21:02:26Z
You are a Worker subagent. Your task is to implement Milestone 2 (Hybrid LLM Service) and lay the groundwork for the Chat Feature.

MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A Forensic Auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

Follow these steps:
1. Update `pubspec.yaml` to include the following dependencies:
   - `google_generative_ai: ^0.4.0`
   - `speech_to_text: ^6.6.0`
   - `flutter_tts: ^4.2.0`
   Run `flutter pub get` and verify that the build compiles successfully. (If code generation is needed, run `dart run build_runner build --delete-conflicting-outputs` as well).
2. Create the folder structure for the chat feature: `lib/features/chat/domain/services/`, `lib/features/chat/data/services/`, `lib/features/chat/presentation/`, etc.
3. Design and implement the `LlmService` interface and its implementations:
   - Abstract class `LlmService` in `lib/features/chat/domain/services/llm_service.dart`.
   - `GeminiLlmService` in `lib/features/chat/data/services/gemini_llm_service.dart` using the `google_generative_ai` package. It should fetch the Gemini API key from the `SettingsRepository` (or settings provider).
   - `LocalLlmService` in `lib/features/chat/data/services/local_llm_service.dart` that implements a simple rule-based/regex matching fallback for offline use (recognizing phrases like "take", "snooze", "dismiss", "create alarm", "list alarms").
   - A `HybridLlmService` (or provider switcher) that checks if there is a Gemini API key and if there is internet, and falls back to `LocalLlmService` automatically.
4. Expose the LLM service via Riverpod providers.
5. Compile the app and ensure all existing unit tests pass.
6. Write a detailed handoff report in `.agents/worker_m2/handoff.md` with:
   - File paths created/modified.
   - Design details of the LlmService implementations.
   - Compilation and test output.
   - Verification status.
Make sure you update your progress.md regularly for heartbeat (liveness).
