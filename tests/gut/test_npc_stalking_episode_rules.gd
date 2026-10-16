extends GutTest
## Pure episode identity, strict success distance and retained active-time eligibility contracts.


#region Success and eligibility
func test_close_success_requires_a_hidden_episode_and_strict_finite_distance() -> void:
	for distance: float in [0.0, 1.4, 2.49]:
		assert_true(NpcStalkingRules.close_success(true, true, distance))
	for distance: float in [2.5, 2.51, -0.1, INF, NAN]:
		assert_false(NpcStalkingRules.close_success(true, true, distance))
	assert_false(NpcStalkingRules.close_success(false, true, 1.0))
	assert_false(NpcStalkingRules.close_success(true, false, 1.0))


func test_success_cooldown_never_expires_before_thirty_active_seconds() -> void:
	var person: NpcRecord = NpcRecord.new()
	person.stalking_sequence = 1
	person.stalking_decision_tick = 1_000_000
	person.stalking_notice_tick = 1_000_000
	person.stalking_next_eligible_tick = NpcStalkingRules.success_deadline(1_000_000)
	assert_eq(person.stalking_next_eligible_tick, 31_000_000)
	assert_false(NpcStalkingRules.opportunity_due(person, 30_999_999))
	assert_true(NpcStalkingRules.opportunity_due(person, 31_000_000))
	# Observing the same clock again, as during pause, cannot advance the deadline or sequence.
	assert_false(NpcStalkingRules.opportunity_due(person, 30_999_999))
	assert_eq(person.stalking_sequence, 1)
	assert_eq(NpcStalkingRules.success_deadline(1_000_000, 7_000_000), 38_000_000)


func test_historical_recognition_does_not_disable_future_opportunities() -> void:
	var person: NpcRecord = NpcRecord.new()
	person.npc_id = &"npc/creepy"
	var memory: NpcMemory = NpcMemory.new()
	memory.kind = NpcMemory.Kind.STALKING_NOTICED
	memory.actor_id = &"player"
	memory.victim_id = person.npc_id
	memory.incident_id = NpcStalkingRules.incident(person, memory.actor_id)
	person.memories.append(memory)
	assert_true(NpcStalkingRules.noticed(person, &"player"))
	assert_true(NpcStalkingRules.valid_memory(person, memory))
	assert_true(NpcStalkingRules.opportunity_due(person, 0))
	assert_eq(person.memories.size(), 1)
#endregion


#region Durable shape and bounded arithmetic
func test_never_started_history_has_one_canonical_shape() -> void:
	var person: NpcRecord = NpcRecord.new()
	assert_true(NpcStalkingRules.valid_history(person, 0))
	assert_false(NpcStalkingRules.valid_history(person, -1))
	person.stalking_decision_tick = 0
	assert_false(NpcStalkingRules.valid_history(person, 0))
	person.stalking_decision_tick = -1
	person.stalking_next_eligible_tick = 1
	assert_false(NpcStalkingRules.valid_history(person, 0))
	person.stalking_next_eligible_tick = 0
	person.stalking_sequence = -1
	assert_false(NpcStalkingRules.valid_history(person, 0))


func test_committed_history_rejects_future_or_reversed_timestamps_and_exhaustion() -> void:
	var person: NpcRecord = NpcRecord.new()
	person.stalking_sequence = 1
	person.stalking_decision_tick = 10
	person.stalking_next_eligible_tick = 20
	assert_true(NpcStalkingRules.valid_history(person, 10))
	assert_false(NpcStalkingRules.valid_history(person, 9))
	assert_false(NpcStalkingRules.opportunity_due(person, 19))
	assert_true(NpcStalkingRules.opportunity_due(person, 20))
	person.stalking_next_eligible_tick = 10
	assert_false(NpcStalkingRules.valid_history(person, 10))
	person.stalking_next_eligible_tick = 9
	assert_false(NpcStalkingRules.valid_history(person, 10))
	person.stalking_next_eligible_tick = 20
	person.stalking_decision_tick = -1
	assert_false(NpcStalkingRules.valid_history(person, 10))
	person.stalking_decision_tick = 10
	person.stalking_sequence = NpcStalkingRules.MAX_COUNTER
	assert_true(NpcStalkingRules.valid_history(person, 20))
	assert_false(NpcStalkingRules.opportunity_due(person, 20))


func test_success_deadline_rejects_native_integer_overflow() -> void:
	var latest_start: int = (
		NpcStalkingRules.MAX_COUNTER - NpcStalkingRules.MIN_SUCCESS_COOLDOWN_TICKS
	)
	assert_eq(NpcStalkingRules.success_deadline(latest_start), NpcStalkingRules.MAX_COUNTER)
	assert_eq(NpcStalkingRules.success_deadline(latest_start + 1), -1)
	assert_eq(NpcStalkingRules.success_deadline(latest_start, 1), -1)
	assert_eq(NpcStalkingRules.success_deadline(-1), -1)
	assert_eq(NpcStalkingRules.success_deadline(0, -1), -1)


func test_recent_success_cannot_load_with_a_shortened_cooldown_or_future_notice() -> void:
	var person: NpcRecord = NpcRecord.new()
	person.stalking_sequence = 1
	person.stalking_decision_tick = 90
	person.stalking_notice_tick = 100
	person.stalking_next_eligible_tick = NpcStalkingRules.success_deadline(100)
	assert_true(NpcStalkingRules.valid_history(person, 105))
	person.stalking_next_eligible_tick -= 1
	assert_false(NpcStalkingRules.valid_history(person, 105))
	person.stalking_next_eligible_tick += 1
	person.stalking_notice_tick = 106
	assert_false(NpcStalkingRules.valid_history(person, 105))
	person.stalking_notice_tick = -2
	assert_false(NpcStalkingRules.valid_history(person, 105))


func test_each_committed_episode_has_a_distinct_canonical_neutral_memory() -> void:
	var person: NpcRecord = NpcRecord.new()
	person.npc_id = &"npc/creepy"
	person.stalking_sequence = 2
	person.stalking_notice_tick = 1
	var memory: NpcMemory = NpcMemory.new()
	memory.kind = NpcMemory.Kind.STALKING_NOTICED
	memory.actor_id = &"player"
	memory.victim_id = person.npc_id
	var first: StringName = NpcStalkingRules.episode_incident(person, &"player", 1)
	var second: StringName = NpcStalkingRules.episode_incident(person, &"player", 2)
	assert_ne(first, second)
	for identity: StringName in [first, second, NpcStalkingRules.incident(person, &"player")]:
		memory.incident_id = identity
		assert_true(NpcStalkingRules.valid_memory(person, memory))
	for suffix: String in ["0", "-1", "3", "01", "+1", "1/extra"]:
		memory.incident_id = StringName(
			"%s/%s" % [NpcStalkingRules.incident(person, &"player"), suffix]
		)
		assert_false(NpcStalkingRules.valid_memory(person, memory), suffix)
	memory.incident_id = first
	memory.reaction = NpcMemory.Reaction.ATTACK
	assert_false(NpcStalkingRules.valid_memory(person, memory))
#endregion
