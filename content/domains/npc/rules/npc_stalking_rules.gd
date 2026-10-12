extends RefCounted
## Pure capability and actor-specific detection views; no route, clock or memory mutations.
class_name NpcStalkingRules


#region Selected capability and durable recognition
static func selected_rule(rules: Array[DEF_NpcTrait]) -> DEF_NpcStalking:
	for rule: DEF_NpcTrait in rules:
		if rule is DEF_NpcStalking:
			return rule as DEF_NpcStalking
	return null


## Recognition is per person/player, persists across days and is never a random social reaction.
static func noticed(person: NpcRecord, actor_id: StringName) -> bool:
	for memory: NpcMemory in person.memories:
		if memory.kind == NpcMemory.Kind.STALKING_NOTICED and memory.actor_id == actor_id:
			return true
	return false


## Validates the closed neutral detection receipt independently of the current selected capability.
static func valid_memory(person: NpcRecord, memory: NpcMemory) -> bool:
	return (
		not memory.actor_id.is_empty() and memory.victim_id == person.npc_id
		and memory.incident_id == incident(person, memory.actor_id)
		and memory.reaction == NpcMemory.Reaction.TALK
	)


## A stable incident prevents repeated visible ticks or restored callbacks from noticing twice.
static func incident(person: NpcRecord, actor_id: StringName) -> StringName:
	return StringName("stalking/noticed/%s/%s" % [person.npc_id, actor_id])
#endregion
