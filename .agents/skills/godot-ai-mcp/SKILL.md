---
name: godot-ai-mcp
description: >
  Use for Godot AI MCP live-editor work, especially GDScript writes/diagnostics,
  ClassDB inspection, scene/runtime inspection, and warning-free validation of
  changed project-owned .gd files.
---

# Godot AI MCP

The installed addon under `addons/godot_ai/` is the local tool/API authority. Use upstream `hi-godot/godot-ai` only when the local contract is unclear; inspect the smallest relevant tool/doc instead of preloading the addon or full docs.

## When to use MCP

Prefer ordinary repository search/read/edit tools for cheap static work. Use Godot AI MCP when the live editor materially improves correctness: GDScript validation, ClassDB/inherited API checks, scene/resource state, editor diagnostics, or runtime state.

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

## PVZ custom GECS tools

When `addons/pvz_ai_tools/` is enabled, prefer its compact read-only tools before broad SceneTree or source-code reconstruction for GECS inspection:

- `custom_pvz_gecs_world_summary` — entity/component/relationship counts.
- `custom_pvz_gecs_find_entities` — narrow entity lookup by id/name/path/class/component.
- `custom_pvz_gecs_entity_inspect` — compact component state for one entity.
- `custom_pvz_gecs_relationships` — incoming/outgoing relationship inspection.

These tools execute in the Godot **Editor** process. Their result explicitly reports its source and must not be mistaken for the separate running-game ECS world. If runtime-only state is required, use an appropriate game-side inspection path instead of assuming editor-side data is live gameplay state.

## Context discipline for GPT-6.1 Sol

Do not use MCP as a broad exploratory mirror of the project. Query the smallest relevant script/class/scene/log range. Prefer one targeted diagnostic or ClassDB call over loading whole scenes, full API sections, screenshots, or runtime state that the task does not need.
