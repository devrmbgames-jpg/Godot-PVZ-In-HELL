# Codex lean workflow

## Goal

Keep project-specific context small without weakening correctness.

The main model should work directly from the user's task and code. Repository documents are references, not a mandatory startup sequence.

## Default context path

For an ordinary task:

```text
AGENTS.md (automatic)
-> exact task paths/symbols
-> direct owner/contract/callers/tests
-> edit
-> narrow validation
```

Do **not** automatically read `CURRENT_WORK.md`, `PROJECT_INDEX.md`, root/subsystem `CONTEXT.md`, roadmap files, or multiple skills.

Use:
- `CURRENT_WORK.md` only to resume unfinished work;
- `PROJECT_INDEX.md` only when the owner/path is unclear;
- `CONTEXT.md` only when a concrete contract is missing;
- roadmap/task docs only for that exact roadmap task.

Prefer exact symbol search and targeted ranges over repository-wide reading. Avoid full large `.tscn`, logs, and diffs when a narrow query is enough.

## Skills

Skills are specialized references, not generic coding instructions.

Keep only:
- `gecs-v8` for GECS-specific API/architecture work;
- `gut-testing` for authoring/running GUT tests;
- `professional-game-design` for design work.

General Godot/GDScript/project rules belong in the short `AGENTS.md` and should not require additional skill loading.

## Subagents

Subagents are disabled by policy for routine navigation, implementation, and validation even though the feature remains available.

Only two project roles remain:
- `reviewer`: opt-in independent review of a substantial completed diff;
- `validator`: opt-in execution of explicitly requested noisy validation.

Use one at a time. Do not spawn speculative agents. The main agent owns architecture and final decisions.

## Checkpoints

Do not create bookkeeping for small/medium tasks.

For long or interruptible work:
- `agent_tasks/<task>.md` contains detailed task scope;
- `CURRENT_WORK.md` contains only a compact resume checkpoint;
- `task_history.md` gets one short completion line.

There is no second `WORK.md` checklist.

## Validation economy

Milestones use static/deterministic checks and changed-file formatting/lint.

For a complete large `Rxx` / `Rxx.x` implementation, normally run the relevant GUT surface once and the relevant headless smoke/runtime surface once near completion. A blocking failure may justify one earlier targeted run.

Rendered/visual Godot validation remains opt-in and user-owned.

## Config guardrails

Project `.codex/config.toml` uses:
- `project_doc_max_bytes = 8192` to keep automatically loaded project instructions bounded;
- `tool_output_token_limit = 4000` to limit accidental log/diff flooding;
- `max_concurrent_threads_per_session = 1` so opt-in subagents cannot race/duplicate work.

The project does not select the main model. The user/session remains responsible for that choice.
