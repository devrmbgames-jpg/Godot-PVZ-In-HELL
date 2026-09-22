---
name: gdscript-style
description: >
  Enforce this project's GDScript naming, static typing, shadowing, file/node/class naming,
  typed collection access, and function organization rules. Use whenever creating or editing .gd
  files, reviewing parse/warning issues, or refactoring GDScript structure.
---

# GDScript style and typing

These rules are mandatory for project-owned GDScript.

## Static typing

Use static typing for:
- member variables;
- exported variables;
- function parameters;
- function return values;
- local variables when inference is ambiguous;
- arrays/dictionaries when a useful concrete type is known.

Prefer:

```gdscript
var speed: float = 5.0
var target: Node3D = null
var items: Array[Item] = []
func get_item(index: int) -> Item:
    ...
```

Do not leave important values as implicit `Variant` when a concrete type is known.

### Untyped collection / Variant-producing access

When a collection/API does not preserve a static element type, explicitly type or cast the extracted value:

```gdscript
var item: Item = array_items[index]
var entity: Entity = entities[index]
var motion: C_Motion = components_motion[index]
var node: Node3D = dictionary_nodes[key] as Node3D
```

Do not rely on a `Variant` result to flow through several statements before typing it.

If a collection can be typed, prefer typing the collection itself:

```gdscript
var items: Array[Item] = []
var entities: Array[Entity] = []
var by_id: Dictionary[StringName, Item] = {}
```


## Member visibility and naming

Project-owned GDScript uses naming to express public/private intent.

### Constants

Constants use `UPPER_SNAKE_CASE`:

```gdscript
const CONST_VAR: int = 0
const MAX_PICKUP_DISTANCE: float = 3.0
```

### Enums

Enum type names use `PascalCase`. Enum members also use `PascalCase` in this project:

```gdscript
enum EnumName {
    EnumVal1,
    EnumVal2,
}
```

Keep enum names semantic; do not use anonymous integer constants when an enum is the real domain model.

### Public and private members

A leading underscore means **private implementation detail**.

Private members must start with `_`:

```gdscript
var _private_var: float = 0.0
@onready var _private_onready_var: Node = %Node
```

Public members must **not** start with `_`:

```gdscript
var public_var: float = 0.0
@onready var public_onready_var: Node = %Node
@export var export_var: float = 0.0
```

All `@export` fields are considered part of the authored/public configuration surface and therefore must not use a leading underscore.

Do not expose a member publicly merely because it is convenient. If external code does not need the member, make it private with `_`.

### Public and private functions

Private helper functions start with `_`:

```gdscript
func _private_func(value: int) -> void:
    ...
```

Public API functions do not:

```gdscript
func public_func(value: int) -> void:
    ...
```

Godot lifecycle/virtual callbacks such as `_ready()`, `_process()`, `_input()`, `_physics_process()`, etc. keep the engine-required leading underscore. They are callbacks, not project-private helper APIs.

### Signal / connection callbacks

Methods used as signal connection slots must use the `_on_` prefix.

Prefer a descriptive source/signal form:

```gdscript
func _on_button_pressed() -> void:
    ...
```

A generic/abstract slot still uses `_on_`:

```gdscript
func _on_pressed() -> void:
    ...
```

Do not name signal callbacks as ordinary public/private helpers when they are connection slots.

## Script and public API documentation

Every project-owned script must begin with a short description of its responsibility.

Place the documentation near the class declaration so the script's purpose is visible immediately. Prefer Godot documentation comments (`##`) for class/API documentation.

Example:

```gdscript
@tool
extends Node
## Resolves authored item metadata and exposes it to the inventory UI.
class_name ItemMetadataResolver
```

Public API must be briefly documented with `##` comments so Godot can pick up the descriptions.

Document at minimum:
- public member variables;
- exported variables when their purpose, units, range, ownership or side effects are not completely obvious from the name;
- public `@onready` references;
- public functions;
- public signals;
- public classes/resources/components and non-obvious enums.

Examples:

```gdscript
## Label used to display the current package registration number.
@onready var package_number_label: Label = %PackageNumber

## Maximum distance in meters at which the scanner can register a package.
@export var scan_range: float = 3.0

## True while this interaction is the active owner of player controls.
var controls_captured: bool = false

## Returns the currently assigned warehouse registration number.
func get_registration_number() -> int:
    return registration_number
```

Comments must explain **purpose/contract**, not restate the identifier.

Bad:

```gdscript
## Scan range.
@export var scan_range: float = 3.0
```

Better:

```gdscript
## Maximum scanner-to-package distance in meters for a valid registration attempt.
@export var scan_range: float = 3.0
```

Private helpers/fields may use ordinary `#` comments when needed, but do not add comments that merely repeat the code.


## No shadowing

Variable names must not shadow:
- another local in an outer scope;
- function parameters;
- class members;
- globals/autoloads used in scope;
- `class_name` types;
- native Godot classes/types;
- commonly imported project types when ambiguity would result.

Bad:

```gdscript
var item: Item = current_item

for item in items:
    ...
```

Bad:

