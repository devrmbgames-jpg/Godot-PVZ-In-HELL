extends RefCounted
## Read-only typed blood eligibility and the NPC's single perceived live binding.
class_name NpcBloodQueries


static func has_trait(actor: Entity, flag: int) -> bool:
	var traits: C_ReceiverTraits = actor.get_component(C_ReceiverTraits) as C_ReceiverTraits
	return traits != null and traits.traits & flag != 0


static func valid_zone(zone: Entity) -> bool:
	if (
		not EntityAvailability.contains(zone, ECS.world)
		or not zone is E_BloodArea or not zone.has_component(C_BloodArea)
	):
		return false
	var hazard: C_Hazard = zone.get_component(C_Hazard) as C_Hazard
	var lifetime: C_HazardLifetime = zone.get_component(C_HazardLifetime) as C_HazardLifetime
	return (
		hazard != null and hazard.definition is DEF_BloodArea
		and HazardProfileRules.valid(hazard.definition) and lifetime != null
		and is_finite(lifetime.remaining_seconds)
		and lifetime.remaining_seconds > 0.0 and not lifetime.owner_loss_pending
	)


static func zone_for(actor: Entity) -> E_BloodArea:
	if not EntityAvailability.contains(actor, ECS.world) or actor.has_component(C_Death):
		return null
	for binding: Relationship in actor.relationships:
		if binding.relation is R_NpcBloodZone and valid_zone(binding.target):
			return binding.target as E_BloodArea
	return null


## Native overlap is authoritative for retention, including authored collider/body extents.
static func inside(actor: E_DistrictNpc, zone: E_BloodArea) -> bool:
	return valid_zone(zone) and zone.get_area().overlaps_body(actor)


static func calmed(actor: Entity) -> bool:
	return has_trait(actor, C_ReceiverTraits.Trait.VAMPIRE) and zone_for(actor) != null
