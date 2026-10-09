# Project Code Style

This document is the on-demand naming reference. The mandatory summary lives in `AGENTS.md`; agents should not preload this file for unrelated work.

## GDScript member visibility

GDScript does not enforce private fields, so naming is the contract.

### Private state

Non-exported member state in behavior/glue/UI code is private by default and **must** start with `_`.

```gdscript
# GOOD
var _value: int = 0
var _target: Entity = null

# BAD
var value: int = 0
var target: Entity = null
```

This applies to project-owned code under:
- `content/entities/`;
- `content/ui/`;
- `content/services/`;
- `content/systems/`;
- `content/observers/`.

Do not remove the underscore merely because another class wants the value. Create a deliberate public method/property instead.

**Default decision rule:** if you are asking whether a behavior-class member needs to be public, it is private. Public mutable member state must be part of an explicit data contract, not a convenience.

### @onready

Every project-owned `@onready` cache is private:

```gdscript
# GOOD
@onready var _panel: PanelContainer = $Panel
@onready var _mesh: MeshInstance3D = $Mesh

# BAD
@onready var panel: PanelContainer = $Panel
@onready var mesh: MeshInstance3D = $Mesh
```

If another object needs the child, expose behavior or a narrow accessor:

```gdscript
@onready var _cargo_area: Area3D = $CargoArea

func get_cargo_area() -> Area3D:
    return _cargo_area
```

Prefer behavior methods such as `terminal.open_for(actor)` over exposing `terminal._panel`.

### Intentional public data

A field without `_` must be intentional public data/API.

Normal cases:
- `Component` / `Relationship` payload;
- typed request/result/event contract;
- `DEF_*` authored data;
- explicit `@export` scene configuration.

Do not use public member state as a shortcut for cross-system access.

## GDScript naming

- files: `snake_case.gd`;
- classes: `PascalCase` for ordinary types; **project role names deliberately keep `C_`, `S_`, `O_`, `R_`, `E_`, `DEF_`, `ET_`, `UI_` + PascalCase suffix**;
- private member variables/functions: `_snake_case`;
- public methods/data: `snake_case`;
- constants: `UPPER_SNAKE_CASE`;
- signals: `snake_case`;
- GECS role prefixes: `C_`, `R_`, `S_`, `O_`, `E_`, `DEF_`, `ET_`, `UI_`.

**Formatter exception:** the GDQuest linter's built-in `class-name` rule would reject the intended `C_Health`, `S_NpcIntent`, `O_CustomerArrived` and similar readable names. The project's `utils/check_gdscript_format.py` disables **only** `class-name` in the external linter, then applies its own allowlist of role prefixes and ordinary PascalCase. All other lint rules, including naming of methods, variables, signals and max line length, stay active. Never rename GECS classes or suppress every lint rule merely to get a green check.

Normal local commands:

```powershell
python utils/check_gdscript_format.py --changed
python utils/validate_agent_changes.py
python -B utils/validate_architecture.py --strict
python utils/validate_project_structure.py
```

If the relevant batch has already been committed, add `--base <base-commit>` to both incremental commands; `--strict` on the style checker verifies **whole files**, intended for Refactoring v2 Phase 3. Missing `gdscript-formatter` gives `NOT_RUN` (exit 2), not PASS. The CLI is resolved from the `GDSCRIPT_FORMATTER_BIN` environment variable (absolute executable path), project `.bin/gdscript-formatter[.exe]`, or system `PATH`; no automatic downloads/installations occur. The CLI is read-only: it does **not** rewrite scripts. Do not run a full-project format pass during an unrelated feature.

For matching editor diagnostics, open **Editor Settings → GDQuest GDScript Formatter → Lint Ignored Rules** and set `class-name` (no other global exclusions). The Editor setting is per-developer; the repository CLI enforces the policy independently. The project `.editorconfig` fixes tab indentation and 100-column wrapping but cannot make the editor-wide role exception itself.

Use explicit types whenever inference is ambiguous or an API returns Variant/untyped data.

## GDScript readability and spacing

Code should be easy to scan by humans, not merely compact.

- Inside non-trivial functions, separate distinct logical phases with exactly one blank line when it improves scanning.
- Typical phase boundaries include: input/setup, guard clauses, data lookup, state mutation, external side effects, and result/follow-up work.
- Keep tightly related statements together. Do not insert blank lines mechanically after every statement.
- Do not collapse several conceptual steps into one dense uninterrupted block just to save vertical space.
- Nested blocks should remain visually clear through indentation plus sensible spacing around separate phases.
- Formatting-only cleanup must not change control flow, evaluation order, API, signals, resource/scene contracts, or gameplay behavior.

