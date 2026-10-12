@tool
extends DEF_NpcTrait
## Immutable fire presence: the existing torso aura plus a separately owned thin floor Hazard.
class_name DEF_NpcFireAura

## Required authored floor volume; Hazard Systems own its follow, damage and lifetime.
@export var floor_hazard: DEF_ToxicArea = null


## Fire presence keeps the existing FIRE_AURA kind and rejects non-floor or invalid tuning.
func valid_configuration() -> bool:
	return (
		kind == Kind.FIRE_AURA and aura != null and HazardProfileRules.valid(aura)
		and floor_hazard != null and floor_hazard.floor_height > 0.0
		and HazardProfileRules.valid(floor_hazard) and floor_hazard.key != aura.key
	)
