# Godot PVZ In Hell — agent policy

Start from the user's task and its named paths, symbols, errors or scenes. Do not preload a repository map, roadmap or history. Inspect the smallest owner, contract and regression surface sufficient for the task.

## Non-negotiable project contracts

- Runtime: Godot 4.7.1, GDScript, Forward Plus, Jolt Physics. GECS v8 is pinned under `addons/gecs/`; the checked-out addon is its API authority. Third-party `addons/` are read-only unless addon work is explicit.
- GECS authority: Components own data/state; Relationships own live Entity-to-Entity bindings; Systems own scheduled behavior; Observers own discrete reactions; Services own explicit synchronous operations. Never disguise a System tick as a Service or introduce competing mutable authorities. Use [content/ARCHITECTURE.md](content/ARCHITECTURE.md#canonical-roles-and-ownership) when changing these boundaries.
- Godot physics bodies own their physical transform/velocity unless an explicit synchronization contract states otherwise. Preserve existing lifetime contracts; do not silently turn mandatory synchronous Entity/Component references into optional values.
- Scene-first: permanent levels, placed NPCs, physical actors and stable UI/HUD layouts are native editable `.tscn`; authored tuning/definitions are typed `.tres`. Runtime spawning and procedural effects are exceptions, not a substitute for editable authored content. Do not generate gameplay `.gd` or authored `.tscn` at runtime.
- Preserve exported properties, node paths/names, signals, authored IDs, scene/resource paths, relationships and Component ownership unless explicitly migrating their contracts.
- Project-owned GDScript is typed, human-readable and role-aware. Intentional `C_`, `S_`, `O_`, `R_`, `E_`, `DEF_`, `ET_`, `UI_` class prefixes must not be renamed to satisfy generic PascalCase lint. Use the `gdscript-style` skill for implementation rules.

## Repository and execution safety

- `master` is read-only. Normal work targets `dev`; create a separate branch if the user requests one.
- Preserve unrelated user edits and history. No bulk restore, destructive cleanup, force-push, dependency upgrades or edits inside generated `.godot/`. Use task-scoped Git operations only; do not depend on GitHub CLI (`gh`). Do not push, merge or open a PR without the user's request.
- Non-visual local Godot, parser, GUT, smoke and validation commands are allowed when relevant. Run/fix focused checks autonomously. Do **not** launch gameplay/rendered playtests, capture visual evidence or claim visual QA without the user's approval for that task.
- Godot AI MCP is optional, not a prerequisite to repository edits. If live editor context is needed, start Godot Editor via `.vscode/start-godot.ps1` when required; use `godot-ai-mcp`. Open scenes are editor-owned: use editor/MCP operations rather than raw `.tscn` patches. Never use "Ignore External Changes".

## Context and skill routing

- Start with named code; read `PROJECT_INDEX.md` only if ownership/path is unclear. Open `content/ARCHITECTURE.md` only for affected lifecycle, authority, physics, GECS, persistence or architecture contracts. Consult subsystem docs only when the edited contract needs them.
- For writing/editing project-owned `.gd`, load [gdscript-style](.agents/skills/gdscript-style/SKILL.md) once before editing; for completion checks load [validation-workflow](.agents/skills/validation-workflow/SKILL.md).
- For GECS implementation use [gecs-v8](.agents/skills/gecs-v8/SKILL.md); for native scene edits use [godot-scene-authoring](.agents/skills/godot-scene-authoring/SKILL.md); for GUT authoring/execution use [gut-testing](.agents/skills/gut-testing/SKILL.md).
- For explicitly broad refactors/architecture migrations use [refactoring](.agents/skills/refactoring/SKILL.md); for durable multi-session `agent_tasks/` state use [task-lifecycle](.agents/skills/task-lifecycle/SKILL.md); for substantial committed milestone review/triage use [review-orchestration](.agents/skills/review-orchestration/SKILL.md).
- Select other domain skills (physics, AI, Dialogue Manager, save, UI, input, shaders, performance, animation, camera, combat) by their `SKILL.md` descriptions. Load only relevant skills and supporting references, not the entire skills directory.

Stop exploring when owner, contract and regression surface are understood. Batch related reads, changes and checks where safe; never reduce actual verification quality to save tool calls.

## Completion and review

- Small fixes: focused edit, relevant verification and concise result. For non-trivial work, use Plan Mode when useful and a clear completion condition. Do not create `agent_tasks/` bookkeeping merely because a plan exists; `task-lifecycle` governs persistent checkpoints and archiving.
- Finish the declared scope before marking DONE. Independent defects need their own evidenced scope; do not silently broaden a task or waive required acceptance. Explicit broad refactors must not leave permanent dual old/new execution paths.
- Validate coherent batches rather than every tiny edit. Use the [validation workflow](.agents/skills/validation-workflow/SKILL.md) for the appropriate formatter/parser/static/GUT/smoke gates. No test, MCP inspection, review or visual check is PASS unless it actually ran.
- On substantial committed changes, main is the sole code writer and review manager; at most one native child agent works at a time. Reviewer must inspect immutable Git SHAs read-only. Collect and triage review before DONE; do not disguise REVIEW_PENDING/NOT_RUN as PASS. Details belong to `review-orchestration`.
- Commit coherent milestones for lengthy work. Report material findings, checks performed (PASS/FAIL/NOT_RUN) and remaining owner gameplay/visual QA.

## Known engine limitation

Godot 4.7.1 editor/process **shutdown-only** retention warnings for `GDScript`, `GDScriptNativeClass`, `Resource`, `StringName` and RID are `KNOWN_ENGINE_LIMITATION / DEFERRED` by owner decision. Preserve logs, but do not block tasks, initiate a standalone leak investigation or change ownership/typing solely to clear them before stable Godot 4.8+ and upstream-fix review (4.7.2 is not planned). Gameplay growth, leaked live Nodes, use-after-free, double-free and actual lifecycle bugs still require fixes. For evidence and testing see [memory/lifetime diagnostics](.agents/skills/validation-workflow/references/memory-lifetime.md).
