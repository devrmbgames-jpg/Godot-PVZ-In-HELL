@tool
extends DEF_NpcTrait
## Authored voluntary blood terms; dialogue offers are explicit operations, never scheduled ticks.
class_name DEF_NpcBloodConsent

## Inclusive minimum percentage of current HP at acceptance.
@export_range(5, 40) var minimum_percent: int = 5
## Inclusive maximum percentage of current HP at acceptance.
@export_range(5, 40) var maximum_percent: int = 40
## Minimum simulation seconds after resolution before another offer from this person.
@export_range(0.0, 3600.0) var offer_cooldown_seconds: float = 60.0


#region Authored capability
func _init() -> void:
	kind = Kind.CAPABILITY


func valid_configuration() -> bool:
	return (
		kind == Kind.CAPABILITY and minimum_percent >= 5 and maximum_percent <= 40
		and minimum_percent <= maximum_percent and is_finite(offer_cooldown_seconds)
		and offer_cooldown_seconds >= 0.0 and offer_cooldown_seconds <= 3600.0
	)
#endregion
