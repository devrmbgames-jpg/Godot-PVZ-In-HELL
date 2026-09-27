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
- classes: `PascalCase`;
- private member variables/functions: `_snake_case`;
- public methods/data: `snake_case`;
- constants: `UPPER_SNAKE_CASE`;
- signals: `snake_case`;
- GECS role prefixes: `C_`, `R_`, `S_`, `O_`, `E_`, `DEF_`.

Use explicit types whenever inference is ambiguous or an API returns Variant/untyped data.

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
