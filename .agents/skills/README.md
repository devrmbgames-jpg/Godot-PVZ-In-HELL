# PVZ agent skills — on-demand index

**Do not preload this catalog.** `AGENTS.md` holds the always-on contract
(target **8 KiB or less** and within `project_doc_max_bytes`).
Load only the matching `SKILL.md` based on its frontmatter (`name`, `description`).
Do not re-copy canonical memory, task-state or MCP rules into root instructions.

| Work area | Skill |
| --- | --- |
| Any GDScript implementation | `gdscript-style` |
| GECS components, relationships, systems, observers, state authority | `gecs-v8` |
| Cross-domain migration and explicit full refactor | `refactoring` |
| Main + read-only reviewer, triage, fix loop | `review-orchestration` |
| Godot editor/MCP scripts, scene edits and live diagnostics | `godot-ai-mcp` |
| Scene-first editable actors, level geometry and UI | `godot-scene-authoring` |
| GUT test authoring/execution | `gut-testing` |
| Measured FPS, profiler, allocations, runtime lifetime and 4.7.1 retention | `godot-performance` |
| Jolt/physics integration | `godot-physics-4.7` |
| AnimationPlayer/Tree/Tween | `godot-animation-4.7` |
| Shader/material work | `godot-shaders-4.7` |
| Character movement/combat | `first-person-combat` |
| Cameras and control smoothing | `camera-systems` |
| Input/rebinding/focus | `input-systems` |
| Menus/HUD/accessibility | `game-ui-ux` |
| GECS NPC logic | `game-ai` |
| LimboAI | `limboai-v1.8` |
| Branching dialogue and response actions | `dialogue-systems` |
| Dialogue Manager v4.1 syntax | `dialogue-manager-v4.1` |
| Persistence/save & load contracts | `save-systems` |
| Product-oriented game design | `professional-game-design` |

Durable task lifecycle and completed-task archives have a single canonical
document: `agent_tasks/README.md`, not another general-purpose skill.
Architecture ownership: `content/ARCHITECTURE.md`. Instructions are selected
by task; do not read every table row's skill.
