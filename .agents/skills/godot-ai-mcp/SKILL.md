---
name: godot-ai-mcp
description: Use for live Godot AI MCP editor/scene inspection, ClassDB, script writes and GDScript diagnostics.
---

# Godot AI MCP

## Connection and editor lifecycle

Codex uses the Godot AI MCP connection in the user-level `~/.codex/config.toml`
(or `$CODEX_HOME/config.toml` when overridden). Do not duplicate its server entry
in project-local Codex config. MCP is optional for static file work.

If live editor state is needed and Godot is closed, start Godot Editor with
`.vscode/start-godot.ps1` automatically. Never launch rendered gameplay or
perform subjective visual QA without approval. For editor-owned scene mutation
use [godot-scene-authoring](../godot-scene-authoring/SKILL.md); if the editor
blocks required filesystem changes, close and relaunch it when needed.

The installed addon under `addons/godot_ai/` is the local tool/API authority. Use upstream `hi-godot/godot-ai` only when the local contract is unclear; inspect the smallest relevant tool/doc instead of preloading the addon or full docs.

## Live authoring is the preferred route for open scenes

Godot AI is **not** just a validator. When the graphical editor is running,
use its native tools for authoring open scenes: `editor_state`,
`scene_manage`/`scene_open`, `node_create`, `node_set_property`,
`node_manage`, `resource_manage`, `scene_save`; use short
`batch_execute` transactions for repetitive operations.

- Before scene open/reload/save, call `custom_pvz_editor_ownership` if installed.
  It reports open and unsaved scenes via Godot 4.7's `get_unsaved_scenes()`;
  if unavailable, treat dirty status as unknown and never force-reload.
- Live scene mutations go through Godot's `EditorUndoRedoManager` and scene
  saving; `script_patch` and `filesystem_manage(op="write_file")` still
  write files externally and **do not** make arbitrary `.tscn` overwrites safe.
- `scene_open` must settle before editing the target. Read the returned
  `switched`/`settle` fields. Never use `force_reload` over unsaved work.
- If no MCP bridge is available, **still run headless Godot** through
  `utils/godot_agent.ps1` for parser/GUT; do not use absent MCP as a reason
  to skip required validation. If the target scene is open, do not rewrite
  it externally; either leave that mutation blocked or first close the editor
  by a normal, non-destructive workflow.
- For large offline editor migrations with the GUI editor closed, use a CLI `SceneTree`/`MainLoop` migration script with
  `PackedScene`/`ResourceSaver`, not string assembly of the `.tscn` syntax.
  `EditorScript` itself runs via the live editor's File -> Run, not the CLI. Refer to [scene authoring](../godot-scene-authoring/SKILL.md).

## project.godot block recovery

- Prefer `project_manage` and `autoload_manage`/editor-owned `ProjectSettings`
  while the editor is open. These write `project.godot` via Godot itself, but
  they **cannot** guarantee that an external-change dialog never appears.
- Owner explicitly authorizes terminating the **identified editor process for
  this repository only** when the `project.godot` external-change dialog
  has been confirmed and blocks development. Gather concrete evidence
  (user report, editor log, MCP message). A disconnect, stale socket,
  missing plugin or generic timeout is insufficient.
- Use `.vscode/stop-blocked-godot.ps1` with exact PID and evidence; it checks
  the editor command line and project path, logs what it does, and refuses
  ambiguous/foreign processes. Unsaved changes in the editor **may be lost**
  with a forced stop. Prefer a normal save/close when possible; if the modal
  prevents that, perform the authorized targeted stop and then restart through
  `.vscode/start-godot.ps1` as needed. No `taskkill /IM Godot*.exe /F`,
  no blanket `Stop-Process`, no automatic "Ignore External Changes".
- Do not repeatedly restart on the same unresolved `project.godot` conflict.
  Inspect the changed file/evidence and correct its write owner before retry.

## Permission to extend Godot AI

If the existing MCP tools are insufficient for a real task, agents are
authorized to implement and maintain **project-owned companion MCP tools**
through the supported custom tool registry (prefer
`addons/pvz_ai_tools/` and its registration contracts).

- Confirm the gap first using the installed `addons/godot_ai/tool_catalog.gd`
  and the smallest relevant handler API; use an existing native tool if it fits.
- Expose bounded, typed, narrowly scoped Godot-editor operations with an explicit
  mutating vs read-only contract, undo/ownership semantics where applicable and
  safe disposal of nodes/Resources. Prefer batches of native Godot operations
  to shell scripts that rewrite open scenes.
- Add GUT/editor-focused tests and a short usage example in
  `addons/pvz_ai_tools/README.md`; document any plugin enable/reload step.
