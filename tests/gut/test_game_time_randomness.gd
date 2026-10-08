extends GutTest
## Proves elapsed-clock ownership, canonical pinned RNG outputs and deterministic durable replay.

const GOLDEN_PATH: String = "res://tests/fixtures/refactoring_v2/decision_rng_golden.json"

var _world: World
var _session: Entity
var _cycle: C_DayCycle
var _clock_owner: S_GameTime

#region Clock fixture
## Builds the required calendar aggregate and actual elapsed-clock owner.
func before_each() -> void:
	_world = World.new()
	add_child(_world)
	ECS.world = _world
	_session = Entity.new()
	_session.component_resources = [C_DayCycle.new()]
	_world.add_entity(_session)
	_cycle = _session.get_component(C_DayCycle) as C_DayCycle
	_clock_owner = S_GameTime.new()
	_clock_owner.group = "Clock"
	_world.add_system(_clock_owner)


## Releases the fixture world and native component graph.
func after_each() -> void:
	_world.purge(false)
	_world.free()
	ECS.world = null


func _step(delta: float) -> void:
	_clock_owner.process([_session], [[_cycle]], delta)
#endregion

#region Elapsed ticks versus calendar
## Carries fractional ticks across partitioned callback deltas.
func test_subtick_remainder_survives_small_steps_without_losing_duration() -> void:
	_step(0.0000004)
	assert_eq(_cycle.clock.elapsed_ticks, 0)
	assert_almost_eq(_cycle.clock.tick_remainder, 0.4, 0.000001)
	_step(0.0000004)
	_step(0.0000004)
	assert_eq(_cycle.clock.elapsed_ticks, 1)
	assert_eq(_cycle.clock.step_ticks, 1)
	assert_almost_eq(_cycle.clock.tick_remainder, 0.2, 0.000001)
	assert_eq(_cycle.day_index, 1)
	assert_eq(_cycle.phase, C_DayCycle.Phase.MORNING)


## Separates elapsed simulation from paused time and player-driven calendar changes.
func test_pause_and_sleep_freeze_elapsed_time_while_calendar_advances_independently() -> void:
	_step(0.25)
	var saved_ticks: int = _cycle.clock.elapsed_ticks
	_cycle.clock.paused = true
	_step(100.0)
	assert_eq(_cycle.clock.elapsed_ticks, saved_ticks)
	assert_eq(_cycle.clock.step_ticks, 0)
	_cycle.clock.paused = false
	_cycle.phase = C_DayCycle.Phase.NIGHT
	_step(86400.0)
	assert_eq(_cycle.clock.elapsed_ticks, saved_ticks)

	var calendar_owner: S_DayPhase = S_DayPhase.new()
	_world.add_system(calendar_owner)
	calendar_owner.process([_session], [[_cycle]], 86400.0)
	assert_eq(_cycle.day_index, 2)
	assert_eq(_cycle.phase, C_DayCycle.Phase.MORNING)
	assert_eq(_cycle.clock.elapsed_ticks, saved_ticks)
	_step(0.5)
	assert_eq(_cycle.clock.elapsed_ticks, saved_ticks + 500_000)


## Rejects invalid engine input without changing the durable timestamp.
func test_invalid_callback_delta_cannot_corrupt_the_clock() -> void:
	_step(1.0)
	for invalid_delta: float in [NAN, INF, -1.0]:
		_step(invalid_delta)
		assert_eq(_cycle.clock.elapsed_ticks, 1_000_000)
		assert_eq(_cycle.clock.step_ticks, 0)
	assert_true(GameTimeRules.valid(_cycle.clock))
#endregion

