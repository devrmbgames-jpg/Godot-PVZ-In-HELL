extends RefCounted
## Pure character and pair-memory rules for local passage conflicts.
class_name NpcTrafficRules

const INCIDENT_PREFIX: String = "traffic/"


#region Character and durable pair aggression
## Aggressive and brazen personalities expect other pedestrians to yield.
static func aggressive(person: NpcRecord) -> bool:
	return (person != null and _aggressive_personality(person.profile.personality))


static func _aggressive_personality(personality: DEF_NpcProfile.Personality) -> bool:
	return personality in [DEF_NpcProfile.Personality.AGGRESSIVE, DEF_NpcProfile.Personality.BRAZEN]


## Derives bounded aggression toward this opponent from existing durable social memory.
static func attack_bonus(person: NpcRecord, opponent_id: StringName, rule: DEF_NpcTraffic) -> float:
	var count: int = 0
	for memory: NpcMemory in person.memories:
		if (
			memory.kind == NpcMemory.Kind.THREAT and memory.actor_id == opponent_id
			and memory.victim_id == person.npc_id
			and String(memory.incident_id).begins_with(INCIDENT_PREFIX)
		):
			count += 1
	return minf(rule.aggression_limit, count * rule.aggression_step)
#endregion