- Do not edit or upgrade vendored `addons/godot_ai/` or `addons/gecs/` merely
  to extend capabilities. Request an upstream dependency change only when a
  companion custom tool genuinely cannot implement the needed behavior.
  Never expose unrestricted OS command execution or arbitrary gameplay mutation.

## When to use MCP

Prefer normal repository search/read/edit tools for static research and code files. For any scene currently owned by a running editor, choose Godot AI MCP native authoring first; use it also for GDScript diagnostics, ClassDB/inherited API checks, scene/resource state, editor diagnostics and runtime state.

For project-owned GDScript, live MCP is also the preferred validation path when the editor is available. Syntax/warning validation does **not** require launching gameplay.

## GDScript write + validation contract

When changing a `.gd` file and live MCP is available:

1. Prefer `script_patch` for focused edits and `script_create` for a new script. These writes are parsed by Godot and return per-file `diagnostics`.
2. Inspect the diagnostics from every GDScript write. Do not ignore the response after a successful disk write.
3. Before declaring the file complete, require `diagnostics_status == "checked"` and resolve diagnostics caused by the changed code. Treat relevant warnings as defects, not only parse errors.
4. If `diagnostics_status == "partial"`, or the editor reports new warning/error stamps, inspect `logs_read(source="editor", include_details=true)`.
5. `filesystem_manage(op="scan")` is useful to settle external/multi-file changes but is **not** proof that a script parsed cleanly.
6. Do not run `project_run` merely to check syntax or warnings.

For a planned multi-file scaffold, temporary diagnostics may exist between related writes. Finish the coherent scaffold first, settle it, then validate the touched scripts instead of fixing transient intermediate errors one-by-one.

If MCP is unavailable, use the cheapest available Godot/static validation and report that live editor diagnostics were unavailable. Never claim Godot parser/warning validation unless it actually ran.

## Prevent warning-prone names

Before introducing a member, parameter, or local with a generic engine-like name, first check the current script and its inheritance surface when collision risk is non-trivial.

Use `api_manage(op="get_class", params={"class_name":"<BaseClass>","sections":["properties","methods"],"include_inherited":true})` selectively when an inherited Godot name is uncertain. Do not dump full ClassDB by default.

Avoid:
- locals/parameters shadowing members of the same script;
- members shadowing inherited Godot properties/methods;
- accidental redeclaration of existing signals, methods, constants, or properties;
- names whose visibility/ownership is ambiguous across a project base class.

Prefer a more specific name over `@warning_ignore`. Suppress a warning only when the collision is intentional, the API requires it, and a short rationale is clear.

## Typed GDScript

Project-owned GDScript remains statically typed. Explicitly type values crossing Variant/untyped APIs, dynamic lookups, Blackboard/ECS dictionaries, or broad Object/Node boundaries. Do not rely on `:=` when the inferred type can be Variant or otherwise ambiguous.

A parser-clean file with avoidable type/shadowing warnings is not considered clean.

## Editor diagnostics

`logs_read(source="editor", include_details=true)` is the focused source for:
- parse errors;
- GDScript reload warnings;
- @tool / EditorPlugin errors;
- Debugger Errors-tab rows;
- push_error / push_warning entries.

Use incremental cursors when doing repeated checks; do not repeatedly dump the whole editor log.

For Godot 4.7.1 shutdown-only retained resources, apply the
[memory diagnostics policy](../validation-workflow/references/memory-lifetime.md).
Do not normalize runtime parser/reload warnings as shutdown retention.

## PVZ custom GECS tools

When `addons/pvz_ai_tools/` is enabled, prefer its compact read-only tools before broad SceneTree or source-code reconstruction for GECS inspection:

- `custom_pvz_gecs_world_summary` — entity/component/relationship counts.
- `custom_pvz_gecs_find_entities` — narrow entity lookup by id/name/path/class/component.
- `custom_pvz_gecs_entity_inspect` — compact component state for one entity.
- `custom_pvz_gecs_relationships` — incoming/outgoing relationship inspection.

The custom-tool handler starts in the Godot **Editor** process but can route read-only inspection over the project's dedicated debugger bridge into the running game's real `ECS.world`. Use `source="runtime"` when live gameplay state is required, `source="editor"` for authored/editor state, and the default `source="auto"` to prefer runtime then fall back. Always respect the returned `source` field.

## Context discipline for GPT-6.1 Sol

Do not use MCP as a broad exploratory mirror of the project. Query the smallest relevant script/class/scene/log range. Prefer one targeted diagnostic or ClassDB call over loading whole scenes, full API sections, screenshots, or runtime state that the task does not need.
