# PVZ In Hell Simulator — agent-ready Godot project

Godot 4.7 + GDScript + GECS v8.

## AI workflow

Codex automatically receives the compact invariants from `AGENTS.md`. Ordinary work should not preload the project context, roadmap, task queue, or multiple skills.

Default implementation path:

```text
user task
  -> exact named symbol/path
  -> investigate direct owner + contract + regression surface
  -> classify Fix / Task / Feature
  -> plan only enough
  -> implement
  -> independent review
  -> narrow validation
```

Use the on-demand `develop` skill for implementation/refactoring work. It loads `gecs-v8`, `gut-testing`, or `professional-game-design` only when the task actually needs those workflows.

Task state is split deliberately:
- `agent_tasks/CONTEXT.md` — queue/status index;
- exact `agent_tasks/<task>.md` / roadmap router — authoritative durable state;
- `CURRENT_WORK.md` — only the current resume pointer/checkpoint;
- `task_history.md` — completed-history summary;
- `docs/roadmap/` — design/source specifications, not parallel task state.

## Important defaults

- `addons/` is read-only unless dependency work is explicit.
- Static typing is required for project-owned GDScript.
- Components are state; Relationships own live Entity-to-Entity bindings; Systems do not call other Systems as services.
- Godot physics bodies retain physical authority unless a documented synchronization contract says otherwise.
- Subagents are optional bounded reviewer/validator roles and run sequentially.
- Do not run broad GUT/smoke/runtime validation after every edit; reserve runtime checks for the task's documented validation stage.
- Rendered/visual Godot validation is user-owned unless explicitly approved.

See `AGENTS.md` for authoritative always-on rules.
