# Codex / Agent Instructions

Keep the default path short: start from the user's task and the exact files/symbols it names. Do not preload project documentation "for context".

## Project invariants

- Godot 4.7, GDScript, Forward Plus, Jolt Physics.
- GECS v8 is pinned under `addons/gecs/`; local pinned source is the API authority.
- `addons/` is read-only unless the user explicitly requests dependency/addon work.
- Static typing is required for project-owned GDScript. When inference is ambiguous or an API returns Variant/untyped collection data, declare the concrete type explicitly.
- Project-owned filenames use `snake_case`; classes use `PascalCase`. GECS prefixes such as `C_`, `S_`, `O_`, `E_`, `DEF_`, `R_` are allowed.
- Relationship/owner-link authority lives in `content/relationships/<subsystem>/` with `r_*.gd` / `R_*`; ordinary mutable actor/effect state belongs in Components.
- Components are data-only. Behavior belongs in Systems, Observers, services, or thin Entity/engine glue.
- Project Systems are atomic: a `System` must not call another `System` as a service/helper. Use `deps()` for ordering and Components/Relationships/typed requests/events for data flow.
- Godot physics bodies own physical transform/velocity unless a documented synchronization contract says otherwise.
- No magic gameplay constants; use named constants or authored/data-driven values.
- Never discard user edits, rewrite unrelated history, force-push, or upgrade dependencies unless requested.
- Never write authored files into `.godot/`.

## Context policy

For ordinary work:
1. Start with the task and exact named paths/symbols.
2. Inspect direct owner, data contract, callers/callees, and the smallest relevant regression surface.
3. Use `PROJECT_INDEX.md` only when the owning subsystem/path is unclear.
4. Use root/subsystem `CONTEXT.md` only when an architecture, dependency, persistence, or validation contract is still unclear.
5. Read roadmap/task docs only when implementing or editing that specific roadmap item.
6. Read `CURRENT_WORK.md` only when resuming unfinished work or when the user explicitly refers to the current checkpoint.

Do not recursively scan directories, reread unchanged context files, or dump large `.tscn`, logs, or diffs when exact search/ranges are enough. Stop exploring once owner, contract, and direct regression surface are known.

## Skills

Load a skill only when its specialized workflow is needed:
- GECS API/architecture: `.agents/skills/gecs-v8/SKILL.md`
- GUT test authoring/execution: `.agents/skills/gut-testing/SKILL.md`
- Game-design work: `.agents/skills/professional-game-design/SKILL.md`

Do not load a skill just because a task edits GDScript/Godot files; the project-specific coding rules are already in this file.

## Subagents

Do not use subagents for ordinary implementation, navigation, or validation.

Use a project subagent only when:
- the user explicitly requests delegation; or
- a substantial task has a genuinely independent bounded review/validation step where separate context materially helps.

Available roles are `reviewer` and `validator`. Never spawn speculative agents. Run at most one subagent at a time and wait for it to finish before deciding whether another is needed. Architecture, ownership, physics authority, GECS boundaries, input priority, and cross-system lifecycle decisions stay with the main agent.

## Work and commits

For small/medium tasks, do not create bookkeeping files.

For large or interruptible work:
- keep the detailed active task in `agent_tasks/<task>.md`;
- keep `CURRENT_WORK.md` as a compact checkpoint only: task/status, important invariants, changed paths, validation, blocker, and one exact next step;
- durable architecture/contracts belong in subsystem docs, not the checkpoint;
- completed work gets one concise dated line in `task_history.md`.

Create a local commit after each completed logical milestone when the task spans multiple stages. Do not push or open a PR unless the user asks.

## Validation cadence

Use the narrowest relevant validation.

For ordinary milestone/subtask changes:
- run deterministic/static checks only (for example `python utils/validate_project_structure.py`, changed-file formatter/lint when available, targeted inspection, `git diff --check`);
- do not run GUT, smoke, or broad runtime validation after every small edit.

For a complete `Rxx` / `Rxx.x` implementation task:
- normally run the relevant GUT regression surface once near completion;
- normally run the relevant headless smoke/runtime check once near completion;
- an early runtime/test run is justified only by an explicit user request or a blocking bug that static evidence cannot resolve.

Never launch Godot in rendered/visual mode, capture screenshots/video, or perform agent-side visual scene inspection unless the user explicitly approves visual validation in the current task. If visual acceptance remains, report it as user-owned / not run.

Never claim a formatter, test, Godot run, or visual check passed unless it actually ran.
