---
name: godot-scene-authoring
description: Required when modifying authored Godot .tscn scenes, placed entities, prefabs, levels or stable HUD layouts.
---

# Godot-first editable authoring (PVZ GECS)

The canonical scene-first boundary is in `content/ARCHITECTURE.md#scene-first-authoring`.
Inspect the nearest existing scene/controller, not the entire project.

- Stable world geometry, placed NPCs, physical interactive objects and permanent
  UI/HUD structure belong in editor-visible `.tscn`; authored configuration
  and reusable tuning belong in typed `.tres` Resources.
- Keep `E_*` entities thin: identity, GECS registration, physics callback and
  scene binding. `C_*` is data, `R_*` holds authoritative relationships,
  `S_*` scheduled behavior, `O_*` events. Never add a monolithic scene
  generator implementing all those roles.
- It is appropriate to `PackedScene.instantiate()` runtime actors, spawn
  effects and build repeated dynamic UI rows; genuinely procedural geometry
  must have an explicit owner and reason. Static UI layouts should remain
  inspectable in the Godot Scene dock.
- Runtime gameplay must not generate `.gd` scripts or permanently authored
  `.tscn`. Editor scripts/import processors may save native reviewed output.
## Active-editor ownership and mutation route

An opened `.tscn` and the `.tres` resources being edited in a live Godot Editor belong to
the editor's in-memory scene/resource model, not an external shell writer.

1. Check live `editor_state` / `scene_manage` and current selection before touching a
   scene. Respect dirty/unsaved user work; never use force-reload to erase it.
2. If the editor is open, **prefer live MCP authoring**: `scene_open`, `node_create`,
   `node_set_property`, `node_manage`, `resource_manage`, `scene_save`.
   For coherent repetitive edits use bounded `batch_execute` (only UndoRedo-backed
   steps are rollback-safe). Preserve sub-scene instance links and native owner/UID
   semantics. Confirm that `scene_open` completed before writing.
3. Never bypass editor ownership with PowerShell, Python, `git checkout`,
   `filesystem_manage(op="write_file")` or a direct text replacement of an open
   `.tscn`/`.tres`. MCP *filesystem* writes are external-file writes too.
4. Offline mass migration: with the graphical editor closed, prefer one native
   headless Godot SceneTree/MainLoop batch script using PackedScene + ResourceSaver over hand-writing
   the `.tscn` grammar. `utils/godot_agent.ps1 -Action OfflineScript` is guarded
   against an open project editor. Direct-file patches to provably closed scenes
   remain an exception for small, reviewable changes.
5. When MCP is missing while a target scene is open, do **not** fall back to a
   conflicting file rewrite. Work on code/tests, or arrange a controlled editor
   close before offline scene mutation. A generic MCP outage is **not** a reason
   to kill the user's editor.
6. While the editor runs, mutate `project.godot` through Godot's native
   `ProjectSettings` / `project_manage` / `autoload_manage` only. Such changes
   may still require a restart or encounter Godot's external-change modal.
   For *confirmed* `project.godot` blockage follow the recovery policy in
   [godot-ai-mcp](../godot-ai-mcp/SKILL.md); never auto-select
   `Ignore External Changes` or erase unsaved work without the authorized
   recovery procedure.

Use external editors for GDScript with native Godot syntax checks afterwards; do
not confuse an LSP/VS Code formatter pass with a successful Godot parse. Headless
parser/GUT/smoke validation remains available independently of MCP.
- Preserve node names, UIDs, ownership, signals, exported fields, physics and
  component/relationship contracts. `MeshInstance3D.material_overlay` is reserved
  for interactive highlights; authored highlight materials remain external `.tres`.
- Validate structural edits with `utils/validate_agent_changes.py`,
  strict role/domain checks and focused Godot parser/GUT. Visual/editor QA
  is for the owner; a headless PASS is not visual proof.
- Existing scripted `settings_menu.gd` is technical debt, not the
  default pattern. Do not mass-refactor it during unrelated fixes.

Before accepting a new feature, identify its state owner, native scenes,
resource definitions, API/command/events, and teardown; make review findings
BLOCKER/BUG/REVIEW explicit and resolve them before DONE.