#region Canonical seed and pinned native RNG
## Checks independent byte/seed oracles and exact pinned native RNG bits.
func test_independent_utf8_sha256_golden_and_pinned_rng_outputs() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(GOLDEN_PATH))
	var fixture: Dictionary = parsed as Dictionary
	assert_eq(String(fixture.algorithm), DecisionRandomRules.ALGORITHM)
	var engine_version: Dictionary = Engine.get_version_info()
	assert_eq("%s.%s.%s" % [engine_version.major, engine_version.minor, engine_version.patch],
		String(fixture.godot))
	for sample: Dictionary in fixture.cases:
		var world_seed: int = String(sample.world_seed).to_int()
		var actor_id: String = String(sample.actor_id)
		var day: int = int(sample.day)
		var kind: String = String(sample.kind)
		var sequence: int = int(sample.sequence)
		var encoded_key: PackedByteArray = DecisionRandomRules.key_bytes(
			world_seed, actor_id, day, kind, sequence,
		)
		assert_eq(encoded_key.hex_encode(), String(sample.key_hex))
		assert_eq(DecisionRandomRules.seed_for(world_seed, actor_id, day, kind, sequence),
			String(sample.seed).to_int())

		var random: RandomNumberGenerator = DecisionRandomRules.generator(
			world_seed, actor_id, day, kind, sequence,
		)
		for expected: float in sample.integers:
			assert_eq(random.randi(), int(expected))
		random = DecisionRandomRules.generator(world_seed, actor_id, day, kind, sequence)
		for expected_bits: String in sample.fraction_bits:
			var actual_bits: String = PackedFloat64Array([random.randf()]).to_byte_array().hex_encode()
			assert_eq(actual_bits, expected_bits)


## Proves field framing and all five decision dimensions matter.
func test_framing_and_each_key_dimension_distinguish_decisions() -> void:
	var canonical: int = DecisionRandomRules.seed_for(7, "npc/1", 3, "activity", 5)
	assert_ne(canonical, DecisionRandomRules.seed_for(8, "npc/1", 3, "activity", 5))
	assert_ne(canonical, DecisionRandomRules.seed_for(7, "npc/2", 3, "activity", 5))
	assert_ne(canonical, DecisionRandomRules.seed_for(7, "npc/1", 4, "activity", 5))
	assert_ne(canonical, DecisionRandomRules.seed_for(7, "npc/1", 3, "social", 5))
	assert_ne(canonical, DecisionRandomRules.seed_for(7, "npc/1", 3, "activity", 6))
	assert_ne(DecisionRandomRules.seed_for(7, "a:1", 3, "b", 5),
		DecisionRandomRules.seed_for(7, "a", 3, "1:b", 5))
#endregion

#region Durable replay and malformed data
## Restores durable clock state and reproduces a repeated-decision preview.
func test_clock_remainder_seed_and_calendar_roundtrip_without_consuming_preview() -> void:
	_cycle.clock.world_seed = -42
	_cycle.day_index = 12
	_step(0.0000014)
	var first_roll: int = GameTimeQueries.decision("npc/7", 12, "activity", 19).randi()
	var encoded: Dictionary = SaveDataCodec.component_data(_cycle)
	var restored: C_DayCycle = C_DayCycle.new()
	assert_true(SaveDataCodec.apply_fields(restored, encoded.fields as Dictionary))
	assert_ne(restored.clock, _cycle.clock)
	assert_eq(restored.clock.elapsed_ticks, _cycle.clock.elapsed_ticks)
	assert_eq(restored.clock.tick_remainder, _cycle.clock.tick_remainder)
	assert_eq(restored.day_index, 12)
	assert_eq(restored.clock.world_seed, -42)
	var restored_random: RandomNumberGenerator = DecisionRandomRules.generator(
		restored.clock.world_seed, "npc/7", restored.day_index, "activity", 19,
	)
	assert_eq(restored_random.randi(), first_roll)
	assert_eq(GameTimeQueries.decision("npc/7", 12, "activity", 19).randi(), first_roll)
	assert_eq(_cycle.clock.elapsed_ticks, 1)


## Rejects malformed clock records before they become gameplay authority.
func test_incomplete_negative_nonfinite_and_out_of_quantum_clock_records_are_rejected() -> void:
	var encoded: Dictionary = SaveDataCodec.encode(_cycle.clock) as Dictionary
	for invalid_ticks: int in [-1, -100]:
		var malformed: Dictionary = encoded.duplicate(true)
		(malformed.fields as Dictionary).elapsed_ticks = invalid_ticks
		assert_null(SaveDataCodec.decode(malformed))
	for invalid_remainder: float in [NAN, INF, -0.1, 1.0]:
		var malformed: Dictionary = encoded.duplicate(true)
		(malformed.fields as Dictionary).tick_remainder = invalid_remainder
		assert_null(SaveDataCodec.decode(malformed))
	var incomplete: Dictionary = encoded.duplicate(true)
	(incomplete.fields as Dictionary).erase("world_seed")
	assert_null(SaveDataCodec.decode(incomplete))
#endregion

