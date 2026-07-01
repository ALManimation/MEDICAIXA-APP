# Plan - Codebase Remediation

This plan outlines the steps to resolve the 14 issues identified in the codebase audit of the Medicaixa Flutter application.

## Milestones & Decompositions

We divide the remediation into 3 execution milestones plus an initial exploration/analysis phase.

### Milestone 0: Exploration & Analysis
- **Goal**: Research all 14 issues in detail, locate files, propose concrete fixes, and draft implementation strategies.
- **Worker**: `teamwork_preview_explorer` (spawns 1 instance)

### Milestone 1: State, Architecture & Memory Leaks (State & UI Cleanup)
- **Goal**: Fix notifier crashes, AsyncNotifier refactoring, inactivity timers, layout rebuild optimization, and cleanup dead code.
- **Issues addressed**:
  - Finding 1.1: `LateInitializationError` due to `late final` fields in Notifiers.
  - Finding 2.1: Manual `isLoading` State Flags Instead of `AsyncValue` in `DashboardNotifier`.
  - Finding 3.2: Layer Violations (Presentation-to-Data Bleeding) for `pairingNotifierProvider` imports.
  - Finding 3.3: Dashboard Inactivity Timer Memory Leak.
  - Finding 4.4: Inefficient UI Rebuilds in `AlarmCardWidget`.
  - Finding 4.6: Non-Idiomatic `AsyncValue` Usage in Synchronous Notifiers.
  - Finding 4.7: Dead Code (Unused Legacy Wizard Classes).
- **Subagents**:
  - Worker: `teamwork_preview_worker`
  - Reviewer: `teamwork_preview_reviewer`
  - Challenger: `teamwork_preview_challenger`

### Milestone 2: Repository, Data Integrity & Search Optimization (Data & Core)
- **Goal**: Implement medication deletion checks, copyWith nullable support, and deduplicate/optimize compressed ANVISA database loading.
- **Issues addressed**:
  - Finding 1.2: Medication Deletion Missing Alarm Usage Check in Repository.
  - Finding 4.1: Custom Model `copyWith` Null Value Limitation.
  - Finding 4.2: Duplicate Compressed ANVISA Database Loading.
- **Subagents**:
  - Worker: `teamwork_preview_worker`
  - Reviewer: `teamwork_preview_reviewer`
  - Challenger: `teamwork_preview_challenger`

### Milestone 3: UI, System Integrations & Robustness (UI & Integration)
- **Goal**: Fix sound label mismatch, timezone UTC fallback, backup JSON decoding off UI thread, and missed alarms count check.
- **Issues addressed**:
  - Finding 3.4: Sound Dropdown Option 0 Label Mismatch (C++ Inconsistency).
  - Finding 3.5: Disabled Alarms Erroneously Counted as Missed.
  - Finding 4.3: Synchronous Backup JSON Decoding on UI Thread.
  - Finding 4.5: Timezone Initialization UTC Fallback Risk.
- **Subagents**:
  - Worker: `teamwork_preview_worker`
  - Reviewer: `teamwork_preview_reviewer`
  - Challenger: `teamwork_preview_challenger`

### Milestone 4: Final Verification & Integrity Audit
- **Goal**: Run complete test suites (`flutter test`), check code compilation, perform hot reload test, and run the Forensic Auditor to verify integrity.
- **Subagents**:
  - Reviewer: `teamwork_preview_reviewer`
  - Auditor: `teamwork_preview_auditor`

## Execution Strategy
- For each implementation milestone:
  1. Dispatch implementation to `teamwork_preview_worker`.
  2. Verify implementation compiles.
  3. Dispatch to `teamwork_preview_reviewer` and `teamwork_preview_challenger` to verify logic.
  4. Run integrity audit on final code.
