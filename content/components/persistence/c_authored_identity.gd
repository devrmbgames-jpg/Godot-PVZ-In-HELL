extends Component
## Immutable placed-actor identity compiled once from explicit level and instance authoring tokens.
class_name C_AuthoredIdentity

## Immutable level/world content scope; PlacedIdentityRules is the sole materialization writer.
var world_id: StringName = &""
## Immutable authored local instance token; renaming/reparenting does not change this reference.
var local_id: StringName = &""

#region Stable identity
## Returns the canonical scoped placed key without consulting Node paths or instance numbers.
func actor_key() -> String:
	return "placed/%s/%s" % [world_id, local_id]
#endregion
