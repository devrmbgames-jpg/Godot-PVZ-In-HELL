---
name: godot-scene-authoring
description: Required for editing native Godot .tscn scenes, placed GECS entities, UI/HUD layouts, reusable prefabs or level authoring; distinguishes designer-owned scenes from dynamic procedural runtime objects.
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
- Prefer editor/MCP mutations for a scene currently open in Godot, and raw
  edits only while it is closed. Preserve node names, UIDs, ownership, signals,
  exported fields, physics and component/relationship contracts.
- Validate structural edits with `utils/validate_agent_changes.py`,
  strict role/domain checks and focused Godot parser/GUT. Visual/editor QA
  is for the owner; a headless PASS is not visual proof.
- Existing scripted `settings_menu.gd` is technical debt, not the
  default pattern. Do not mass-refactor it during unrelated fixes.

Before accepting a new feature, identify its state owner, native scenes,
resource definitions, API/command/events, and teardown; make review findings
BLOCKER/BUG/REVIEW explicit and resolve them before DONE.
