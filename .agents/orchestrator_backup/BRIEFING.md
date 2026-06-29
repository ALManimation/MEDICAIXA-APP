# BRIEFING — 2026-06-29T08:50:00-03:00

## Mission
Orchestrate the implementation of backup, restore, and reset features for the MediCaixa App.

## 🔒 My Identity
- Archetype: teamwork_preview_orchestrator
- Roles: orchestrator, user_liaison, human_reporter, successor
- Working directory: /Users/almanimation/Downloads/Caixa Remedios/medicaixa_app/.agents/orchestrator_backup/
- Original parent: parent
- Original parent conversation ID: 8be2ec91-2153-4d5f-bb0a-050965a689d0

## 🔒 My Workflow
- **Pattern**: Project
- **Scope document**: /Users/almanimation/Downloads/Caixa Remedios/medicaixa_app/.agents/orchestrator_backup/plan.md
1. **Decompose**: Decompose the backup, restore, and reset features into milestones.
2. **Dispatch & Execute**:
   - **Delegate (sub-orchestrator)**: Spawn subagents/workers to perform the tasks and verification.
3. **On failure** (in this order):
   - Retry: nudge stuck agent or re-send task
   - Replace: spawn fresh agent with partial progress
   - Skip: proceed without (only if non-critical)
   - Redistribute: split stuck agent's remaining work
   - Redesign: re-partition decomposition
   - Escalate: report to parent (sub-orchestrators only, last resort)
4. **Succession**: Self-succeed at 16 spawns, write handoff.md, spawn successor.
- **Work items**:
  1. Explore current code and REST api contracts [done]
  2. Implement Backup (export) logic & UI [done]
  3. Implement Restore (import) logic & UI [done]
  4. Implement Reset logic & UI [done]
  5. Implement Integration & Robustness Tests [done]
- **Current phase**: 4
- **Current focus**: Completed

## 🔒 Key Constraints
- Never write, modify, or create source code files directly.
- Never run build/test commands yourself — require workers to do so.
- Do not use 'const' with AppColors.
- Follow drift database naming conventions and keep offline-first database.
- Use context.mounted in asynchronous operations.
- Never reuse a subagent after it has delivered its handoff — always spawn fresh

## Current Parent
- Conversation ID: 8be2ec91-2153-4d5f-bb0a-050965a689d0
- Updated: not yet

## Key Decisions Made
- [TBD]

## Team Roster
| Agent | Type | Work Item | Status | Conv ID |
|-------|------|-----------|--------|---------|
| Explorer | teamwork_preview_explorer | Explore database, settings repository, and settings screen | completed | 9d2f93b1-f9b1-4b9a-828c-a2e487330e8a |
| Worker | teamwork_preview_worker | Implement backup, restore, reset features | completed | ef8fc956-22b2-4f79-a47d-7d5ae21fa086 |
| Reviewer | teamwork_preview_reviewer | Verify correctness, robustness, and layout of settings changes | completed | e90758cc-6ee6-43c7-ae42-be873605e698 |
| Auditor | teamwork_preview_auditor | Perform integrity audit on settings changes | completed | bc8cfea8-5116-4648-acfa-eddf0bb34d2f |

## Succession Status
- Succession required: no
- Spawn count: 4 / 16
- Pending subagents: none
- Predecessor: none
- Successor: not yet spawned

## Active Timers
- Heartbeat cron: task-19
- Safety timer: none
- On succession: kill all timers before spawning successor
- On context truncation: run manage_task(Action="list") — re-create if missing

## Artifact Index
- /Users/almanimation/Downloads/Caixa Remedios/medicaixa_app/.agents/orchestrator_backup/plan.md — Scope and execution plan
- /Users/almanimation/Downloads/Caixa Remedios/medicaixa_app/.agents/orchestrator_backup/progress.md — Execution progress tracking
