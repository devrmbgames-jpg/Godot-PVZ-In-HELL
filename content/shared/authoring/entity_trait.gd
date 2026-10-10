@tool
extends Resource
## Immutable capability configuration; recipes and validation never tick or mutate a gameplay world.
class_name EntityTrait

## Stable capability identity used for provider diagnostics and deterministic ordering.
@export var trait_id: StringName = &""
## Declarative initial data; the compiler creates isolated copies for each build.
@export var component_recipes: Array[Component] = []
## Component contracts that must be supplied by the scene/code/direct Trait composition.
@export var required_components: Array[Script] = []
## Required authored root engine class; empty accepts the scene's existing root class.
@export var required_root_class: StringName = &""
## Local engine-node paths required by this capability before registration.
@export var required_nodes: Array[NodePath] = []
## Initial bindings are authoring intents, never authoritative live Relationships on this Resource.
@export var initial_bindings: Array[EntityInitialBinding] = []

## Enumerated instance fields accepted from factory inputs, never arbitrary live state writes.
@export var initial_field_names: Dictionary[Script, PackedStringArray] = { }


#region Pure capability compilation
## A concrete capability may select its existing Profile variant without changing configuration.
func enabled_for(_context: EntitySpawnContext) -> bool:
	return true


## Returns declarative recipes; concrete Traits may calculate data from typed immutable inputs.
func recipes_for(_context: EntitySpawnContext) -> Array[Component]:
	return component_recipes


## Declares exact initial Component fields configured from immutable Profile inputs.
## The compiler validates fields/types and rejects two Traits configuring the same field.
func configuration_for(_context: EntitySpawnContext) -> Dictionary[Script, Dictionary]:
	return { }


## Returns capability configuration errors without install hooks or runtime effects.
func configuration_issues(_context: EntitySpawnContext) -> PackedStringArray:
	return PackedStringArray()
#endregion
