# PVZ In Hell Simulator — Codex setup

Godot 4.7 + GDScript + GECS v8 project.

## AI workflow

Codex automatically receives the short project rules from `AGENTS.md`. Do not start a task by preloading `CONTEXT.md`, `PROJECT_INDEX.md`, checkpoints, roadmap files, or multiple skills.

Default path:

```text
user task
  -> exact named symbol/path
  -> direct owner + contract + callers/tests
  -> edit
  -> narrow validation
```

Use `PROJECT_INDEX.md` only when the owning subsystem is unclear. Use a `CONTEXT.md` only when a concrete architecture/dependency contract is missing. Read `CURRENT_WORK.md` only when resuming unfinished work.

Specialized skills are intentionally limited to:
- `.agents/skills/gecs-v8/SKILL.md`
- `.agents/skills/gut-testing/SKILL.md`
- `.agents/skills/professional-game-design/SKILL.md`

Subagents are opt-in for substantial independent review/validation, not a default navigation or implementation layer.

## Important defaults

- `addons/` is read-only unless dependency work is explicitly requested.
- Static typing is required for project-owned GDScript.
- GECS Systems are atomic and do not call other Systems as services.
- Rendered/visual Godot validation is user-owned unless explicitly approved for the current task.
- Do not run broad GUT/smoke/runtime validation after each small edit; batch it near completion of a large implementation task.

See `AGENTS.md` for the authoritative agent rules.
