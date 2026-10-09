extends RefCounted
## Transient validated recipes/provenance; it is neither a runtime registry nor gameplay authority.
class_name EntityBuildPlan


## Actionable configuration diagnostic with source capability and authored instance context.
class Issue extends RefCounted:
	## Stable reason category, distinct from gameplay rejection or runtime action failure.
	var code: StringName = &""
	## Human-readable configuration explanation.
	var message: String = ""
	## Authored instance path supplied by the caller.
	var instance_path: String = ""
	## Owning capability identity; empty identifies scene/code/context preparation.
	var trait_id: StringName = &""
	## Scene/code/Trait resource provenance.
	var source: String = ""


## Validated initial binding data; the boundary resolves lifecycle again before live fixup.
class Binding extends RefCounted:
	## Fresh Relationship data recipe, not an installed binding.
	var relation: Component = null
	## Captured endpoint identity from the explicit context.
	var target: Entity = null
	## Owning provider/capability provenance.
	var source: String = ""


## Scene instance captured by the compiler; only that instance may consume this transient plan.
var built_actor: Entity = null
## Explicit World captured during compilation; null remains valid for pure preview only.
var built_world: World = null
## Captured instance ID; changing identity requires a fresh compilation/preflight.
var built_actor_id: String = ""
## Independently owned initial Component recipes in canonical Script-path order.
var component_recipes: Array[Component] = []
## Validated binding intents to materialize after registration and any saved-state overlay.
var bindings: Array[Binding] = []
## One provider per Component Script; this cache explains composition and owns no live state.
var provenance: Dictionary[Script, String] = { }
## Exact initial field provenance per Component Script; this is transient compiler explanation.
var field_provenance: Dictionary[Script, Dictionary] = { }
## Configuration errors prevent materialization and ready publication.
var issues: Array[Issue] = []


#region Build outcome
## Reports whether every known provider/requirement/binding validation passed.
func valid() -> bool:
	return issues.is_empty()
#endregion
