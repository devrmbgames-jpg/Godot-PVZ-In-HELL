# PVZ Godot AI Tools

Project-specific companion MCP extensions for `addons/godot_ai`. Inspection tools are
read-only; explicit native configuration/verification tools declare their bounded mutations.

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

The inspection tools are read-only. They do not add/remove entities, components, relationships,
or mutate gameplay state. The explicit `pvz_editor_traits_signal_check` verification tool briefly
changes the Inspector's viewed resource using disposable controls and restores its original object.
It never changes authored content, scene selection or Undo/Redo history.

## Native Traits signal verification

Call `custom_manage(op="invoke", params={"tool_name":"pvz_editor_traits_signal_check","params":{}})`
with gameplay stopped. It checks New Trait, Make Unique and local-resource settings navigation:
the source button must survive its signal, then be disposed during deferred native Inspector
navigation. The response contains nine assertions, failures and `inspector_restored`.
No script paths or arbitrary actions are accepted. Calls are bounded to 18 editor frames,
overlapping requests are rejected, and hot swaps wait until signals/temporary Nodes are released.
After adding the tool, reload Godot AI through `editor_reload_plugin`; the companion registry
re-registers it. The live MCP check is editor acceptance; `test_pvz_editor_traits_signal_tool.gd`
covers parameter rejection, overlap and hot-swap safety without an editor.

## Pinned GDScript editor settings

`pvz_gdscript_batch_diagnostics` compiles at most25 fixed manifest paths for task61–65
without creating gameplay instances. The executing handler is validated against its
already compiled source only when that source exactly matches disk. A stale handler
returns `ERR_BUSY` / `handler_reload_required`; reload the registry before retrying.
This avoids compiling the handler while its bytecode is executing. Other paths use an
explicit native reload result; non-tool scripts cannot be instantiated in the editor.

`custom_manage(op="invoke", params={"tool_name":"pvz_gdscript_style_settings",
"params":{"action":"inspect"}})` checks the native GDQuest addon configuration.
Use `action="apply"` to persist only the fixed formatter0.26.2 path, tabs,100-column lint,
class-name-only exclusion, no reordering and no format-on-save. This affects EditorSettings
through Godot, never project.godot or authored scripts. The installed addon still emits the
removed `--safe` option in Verify Structure mode; keep its Normal mode. The repository CLI
uses the supported `--check --verify-structure` combination. No arbitrary setting paths,
executable paths or commands are accepted.

By default (`source="auto"`) the tools prefer the **running game's** `ECS.world`
through a dedicated Godot debugger-channel bridge. If no game is connected they fall
back to editor-side GECS state / Entity nodes in the currently edited scene.

Use `source="runtime"` when live gameplay state is required and `source="editor"`
when authored/editor state is required. Responses always report their `source`.

The runtime bridge is read-only and uses Godot's debugger IPC. It does not use arbitrary
`game_eval` and does not expose mutation shortcuts.

## Diagnostic translation-source cleanup

`custom_manage(op="invoke", params={"tool_name":"pvz_translation_sources",
"params":{"action":"preview"}})` lists missing dialogue copies from the four known
historical `.bin/` snapshots. `action="apply"` removes only those absent copies through
native `ProjectSettings`, retaining `PackedStringArray` and all authored/custom sources.
It removes matching stale Dialogue Manager cache entries to prevent their reintroduction.
No scene, arbitrary setting, existing file or gameplay state is changed. Save errors restore
the in-memory setting; the synchronous handler retains no Nodes or requests. The operation
is not undoable. Reload Godot AI through `editor_reload_plugin` after tool registration.
Focused tests: `res://tests/gut/test_pvz_translation_sources_tool.gd`.

Preserved diagnostic project copies belong under
`.artifacts/godot_agent/.tmp/isolated_snapshots/`, with `.gdignore` for native imports.
Dialogue Manager has its own recursive scanner: it ignores `.godot` and `.tmp`, but does
not honor `.gdignore`. Keeping copies under `.tmp` prevents a fresh scan from adding their
dialogues back to translation sources. Do not modify the vendored scanner for this cleanup.

## Dependencies

