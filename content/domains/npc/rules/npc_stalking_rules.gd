extends RefCounted
## Pure capability and actor-specific detection views; no route, clock or memory mutations.
class_name NpcStalkingRules

## Owner-defined strict centre distance for an actual hidden-approach success, in metres.
const SUCCESS_DISTANCE: float = 2.5
## Owner-defined minimum active GameClock interval after success, in microsecond ticks.
const MIN_SUCCESS_COOLDOWN_TICKS: int = 30_000_000
## Native signed integer bound; arithmetic rejects overflow instead of wrapping a deadline.
const MAX_COUNTER: int = 9223372036854775807


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
	if (
		memory.actor_id.is_empty() or memory.victim_id != person.npc_id
		or memory.reaction != NpcMemory.Reaction.TALK
	):
		return false
	# Fixed receipts remain history for dialogue; new attempts use their own committed identity.
	if memory.incident_id == incident(person, memory.actor_id):
		return true
	var identity: String = String(memory.incident_id)
	var sequence_text: String = identity.get_slice("/", identity.get_slice_count("/") - 1)
	if not sequence_text.is_valid_int():
		return false
	var sequence: int = sequence_text.to_int()
	return (
		sequence > 0 and sequence <= person.stalking_sequence
		and person.stalking_notice_tick >= 0
		and memory.incident_id == episode_incident(person, memory.actor_id, sequence)
	)


## A stable incident prevents repeated visible ticks or restored callbacks from noticing twice.
static func incident(person: NpcRecord, actor_id: StringName) -> StringName:
	return StringName("stalking/noticed/%s/%s" % [person.npc_id, actor_id])
#endregion


#region Durable episode contract
## Validates the one personal opportunity clock without consulting derived sensing or memory.
static func valid_history(person: NpcRecord, now_tick: int) -> bool:
	if now_tick < 0 or person.stalking_sequence < 0:
		return false
	if person.stalking_sequence == 0:
		return (
			person.stalking_decision_tick == -1 and person.stalking_notice_tick == -1
			and person.stalking_next_eligible_tick == 0
		)
	if (
		person.stalking_decision_tick < 0 or person.stalking_decision_tick > now_tick
		or person.stalking_next_eligible_tick <= person.stalking_decision_tick
	):
		return false
	if person.stalking_notice_tick == -1:
		return true
	if person.stalking_notice_tick < 0 or person.stalking_notice_tick > now_tick:
		return false
	var minimum_deadline: int = success_deadline(person.stalking_notice_tick)
	return minimum_deadline >= 0 and person.stalking_next_eligible_tick >= minimum_deadline


## Expiry permits evaluating a new opportunity; it never starts one or rerolls a stored choice.
static func opportunity_due(person: NpcRecord, now_tick: int) -> bool:
	return (
		valid_history(person, now_tick) and person.stalking_sequence < MAX_COUNTER
		and now_tick >= person.stalking_next_eligible_tick
	)


## Only an active hidden episode observed strictly inside the distance can count as success.
static func close_success(active_episode: bool, observed: bool, distance: float) -> bool:
	return (
		active_episode and observed and is_finite(distance) and distance >= 0.0
		and distance < SUCCESS_DISTANCE
	)


## Extra delay is already selected by the caller, in ticks; -1 rejects invalid/overflow input.
static func success_deadline(now_tick: int, extra_ticks: int = 0) -> int:
	if now_tick < 0 or extra_ticks < 0:
		return -1
	var latest_start: int = MAX_COUNTER - MIN_SUCCESS_COOLDOWN_TICKS
	if now_tick > latest_start:
		return -1
	var minimum_deadline: int = now_tick + MIN_SUCCESS_COOLDOWN_TICKS
	if extra_ticks > MAX_COUNTER - minimum_deadline:
		return -1
	return minimum_deadline + extra_ticks


## One committed episode has one neutral memory, without erasing earlier dialogue history.
static func episode_incident(
	person: NpcRecord, actor_id: StringName, sequence: int,
) -> StringName:
	return StringName("%s/%d" % [incident(person, actor_id), sequence])
#endregion
