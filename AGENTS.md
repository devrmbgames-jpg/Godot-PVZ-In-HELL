# Codex / Agent Instructions

This is the agent entry point. Keep this file short; load detailed rules only when needed.

## Start here

1. Read `CURRENT_WORK.md`. If it describes an active matching task, resume from its exact next step.
2. Read root `CONTEXT.md`.
3. Read `PROJECT_INDEX.md`. Treat it as the primary map of canonical entry points.
4. Read only the nearest subsystem `CONTEXT.md` named by `CONTEXT.md` / `PROJECT_INDEX.md`.
5. Load only the relevant skill(s) from `.agents/skills/`. Start with at most two; add another only when the task crosses that boundary.
6. Inspect only the named implementation files and their direct callers/callees. Prefer exact symbol/path searches over broad repository scans.

Do not reread documents already summarized in `CURRENT_WORK.md` unless they changed or the summary is insufficient.

## Skill router

- Project architecture or any code change: `.agents/skills/project-rules/SKILL.md`
- Project discovery/navigation/index maintenance: `.agents/skills/project-navigation/SKILL.md`
- Godot APIs, scenes, physics, lifecycle: `.agents/skills/godot-4-7/SKILL.md`
- GDScript coding/style/type rules: `.agents/skills/gdscript-style/SKILL.md`
- GECS components/systems/observers/queries: `.agents/skills/gecs-v8/SKILL.md`
- GDScript formatting/linting: `.agents/skills/gdscript-format/SKILL.md`
- VS Code/Codex editor workflow: `.agents/skills/vscode-workflow/SKILL.md`
- Tests or test infrastructure: `.agents/skills/gut-testing/SKILL.md`
- Mechanics, balance, progression, game feel, level/pacing decisions: `.agents/skills/professional-game-design/SKILL.md`
- Multi-step work, context pressure, interruption recovery: `.agents/skills/agent-continuity/SKILL.md`

## Hard boundaries

- **Never modify anything under `addons/` unless the user explicitly requests dependency/addon work.**
- Treat `addons/` as read-only reference code.
- Do not upgrade, reformat, patch, rename, or "clean up" addon files during gameplay/project work.
- The engine/framework version declared by the repository wins.
- Target Godot 4.7 unless the repository explicitly says otherwise.
- Treat the checked-out GECS version as API authority; do not silently use newer upstream APIs.
- Godot physics bodies own transform/velocity unless an explicit sync contract says otherwise.
- Never claim a formatter, Godot run, or test passed unless it actually ran successfully.

## GDScript baseline

- Static typing is required.
- File names are `snake_case`, except raw source assets that intentionally preserve external/vendor naming.
- Inspector Node names are `PascalCase`.
- Class names are `PascalCase`. GECS role prefixes such as `C_`, `S_`, `O_`, `DEF_`, `R_`, `E_` are allowed.
- Never shadow variables, parameters, members, globals, or class/native names in nested/local scopes.
- When reading from an untyped collection or Variant-producing API, explicitly type/cast the result.
- Group functions by responsibility; do not intermix lifecycle callbacks, public API, signal/UI callbacks, and private helpers.

Detailed rules: `.agents/skills/gdscript-style/SKILL.md`.

## Work protocol

For a sizable task, create/update `WORK.md` before editing. For long or interruptible work, keep `CURRENT_WORK.md` current after each meaningful milestone.

Keep only unfinished task files in `agent_tasks/`. After a task is completed and validated:
- preserve lasting architecture, contracts and usage instructions in the relevant context/docs;
- append one short line to root `task_history.md`: `- YYYY-MM-DD — completed result` (no logs, checklists or duplicate entries);
- delete the completed task file from `agent_tasks/` and update references to it;
- return `WORK.md` and `CURRENT_WORK.md` to idle when no active task remains.

Do not delete active/blocked tasks or `agent_tasks/README.md`. Routine cleanup of completed task files is authorized; no additional confirmation is needed.

Make small thematic changes. Validate the narrowest affected surface first.

Do not manually write files into `.godot/`; it is engine-managed technical storage. Place all test scripts, temporary test scenes and test artifacts under `res://tests/`.
Do not add new GUT tests without the user's explicit instruction.

Before finishing:
1. format/check changed GDScript when the formatter is available;
2. run project static checks;
3. run targeted GUT tests when installed and relevant;
4. broaden testing only when warranted.

Use git directly. Do not force-push, discard user edits, rewrite unrelated history, or upgrade dependencies unless requested.

## Token and context budget

- Use `PROJECT_INDEX.md` before searching the repository.
- Do not read the project file-by-file or directory-by-directory.
- Do not recursively inspect unrelated folders "to understand the project."
- Search exact class/function/component/resource names first.
- Read only the smallest useful files/ranges.
- If `PROJECT_INDEX.md` is missing or stale, create/update a **small canonical index**, not a full manifest.
- Record durable facts and decisions in project files instead of repeatedly explaining them.
- Keep `CURRENT_WORK.md` factual and compact; never paste full logs or diffs into it.
- If context is becoming large, checkpoint immediately.
- Prefer deterministic tools (formatter, tests, static checks) over repeated prose review.
