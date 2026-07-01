# Project: Medicaixa Code Review Audit

## Architecture
- Framework: Flutter 3.x + Dart 3.x
- State Management: Riverpod 2.x (with code generation)
- Local Database: Drift (SQLite) with reactive streams
- HTTP Client: Dio 5.x with interceptors
- Architecture: Feature-First Clean Architecture (data / domain / presentation)

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| 1 | AlarmEngine Analysis | Audit background alarm engine logic, timers, notification scheduling, timezone handling | None | DONE |
| 2 | Drift Database Analysis | Audit database schemas, repository patterns, reactive streams, concurrency | None | DONE |
| 3 | Riverpod Notifiers Analysis | Audit state management, AsyncValue, code generation, UI rebuilds, memory leaks | None | DONE |
| 4 | Architecture & Performance Audit | Audit Feature-First architecture adherence, ESP32 HTTP communication, serialization, isolates | None | DONE |
| 5 | Synthesis & Report Generation | Aggregate findings from all milestones into a final audit_report.md | M1, M2, M3, M4 | DONE |

## Code Layout
- `.agents/orchestrator_code_review/` — Metadata for orchestrator
- `lib/` — Source code of the application
- `test/` — Unit and widget tests
