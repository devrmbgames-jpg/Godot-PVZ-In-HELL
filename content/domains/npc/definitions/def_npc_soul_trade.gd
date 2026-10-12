@tool
extends DEF_NpcTrait
## Immutable terms for an explicit soul offer; elapsed time remains owned by GameClock.
class_name DEF_NpcSoulTrade

## Permanent Strength gain for one accepted offer.
@export_range(0.1, 100.0) var strength_gain: float = 1.0
## Permanent reduction of maximum Health, in HP.
@export_range(0.1, 1000.0) var maximum_health_cost: float = 10.0
## Total accepted deals before death that forfeit the player's remaining life.
@export_range(1, 100) var fatal_deal_count: int = 3
## Minimum elapsed simulation seconds before this dealer can issue another resolved offer.
@export_range(0.0, 3600.0) var offer_cooldown_seconds: float = 60.0


#region Authored terms
func _init() -> void:
	kind = Kind.CAPABILITY


func valid_configuration() -> bool:
	return (
		kind == Kind.CAPABILITY and is_finite(strength_gain) and strength_gain > 0.0
		and is_finite(maximum_health_cost) and maximum_health_cost > 0.0
		and fatal_deal_count > 0 and is_finite(offer_cooldown_seconds)
		and offer_cooldown_seconds >= 0.0 and offer_cooldown_seconds <= 3600.0
	)
#endregion
