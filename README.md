# Codex Godot 4.7 + GECS Agent Kit

Portable project setup for Codex / AI coding agents working with:

- Godot Engine 4.7
- GDScript with strict project style/typing rules
- GECS
- GDQuest GDScript Formatter
- VS Code
- GUT
- Professional game-design rules
- Low-token project navigation
- Long-task/context-limit recovery

## Install

Copy the contents of this archive into the root of your Godot project.

Then edit:
- `CONTEXT.md` — stable project facts and subsystem routing;
- `PROJECT_INDEX.md` — short canonical code map, not a full file manifest;
- `.agents/skills/project-rules/SKILL.md` — project-specific architecture rules if needed;
- GECS/GUT dependency pins in `CONTEXT.md` and `PROJECT_INDEX.md`.

## Important defaults

- `addons/` is read-only unless the user explicitly requests addon/dependency work.
- Project-owned filenames use `snake_case`.
- Inspector Node names use `PascalCase`.
- Classes use `PascalCase`; GECS prefixes such as `C_`, `S_`, `O_`, `DEF_`, `E_`, `R_` are allowed.
- Static typing is required.
- Shadowed variables/parameters/members/types are treated as errors.
- Functions are grouped by responsibility.
- Untyped collection/API results are explicitly typed/cast before use.

## Recommended first prompt to Codex

> Read AGENTS.md, CURRENT_WORK.md, CONTEXT.md and PROJECT_INDEX.md. Load only the skills relevant to this task. Do not scan the whole repository and do not modify addons/.

## Navigation model

```text
AGENTS.md
  -> CONTEXT.md
  -> PROJECT_INDEX.md
  -> subsystem CONTEXT.md
  -> exact symbol/file
  -> direct callers/callees only
```

If `PROJECT_INDEX.md` is missing, the agent should create a small one from top-level structure and current-task entry points. It must not enumerate every file.

## Long tasks

Use:
- `WORK.md` — checklist;
- `CURRENT_WORK.md` — crash/context-limit checkpoint;
- `agent_tasks/<task>.md` — only for genuinely large multi-session tasks.
