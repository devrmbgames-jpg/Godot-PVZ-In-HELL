# Godot PVZ In Hell — agent policy

Start from the user's task and the exact files, symbols, errors, scenes, or resources it names. Do not preload roadmap/history/project documentation for general context.

## Hard invariants

- Runtime: Godot 4.7, GDScript, Forward Plus, Jolt Physics.
- GECS v8 is pinned under `addons/gecs/`; checked-out source is the API authority. `addons/` is read-only unless addon/dependency work is explicit.
- Project-owned GDScript is statically typed. Declare concrete types when inference crosses Variant/untyped APIs, containers, dynamic lookup, or broad Object/Node boundaries. Avoid local/member/parameter names that shadow existing or inherited properties/methods.
- Project-owned GDScript is written for humans first: clarity and explicit intent take priority over cleverness or brevity. Give each script a short `##` description; document public variables, every `@export` field, signals, and public methods with concise `##` comments; group methods by responsibility inside named `#region ...` / `#endregion` blocks. Inside non-trivial functions, separate distinct logical phases with a single blank line and add a short intent comment above non-obvious multi-step blocks. Do not compress setup, guards, state changes, side effects, and follow-up work into one dense uninterrupted block. Keep closely related statements together and do not add blank lines or comments mechanically.
- Components contain data/state. Relationships own authoritative live Entity-to-Entity bindings. Systems are scheduled behavior and do not call other Systems as services. Reusable imperative logic belongs in services/solvers/observers or thin Entity/engine glue.
- Godot physics bodies own physical transform/velocity unless an explicit synchronization contract says otherwise.
- Preserve scene/resource/data contracts unless migration is explicit: exported properties, node names/paths, signals, authored IDs, relationship/component ownership, and resource paths.
- Behavior/glue/UI members are private by default; all `@onready` members are private. Public mutable fields are deliberate data/API contracts only.
- Avoid unexplained gameplay constants; use named constants or authored/data-driven values.
- Preserve unrelated user edits. Do not rewrite unrelated history, force-push, upgrade dependencies, write authored files into `.godot/`, or use `gh`.
- `master` is read-only. Normal development targets `dev`; use a separate branch when the user requests one.
- `MeshInstance3D.material_overlay` is reserved for interactive feedback/highlights; authored highlight materials are external editable resources.

## Context routing

1. Start from named code and inspect only its owner, direct contract, direct callers/callees, and smallest regression surface.
2. Use `PROJECT_INDEX.md` only when ownership/path is unclear.
3. Read `content/ARCHITECTURE.md` only when a cross-system lifecycle, authority, persistence, physics, or GECS invariant is actually needed.
4. Read subsystem/design docs only when the edited contract depends on them.
5. Read an `agent_tasks/*.md` file only when the user references that task or durable cross-session state is needed.

Stop exploring once owner, contract, and regression surface are known. Prefer exact symbol/path search and targeted ranges over recursive inventories or full-file dumps.

## Tool batching and reasoning efficiency

- Prefer coherent batches of related reads, edits, and validations over many tiny tool calls.
- Before calling a tool, consider whether several independent operations can safely be combined.
- Avoid alternating `reason -> read one file -> reason -> read one file` when the needed files are already known.
- Validate after a coherent implementation batch, not after every small edit.
- Do not reduce verification quality to save time.

## Plan, Goal, and durable task state

Use the session's Plan Mode for non-trivial investigation/approach when planning is useful. Use a Goal as the active completion condition for multi-step work.

Do not create repository bookkeeping merely because a plan exists. Create or reuse `agent_tasks/<task>.md` only when state must survive another session/thread, the work is genuinely long/interruptible, or the user explicitly asks for durable tracking.

One durable task file owns its own status/current/next/validation. There is no separate queue, current-work, or task-history source of truth. Git history is the implementation history; design docs describe durable product contracts; `qa_tasks/` owns remaining manual acceptance.

## Specialized skills

