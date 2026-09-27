# Astra lean workflow

## Goal

Optimize this repository for GPT-6 Astra without paying a permanent context cost for documentation that is only occasionally relevant.

The default workflow is progressive disclosure:

```text
AGENTS.md (automatic)
-> exact task symbols/paths
-> direct owner + contract + callers/tests
-> edit
-> narrow validation
```

Do not preload `CURRENT_WORK.md`, `PROJECT_INDEX.md`, root/subsystem `CONTEXT.md`, roadmap files, token-economy docs, or multiple skills.

## Context routing

Read only when needed:
- `CURRENT_WORK.md`: resume an interrupted task explicitly referenced by the user;
- `PROJECT_INDEX.md`: owner/path is unclear;
- root/subsystem `CONTEXT.md`: a concrete cross-system invariant is missing;
- `agent_tasks/*`: that exact roadmap task is being implemented/resumed;
- subsystem docs: the edited feature depends on their contract;
- dependency source under `addons/`: version-sensitive API is uncertain.

Prefer exact symbol search and file ranges over full-file/repository dumps. Large `.tscn`, logs, roadmaps, and diffs should be filtered before they enter the main context.

## Astra reasoning

The repository does not pin the main model or reasoning level. Keep that choice session-owned.

Suggested Astra usage:
- ordinary bugfix / focused implementation: medium;
- cross-system ECS/physics refactor: high;
- difficult architecture audit with conflicting evidence: high, occasionally xhigh;
- max: exceptional cases only.

Do not raise reasoning merely because the repository is large. Reduce input context first.

## Skills

Keep the installed project skill set intentionally small:
- `gecs-v8`;
- `gut-testing`;
- `professional-game-design`.

Descriptions should stay narrow. Do not create generic Godot, GDScript, coding-style, repository-navigation, or “project rules” skills that duplicate `AGENTS.md`.

A skill is a specialized on-demand reference, not another startup instruction file.

## Subagents

Routine work stays with the main agent. Only two opt-in roles exist:
- `reviewer`: focused independent review of a substantial completed diff;
- `validator`: explicitly requested noisy validation with compressed output.

Never spawn speculative agents. Run at most one subagent at a time. The main agent owns architecture and final decisions.

## Checkpoints

Small/medium tasks have no bookkeeping.

For long interruptible work:
- `agent_tasks/<task>.md` holds task scope;
- large task docs act as routers and link smaller milestone files;
- `CURRENT_WORK.md` holds only the resume checkpoint and otherwise stays `Status: none`;
- `task_history.md` stores one short completion line.

Do not create a second `WORK.md`.

## Validation economy

Ordinary milestones use static/deterministic checks only.

For a complete large `Rxx` / `Rxx.x` task, normally use one relevant GUT invocation and one relevant headless smoke/runtime invocation near completion. An early blocking run consumes that budget; additional reruns should have a concrete reason or explicit approval.

Rendered/visual Godot remains opt-in and user-owned.

## Config guardrails

`.codex/config.toml` intentionally keeps:
- `project_doc_max_bytes = 8192`;
- `tool_output_token_limit = 4000`;
- `max_concurrent_threads_per_session = 1`.

Do not reduce the tool output limit aggressively: Godot/GUT parse errors and stacks can require a few thousand tokens before filtering.

Do not pin the main Astra model in repository config. Session/model switching should remain possible; cheaper reviewer/validator models may be used for their bounded roles.

## Document size targets

These are maintenance targets, not hard runtime rules:
- `AGENTS.md`: <= 8 KB;
- root `CONTEXT.md`: <= 5 KB;
- subsystem `CONTEXT.md`: preferably <= 8 KB;
- `PROJECT_INDEX.md`: preferably <= 7 KB;
- active roadmap router: preferably <= 5 KB;
- `CURRENT_WORK.md`: <= 1 KB.

If a document grows beyond its target, split detail into on-demand subsystem or milestone docs instead of increasing startup context.
