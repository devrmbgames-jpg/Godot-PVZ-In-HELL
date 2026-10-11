@tool
extends DEF_NpcTrait
## Authored reversible darkness hunting; legacy DARK_PREDATOR reactions retain their policy.
class_name DEF_NpcDarkPredator

## Exposure at or above this threshold ends combat; must exceed the inherited hunt threshold.
@export_range(0.0, 1.0) var peaceful_light_threshold: float = 0.5


#region Authored capability
func _init() -> void:
	kind = Kind.DARK_PREDATOR
	light_threshold = 0.25


func valid_configuration() -> bool:
	return (
		kind == Kind.DARK_PREDATOR and is_finite(light_threshold)
		and is_finite(peaceful_light_threshold) and light_threshold >= 0.0
		and peaceful_light_threshold <= 1.0 and light_threshold < peaceful_light_threshold
	)
#endregion
