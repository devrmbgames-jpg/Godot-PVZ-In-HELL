# Godot PVZ In Hell — core agent rules

Start with the user's concrete task/path/symbol and the smallest relevant owner, callers and tests. Never preload all roadmap, history, project docs or skills. These are **always-on invariants**; domain-specific workflows live in skills below.

## Project and architecture boundaries

- Godot 4.7, GDScript, Forward Plus, Jolt Physics; pinned GECS v8 under `addons/gecs/`. Its checked-out API is authoritative. Do not modify/upgrade `addons/` during ordinary project work.
- GECS: Components (`C_*`) own data, Relationships (`R_*`) authoritative live bindings, Systems (`S_*`) scheduled work, Observers (`O_*`) reactive changes, Services explicit synchronous operations. One authoritative writer per mutable state. Never hide a System scheduler in `Service.tick()`, create a second authority or call Systems as services. Full contract: `content/ARCHITECTURE.md`; use `gecs-v8` skill when changing these boundaries.
- Godot/Jolt bodies own physical transforms/velocities. Preserve node paths/names, scene/resource UIDs, exported data, signals, authored IDs, persistence, GECS relationships and networking contracts unless migration is explicit.
- Author stable levels, placed visible NPCs/objects and permanent UI in native editable `.tscn`; authored settings/definitions in `.tres`. Procedural/dynamic content is allowed for actual runtime needs, never as an excuse to script-build a permanent level/UI or generate tracked `.gd` source at runtime.
- Project code: statically typed, human-readable GDScript. Keep GECS class prefixes `C_`, `S_`, `O_`, `R_`, `E_`, `DEF_`, `ET_`, `UI_` (not generic PascalCase). Code Style and documentation/region details belong in `gdscript-style`, not here.
- An explicitly requested full refactor completes its declared scope: no permanent old/new execution paths or duplicate owners. Keep unrelated work and existing user edits intact.

## Load skills only when needed

| Trigger | On-demand source |
| --- | --- |
| Any project-owned `.gd` creation/change | `.agents/skills/gdscript-style/SKILL.md` |
| GECS Components/Relationships/Systems/Observers, authority | `.agents/skills/gecs-v8/SKILL.md` |
| Explicit refactor or cross-domain migration | `.agents/skills/refactoring/SKILL.md` |
| New/edited `.tscn`, placed NPC, prefab or UI layout | `.agents/skills/godot-scene-authoring/SKILL.md` |
| Live editor, MCP, GDScript diagnostics or open scene | `.agents/skills/godot-ai-mcp/SKILL.md` |
| GUT test authoring/execution | `.agents/skills/gut-testing/SKILL.md` |
| Profiling, allocations, memory/lifetime/shutdown warnings | `.agents/skills/godot-performance/SKILL.md` |
| Substantial committed milestone, reviewer or fix triage | `.agents/skills/review-orchestration/SKILL.md` |
| Durable/interrupted task | `agent_tasks/README.md` |

For camera, input, physics, animations, shaders, UI/UX, NPC AI, LimboAI, Dialogue Manager, save systems and game design, select the matching skill by its description. Browse `.agents/skills/README.md` **only if the matching skill is unclear**. Do not preload the catalog or every skill.

## Efficient execution and durable state

- Read named source first; use `PROJECT_INDEX.md` only when ownership is unknown, `content/ARCHITECTURE.md` only for cross-system invariants, and subsystem docs only when needed. Stop browsing when owner/API/tests are known.
- Plan significant work via session Plan/Goal. Create/reuse one task under `agent_tasks/` only if work must survive sessions or the owner requests it. **`agent_tasks/README.md` is the task state and archiving authority**. No second queue, historical activity log or duplicated Current/Next.
- Batch related reads/edits and run tests after coherent changes, not every minor edit. Keep output concise; no full Godot logs unless needed for failure diagnosis.
- Compare evidence against an equivalent baseline before treating an unfamiliar defect as an in-scope regression. No unapproved scope creep or silent removal of required acceptance criteria.

## Parallel review pilot

- **Main is the only code writer.** At a coherent commit, pin `BASE_SHA..TARGET_SHA` for one read-only reviewer while Main continues **independent work**. Never review a moving working tree. Only one reviewer may work at a time, regardless of configured child-agent capacity; shared Godot/editor operations and validator runs remain sequential.
- Main triages provisional R1.. findings against the current HEAD and records durable RV-001.. only in the owning task. Accepted **P0/P1/P2** require scoped, verified fixes before DONE; P3 can be deferred with evidence. `REVIEW_PENDING`, unreviewed architecture or missing tests are not PASS.
- Collect and resolve review before significant milestone DONE. If native concurrent review is unavailable, report serial/non-independent review honestly. The full workflow is in `review-orchestration`; reviewer/validator role configs contain their own detailed contracts.

## Local validation and reporting

- GDScript changes: `python utils/check_gdscript_format.py --changed`; resolve parser/diagnostic errors and relevant warnings near the end of a coherent batch. Missing formatter = `NOT_RUN`, never PASS.
- Substantial gameplay/scene changes: run `python utils/validate_agent_changes.py`, `python -B utils/validate_architecture.py --strict`, and `python utils/validate_project_structure.py`. Run focused GUT/headless smoke at major acceptance boundaries, not after every edit; commit meaningful milestones separately.
- Do not launch rendered gameplay or perform subjective visual/gameplay QA without owner approval. Starting Godot **Editor** for MCP is allowed when necessary. Do not raw-edit a scene currently open in the editor; see `godot-ai-mcp`.
- Godot 4.7.1 shutdown-only GDScript/Resource/RID retention (`KNOWN_ENGINE_LIMITATION / DEFERRED`) is not itself a blocker. Preserve diagnostics, defer investigation until stable 4.8+ adoption; proven runtime leaks/use-after-free remain defects. Canonical evidence criteria: `godot-performance`.
- Report PASS/FAIL/NOT_RUN only for checks actually executed. Distinguish Godot/parser/GUT from manual device/visual QA.

## Git and workspace safety

- `master` is read-only; develop on `dev` or a user-specified branch. Do not push, merge or open PRs unless requested. Do not use GitHub CLI (`gh`).
- Preserve unrelated/uncommitted user edits. No bulk restore/reset/cleanup or forced dependency changes. Any destructive operation must target known task files; validate separately from cleanup/baseline mutation.
