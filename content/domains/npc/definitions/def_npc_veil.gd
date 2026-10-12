@tool
extends DEF_NpcTrait
## Conditional escape appearance; physical collision and damage remain authoritative.
class_name DEF_NpcVeil

## Confirmed combat permits escape below this fraction of maximum Health.
@export_range(0.05, 0.9) var escape_health_fraction: float = 0.35
## A fleeing actor may conceal its appearance after losing confirmed player sight.
@export var allow_invisible_escape: bool = true


#region Authored capability
func _init() -> void:
	kind = Kind.CAPABILITY


func valid_configuration() -> bool:
	return (
		kind == Kind.CAPABILITY and is_finite(escape_health_fraction)
		and escape_health_fraction >= 0.05 and escape_health_fraction <= 0.9
	)
#endregion
