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
| Durable/interrupted `agent_tasks
