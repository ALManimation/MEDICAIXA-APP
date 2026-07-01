# Original User Request

## 2026-07-01T10:13:38Z

# Teamwork Project Prompt — Draft

> Status: Launched
> Goal: Craft prompt → get user approval → delegate to teamwork_preview

O objetivo deste projeto é implementar a lógica de exclusão de alarmes no aplicativo Flutter MediCaixa, espelhando fielmente o comportamento do projeto C++ original para a exibição de alarmes passados (Ghost Alarms) no calendário.

Working directory: /Users/almanimation/Downloads/Caixa Remedios/medicaixa_app
Integrity mode: benchmark

## Requirements

### R1. Análise da Lógica Original (C++)
A equipe deve analisar o projeto C++ (especialmente `../Versoes/08.90 C++ Xiaozhi/littlefs_data/www/index.html` e os arquivos no diretório de `components/` referentes ao firmware) para entender exatamente como a exclusão de alarmes e o histórico são processados. A equipe decidirá a melhor abordagem técnica de persistência e reconstrução em memória com base nessa análise.

### R2. Tratamento de Alarmes com Histórico
Quando um alarme for excluído, se ele possuir um histórico de status (tomado ou perdido) no dia da exclusão (ou em dias anteriores), ele deve ser mantido no calendário desse(s) dia(s) específico(s) para conferência. Ele deve assumir o estado de "Ghost Alarm" (propriedade `isGhost: true`, bordas/ícones em cinza, opacidade 0.55, badge "Excluído" e sem interação de clique). Nos dias seguintes ao último status, ele não deve mais aparecer no calendário.

### R3. Tratamento de Alarmes Sem Histórico
Se um usuário criar e excluir um alarme no mesmo dia sem que ele tenha recebido nenhum status (nem tomado, nem perdido), o alarme deve ser completamente removido e não deve aparecer no calendário, nem mesmo como "Ghost Alarm".

## Acceptance Criteria

### Verificação Programática e Testes
- [ ] Toda a suíte de testes do aplicativo (`flutter test`) deve passar com sucesso sem quebrar testes existentes de calendário e persistência.

## Follow-up — 2026-07-01T12:01:43Z

Conduct a comprehensive code review of the Medicaixa Flutter application. The goal is to analyze the codebase for logical flaws, unfinished implementations, inconsistencies, and potential performance or stability issues, providing a detailed audit report.

Working directory: `/Users/almanimation/Downloads/Caixa Remedios/medicaixa_app`
Integrity mode: benchmark

## Requirements

### R1. Deep Codebase Analysis
Analyze the Flutter app architecture, specifically focusing on Riverpod state management, Drift (SQLite) database interactions, and background alarm engine logic for race conditions, memory leaks, or unhandled exceptions.

### R2. Feature-First Architecture Consistency
Verify that the codebase adheres to the defined feature-first clean architecture (data/domain/presentation separation) and identify any code smells or logic bleeding across layers.

### R3. Performance & Stability Audit
Identify performance bottlenecks (e.g., inefficient UI rebuilds, heavy isolate usage issues, unnecessary network polling) and stability risks in the communication with the ESP32 hardware.

## Acceptance Criteria

### Audit Report
- [ ] A final markdown artifact (`audit_report.md`) is generated containing categorized issues (Critical, High, Medium, Low).
- [ ] Each issue includes a clear description of the flaw, the file/line number, and a concrete recommendation for fixing it.
- [ ] The report explicitly covers the `AlarmEngine`, Drift Database repositories, and Riverpod Notifiers.
- [ ] The review focuses purely on generating the report; the agents do not write new implementation code or automated tests, but they may use linters and reference the existing tests/firmware C++ to validate their findings.

## Follow-up — 2026-07-01T12:21:31Z

<USER_REQUEST>
# Teamwork Project Prompt — Draft

> Status: Launched

Implement all the required code fixes and refactorings for the 14 issues identified in the recent `audit_report.md` codebase audit.

Working directory: `/Users/almanimation/Downloads/Caixa Remedios/medicaixa_app`
Integrity mode: development

## Requirements

### R1. Resolve Critical Issues (Hot Reload & Data Integrity)
Refactor `AlarmWizardNotifier` and `PairingNotifier` to eliminate `late final` variables (Rule 28 violation). Update `MedicationRepository.deleteMedication` to query the `AlarmRepository` and block deletion if the medication is currently used by an active alarm (Rule 35 violation).

### R2. Resolve High & Medium Issues (State, Architecture & Memory Leaks)
Convert `DashboardNotifier` to `AsyncNotifier` to eliminate manual `isLoading` flags (Rule 3 violation). Fix layer bleeding where repositories directly import presentation notifiers. Cancel the `_inactivityTimer` in `DashboardNotifier` on dispose. Correct the sound labeling mismatch for option 0 (from "Beep" to "Gentil"). Ensure `DashboardScreen` only counts missed alarms if they are actually enabled/active.

### R3. Resolve Low Severity Issues
Refactor model `copyWith` methods to handle null overrides cleanly. Consolidate ANVISA database loading to a single isolate-backed service. Move synchronous JSON decoding of backups off the UI thread via `compute`. Optimize `AlarmCardWidget` to select only the required state properties to avoid unnecessary rebuilds. Ensure timezone initialization failures do not silently fall back to UTC.

## Acceptance Criteria

### Testing & Compilation
- [ ] All 14 issues documented in `audit_report.md` are resolved in the codebase.
- [ ] The application compiles successfully for iOS and macOS (`flutter build ios --simulator`, etc).
- [ ] `flutter test` completes successfully without regressions (specifically dashboard, alarm, and medication tests).
- [ ] No `LateInitializationError` is thrown when Hot Reloading any screen.

---
*Next: when approved → delegate via invoke_subagent*
</USER_REQUEST>
