## 2026-06-30T21:27:32Z
You are a Worker subagent. Your task is to implement Milestone 4: Voice Pipeline (STT/TTS setup).

MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A Forensic Auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

Follow these steps:
1. Implement the `VoiceService` class in `lib/features/chat/services/voice_service.dart`. The service must:
   - Handle STT (Speech-to-Text) using the `speech_to_text` package.
     - Include logic to request microphone permission, handle denials, and track listening state.
     - Provide `startListening({required Function(String text) onResult, required Function(bool isListening) onListeningStatusChanged})` and `stopListening()`.
   - Handle TTS (Text-to-Speech) using the `flutter_tts` package.
     - Include logic to speak text, stop speaking, and set locale/rate/pitch.
   - Play audio feedback tones using the `audioplayers` package for interaction states:
     - "start_listening": play sound when recording begins.
     - "success": play sound when action successfully executed.
     - "error": play sound when action failed.
     - Note: Use existing sound assets (like `assets/sounds/alarm_beep.wav` or others in `assets/sounds/`) or play synthesized sounds. Ensure it doesn't crash if the asset isn't found.
   - Include graceful fallbacks so it does not crash when STT/TTS native components are unavailable (like in unit tests or unsupported desktop platforms).
2. Expose `VoiceService` via a Riverpod provider in `lib/features/chat/data/services/llm_providers.dart` or `lib/features/chat/services/voice_providers.dart`.
3. Write unit and mock tests in `test/features/chat/voice_service_test.dart` verifying state updates, listening callbacks, and audio trigger calls. Mock all native platform plugins (`speech_to_text`, `flutter_tts`) so that tests compile and pass on headless/CI systems.
4. Run `flutter analyze` and `flutter test` to ensure the project compiles cleanly and all 191+ tests pass.
5. Write a detailed handoff report in `.agents/worker_m4/handoff.md`.
Make sure you update your progress.md regularly for heartbeat (liveness).