Example:

```gdscript
# GOOD
func begin_delivery(actor: Entity, order: DeliveryOrder) -> bool:
    if actor == null or order == null:
        return false

    var inventory: C_Inventory = actor.get_component(C_Inventory) as C_Inventory
    if inventory == null:
        return false

    order.status = DeliveryOrder.Status.ACTIVE
    inventory.active_order_id = order.order_id

    DeliveryEvents.started.emit(actor, order)
    return true


# BAD
func begin_delivery(actor: Entity, order: DeliveryOrder) -> bool:
    if actor == null or order == null:
        return false
    var inventory: C_Inventory = actor.get_component(C_Inventory) as C_Inventory
    if inventory == null:
        return false
    order.status = DeliveryOrder.Status.ACTIVE
    inventory.active_order_id = order.order_id
    DeliveryEvents.started.emit(actor, order)
    return true
```

## GDScript documentation and regions

Project-owned scripts are documented for humans using Godot documentation comments.

- Every `.gd` script gets a short script-level `##` description of its responsibility.
- Every public variable (name without a leading `_`) gets a concise `##` description.
- Every `@export` field gets a concise `##` description, even when its name is private. Place the documentation immediately before the annotation/field so Godot can use it as Inspector documentation.
- Every signal gets a concise `##` description.
- Every public method (name without a leading `_`) gets a concise `##` description of its contract/intent.
- Keep documentation short and useful; normally one line is enough. Do not narrate obvious implementation details or document private helpers merely to add comments.

Functions must be grouped into named Godot code regions by responsibility, for example:

```gdscript
#region Lifecycle

func _ready() -> void:
    pass

#endregion

#region Public API

## Opens the terminal for the given actor.
func open_for(actor: Entity) -> void:
    pass

#endregion

#region Signal handlers

func _on_button_pressed() -> void:
    pass

#endregion
```

Use logical groups such as `Lifecycle`, `Public API`, `GECS`, `Input`, `Presentation`, `Signal handlers`, or `Internal` according to the script. Do not create arbitrary one-function regions when a nearby logical group exists.

Godot region syntax is exact: use `#region` and `#endregion` with **no space** after `#`. Do not write `# region`.

Reference: https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_documentation_comments.html

## Resource filenames

Project-authored `.tres` resources use a short type prefix so global search groups similar assets immediately.

| Resource role/type | Prefix | Example |
| --- | --- | --- |
| Definition / `DEF_*` | `def_` | `def_impact_fragile.tres` |
| Material (`StandardMaterial3D`, `ShaderMaterial`, `CanvasItemMaterial`, `PhysicsMaterial`, etc.) | `mat_` | `mat_cardboard.tres` |
| Theme | `theme_` | `theme_terminal.tres` |
| StyleBox / UI style | `style_` | `style_panel_warning.tres` |
| Mesh resource | `mesh_` | `mesh_package_debris.tres` |
| Shape resource | `shape_` | `shape_package_box.tres` |
| Texture resource authored as `.tres` | `tex_` | `tex_noise_mask.tres` |
| Font resource authored as `.tres` | `font_` | `font_terminal.tres` |
| Environment | `env_` | `env_warehouse.tres` |
| LabelSettings | `label_` | `label_world_hint.tres` |
| NavigationMesh | `navmesh_` | `navmesh_warehouse.tres` |
| Noise resource | `noise_` | `noise_grass_variation.tres` |
| Curve | `curve_` | `curve_damage_falloff.tres` |
| Gradient | `grad_` | `grad_health_bar.tres` |
| Animation | `anim_` | `anim_door_open.tres` |
| AnimationLibrary | `animlib_` | `animlib_player.tres` |

Rules:
- the prefix describes the resource type/role, not the folder name;
- use one prefix only; do not stack prefixes;
- keep the descriptive suffix concise and searchable;
- new reusable resource types must get a canonical prefix in this table and in `utils/validate_project_structure.py` before multiple files of that type are created;
- `content/definitions/**/*.tres` always uses `def_`;
- third-party/imported/vendor content under `addons/` or imported asset collections under `resources/` is exempt unless the project deliberately takes ownership of those files;
- engine-conventional files such as `default_bus_layout.tres` are exempt.

## Validation

`python utils/validate_project_structure.py` enforces:
- GECS role/path conventions;
- project resource paths;
- private `@onready` caches;
- private non-exported member state in behavior/glue/UI roots;
- canonical prefixes for project-authored `.tres` resources where the type/role is known.

Do not weaken the validator to make a new violation pass. Fix the authored code/resource name unless the file is genuinely an explicit exception.
