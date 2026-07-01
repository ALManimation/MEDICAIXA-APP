## 2026-06-30T21:40:06Z
Implement Milestone 5: Voice & Chat UI/UX.
1. Create `lib/features/chat/presentation/widgets/voice_assistant_sheet.dart` which implements the quick chat sliding modal panel:
   - Header with title "Assistente MediCaixa" and close button.
   - Conversation history list displaying messages in speech bubbles (differentiating user vs assistant, using dynamic theme colors. NEVER hardcode text/icon colors, as per Rule 58).
   - Bottom input panel containing:
     - Text field for text query.
     - Send button.
     - Pulse/wave mic button for voice interaction.
   - Microphone voice states and visualization:
     - When listening: display animated pulsing wave indicators and a microphone button indicating active recording.
     - When LLM is generating: display a "Pensando..." indicator with a CircularProgressIndicator.
   - Connect it to `LlmService` (via `hybridLlmServiceProvider`), `ActionExecutor` (via `actionExecutorProvider`), and `VoiceService` (via `voiceServiceProvider`):
     - For voice input: tap to start recording -> speak -> transcribe -> query LLM -> execute actions -> voice TTS response -> speak -> feedback chime.
     - Ensure proper cleanup when sheet is closed (e.g. stop voice recording, stop TTS playback).
     - Use `context.mounted` inside async callbacks to prevent lifecycle crashes (Rule 32).
2. Add a trigger for `VoiceAssistantSheet`:
   - Add a microphone Floating Action Button (FAB) in `lib/core/presentation/app_shell.dart`. Position it on the bottom left (opposite side of the MultiActionFab, elevated by 80px on mobile to clear the bottom navigation bar, and 16px on desktop) so that it remains easily accessible from any screen without altering the 4 bottom bar navigation tabs (Rule 36).
3. Write widget and unit tests in `test/features/chat/voice_assistant_sheet_test.dart` verifying the UI elements, state transitions (idle, listening, thinking, displaying text), text submit flow, and close cleanup. Mock the LLM and Voice services so that tests compile and pass cleanly on headless systems.
4. Run `flutter analyze` and `flutter test` to ensure that all 207+ tests pass successfully with zero static analysis issues.
5. Write your handoff report in `.agents/worker_m5/handoff.md`.
Make sure you update your progress.md regularly for heartbeat (liveness).