```gdscript
var position: Vector3 = ...

func update(position: Vector3) -> void:
    ...
```

Choose a semantic distinct name:

```gdscript
for inventory_item: Item in items:
    ...

func update(target_position: Vector3) -> void:
    ...
```

Treat Godot shadowing warnings as code-quality errors, not harmless warnings.

## File names

Project-owned code/data files must use `snake_case`.

Examples:

```text
s_motion.gd
c_controller.gd
e_rigid_body_character.gd
player_inventory.tscn
damage_definition.tres
```

Exception: raw/source assets from external tools/vendors may preserve their original names when renaming would break the asset pipeline, import references, or source tracking.

Do not use PascalCase/camelCase for project-owned script filenames.

## Node names

Nodes authored in the Godot Inspector/scene tree use `PascalCase`.

Good:

```text
Player
HeadAxisY
HeadAxisX
CollisionShapeStanding
CameraRoot
AnimationTree
```

Avoid:

```text
head_axis_y
cameraRoot
collision-shape
```

Generated/runtime-only Node names may follow a subsystem-specific convention when not exposed as authored scene structure.

## Class names

Classes use `PascalCase`.

Examples:

```gdscript
class_name PlayerInventory
class_name DamageResolver
```

GECS role prefixes are allowed and expected when the project uses them:

```gdscript
class_name C_Health
class_name S_Motion
class_name O_HealthChanged
class_name DEF_Ability
class_name E_RigidBodyCharacter
class_name R_OwnedBy
```

The prefix identifies the GECS role; the remaining name is PascalCase.

## Function grouping

Functions must be grouped by responsibility. Do not intermix unrelated function categories.

Use `#region` / `#endregion` when a script has enough functions to benefit from visible grouping.

Recommended structure (adapt when a file does not need a group):

```gdscript
extends Node
class_name Example

#region Constants / enums
...
#endregion

#region Exported state
...
#endregion

#region Public state
...
#endregion

#region Private state
...
#endregion

#region Godot lifecycle
func _init() -> void:
    ...

func _ready() -> void:
    ...

func _process(delta: float) -> void:
    ...
#endregion

#region Public API
func start() -> void:
    ...

func stop() -> void:
    ...
#endregion

#region Signal / UI callbacks
func _on_button_pressed() -> void:
    ...

func _on_inventory_changed() -> void:
    ...
#endregion

#region Private helpers
func _calculate_target() -> Vector3:
    ...

func _update_visuals() -> void:
    ...
#endregion
```

Mandatory separation:
- Godot lifecycle/callbacks such as `_init`, `_enter_tree`, `_ready`, `_process`, `_physics_process`, `_input`, `_unhandled_input`;
- public API;
- signal/UI callback methods (`_on_...`);
- private helpers;
- GECS-specific callbacks when applicable (`query`, `process`, `deps`, `each`, etc.) should be grouped together rather than scattered.

Keep closely related helpers adjacent.

## Function signatures

Every function should declare a return type, including `-> void`.

Prefer fully typed parameters:

```gdscript
func apply_damage(target: Entity, amount: float) -> void:
    ...
```

Avoid:

```gdscript
func apply_damage(target, amount):
    ...
```

Use `Variant` only when the API is genuinely polymorphic and the code handles the possible types explicitly.

## Type narrowing and casts

After runtime type checks, use an explicit typed binding when it improves clarity:

```gdscript
if collider is RigidBody3D:
    var rigid_body: RigidBody3D = collider as RigidBody3D
```

Do not repeatedly cast the same `Variant` in multiple expressions.

## Collections and loops

Prefer typed loop variables when the collection is untyped or framework-provided:

```gdscript
for index: int in entities.size():
    var entity: Entity = entities[index]
```

For typed arrays, inference is acceptable when the type is unambiguous, but explicit types are preferred in hot/framework code where accidental `Variant` propagation is costly.


## Visual structure inside functions

Do not write functions as one dense uninterrupted block of statements.

Split a function into **semantic blocks** with one empty line between them. A semantic block is a small group of statements that performs one immediately understandable step, for example:

1. derive/validate input;
2. allocate or prepare data;
3. iterate/process;
4. construct/configure a result;
5. return/commit.

Good:

```gdscript
func _make_beep() -> AudioStreamWAV:
    var sample_count: int = int(SAMPLE_RATE * BEEP_SECONDS)
    var samples: PackedByteArray = PackedByteArray()
    samples.resize(sample_count * 2)

    for sample_index: int in sample_count:
        var envelope: float = sin(PI * float(sample_index) / sample_count)
        var amplitude: float = sin(TAU * BEEP_FREQUENCY * sample_index / SAMPLE_RATE)
        samples.encode_s16(sample_index * 2, int(amplitude * envelope * 9000.0))

    var stream: AudioStreamWAV = AudioStreamWAV.new()
    stream.format = AudioStreamWAV.FORMAT_16_BITS
    stream.mix_rate = SAMPLE_RATE
    stream.data = samples

    return stream
```

Avoid:

```gdscript
func _make_beep() -> AudioStreamWAV:
    var sample_count: int = int(SAMPLE_RATE * BEEP_SECONDS)
    var samples: PackedByteArray = PackedByteArray()
    samples.resize(sample_count * 2)
    for sample_index: int in sample_count:
        ...
    var stream: AudioStreamWAV = AudioStreamWAV.new()
    ...
    return stream
```

Rules:
- use exactly one empty line between neighboring semantic blocks;
- keep tightly related assignments together;
- separate a guard/early-return section from the next operation;
- separate loops/branches from setup before them and result construction after them;
- separate final `return` when it concludes a multi-step function;
- do not add empty lines after every statement; whitespace must communicate structure;
- do not leave trailing spaces/tabs on blank lines.

The goal is that the shape of the function can be understood before reading every expression.

## Readable conditions

Prefer simple conditions that express one idea. Avoid deeply nested, heavily parenthesized boolean expressions when the intent is not immediately obvious.

Bad:

```gdscript
if (
    best == null or action.priority > best.priority
    or (
        action.priority == best.priority
        and action.action_id < best.action_id
    )
):
    best = action
```

Prefer naming the decision:

```gdscript
var has_no_best: bool = best == null
var has_higher_priority: bool = best != null and action.priority > best.priority
var has_same_priority: bool = best != null and action.priority == best.priority
var comes_first: bool = best != null and action.action_id < best.action_id
var should_replace: bool = (
    has_no_best
    or has_higher_priority
    or (has_same_priority and comes_first)
)

if should_replace:
    best = action
```

For domain logic, a helper is often better:

```gdscript
if _is_better_action(action, best):
    best = action
```

Use nested `if` statements when they make the decision tree easier to read:

```gdscript
if best == null:
    best = action
elif action.priority > best.priority:
    best = action
elif action.priority == best.priority:
    if action.action_id < best.action_id:
        best = action
```

Guidelines:
- if a boolean expression needs multiple indentation levels, repeated parentheses, or mixes several domain concepts, simplify it;
- give important predicates semantic names such as `is_valid_target`, `has_same_priority`, `should_replace`;
- extract repeated or domain-significant comparison logic into a private helper;
- prefer a readable decision tree over a clever one-liner;
- do not duplicate an expensive function call merely to make a condition shorter; cache its result when needed.

## Avoid redundant and misleading conversions

Do not cast a value to the type it already has merely to satisfy or decorate an expression.

Bad when `action_id` is already `String`:

```gdscript
String(action.action_id) < String(best.action_id)
```

Prefer:

```gdscript
action.action_id < best.action_id
```

More importantly, choose the comparison type from the **domain meaning**, not from whichever conversion makes the expression compile.

If an identifier is semantically numeric and ordering is numeric, store/parse it as an integer at the boundary and compare integers:

```gdscript
var action_order: int = action.order
var best_order: int = best.order

if action_order < best_order:
    ...
```

If an identifier is a textual stable ID, do not convert it to `int` just to sort it unless the data contract explicitly defines a numeric representation.

Rules:
- never use redundant casts to the same known type;
- avoid chains such as `String(...)`, `int(...)`, `float(...)` inside domain comparisons when a correctly typed value can be prepared once;
- convert at system/data boundaries, then keep internal logic strongly typed;
- do not introduce lexical ordering of IDs as an implicit business rule; if tie-breaking order matters, model it explicitly (`priority`, `order`, enum, or documented stable ID rule).


## Constants and magic numbers

Behavioral thresholds/rates that carry meaning must be:
- exported tuning fields;
- named `const`;
- design data/Resource values.

Do not bury repeated meaningful literals in logic.


## Canonical class layout example

```gdscript
@tool
extends Node
## Demonstrates the project's required GDScript naming and documentation layout.
class_name MyClass

const MY_NAME: String = "name"

enum TypeProperty {
    Title,
    Description,
}

@onready var _label_name: Label = %LabelName

## Property that controls which metadata field is presented by this node.
@export var type_property: TypeProperty = TypeProperty.Title

## True when this instance is currently selected as the preferred option.
var is_best: bool = false

var _current_position: Vector2 = Vector2.ZERO


func _ready() -> void:
    pass


func _calculate_new_name() -> StringName:
    var result: StringName = &""
    # ...
    return result


## Returns the current Node name as a StringName.
func get_current_name() -> StringName:
    return name


func _on_label_text_changed() -> void:
    pass
```


## Final review

Before finishing a `.gd` edit, check:
- constants use `UPPER_SNAKE_CASE`;
- enums and enum members follow the project convention;
- private members/helpers start with `_`;
- public/export/onready members that are public do not start with `_`;
- signal slots start with `_on_`;
- every script has a short responsibility description;
- public API has useful `##` documentation comments;
- no shadowed names;
- no unintended `Variant`;
- all signatures typed;
- extracted collection values typed;
- project-owned filename is `snake_case`;
- authored Node names are `PascalCase`;
- class name follows `PascalCase` / approved GECS prefix;
- functions are grouped by responsibility;
- function bodies are separated into readable semantic blocks;
- complex conditions are named, nested clearly, or extracted into helpers;
- no redundant/misleading type conversions are used;
- no changes were made under `addons/`.