`pvz_behavior_tree_authoring` fills the native LimboAI child-insertion gap. It operates
only on direct NPC and customer `ai/trees/*.tres` resources. `inspect` is read-only;
`create` refuses existing files and accepts a bounded native task graph; `insert`
preserves the existing root, children and Blackboard plans and refuses stale child
order, duplicate subtrees or cycles. Saves use editor-side ResourceSaver, are explicit
and non-undoable. No retained Resources or pending requests survive plugin exit.
`replace` requires `root` and the exact SHA-256 `fingerprint` of an existing tree,
clean editor scenes and an uninspected target. It prepares a detached native graph
before writing, retains the resource UID/Blackboard plan and refreshes the native cache.
Malformed graphs and stale fingerprints leave the file and cached tree unchanged.
Reload Godot AI after registration; the companion registry unregisters on exit.

Example: `custom_manage(op="invoke", params={"tool_name":"pvz_behavior_tree_authoring",
"params":{"op":"inspect","path":"res://content/domains/npc/ai/trees/bt_npc_native.tres"}})`.
Insert adds `subtree`, zero-based `index`, `name` and the exact `expected_children`
returned by inspect. Creation uses `root` with `type`, `name`, optional NPC leaf `script`,
`intent_owner` and recursive `children` (64 tasks, depth 6). Focused refusal/identity
tests: `res://tests/gut/test_pvz_behavior_tree_authoring_tool.gd`.

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

`pvz_gdscript_batch_diagnostics` validates at most25 scripts from the fixed Phase3
manifest: `custom_manage(op="invoke", params={"tool_name":
"pvz_gdscript_batch_diagnostics", "params":{"task":"61","offset":0,"limit":25}})`.
Repeat from `next_offset` until `total`. It compiles native resource paths, captures
file diagnostics and creates no gameplay instances or authored data. The installed
script writer validates an anonymous GDScript, which can return error43 for an
otherwise valid global `class_name`; the path-bound tool resolves that ambiguity.
It does not replace the independent CLI parser/style gates. Registration is removed
on plugin exit; calls retain no editor objects or pending requests.

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

`pvz_npc_archetype_cache_refresh` refreshes up to16 `.tres` definitions directly under
`content/domains/npc/definitions/` after a native MCP save changed their scripted type.
Example: `custom_manage(op="invoke", params={"tool_name":"pvz_npc_archetype_cache_refresh",
"params":{"paths":["res://content/domains/npc/definitions/def_npc_profile_1.tres"]}})`.
It also accepts exactly the two `et_district_{npc,trader}_npc_identity.tres` policies under
`content/domains/npc/authoring/`, whose freshly loaded script must be `ET_NpcIdentity`.
The two `et_district_{npc,trader}_npc_brain_state.tres` policies are exact dependencies too,
requiring `ET_NpcBrainState`; this refreshes selected capability inputs after script edits.
The order dependencies are also exact paths: `packages/definitions/def_delivery_morning_supply.tres`
and `packages/authoring/et_package_package_state.tres` under `content/domains/`, requiring the
`DEF_Delivery` and `ET_PackageState` scripts respectively. Arbitrary package resources are excluded.
Other authoring resources are excluded. NPC definition files must load with `DEF_NpcArchetype`;
the whole set is checked before
native cache replacement. No files or UIDs are changed; cached definition values refresh from disk.
Dirty scenes and
an inspected target Resource refuse the operation; reload affected clean scenes afterwards.
Registration is removed on plugin exit; the handler retains no resources or connections.

`pvz_npc_archetype_resave` fills the native resource tool's gap for existing graphs
with embedded schedules/trait options. It saves up to eight existing `DEF_NpcArchetype`
definitions after clean-scene, Inspector, exact SHA-256, exported-default and UID checks.
Example: `custom_manage(op="invoke", params={"tool_name":"pvz_npc_archetype_resave",
"params":{"fingerprints":{"res://content/domains/npc/definitions/def_npc_profile_1.tres":
"<SHA-256 of the inspected file>"}}})`. Native `ResourceSaver` retains the loaded graph
and root UID; this persistent save has no editor undo. Restart the editor after adding
the tool. Plugin exit unregisters it; no resources or connections survive a call.
Optional `dialogue_pools` maps fingerprinted target paths to two through sixteen unique
imported `.dialogue` paths. Only this authored field changes on a separate native graph;
all pools preflight before saving, retaining embedded schedules/traits and other tuning.
Optional `trait_additions` maps fingerprinted targets to one through four existing native
NPC trait `.tres` paths. Only the separate graph's mandatory rules are appended; invalid,
duplicate or incompatible traits refuse the complete batch before any save.
An anonymous global script reload error43 does not refresh exported layouts: confirm
the actual exported properties or restart before saving authored resources.
