# PVZ Godot AI Tools

Project-specific, read-only MCP extensions for `addons/godot_ai`.

The addon intentionally starts small. It exposes compact GECS/entity inspection so an
agent does not need to dump a full SceneTree or reconstruct entity composition from many
source files.

## Tools

Promoted tools appear as first-class `custom_*` MCP tools:

- `custom_pvz_gecs_world_summary`
- `custom_pvz_gecs_find_entities`
- `custom_pvz_gecs_entity_inspect`
- `custom_pvz_gecs_relationships`

They are also discoverable through Godot AI's `custom_manage(op="list")` surface.

## Safety

All v0.1 tools are read-only. They do not add/remove entities, components, relationships,
or mutate gameplay state.

Custom addon handlers execute in the Godot **Editor** process. The tools prefer an
editor-side `ECS.world` when available and otherwise inspect Entity nodes in the
currently edited scene. They do not pretend to read the separate running-game ECS world.

Runtime game-side GECS inspection should be added later through an explicit bridge rather
than by exposing mutation/eval shortcuts.

## Dependencies

- Godot 4.7
- Godot AI 4.2.3 as currently vendored by this project
- GECS v8 as pinned in `addons/gecs/`
