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
- A scene open/loaded in Godot Editor is editor-owned. Use Godot Editor or MCP
  scene operations while it is open; raw `.tscn` patches are allowed only when
  it is not open. If editor state blocks a needed update, close the editor,
  update the file, then relaunch if needed. Never select "Ignore External Changes".
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