Load a skill only when its domain is actually involved:
- creating or modifying project-owned GDScript: `.agents/skills/gdscript-style/SKILL.md`;
- GECS-specific API/architecture: `.agents/skills/gecs-v8/SKILL.md`;
- GUT test authoring/execution: `.agents/skills/gut-testing/SKILL.md`;
- Godot AI MCP, GDScript parser diagnostics, live ClassDB/scene/editor inspection: `.agents/skills/godot-ai-mcp/SKILL.md`;
- Godot 4.7/Jolt physics bodies, contacts, joints and queries: `.agents/skills/godot-physics-4.7/SKILL.md`;
- Godot 4.7 AnimationPlayer/AnimationTree/Tween work: `.agents/skills/godot-animation-4.7/SKILL.md`;
- Godot 4.7 shaders/material parameters and shader-performance work: `.agents/skills/godot-shaders-4.7/SKILL.md`;
- measured Godot performance/profiling/optimization work: `.agents/skills/godot-performance/SKILL.md`;
- NPC decision architecture, sensing, navigation intent and utility/BT composition: `.agents/skills/game-ai/SKILL.md`;
- LimboAI v1.8.1 behavior trees/HSM/Blackboard/custom tasks: `.agents/skills/limboai-v1.8/SKILL.md`;
- Customer/NPC dialogue branching, response tags and dialogue-side actions: `.agents/skills/dialogue-systems/SKILL.md`;
- Dialogue Manager v4.1.0 syntax/API, `.dialogue` resources, cues/conditions/mutations and custom runtime integration: `.agents/skills/dialogue-manager-v4.1/SKILL.md`;
- persistence, stable-ID serialization, schema migration and save/load: `.agents/skills/save-systems/SKILL.md`;
- player input/rebinding/deadzones and control-focus routing: `.agents/skills/input-systems/SKILL.md`;
- first/third-person camera ownership, smoothing, recoil/shake and camera bugs: `.agents/skills/camera-systems/SKILL.md`;
- HUD/menu/dialogue UI layout, focus, modal lifecycle and accessibility: `.agents/skills/game-ui-ux/SKILL.md`;
- first-person combat targeting/feel and damage-boundary composition: `.agents/skills/first-person-combat/SKILL.md`;
- player-facing game design: `.agents/skills/professional-game-design/SKILL.md`.

Ordinary Godot/GDScript implementation does not require a general-purpose workflow skill. For any creation or modification of project-owned GDScript, load `gdscript-style` once before the first implementation edit.

## Godot AI MCP

Codex loads the Godot AI MCP entry from the user-level `~/.codex/config.toml` (or `$CODEX_HOME/config.toml` when overridden). Do not duplicate the server entry in project config. Godot AI MCP is optional live editor/runtime context, not a mandatory step.

Prefer ordinary file/search/edit tools when cheaper. Use MCP when live scene tree, node/resource state, editor diagnostics, ClassDB introspection, or runtime state materially improves the task. For changed project-owned GDScript, use the Godot parser/diagnostics near completion; MCP `script_patch`/`script_create` is the preferred path when the editor is available. Query the smallest relevant scene/subtree/resource/log range first and widen only when useful.

If live MCP access matters and the editor is not running, the agent may start it with `.vscode/start-godot.ps1`. Do not launch gameplay/rendered playtests, capture visual evidence, or perform subjective visual validation unless the user explicitly approved it for the task.


### Scene ownership

- Treat opened `.tscn` scenes in Godot Editor as editor-owned.
- Do not modify an editor-owned `.tscn` through raw filesystem/text patches.
- When a scene is open or loaded in the editor, prefer Godot AI MCP scene operations.
- Raw `.tscn` edits are allowed only when the scene is not open in Godot.
- Never choose or rely on "Ignore External Changes" as part of automated workflow.

## Subagents

Routine work stays in the main GPT-6.1 Sol session. Optional native Codex subagents:
- `reviewer` — read-only focused review of a substantial completed diff;
- `validator` — explicitly assigned bounded validation with concise PASS/FAIL output.

Run at most one subagent at a time and integrate it before starting another. Architecture/ownership/physics/GECS decisions remain with the main agent.

## Validation and commits

Use the cheapest check that can falsify the change. Do not run GUT, smoke, or broad runtime checks after every small edit.

- Run changed-file/static checks and `python utils/validate_project_structure.py` when structure/contracts are affected.
- Before completing GDScript work, validate the changed project-owned `.gd` files with Godot's parser near the end of the coherent edit batch. Resolve new/relevant parse or reload warnings as well as errors; do not launch gameplay merely for this check.
- For a complete large implementation, normally run one relevant GUT surface and one relevant headless smoke/runtime check near completion unless the exact task says otherwise.
- Never claim a test, formatter, engine run, MCP inspection, or visual check passed unless it actually ran.
- Commit coherent milestones separately for long work. Do not push, merge, or open a PR unless requested.
- Runnable Windows QA builds under `.export/` are for completed large gameplay milestones, not documentation/config-only changes.

Report material findings first, then validation, then remaining owner QA.
