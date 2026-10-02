# Godot PVZ In Hell — agent policy

Keep the default path short: start from the user's task and the exact files, symbols, errors, or scene/resource paths it names. Do not preload project documentation for general context.

## Hard invariants

- Runtime: Godot 4.7, GDScript, Forward Plus, Jolt Physics.
- GECS v8 is pinned under `addons/gecs/`; checked-out local source is the API authority. `addons/` is read-only unless dependency/addon work is explicitly requested.
- Project-owned GDScript is statically typed. When inference crosses Variant/untyped APIs, Array/Dictionary values, dynamic lookup, or broad Object/Node boundaries, declare the concrete type explicitly.
- Components contain data/state only. Behavior belongs in Systems, Observers, services/solvers, or thin Entity/engine glue.
- Authoritative live Entity-to-Entity ownership/session/binding uses Relationships under `content/relationships/<subsystem>/`. Derived caches may exist but are not co-authority.
- Project Systems are atomic: a System does not call another System as a service/helper. Use scheduling/dependencies plus Components, Relationships, and typed contracts.
- Godot physics bodies own physical transform/velocity unless an explicit synchronization contract says otherwise.
- Behavior/glue/UI members are private by default; all `@onready` members are private. Public mutable fields are for deliberate data/API contracts only.
- No unexplained gameplay magic constants. Use named constants or authored/data-driven values.
- Preserve scene/resource/data contracts unless migration is explicit: exported properties, node paths/names, signals, relationship/component ownership, resource paths, authored IDs.
- Preserve unrelated user edits. Do not rewrite unrelated history, force-push, upgrade dependencies, write authored files into `.godot/`, or use `gh`.

## Context routing

1. Start from the task and named code.
2. Inspect the authoritative owner, direct data/scene contract, direct callers/callees, and smallest regression surface.
3. Use `PROJECT_INDEX.md` only when ownership is unclear.
4. Read root/subsystem `CONTEXT.md` only when a concrete architecture, lifecycle, persistence, physics-authority, or cross-system fact is missing.
5. Read roadmap/task documents only for the exact tracked item being implemented or resumed.
6. Read `CURRENT_WORK.md` only when resuming prior unfinished work.

Stop exploring once owner, contract, and direct regression surface are known. Prefer exact symbol/path search and targeted ranges over recursive inventories or full-file dumps.

## Skills

Load skills only when their workflow is needed:
- implementation, bug fixing, refactoring, tracked-task execution, or substantial code review: `.agents/skills/develop/SKILL.md`;
- GECS-specific API/architecture: `.agents/skills/gecs-v8/SKILL.md`;
- GUT authoring/execution: `.agents/skills/gut-testing/SKILL.md`;
- player-facing game design: `.agents/skills/professional-game-design/SKILL.md`.

Do not load skills speculatively. Ordinary Godot/GDScript work does not require the GECS or GUT skill unless the task actually crosses those contracts.

## Godot AI MCP

Godot AI MCP is available as an optional live bridge to the editor and running game. Use it when it materially improves understanding, implementation, or validation; the agent should decide when it is useful rather than treating MCP as a mandatory step.

Prefer ordinary file/search/edit tools when they are simpler or cheaper. When using MCP, start with the relevant scene, subtree, node, resource, or log range and widen the inspection if the task benefits from more context. Large hierarchy/property/log dumps and visual captures are reasonable when they genuinely help, but do not collect them by default just because the tools are available.

If the MCP/editor is unavailable and live inspection is not essential, continue with normal repository tools instead of blocking the task. If live MCP access would materially help, the agent may start the project-local Godot editor with `.vscode/start-godot.ps1` and then retry the MCP connection; the helper already guards against duplicate editor launches.

## Subagents

Routine work stays in the main session. Use project subagents only when the user explicitly requests delegation or a substantial bounded review/validation step benefits from separate context:
- `reviewer` — read-only review of a substantial completed diff;
- `validator` — explicitly assigned bounded validation with compressed PASS/FAIL output.

Run at most one subagent at a time, including nested delegation. Await and integrate it before starting another. Architecture, ownership, physics authority, GECS boundaries, input priority, and cross-system lifecycle remain with the main agent.

## Work state and commits

Do not create bookkeeping for local fixes. For long or interruptible work, keep detailed state in the repository's existing task/roadmap file and keep `CURRENT_WORK.md` only as a compact resume checkpoint.

Commit completed logical milestones separately when a task spans multiple stages. Do not push or open a PR unless requested.

## Validation

Use the cheapest check that can falsify the change.

- Ordinary edits/milestones: targeted static/deterministic checks, changed-file formatter/lint where available, `python utils/validate_project_structure.py` when structure is affected, and diff inspection.
- Do not run GUT, smoke, or broad runtime checks after every small edit.
- GitHub GUT jobs that only need `global_script_class_cache.cfg` must use `bash utils/bootstrap_godot_class_cache.sh`, not `godot --import`. The helper exits immediately after Godot writes the script-class cache, before `EditorFileSystem::_update_scan_actions()` performs the expensive asset reimport pass (notably thousands of SVG/PNG files).
- For a complete large `Rxx` / `Rxx.x` implementation, normally run the relevant GUT surface once and one relevant headless smoke/runtime check near completion, unless the active task states otherwise.
- Starting the Godot editor solely to establish useful MCP access is allowed. Do not launch gameplay/rendered playtests, capture screenshots/video, or perform visual scene inspection unless explicitly approved for the current task.
- Never claim a formatter, test, engine run, or visual check passed unless it actually ran.

Keep reports concise: material findings first, then validation, then remaining owner QA.
