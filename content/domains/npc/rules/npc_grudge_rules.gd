extends RefCounted
## Read-only actor-specific resentment derived from the person's existing durable incident memory.
class_name NpcGrudgeRules

const OFFENSES: Array[NpcMemory.Kind] = [
	NpcMemory.Kind.THREAT,
	NpcMemory.Kind.LIE,
	NpcMemory.Kind.BROKEN_PROMISE,
	NpcMemory.Kind.ATTACK,
	NpcMemory.Kind.KILLING,
	NpcMemory.Kind.OFFENSE,
]


#region Durable personal resentment
## Resolves the committed typed capability without adding another mutable trait or memory cache.
static func capability(person: NpcRecord) -> DEF_NpcGrudge:
	for rule: DEF_NpcTrait in person.rules_for():
		if rule is DEF_NpcGrudge:
			return rule as DEF_NpcGrudge
	return null


## Only remembered personal offenses count; witnessed harm to another person is not a grudge.
## Legacy broken-promise memories without a physical victim remain personal to their owner.
static func remembers_offender(person: NpcRecord, actor_id: StringName) -> bool:
	if actor_id.is_empty() or capability(person) == null:
		return false
	for memory: NpcMemory in person.memories:
		if memory.actor_id != actor_id or memory.kind not in OFFENSES:
			continue
		if (
			memory.victim_id == person.npc_id
			or (memory.kind == NpcMemory.Kind.BROKEN_PROMISE and memory.victim_id.is_empty())
		):
			return true
	return false


## A bounded authored bonus never stacks or rerolls, and survives day/body/save changes.
static func attack_bonus(person: NpcRecord, actor_id: StringName) -> float:
	var rule: DEF_NpcGrudge = capability(person)
	return (
		rule.attack_probability_bonus
		if rule != null and remembers_offender(person, actor_id)
		else 0.0
	)
#endregion
