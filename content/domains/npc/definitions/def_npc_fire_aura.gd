@tool
extends DEF_NpcTrait
## Immutable fire presence: the existing torso aura plus a separately owned thin floor Hazard.
class_name DEF_NpcFireAura

## Required authored floor volume; Hazard Systems own its follow, damage and lifetime.
@export var floor_hazard: DEF_ToxicArea = null
## Probability of opening a received parcel at the handoff, without a private booth.
@export_range(0.0, 1.0) var immediate_unpack_probability: float = 0.8
## One committed roll per opening with a matching real physical reagent.
@export_range(0.0, 1.0) var opening_explosion_probability: float = 0.3
## Immutable blast profile; generic Hazard damage/impulse/lifetime owners execute it.
@export var opening_explosion: DEF_Explosion = preload(
	"res://content/domains/hazards/definitions/def_npc_opening_fire_blast.tres"
)
## Authored physical item definitions eligible for heat ignition; acid/blood are excluded.
@export var ignition_items: Array[DEF_InventoryItem] = [
	preload("res://content/domains/inventory/definitions/def_item_fire_flask.tres"),
	preload("res://content/domains/inventory/definitions/def_item_fire_barrel.tres"),
]


## Fire presence keeps the existing FIRE_AURA kind and rejects non-floor or invalid tuning.
func valid_configuration() -> bool:
	if (
		not is_finite(immediate_unpack_probability) or immediate_unpack_probability < 0.0
		or immediate_unpack_probability > 1.0
		or not is_finite(opening_explosion_probability) or opening_explosion_probability < 0.0
		or opening_explosion_probability > 1.0
		or opening_explosion == null or not HazardProfileRules.valid(opening_explosion)
		or opening_explosion.damage_type != DamageRequest.Type.FIRE
		or ignition_items.is_empty()
	):
		return false
	for item: DEF_InventoryItem in ignition_items:
		if (
			item == null or item.key == &"" or not item.requires_world_body()
			or not item.world_pickup_scene.ends_with(".tscn")
			or not ResourceLoader.exists(item.world_pickup_scene)
		):
			return false
	return (
		kind == Kind.FIRE_AURA and aura != null and HazardProfileRules.valid(aura)
		and floor_hazard != null and floor_hazard.floor_height > 0.0
		and HazardProfileRules.valid(floor_hazard) and floor_hazard.key != aura.key
	)
