@tool
extends DEF_NpcTrait
## Immutable feeding preference and ordinary attack floor; no per-tick behavior in this definition.
class_name DEF_NpcFeeding

## Every ordinary attack retains this fraction of the target's effective maximum HP.
@export_range(0.01, 0.99) var minimum_health_fraction: float = 0.1
## Visible players at or below this fraction are preferred feeding targets.
@export_range(0.01, 1.0) var wounded_health_fraction: float = 0.75


#region Authored capability
func _init() -> void:
	kind = Kind.CAPABILITY


func valid_configuration() -> bool:
	return (
		kind == Kind.CAPABILITY and is_finite(minimum_health_fraction)
		and is_finite(wounded_health_fraction) and minimum_health_fraction > 0.0
		and minimum_health_fraction < wounded_health_fraction and wounded_health_fraction <= 1.0
	)
#endregion
