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


## A completed failure belongs to blood only when request, native action and goal still match.
static func approach_failed(actor: Entity, zone: E_BloodArea) -> bool:
	var intent: C_NpcIntent = actor.get_component(C_NpcIntent) as C_NpcIntent
	var decision: C_NpcDecision = actor.get_component(C_NpcDecision) as C_NpcDecision
	var route: C_NpcRoute = actor.get_component(C_NpcRoute) as C_NpcRoute
	if (
		not intent.movement_active or intent.move_uses_entity or not intent.navigation_blocked
		or intent.navigation_pending or route.pending
		or intent.navigation_generation != intent.movement_generation
		or intent.move_position != zone.global_position or route.goal != intent.move_position
	):
		return false
	for binding: Relationship in actor.relationships:
		if binding.relation is R_NpcBloodZone and binding.target == zone:
			var approach: R_NpcBloodZone = binding.relation as R_NpcBloodZone
			return (
				approach.approach_task_id != 0
				and approach.approach_task_id == decision.active_task_id
				and approach.approach_task_id == intent.navigation_task_id
			)
	return false
