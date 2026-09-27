# Agent Instructions

Keep the default path short: start from the user's task and the exact files/symbols it names. Do not preload project documentation "for context".

## Project invariants

- Godot 4.7, GDScript, Forward Plus, Jolt Physics.
- GECS v8 is pinned under `addons/gecs/`; local pinned source is the API authority.
- `addons/` is read-only unless dependency/addon work is explicitly requested.
- Static typing is required for project-owned GDScript. If inference is ambiguous or an API returns Variant/untyped data, declare the concrete type explicitly.
- Project-owned filenames use `snake_case`; classes use `PascalCase`. GECS prefixes such as `C_`, `S_`, `O_`, `E_`, `DEF_`, `R_` are allowed.
- Components are data/state only. Behavior belongs in Systems, Observers, services/solvers, or thin Entity/engine glue.
- Authoritative live Entity-to-Entity ownership/session/binding uses Relationships under `content/relationships/<subsystem>/`. Documented reverse caches may remain Components but are never co-authority.
- Project Systems are atomic: no System calls another System as a service/helper. Use `deps()`, groups, Components, Relationships, typed requests/events/results.
- Godot physics bodies own physical transform/velocity unless a documented synchronization contract says otherwise.
- No magic gameplay constants; use named constants or authored/data-driven values.
- Private member state uses a leading underscore. In behavior/glue/UI code, non-exported member variables are private by default: `var _value`, never accidental `var value`.
- Every `@onready` cache is private and starts with `_`. Do not expose child-node caches as fields; expose an intentional method/property API when another object needs access.
- Public data fields without `_` are appropriate only when they are intentionally part of a data/API contract (for example Components, Relationships, typed contracts, Definitions, or explicit `@export` scene configuration).
- Project-authored `.tres` filenames use searchable type prefixes. Definitions use `def_*`, materials `mat_*`, themes `theme_*`, styles `style_*`, meshes `mesh_*`; see `docs/code_style.md` for the canonical table. Imported/vendor resources are not renamed solely for style.
- Never discard user edits, rewrite unrelated history, force-push, upgrade dependencies, or write authored files into `.godot/`.

## Context policy

For ordinary work:
1. Start with the task and exact named paths/symbols.
2. Inspect the direct owner, data contract, callers/callees, and smallest relevant regression surface.
3. Use `PROJECT_INDEX.md` only when the owning subsystem/path is unclear.
4. Use root/subsystem `CONTEXT.md` only when a concrete cross-system contract is still unclear.
5. Read roadmap/task docs only for the exact roadmap task being implemented or resumed.
6. Read `CURRENT_WORK.md` only when the user asks to resume/continue prior unfinished work.

Prefer exact symbol search and targeted ranges. Do not recursively scan directories, reread unchanged context, or dump full large `.tscn`, logs, diffs, roadmaps, or context files when a narrow lookup is enough. Stop exploring once owner, contract, and direct regression surface are known.

`docs/codex_token_economy.md` and `docs/ai_prompt_cheatsheet.md` are human-facing guidance; do not load them during ordinary implementation.

## Skills

Load a skill only when its specialized workflow is needed:
- GECS API/architecture: `.agents/skills/gecs-v8/SKILL.md`
- GUT authoring/execution: `.agents/skills/gut-testing/SKILL.md`
- Game-design work: `.agents/skills/professional-game-design/SKILL.md`

Do not load a skill merely because a task edits Godot/GDScript. Do not add generic Godot/GDScript/coding skills that duplicate this file; keep the skill set narrow unless the user explicitly requests a new specialized workflow.

## Subagents

Do not use subagents for ordinary navigation, implementation, or validation.

Use a project subagent only when the user explicitly requests delegation or a substantial completed diff has a genuinely independent bounded review/validation step. Available roles are `reviewer` and `validator`. Run at most one at a time and await it before starting another. Architecture, ownership, physics authority, GECS boundaries, input priority, and cross-system lifecycle decisions stay with the main agent.

## Work and checkpoints

For small/medium tasks, do not create bookkeeping files.

For a large interruptible task:
- detailed active scope belongs in `agent_tasks/<task>.md`;
- `CURRENT_WORK.md` is only a compact resume checkpoint and should otherwise remain `Status: none`;
- durable contracts belong in subsystem docs;
- completed work gets one concise dated line in `task_history.md`.

Create a local commit after each completed logical milestone when a task spans multiple stages. Do not push or open a PR unless requested.

## Validation cadence

Use the narrowest relevant validation.

For ordinary milestones:
- use deterministic/static checks such as `python utils/validate_project_structure.py`, changed-file formatter/lint when available, targeted inspection, and `git diff --check`;
- do not run GUT, smoke, or broad runtime validation after every small edit.

For a complete `Rxx` / `Rxx.x` implementation, normally run the relevant GUT surface once and one relevant headless smoke/runtime check near completion. An earlier runtime run is justified only by an explicit request or a blocking bug that static evidence cannot resolve.

Never launch rendered/visual Godot, capture screenshots/video, or perform agent-side visual scene inspection unless explicitly approved for the current task. Never claim a formatter, test, Godot run, or visual check passed unless it actually ran.
