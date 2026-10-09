extends RefCounted
## Explicit transient build inputs; compilation reads this context without binding ECS.world.
class_name EntitySpawnContext

## World used only to validate existing endpoints; null is valid for read-only scene preview.
var world: World = null
## Scene instance whose native structure is validated; it stays outside registration until commit.
var actor: Entity = null
## Captured stable instance identity; allocation and duplicate-ID checks belong to the boundary.
var actor_id: String = ""
## Human-readable authored instance path supplied by Inspector/factory/bootstrap.
var instance_path: String = ""
## Immutable tuning inputs keyed by their explicit capability role.
var definitions: Dictionary[StringName, GameDefinition] = {}
## Named endpoints supplied by authored bindings or the owning spawn request.
var bindings: Dictionary[StringName, Entity] = {}
## Entire unregistered placed set allowed as endpoints during one bootstrap preparation.
var candidate_actors: Array[Entity] = []
## Data-only binding intents supplied by a factory request, validated with authored Trait intents.
var initial_bindings: Array[EntityInitialBinding] = []

## Explicit instance values; only fields enumerated by the enabled Traits may be supplied.
var initial_fields: Dictionary[Script, Dictionary] = {}
