# Godot PVZ In Hell — agent policy

Start from the user's task and the exact files, symbols, errors, scenes, or resources it names. Do not preload roadmap/history/project documentation for general context.

## Hard invariants

- Runtime: Godot 4.7, GDScript, Forward Plus, Jolt Physics.
- GECS v8 is pinned under `addons/gecs/`; checked-out source is the API authority. `addons/` is read-only unless addon/dependency work is explicit.
- Project-owned GDScript is statically typed. Declare concrete types when inference crosses Variant/untyped APIs, containers, dynamic lookup, or broad Object/Node boundaries. Avoid local/member/parameter names that shadow existing or inherited properties/methods.
- Project-owned GDScript is written for humans first: clarity and explicit intent take priority over cleverness or brevity. Give each script a short `##` description; document public variables, every `@export` field, signals, and public methods with concise `##` comments; group methods by responsibility inside named `#region ...` / `#endregion` blocks. Inside non-trivial functions, separate distinct logical phases with a single blank line and add a short intent comment above non-obvious multi-step blocks. Do not compress setup, guards, state changes, side effects, and follow-up work into one dense uninterrupted block. Keep closely related statements together and do not add blank lines or comments mechanically.
- Components contain data/state. Relationships own authoritative live Entity-to-Entity bindings. Systems own scheduled behavior and do not call other Systems as services. Services own explicit synchronous operations; extracting a recurring tick into a Service does not change its scheduled ownership. Canonical role/selection rules live in [content/ARCHITECTURE.md](content/ARCHITECTURE.md#canonical-roles-and-ownership).
- Typed records nested in an ECS-owned Component may form an aggregate with one explicit writer; they are not a second runtime model merely because they are Resources. Mark derived caches, immutable identity references and terminal history; reject competing mutable authorities.
- Godot physics bodies own physical transform/velocity unless an explicit synchronization contract says otherwise.
- Preserve scene/resource/data contracts unless migration is explicit: exported properties, node names/paths, signals, authored IDs, relationship/component ownership, and resource paths.
- Scene-first authoring: permanent levels, visible placed NPC/objects, reusable physical actors and stable UI/HUD layouts belong in editable native `.tscn`; authored definitions/tuning belong in typed `.tres`. Dynamic spawn/procedural effects are exceptions, not a shortcut for writing permanent scene trees in `_ready()`. Never generate gameplay source `.gd` or authored `.tscn` from runtime.
- A large `S_*` System is acceptable when it has one coherent scheduled responsibility; do not hide its tick in a Service just to reduce line count. Do not add more unrelated responsibilities to an existing large script or create one-shot generators that replace editable authored content.
- Human-readable `class_name` role prefixes `C_`, `S_`, `O_`, `R_`, `E_`, `DEF_`, `ET_`, `UI_` are intentional. Never rename them to satisfy generic `PascalCase` lint. Project style checks disable only the generic `class-name` rule and independently verify valid role-aware names.
- Behavior/glue/UI members are private by default; all `@onready` members are private. Public mutable fields are deliberate data/API contracts only.
- Avoid unexplained gameplay constants; use named constants or authored/data-driven values.
- Synchronous gameplay code trusts its required lifetime/type/component contracts. Do not scatter `null` / `is_instance_valid()` guards over mandatory Entity/Node arguments, required Components, or `ECS.world`. Revalidate only when a reference intentionally crossed a time/lifetime boundary (deferred/queued call or signal, queued World event/request, `await`/timer, stored callback/reference) or when the value is explicitly optional. For suspicious invariant violations, prefer a side-effect-free `assert(...)` in debug code over silently returning; fix the owner/lifecycle contract instead of normalizing invalid state.
- Preserve unrelated user edits. Do not rewrite unrelated history, force-push, upgrade dependencies, write authored files into `.godot/`, or use `gh`.
- When the user explicitly requests a broad refactor, complete the declared migration to its target architecture instead of leaving permanent old/new parallel paths, compatibility wrappers, duplicate authority, or renamed-but-unmigrated ownership. Temporary adapters are allowed only inside the same unfinished milestone; if they cannot be removed, the milestone is not DONE.
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

Task files describe current state, not an activity log. Keep the goal, acceptance, important architectural decisions, latest checkpoint/next action, relevant validation evidence and unresolved findings. A new checkpoint replaces obsolete Current/Next and validation entries; do not append a chronological account of every action, test run or diagnostic experiment. Preserve unique evidence through concise results and links to manifests/reproductions, and use full Git SHAs for review/fix checkpoints.

Keep each task within its declared scope. Classify suspected regressions with comparable baseline/current evidence before expanding implementation. Independent defects get separate owning tasks with evidence, reproduction and acceptance; link any remaining dependency from the original task. Moving a defect does not waive an existing mandatory criterion: if changing that criterion is necessary, record the exact owner decision needed and keep acceptance open. Uncontrolled scope expansion is prohibited.

Aim for at most 200 lines in an active task file. An exception needs a substantive explanation of the indispensable current contracts/evidence; accumulated history or repeated test results are not justification. Do not move the same activity log to an auxiliary report or duplicate Current/Next in an index.

When a task reaches DONE after its required validation/review, move its existing task file to `agent_tasks/completed/<original relative path>` in the same completion batch. Preserve its status, evidence and original subdirectory structure; update incoming links and relative links inside the moved file. Do not leave a duplicate or forwarding task file in the active directory. Tasks with unfinished implementation, pending review, blockers or owner acceptance stay active under their actual status. The archive preserves completed task records, not a separate queue or history log.

## Specialized skills

Load a skill only when its domain is actually involved:
- explicit broad refactoring, architecture migration, subsystem decomposition, or repository-wide cleanup: `.agents/skills/refactoring/SKILL.md`;
- substantial committed milestones or explicit parallel review/triage: `.agents/skills/review-orchestration/SKILL.md`;
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
- creating or substantially altering authored `.tscn`, placed NPCs, levels or stable HUD/menu layouts: `.agents/skills/godot-scene-authoring/SKILL.md`;
- first-person combat targeting/feel and damage-boundary composition: `.agents/skills/first-person-combat/SKILL.md`;
- player-facing game design: `.agents/skills/professional-game-design/SKILL.md`.

Ordinary Godot/GDScript implementation does not require a general-purpose workflow skill. For any creation or modification of project-owned GDScript, load `gdscript-style` once before the first implementation edit.

## Godot AI MCP

Codex loads the Godot AI MCP entry from the user-level `~/.codex/config.toml` (or `$CODEX_HOME/config.toml` when overridden). Do not duplicate the server entry in project config. Godot AI MCP is optional live editor/runtime context, not a mandatory step.

Prefer ordinary file/search/edit tools when cheaper. Use MCP when live scene tree, node/resource state, editor diagnostics, ClassDB introspection, or runtime state materially improves the task. For changed project-owned GDScript, use the Godot parser/diagnostics near completion; MCP `script_patch`/`script_create` is the preferred path when the editor is available. Query the smallest relevant scene/subtree/resource/log range first and widen only when useful.

If live MCP access matters and the editor is not running, the agent may start it with `.vscode/start-godot.ps1`. Do not launch gameplay/rendered playtests, capture visual evidence, or perform subjective visual validation unless the user explicitly approved it for the task.

If MCP needs Godot, launch Godot automatically.
If the Editor blocks MCP because a scene or project file must be updated, close Godot, apply the update, and relaunch it if needed.

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

**Parallel reviewer pilot:** once a coherent implementation checkpoint is committed, Main may spawn the read-only `reviewer` on explicit, immutable `BASE_SHA..TARGET_SHA` and continue only **independent work** during its analysis. Exactly one child agent at a time; reviewer may not edit code/tasks, run Godot/MCP or inspect changing source via live worktree. Main is the only code writer and Review Manager. Read the `review-orchestration` skill on substantive milestones.

The review must be collected, triaged and integrated before milestone DONE even if GUT passes. Reviewer returns provisional R1..; Main accepts/rejects, deduplicates, assigns and, where needed, records RV-001.. in the **owning** `agent_tasks/` file, not a new global queue. Accepted P0/P1/P2 block DONE until fixed/verified; P3 may be explicitly deferred. Revalidate findings if HEAD advanced. Do not fabricate PASS while a review is REVIEW_PENDING or unavailable; if no isolated parallel subagent is possible, use sequential review and mark NON_INDEPENDENT if self-reviewed. See `docs/parallel_review_workflow.md`.

## Validation and commits

Use the cheapest check that can falsify the change. Do not run GUT, smoke, or broad runtime checks after every small edit.

- For project-owned GDScript, run `python utils/check_gdscript_format.py --changed` before a coherent commit. It checks changed lines/new files without rewriting unrelated legacy code. Missing GDQuest `gdscript-formatter` is **NOT_RUN (exit 2)**, never PASS. To check a committed milestone compare with its original base using `--base <revision>`; Phase 3 uses `--strict`.
- For substantial code/scene work, run `python utils/validate_agent_changes.py`, `python -B utils/validate_architecture.py --strict`, and `python utils/validate_project_structure.py` after the coherent batch. A pinned-SHA architecture review must finish and receive triage before milestone DONE. `validate_agent_changes.py --staged` checks the Git index; `--report-only` is **not** a valid PASS. Static checks supplement architectural review, not replace it.
- Run changed-file/static checks and `python utils/validate_project_structure.py` when structure/contracts are affected.
- Before completing GDScript work, validate the changed project-owned `.gd` files with Godot's parser near the end of the coherent edit batch. Resolve new/relevant parse or reload warnings as well as errors; do not launch gameplay merely for this check.
- For a complete large implementation, normally run one relevant GUT surface and one relevant headless smoke/runtime check near completion unless the exact task says otherwise.
- Never claim a test, formatter, engine run, MCP inspection, or visual check passed unless it actually ran.
- Commit coherent milestones separately for long work. Do not push, merge, or open a PR unless requested.
- Runnable Windows QA builds under `.export/` are for completed large gameplay milestones, not documentation/config-only changes.

Report material findings first, then validation, then remaining owner QA.


## Working tree safety

- Never bulk-restore modified files based only on directory or filename patterns.
- Do not discard pre-existing or unrelated working-tree changes.
- `git restore`, baseline pruning, generated-file cleanup, and other destructive mutations must target only files known to belong to the current task.
- Run validation separately from destructive cleanup or baseline mutation.