#region Canonical random candidate order
## Proves canonical sorting makes physical variants independent of container order.
func test_package_scene_preview_is_independent_of_authored_variant_order() -> void:
	var definition: DEF_Package = DEF_Package.new()
	definition.scene_variants = [
		"res://content/domains/packages/entities/package_b.tscn",
		"res://content/domains/packages/entities/package_a.tscn",
		"res://content/domains/packages/entities/package.tscn",
	]
	var chosen: String = PackageSceneRules.variant_for(definition, "package/7", 12, -42)
	definition.scene_variants.reverse()
	assert_eq(PackageSceneRules.variant_for(definition, "package/7", 12, -42), chosen)
	assert_eq(PackageSceneRules.variant_for(definition, "package/7", 12, -42), chosen)


## Proves macro schedule previews neither depend on authored ordering nor consume sequences.
func test_macro_schedule_goal_uses_sorted_ids_without_consuming_activity_sequence() -> void:
	var district: DEF_District = DEF_District.new()
	var person: NpcRecord = NpcRecord.new()
	person.npc_id = &"npc/7"
	person.profile = DEF_NpcProfile.new()
	person.activity_sequence = 19
	for identity: StringName in [&"activity/z", &"activity/a", &"activity/m"]:
		var place: DEF_DistrictPlace = DEF_DistrictPlace.new()
		place.key = identity
		place.kind = DEF_DistrictPlace.Kind.ACTIVITY
		district.places.append(place)
	var goal: StringName = NpcScheduleRules.goal_for(
		district, person, DEF_NpcSchedule.Location.STREET, -42, 12, C_DayCycle.Phase.DAY,
	)
	district.places.reverse()
	var reordered_goal: StringName = NpcScheduleRules.goal_for(
		district, person, DEF_NpcSchedule.Location.STREET, -42, 12, C_DayCycle.Phase.DAY,
	)
	assert_eq(reordered_goal, goal)
	assert_eq(person.activity_sequence, 19)
#endregion

#region Storage retry clock
## Storage retries make bounded progress during Night while elapsed gameplay remains frozen.
func test_night_storage_retry_progress_does_not_advance_gameplay_timestamp() -> void:
	var state: C_Autosave = C_Autosave.new()
	state.path = "user://task47_rejected_slot.pvzh"
	state.rejected_path = state.path
	state.retry_seconds = 1.0
	_session.add_component(state)
	_cycle.phase = C_DayCycle.Phase.NIGHT
	_cycle.night_ready = false
	var storage_owner: S_NightSave = S_NightSave.new()
	_world.add_system(storage_owner)

	_world.process(2.0, "Clock")
	_world.process(2.0, "Storage")
	assert_eq(state.last_error, ERR_UNAUTHORIZED)
	assert_eq(state.retry_remaining, 1.0)
	assert_eq(_cycle.clock.elapsed_ticks, 0)
	_world.process(0.4, "Clock")
	_world.process(0.4, "Storage")
	assert_almost_eq(state.retry_remaining, 0.6, 0.000001)
	_world.process(1.0, "Clock")
	_world.process(1.0, "Storage")
	assert_eq(state.retry_remaining, 1.0)
	assert_eq(_cycle.clock.elapsed_ticks, 0)
	assert_eq(_cycle.day_index, 1)
	assert_false(_cycle.night_ready)
#endregion

#region Exclusive clock aggregate ownership
## Two GECS entities using one authored recipe receive independent live clocks and leave the recipe intact.
func test_reused_component_recipe_does_not_share_mutable_clock_state() -> void:
	var recipe: C_DayCycle = C_DayCycle.new()
	recipe.clock.world_seed = -42
	recipe.clock.elapsed_ticks = 7
	var first_owner: Entity = Entity.new()
	first_owner.component_resources = [recipe]
	_world.add_entity(first_owner)
	var second_owner: Entity = Entity.new()
	second_owner.component_resources = [recipe]
	_world.add_entity(second_owner)
	var first_cycle: C_DayCycle = first_owner.get_component(C_DayCycle) as C_DayCycle
	var second_cycle: C_DayCycle = second_owner.get_component(C_DayCycle) as C_DayCycle
	assert_ne(first_cycle.clock, recipe.clock)
	assert_ne(first_cycle.clock, second_cycle.clock)
	_clock_owner.process([first_owner], [[first_cycle]], 1.0)
	assert_eq(first_cycle.clock.elapsed_ticks, 1_000_007)
	assert_eq(second_cycle.clock.elapsed_ticks, 7)
	assert_eq(recipe.clock.elapsed_ticks, 7)
	assert_eq(first_cycle.clock.world_seed, -42)
#endregion
