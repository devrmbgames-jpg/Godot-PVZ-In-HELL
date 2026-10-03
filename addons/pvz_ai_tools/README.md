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

By default (`source="auto"`) the tools prefer the **running game's** `ECS.world`
through a dedicated Godot debugger-channel bridge. If no game is connected they fall
back to editor-side GECS state / Entity nodes in the currently edited scene.

Use `source="runtime"` when live gameplay state is required and `source="editor"`
when authored/editor state is required. Responses always report their `source`.

The runtime bridge is read-only and uses Godot's debugger IPC. It does not use arbitrary
`game_eval` and does not expose mutation shortcuts.

## Dependencies

- Godot 4.7
- Godot AI 4.2.3 as currently vendored by this project
- GECS v8 as pinned in `addons/gecs/`


## Quick verification

1. Open the project in Godot and confirm both **Godot AI** and **PVZ Godot AI Tools** are enabled.
2. In Godot AI -> Tools, confirm the four `pvz_gecs_*` tools are registered.
3. With the game stopped, call `custom_pvz_gecs_world_summary` with `source="editor"`.
4. Run the game and call the same tool with `source="runtime"`; the response should report `source="runtime_gecs_world"`.
