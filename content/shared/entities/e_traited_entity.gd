@tool
extends Entity
## Direct scene-owned capability inputs; registration remains an explicit construction operation.
class_name E_TraitedEntity

@export_group("Gameplay Traits")
## Declarative resources compiled once before registration, never mutable gameplay state.
@export var traits: Array[EntityTrait] = []

@export_group("Advanced Authoring")
## Immutable tuning supplied by the owning scene; factories may supply explicit context inputs.
@export var definitions: Dictionary[StringName, GameDefinition] = { }
## Named local endpoints, resolved relative to this Entity before registration.
@export var bindings: Dictionary[StringName, NodePath] = { }
## Named endpoints resolved to the nearest ancestor Entity, preserving prefab mount semantics.
@export var ancestor_entity_bindings: PackedStringArray = PackedStringArray()
