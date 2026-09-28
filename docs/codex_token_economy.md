# Lean agent architecture

## Goal

Use Astra/Codex intelligence without paying a permanent context cost for project history, roadmaps, specialized workflows, or unrelated subsystem documentation.

The design borrows the useful parts of BMad-style execution without installing BMad as a framework.

## Five core patterns

| Pattern | Project implementation |
| --- | --- |
| Right-sized workflow | `Fix / Task / Feature` chosen after investigation |
| Quick Dev | `investigate → classify → plan only enough → implement → review → verify` |
| Durable task/story state | authoritative `agent_tasks/<task>.md` or roadmap router |
| Context isolation | load index/context/docs/skills only when the task needs them |
| Review triage | material findings get `R1/R2/...` and end `FIXED / ACCEPTED / FALSE_POSITIVE` |

## Context layers

### Always on

`AGENTS.md` contains only correctness-critical project invariants, routing, subagent policy, task-state policy, and validation permissions.

### On-demand process

`.agents/skills/develop/SKILL.md` owns the implementation workflow. It may load:
- `gecs-v8` for GECS API/architecture;
- `gut-testing` for GUT authoring/execution;
- `professional-game-design` for player-facing design.

Do not preload all skills.

### On-demand facts

Use:
- `PROJECT_INDEX.md` only when ownership/path is unclear;
- root/subsystem `CONTEXT.md` only for a missing concrete invariant;
- subsystem docs only when the edited contract depends on them;
- dependency source under `addons/` only for version-sensitive API uncertainty.

## Task state architecture

`agent_tasks/CONTEXT.md` is the queue/status index.

An executable task/router is authoritative for:
- status;
- goal;
- constraints/acceptance;
- milestones;
- durable decisions;
- exact current checkpoint and next action;
- validation;
- owner QA/blockers;
- material review findings when present.

Supported statuses:
- `PLANNED`
- `IN_PROGRESS`
- `DEFERRED`
- `BLOCKED`
- `OWNER_QA`
- `DONE`
- `SUPPORT` for non-executable specs/inventories owned by another task.

`CURRENT_WORK.md` is not a second task document. It points only to the current execution focus and its next step.

`task_history.md` stores completed-history summaries. Removed completed task files do not need to be recreated.

Large tasks may use bounded milestone files. The root/router still owns overall task status; a milestone owns only its own bounded state/evidence.

## Roadmap relationship

`docs/roadmap/` contains design specifications (`ТЗ xx`). They are source requirements, not current implementation state.

Canonical implementation IDs are `Rxx` / `Rxx.x`. The mapping lives in `docs/roadmap/README.md`; the live queue/status lives in `agent_tasks/CONTEXT.md`.

Never maintain the same Current/Next state in both a design doc and a task file.

## Review triage

For substantial tracked work:
1. review the resulting diff independently of the implementation plan;
2. assign material findings stable IDs `R1`, `R2`, ...;
3. classify severity as `BLOCKER`, `BUG`, `RISK`, or `CLEANUP`;
4. resolve every emitted finding to `FIXED`, `ACCEPTED`, or `FALSE_POSITIVE`;
5. persist only findings that materially matter to the tracked task.

The optional `reviewer` subagent emits OPEN findings; the main agent owns resolution.

## Validation economy

Ordinary milestones use the cheapest deterministic checks that can falsify the change.

For a complete large `Rxx` / `Rxx.x`, normally reserve:
- one relevant GUT invocation;
- one relevant headless smoke/runtime invocation.

Earlier runtime runs require a blocking reason or explicit request. Rendered/visual validation remains opt-in and user-owned.

## Config guardrails

Repository defaults intentionally keep:
- `project_doc_max_bytes = 6144`;
- `tool_output_token_limit = 4000`;
- `max_concurrent_threads_per_session = 1`.

The repository does not pin the main model or subagent models. Model/reasoning choice stays session-owned.

## Maintenance rule

Before adding always-on instructions, ask whether the rule applies to most work and whether missing it creates a correctness/safety failure. If not, put it in a specialized skill, subsystem context, task artifact, or durable domain doc instead.
