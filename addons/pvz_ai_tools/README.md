# PVZ Godot AI Tools

Project-specific companion MCP extensions for `addons/godot_ai`. The **currently registered** tools are read-only; agents may add narrowly scoped editor-authoring tools when native Godot AI tools cannot satisfy a task.

The addon intentionally starts small. It exposes compact GECS/entity inspection so an
agent does not need to dump a full SceneTree or reconstruct entity composition from many
source files.

## Tools

Promoted tools appear as first-class `custom_*` MCP tools:

- `custom_pvz_gecs_world_summary`
- `custom_pvz_gecs_find_entities`
- `custom_pvz_gecs_entity_inspect`
- `custom_pvz_gecs_relationships`
- `custom_pvz_editor_ownership` — lists current/open/unsaved editor scenes before save or reload; no gameplay access

They are also discoverable through Godot AI's `custom_manage(op="list")` surface.

## Safety

All currently registered tools are read-only. They do not add/remove entities, components, relationships,
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
2. In Godot AI -> Tools, confirm the four `pvz_gecs_*` tools plus `pvz_editor_ownership` are registered.
3. Call `custom_pvz_editor_ownership`; it should return the current scene, open scenes, and any unsaved scene paths. Unsaved plugin-external data is not covered.
4. With the game stopped, call `custom_pvz_gecs_world_summary` with `source="editor"`.
5. Run the game and call the same tool with `source="runtime"`; the response should report `source="runtime_gecs_world"`.

## Adding project-owned MCP capabilities

The project owner authorizes Codex to extend this companion addon when the
installed Godot AI API lacks a required operation. Prefer the existing
`scene_open`, `node_create`, `node_set_property`, `batch_execute` and
`scene_save` tools first; do not reimplement an existing handler.

1. Inspect `plugin.gd`: custom tools are declared with
   `McpCustomToolSpec` and registered via `McpToolRegistry.batch_register()`.
   Handler methods receive `(params: Dictionary, ctx: McpCallContext)`.
   Use a new project-owned handler script for an unrelated editing domain.
2. Define typed, bounded parameter schemas. For mutations set
   `requires_writable = true` and mark `undoable = true` **only** if every
   state change is handled by the native editor UndoRedo contract. Use
   `deferred = true` only for genuinely asynchronous operations with
   an explicit completion/error path.
3. Perform scene changes through the live Godot editor model, respecting
   `owner`, UIDs and unsaved state. Do not rewrite open `.tscn` via
   `FileAccess`, shell scripts, Python or even MCP filesystem tools.
4. Unregister custom tools on plugin exit and release any live references,
   connections and queued requests. Avoid hidden processing loops.
5. Add GUT/editor verification, a minimal usage example and relevant
   contract notes here. Report tests that cannot run as NOT_RUN.
6. Never modify vendored `addons/godot_ai/` or `addons/gecs/` simply to
   extend the project tool surface. If the supported custom API cannot
   implement an operation, document that limitation first.

For a confirmed project.godot modal recovery, follow
`docs/godot_agent_tooling.md` and the guarded project-scoped PowerShell
helper. Custom MCP tools must never terminate arbitrary OS processes.
