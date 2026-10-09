@tool
extends Resource
## Scene-owned composition inputs; mutable runtime state belongs to registered Components.
class_name EntityAuthoring

## Optional flat Template owned by the visible scene instance; null allows intrinsic data only.
@export var entity_template: DEF_EntityTemplate = null
## Immutable tuning references supplied by the owning scene or factory.
@export var definitions: Dictionary[StringName, GameDefinition] = {}
## Local scene endpoint references; explicit World preparation validates their ownership.
@export var bindings: Dictionary[StringName, NodePath] = {}

## Named optional scene endpoints resolved to the nearest ancestor Entity during pure capture.
@export var ancestor_entity_bindings: PackedStringArray = PackedStringArray()
