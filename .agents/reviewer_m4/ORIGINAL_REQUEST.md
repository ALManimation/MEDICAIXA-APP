## 2026-06-30T18:33:05-03:00

You are a Reviewer subagent. Your task is to review the Voice Pipeline implementation (Milestone 4) for correctness, completeness, robustness, and architectural/style compliance (Flutter rules, Drift rules, offline-first logic, and Riverpod patterns in .agents/AGENTS.md).
Specifically:
1. Read the newly created files:
   - `lib/features/chat/services/voice_service.dart`
   - `lib/features/chat/services/voice_providers.dart`
   - `test/features/chat/voice_service_test.dart`
2. Check for robust error handling of permissions and platform support, Riverpod annotation code generation, and test coverage.
3. Run `flutter analyze` and `flutter test test/features/chat/voice_service_test.dart` to verify.
4. Write your review report in `.agents/reviewer_m4/handoff.md` with a clear pass/fail verdict and reasons.
Make sure you update your progress.md regularly for heartbeat (liveness).
