## 2026-06-30T21:50:45Z
You are a Worker subagent. Your task is to apply remediations for Milestone 5: Voice & Chat UI/UX.

MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A Forensic Auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

Follow these steps:
1. Fix the Rule 32 violation:
   - In `lib/features/chat/presentation/widgets/voice_assistant_sheet.dart`, replace all instances of `mounted` checks inside asynchronous callbacks (e.g., lines 75, 89, 96, 134, 156) with `context.mounted`.
2. Fix the Rule 58 violation:
   - In `lib/core/presentation/app_shell.dart`, replace the hardcoded `Colors.white` for the FAB icons (lines 128 and 157) with `Theme.of(context).colorScheme.onPrimary`.
3. Add locale synchronization:
   - In `voice_assistant_sheet.dart` `initState()`, fetch the selected language (e.g. converting pt_BR/en_US to flat 2-letter codes or using the correct locale, complying with Rule 57) and call `_voiceService.setLocale(...)` so the STT/TTS models utilize the user's selected language.
4. Add concurrency protection on Voice recording:
   - In `voice_assistant_sheet.dart`, introduce a `_isListeningBusy` boolean flag to prevent race conditions during rapid tapping of the mic button. Disable action while busy.
5. Add background execution safety:
   - In `voice_assistant_sheet.dart`, check `if (!context.mounted) return;` before executing actions, speaking, or playing chimes after the LLM response completes in the background, preventing unintended side effects if the sheet has already been closed.
6. Implement Localization updates:
   - In `lib/features/chat/presentation/widgets/voice_assistant_sheet.dart`, replace the following hardcoded text strings with the `t()` helper:
     - `'Desculpe, ocorreu um erro ao processar sua solicitação.'` -> `t('voice_error')`
     - `'Assistente MediCaixa'` -> `t('voice_title')`
     - `'Ouvindo...'` -> `t('voice_listening_label')`
     - `'Pensando...'` -> `t('voice_thinking_label')`
   - Inspect translation files (`assets/lang/pt.json`, etc.) and add these keys with appropriate translations in Portuguese, English, and Spanish.
7. Run `flutter analyze` and `flutter test` to ensure that all 211+ tests compile and pass cleanly, with zero warnings or errors.
8. Write your handoff report to `.agents/worker_m5_remediation/handoff.md`.
Make sure you update your progress.md regularly for heartbeat (liveness).
