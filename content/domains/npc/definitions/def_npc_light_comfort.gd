@tool
extends DEF_NpcTrait
## Authored local light preference; ordinary obligations and conflicts remain available.
class_name DEF_NpcLightComfort

## Exposure above this fraction motivates an optional local position adjustment.
@export_range(0.0, 1.0) var discomfort_threshold: float = 0.65
## A preferred authored destination must be at or below this exposure.
@export_range(0.0, 1.0) var comfortable_threshold: float = 0.35
## Maximum local adjustment distance in metres; never chooses a district exit.
@export_range(0.5, 20.0) var search_radius: float = 12.0


#region Authored capability
func _init() -> void:
	kind = Kind.CAPABILITY
	incompatible = [Kind.LIGHT_AVERSION]


func valid_configuration() -> bool:
	return (
		kind == Kind.CAPABILITY and is_finite(discomfort_threshold)
		and is_finite(comfortable_threshold) and is_finite(search_radius)
		and comfortable_threshold >= 0.0 and comfortable_threshold < discomfort_threshold
		and discomfort_threshold <= 1.0 and search_radius >= 0.5
		and search_radius <= 20.0 and incompatible.has(Kind.LIGHT_AVERSION)
	)
#endregion
