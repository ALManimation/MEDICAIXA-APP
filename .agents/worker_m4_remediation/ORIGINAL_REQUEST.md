## 2026-06-30T18:35:16Z
You are a Worker subagent. Your task is to apply remediations for Milestone 4: Voice Pipeline.

MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A Forensic Auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

Please do the following:
1. Relocate files to maintain Feature-First layering:
   - Move `lib/features/chat/services/voice_service.dart`, `lib/features/chat/services/voice_providers.dart`, and `lib/features/chat/services/voice_providers.g.dart` to `lib/features/chat/data/services/`.
   - Update any import paths referencing these files (especially in `test/features/chat/voice_service_test.dart` and `test/features/chat/voice_service_challenger_test.dart`).
   - Run `dart run build_runner build --delete-conflicting-outputs` to ensure Riverpod generated code is rebuilt.
2. Configure Android Permissions:
   - In `android/app/src/main/AndroidManifest.xml`, add `<uses-permission android:name="android.permission.RECORD_AUDIO"/>` under the `<manifest>` tag.
3. Configure iOS Info.plist:
   - In `ios/Runner/Info.plist`, add the keys `NSMicrophoneUsageDescription` and `NSSpeechRecognitionUsageDescription` with appropriate description strings in Portuguese (e.g., "MediCaixa precisa acessar o microfone para comandos de voz" and "MediCaixa precisa de permissão de reconhecimento de fala para o chat por voz").
4. Configure macOS Entitlements & Info.plist:
   - In `macos/Runner/Info.plist`, add the keys `NSMicrophoneUsageDescription` and `NSSpeechRecognitionUsageDescription` (same as iOS).
   - In both `macos/Runner/DebugProfile.entitlements` and `macos/Runner/Release.entitlements`, add the key and value:
     `<key>com.apple.security.device.audio-input</key>`
     `<true/>`
5. Clean up lints in tests:
   - In `test/features/chat/voice_service_test.dart`, resolve the lints reported:
     - Remove unnecessary `this.` qualifiers.
     - Remove/use the unused local variable `isListeningStatus`.
6. Run `flutter analyze` and `flutter test` to verify everything is 100% clean and all 207+ tests pass successfully.
7. Write your handoff report to `.agents/worker_m4_remediation/handoff.md`.
Make sure you update your progress.md regularly for heartbeat (liveness).
