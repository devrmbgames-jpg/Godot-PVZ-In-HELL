extends RefCounted
## Read-only selected pride and remembered strength; no hidden behavior dispatcher or clocks.
class_name NpcPrideRules


#region Selected capability and remembered strength
## Returns an already committed immutable rule without an archetype key or variation reroll.
static func selected_rule(traits: Array[DEF_NpcTrait]) -> DEF_NpcStrengthPride:
	for rule: DEF_NpcTrait in traits:
		if rule is DEF_NpcStrengthPride:
			return rule as DEF_NpcStrengthPride
	return null


## Latest recognized submission overrides former respect; neutral incidents leave it intact.
static func respects(person: NpcRecord, actor_id: StringName) -> bool:
	if actor_id.is_empty():
		return false
	for index: int in range(person.memories.size() - 1, -1, -1):
		var memory: NpcMemory = person.memories[index]
		if memory.actor_id != actor_id:
			continue
		if memory.kind == NpcMemory.Kind.SUBMISSION:
			return false
		if memory.reaction == NpcMemory.Reaction.RESPECT or memory.kind == NpcMemory.Kind.KILLING:
			return true
	return false


## One recognized exposed item per phase is one offense; replay cannot restart canceled combat.
static func toy_incident(person: NpcRecord, item_id: String, day: int, phase: int) -> StringName:
	return StringName("toy/%s/%d/%d/%s" % [person.npc_id, day, phase, item_id])


## Existing incident memory is the sole durable idempotency authority.
static func remembered(person: NpcRecord, incident: StringName) -> bool:
	for memory: NpcMemory in person.memories:
		if memory.incident_id == incident:
			return true
	return false
#endregion
