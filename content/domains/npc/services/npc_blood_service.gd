extends RefCounted
## Explicit observation/release/calming operations; sensing cadence stays in Systems.
class_name NpcBloodService


## Commit one already-perceived zone. A spawn fact requests an urgent cadence wake.
static func observe(
	actor: E_DistrictNpc,
	person: NpcRecord,
	zone: E_BloodArea,
	wake: bool = false,
) -> void:
	if (
		not EntityAvailability.contains(actor, ECS.world)
		or actor.has_component(C_Death) or not NpcBloodQueries.valid_zone(zone)
	):
		return
	var vampire: bool = NpcBloodQueries.has_trait(actor, C_ReceiverTraits.Trait.VAMPIRE)
	if not vampire and not NpcBloodQueries.has_trait(actor, C_ReceiverTraits.Trait.UNCLEAN):
		return
	var awareness: C_NpcAwareness = actor.get_component(C_NpcAwareness) as C_NpcAwareness
	if awareness.rejected_blood_ids.has(zone.id):
		return
	var previous: E_BloodArea = NpcBloodQueries.zone_for(actor)
	if (
		vampire and previous != null and previous != zone
		and NpcBloodQueries.inside(actor, previous)
	):
		calm(actor)
		return
	var changed: bool = previous != zone
	if changed:
		release(actor)
		actor.add_relationship(Relationship.new(R_NpcBloodZone.new(), zone))
	if vampire:
		if changed:
			NpcIntentService.stop(actor)
		calm(actor)
	elif changed:
		_provoke(actor, person, zone)
	if wake and EntityAvailability.contains(actor, ECS.world):
		NpcDecisionService.request_wake(actor, &"perceived_blood", true)


## Cancel attack execution and remembered search/fear intent, preserving durable memories.
static func calm(actor: E_DistrictNpc) -> void:
	var combat: C_NpcCombat = actor.get_component(C_NpcCombat) as C_NpcCombat
	if (
		CombatQueries.target_for(actor) != null
		or combat != null and combat.phase != C_NpcCombat.Phase.READY
	):
		CombatService.end_combat(actor)
	var awareness: C_NpcAwareness = actor.get_component(C_NpcAwareness) as C_NpcAwareness
	awareness.fleeing = false
	awareness.flee_portal_id = &""
	awareness.has_last_seen = false
	awareness.search_elapsed = 0.0
	awareness.target_visible = false


static func release(actor: Entity) -> void:
	for binding: Relationship in actor.relationships.duplicate():
		if binding.relation is R_NpcBloodZone:
			actor.remove_relationship(binding)


## Associate an accepted native approach request with its already perceived zone.
static func mark_approach(actor: Entity, zone: E_BloodArea, task_id: int) -> void:
	for binding: Relationship in actor.relationships:
		if binding.relation is R_NpcBloodZone and binding.target == zone:
			(binding.relation as R_NpcBloodZone).approach_task_id = task_id
			return


## Provocation concerns only the actually visible, recognized live blood instigator.
static func _provoke(actor: E_DistrictNpc, person: NpcRecord, zone: E_BloodArea) -> void:
	var hazard: C_Hazard = zone.get_component(C_Hazard) as C_Hazard
	var profile: DEF_BloodArea = hazard.definition as DEF_BloodArea
	var instigator: Entity = hazard.instigator
	if (
		not profile.provokes_unclean or not EntityAvailability.contains(instigator, ECS.world)
		or instigator == actor or instigator.has_component(C_Death)
		or NpcSocialService.identity_for(instigator).is_empty()
		or not NpcPerceptionService.can_see(actor, instigator, person)
	):
		return
	var incident: StringName = StringName("blood/%s" % hazard.request_id)
	for memory: NpcMemory in person.memories:
		if memory.incident_id == incident:
			return
	NpcSocialService.remember(
		person,
		instigator,
		actor,
		NpcMemory.Kind.OFFENSE,
		incident,
		NpcMemory.Reaction.ATTACK,
	)
	NpcSocialService.apply_reaction(actor, instigator, NpcMemory.Reaction.ATTACK)
