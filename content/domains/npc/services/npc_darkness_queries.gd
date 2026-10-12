extends RefCounted
## Read-only sampled light constraint; no sensing, clocks or target mutation.
class_name NpcDarknessQueries


#region Sampled constraint
## Adapts an optional dialogue actor to the same perceived-light criterion used by the hunt guard.
static func player_in_hunting_darkness(actor: Entity) -> bool:
	if actor == null:
		return false
	var identity: C_NpcIdentity = actor.get_component(C_NpcIdentity) as C_NpcIdentity
	var awareness: C_NpcAwareness = actor.get_component(C_NpcAwareness) as C_NpcAwareness
	if identity == null or awareness == null:
		return false
	var person: NpcRecord = NpcPopulationQueries.person_for(identity.npc_id)
	if person == null:
		return false
	var rule: DEF_NpcDarkPredator = (
		person.rule_for(DEF_NpcTrait.Kind.DARK_PREDATOR) as DEF_NpcDarkPredator
	)
	return NpcTraitRules.player_in_hunting_darkness(awareness, rule)


## Attack boundaries share the due-step trait fact even when another native branch preempts calm.
static func combat_suppressed(actor: Entity) -> bool:
	var awareness: C_NpcAwareness = actor.get_component(C_NpcAwareness) as C_NpcAwareness
	return awareness != null and awareness.darkness_combat_suppressed
#endregion
