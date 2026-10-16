extends GutTest
## Actual camera/solid geometry/navmesh and durable stalking recognition regressions.

const ENTITY_SCRIPT: Script = preload("res://addons/gecs/ecs/entity.gd")
const CREEPY: DEF_NpcArchetype = preload(
	"res://content/domains/npc/definitions/def_npc_archetype_creepy.tres"
)
const BODY: PackedScene = preload("res://content/domains/npc/entities/district_npc.tscn")
const DISTRICT: DEF_District = preload(
	"res://content/domains/npc/definitions/def_district_default.tres"
)
const STALKING_TREE: BehaviorTree = preload(
	"res://content/domains/npc/ai/trees/bt_npc_stalking.tres"
)

var _root: Node3D
var _world: World
var _actor: E_DistrictNpc
var _person: NpcRecord
var _player: Entity
var _camera: Camera3D
var _awareness: C_NpcAwareness
var _decision: C_NpcDecision
var _rule: DEF_NpcStalking
var _map: RID = RID()
var _region: RID = RID()
var _state: C_NpcStalking


## Exercises actual synchronous target-binding publication and release callbacks.
class DuringTargetChange extends Observer:
	## Configured once before registration; true watches publication, false watches release.
	var added: bool = true
	## Borrowed fixture mutation, cleared by removing this observer before teardown.
	var on_change: Callable


	func query() -> QueryBuilder:
		return (
			q.on_relationship_added([R_NpcStalkingTarget])
			if added
			else q.on_relationship_removed([R_NpcStalkingTarget])
		)


	func each(_event: Variant, _entity: Entity, _payload: Variant = null) -> void:
		on_change.call()


#region Native fixture and deterministic boundaries
func before_each() -> void:
	_root = Node3D.new()
	add_child(_root)
	_world = World.new()
	_root.add_child(_world)
	ECS.world = _world
	var marker: Node3D = Node3D.new()
	marker.name = "District"
	_root.add_child(marker)
	var session: Entity = Entity.new()
	var district: C_District = C_District.new()
	district.definition = DISTRICT
	session.component_resources = [district, C_DayCycle.new()]
	_world.add_entity(session)
	_person = NpcRecord.new()
	_person.npc_id = &"stalking/creepy"
	_person.profile = CREEPY
	_person.variation = NpcVariationRules.create(
		CREEPY,
		GameTimeQueries.current().world_seed,
		_person.npc_id,
		1,
	)
	_person.placement = NpcRecord.Placement.STREET
	_person.phase_complete = true
	district.people.append(_person)
	_actor = BODY.instantiate() as E_DistrictNpc
	var context: EntitySpawnContext = EntityCompositionService.context_for(
		_actor,
		_world,
		String(_person.npc_id),
	)
	NpcConstructionService.configure_context(context, _person, DISTRICT)
	assert_true(EntityCompositionService.try_register(context))
	_actor.place_at(Vector3(0.0, 0.0, -3.0))
	_actor.freeze = true
	_awareness = _actor.get_component(C_NpcAwareness) as C_NpcAwareness
	_awareness.player_visible = true
	_decision = _actor.get_component(C_NpcDecision) as C_NpcDecision
	_rule = NpcStalkingRules.selected_rule(_person.rules_for()).duplicate() as DEF_NpcStalking
	_rule.opportunity_probability = 1.0
	_rule.delay_seconds = 0.0
	_rule.success_extra_seconds = 0.0
	_state = _actor.get_component(C_NpcStalking) as C_NpcStalking
	_state.rule = _rule
	NpcBrainService.bind_engine(_actor)
	var sensing: S_NpcStalkingWitness = S_NpcStalkingWitness.new()
	sensing.group = "StalkingFixture"
	_world.add_system(sensing)
	_world.add_observer(O_NpcStalkingNotice.new())
	var clock_owner: S_GameTime = S_GameTime.new()
	clock_owner.group = "StalkingClock"
	_world.add_system(clock_owner)
	var player_body: CharacterBody3D = CharacterBody3D.new()
	player_body.set_script(ENTITY_SCRIPT)
	_player = player_body as Node as Entity
	_player.component_resources = [C_PlayerInputController.new(), C_Health.new()]
	_camera = Camera3D.new()
	_camera.position = Vector3.UP * NpcPerceptionService.EYE_HEIGHT
	player_body.add_child(_camera)
	_world.add_entity(_player)
	_camera.make_current()
	await _sync_physics()


func after_each() -> void:
	if _region.is_valid():
		NavigationServer3D.free_rid(_region)
	if _map.is_valid():
		NavigationServer3D.free_rid(_map)
	_region = RID()
	_map = RID()
	for entity: Entity in _world.entities.duplicate():
		_world.remove_entity(entity)
	_world.purge(false)
	ECS.world = null
	_root.free()
	# The terminal's detached designer row belongs to the deferred deletion queue.
	await get_tree().process_frame


func _sync_physics() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame


func _flat_map() -> void:
	var mesh: NavigationMesh = NavigationMesh.new()
	mesh.vertices = PackedVector3Array(
		[Vector3(-20, 0, -20), Vector3(-20, 0, 20), Vector3(20, 0, 20), Vector3(20, 0, -20)]
	)
	mesh.add_polygon(PackedInt32Array([0, 1, 2, 3]))
	_map = NavigationServer3D.map_create()
	_region = NavigationServer3D.region_create()
	NavigationServer3D.map_set_active(_map, true)
	NavigationServer3D.region_set_map(_region, _map)
	NavigationServer3D.region_set_navigation_mesh(_region, mesh)
	_actor.navigation_agent.set_navigation_map(_map)
	for frame: int in range(120):
		await get_tree().physics_frame
		if NavigationServer3D.map_get_iteration_id(_map) > 0 \
				and NavigationServer3D.map_get_closest_point_owner(_map, Vector3.ZERO) == _region:
			break
	assert_gt(NavigationServer3D.map_get_iteration_id(_map), 0)
	assert_eq(NavigationServer3D.map_get_closest_point_owner(_map, Vector3.ZERO), _region)


func _sample(delta: float) -> void:
	_world.process(delta, "StalkingClock")
	_world.process(delta, "StalkingFixture")
	_world.flush_command_buffers()


func _step() -> void:
	_sample(0.0)
	_decision.intent_owner = C_NpcDecision.Owner.NONE
	NpcBrainService.update_tree(_actor, 0.1)


func _use_stalking_tree() -> void:
	var runner: BTPlayer = _actor.get_node("Brain") as BTPlayer
	runner.behavior_tree = STALKING_TREE


func _intent() -> C_NpcIntent:
	return _actor.get_component(C_NpcIntent) as C_NpcIntent
#endregion


#region Captured hidden episodes
func _begin_hidden(distance: float = 1.8) -> void:
	_camera.rotation.y = 0.0
	_actor.place_at(Vector3(0.0, 0.0, distance))
	_sample(0.0)
	assert_true(NpcStalkingService.begin(_actor, _player))
	assert_same(NpcStalkingQueries.target_for(_actor), _player)


func test_close_visibility_commits_one_neutral_episode_without_half_second_exposure() -> void:
	_begin_hidden()
	_camera.rotation.y = PI
	_sample(0.000001)
	assert_true(_state.observed)
	assert_eq(_person.memories.size(), 1)
	assert_true(NpcStalkingRules.noticed(_person, &"player"))
	assert_eq(_person.memories[0].reaction, NpcMemory.Reaction.TALK)
	assert_eq(
		_person.memories[0].incident_id,
		NpcStalkingRules.episode_incident(_person, &"player", 1),
	)
	assert_eq(_person.stalking_notice_tick, GameTimeQueries.current().elapsed_ticks)
	assert_eq(_person.stalking_next_eligible_tick, _person.stalking_notice_tick + 30_000_000)
	assert_eq(_state.episode_sequence, 0)
	assert_null(NpcStalkingQueries.binding(_actor))
	_sample(10.0)
	NpcStalkingService.notice(_actor, _player)
	assert_eq(_person.memories.size(), 1)
	assert_true(SaveDataCodec.component_data(_state).is_empty())


func test_strict_native_distance_counts_249_but_not_250_or_distant_detection() -> void:
	for distance: float in [2.49, 2.5, 3.0]:
		GameTimeQueries.current().elapsed_ticks = _person.stalking_next_eligible_tick
		var previous: int = _person.memories.size()
		_begin_hidden(distance)
		_camera.rotation.y = PI
		_sample(0.001)
		assert_eq(_person.memories.size(), previous + (1 if distance < 2.5 else 0))
		assert_eq(_state.episode_sequence, 0)
		assert_null(NpcStalkingQueries.binding(_actor))


func test_ambient_observation_is_not_a_hidden_episode_or_a_success() -> void:
	_sample(10.0)
	assert_true(_state.observed)
	assert_true(_person.memories.is_empty())
	assert_eq(_person.stalking_sequence, 0)
	assert_false(NpcStalkingService.begin(_actor, _player))
	assert_eq(_person.stalking_sequence, 0)


func test_historical_notice_survives_and_two_later_successes_have_distinct_ids() -> void:
	NpcSocialService.remember(
		_person,
		_player,
		_actor,
		NpcMemory.Kind.STALKING_NOTICED,
		NpcStalkingRules.incident(_person, &"player"),
		NpcMemory.Reaction.TALK,
	)
	for sequence: int in [1, 2]:
		GameTimeQueries.current().elapsed_ticks = _person.stalking_next_eligible_tick
		_begin_hidden()
		_camera.rotation.y = PI
		_sample(0.001)
		assert_eq(_person.stalking_sequence, sequence)
	assert_eq(_person.memories.size(), 3)
	assert_ne(_person.memories[0].incident_id, _person.memories[1].incident_id)
	assert_ne(_person.memories[1].incident_id, _person.memories[2].incident_id)
	var restored: NpcRecord = SaveDataCodec.decode(SaveDataCodec.encode(_person)) as NpcRecord
	assert_eq(restored.stalking_next_eligible_tick, _person.stalking_next_eligible_tick)
	assert_false(
		NpcStalkingRules.opportunity_due(restored, GameTimeQueries.current().elapsed_ticks)
	)
	assert_true(NpcStalkingRules.noticed(restored, &"player"))
	assert_false(NpcStalkingRules.noticed(restored, &"other"))


func test_real_wall_blocks_close_success_until_actual_clear_camera_view() -> void:
	_begin_hidden()
	_camera.rotation.y = PI
	var wall: StaticBody3D = StaticBody3D.new()
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(4.0, 4.0, 0.3)
	collision.shape = shape
	wall.add_child(collision)
	_root.add_child(wall)
	wall.position = Vector3(0.0, 1.0, 0.9)
	await _sync_physics()
	_sample(0.001)
	assert_false(_state.observed)
	assert_eq(_state.episode_sequence, 1)
	assert_true(_person.memories.is_empty())
	wall.free()
	await _sync_physics()
	_sample(0.001)
	assert_eq(_person.memories.size(), 1)


func test_foreign_camera_interrupts_the_episode_without_a_false_success() -> void:
	_begin_hidden()
	var foreign_camera: Camera3D = Camera3D.new()
	_root.add_child(foreign_camera)
	foreign_camera.make_current()
	_sample(0.001)
	assert_false(_state.observed)
	assert_eq(_state.episode_sequence, 0)
	assert_null(NpcStalkingQueries.binding(_actor))
	assert_true(_person.memories.is_empty())
	foreign_camera.free()
	_camera.make_current()


func test_queued_notice_rejects_brain_generation_and_component_replacement() -> void:
	_begin_hidden()
	_camera.rotation.y = PI
	_state.observed = true
	var request: NpcStalkingNoticeRequest = NpcStalkingNoticeRequest.new(_actor, _player, _state)
	_decision.reset_transient_state()
	_world.emit_event(NpcStalkingNoticeRequest.EVENT, _actor, request)
	_world.flush_command_buffers()
	assert_true(_person.memories.is_empty())
	request = NpcStalkingNoticeRequest.new(_actor, _player, _state)
	_actor.remove_component(C_NpcStalking)
	var replacement: C_NpcStalking = C_NpcStalking.new()
	replacement.rule = _rule
	replacement.observed = true
	_actor.add_component(replacement)
	_world.emit_event(NpcStalkingNoticeRequest.EVENT, _actor, request)
	_world.flush_command_buffers()
	assert_true(_person.memories.is_empty())
	NpcStalkingService.cancel(_actor)
	assert_null(NpcStalkingQueries.binding(_actor))


func test_dead_player_and_higher_priority_combat_interrupt_without_cancelling_combat() -> void:
	_begin_hidden()
	_player.add_component(C_Death.new())
	_sample(0.001)
	assert_eq(_state.episode_sequence, 0)
	assert_true(_person.memories.is_empty())
	_player.remove_component(C_Death)
	GameTimeQueries.current().elapsed_ticks = _person.stalking_next_eligible_tick
	_begin_hidden()
	assert_true(CombatService.bind_target(_actor, _player))
	_camera.rotation.y = PI
	_sample(0.001)
	assert_same(CombatQueries.target_for(_actor), _player)
	assert_eq(_state.episode_sequence, 0)
	assert_true(_person.memories.is_empty())
#endregion


#region Native motion and finite opportunities
func test_hidden_native_route_is_fixed_and_never_writes_physical_transform() -> void:
	await _flat_map()
	_use_stalking_tree()
	_actor.place_at(Vector3(0.0, 0.0, 5.0))
	var original: Vector3 = _actor.global_position
	_step()
	assert_true(_intent().movement_active)
	assert_eq(_decision.intent_owner, C_NpcDecision.Owner.IDLE)
	assert_gt(_intent().move_position.z, 0.0)
	assert_true(
		NpcStalkingSolver.hidden_path(
			_actor,
			_player,
			PackedVector3Array([original, _intent().move_position]),
			_rule,
		)
	)
	var generation: int = _intent().movement_generation
	var destination: Vector3 = _intent().move_position
	for tick: int in 4:
		_step()
	assert_eq(_intent().movement_generation, generation)
	assert_eq(_intent().move_position, destination)
	assert_eq(_person.stalking_sequence, 1)
	assert_eq(_actor.global_position, original)
	_camera.rotation.y = PI
	_sample(0.001)
	assert_false(_intent().movement_active)
	assert_eq(_state.episode_sequence, 0)
	assert_true(_person.memories.is_empty(), "Five metres is detection, not a close success")


func test_segment_interiors_and_unreachable_routes_end_without_permanent_hold() -> void:
	_actor.place_at(Vector3(-4.0, 0.0, -3.0))
	_camera.fov = 20.0
	var crossing: PackedVector3Array = PackedVector3Array(
		[Vector3(-4.0, 0.0, -3.0), Vector3(4.0, 0.0, -3.0)]
	)
	assert_false(NpcStalkingSolver.observed(_actor, _player, crossing[0], _rule))
	assert_false(NpcStalkingSolver.observed(_actor, _player, crossing[1], _rule))
	assert_false(NpcStalkingSolver.hidden_path(_actor, _player, crossing, _rule))
	_use_stalking_tree()
	_actor.place_at(Vector3(0.0, 0.0, 5.0))
	_actor.navigation_agent.set_navigation_map(RID())
	_step()
	assert_false(_intent().movement_active)
	assert_eq(_state.episode_sequence, 0)
	assert_null(NpcStalkingQueries.binding(_actor))
	assert_eq(_person.stalking_sequence, 1)
	assert_gt(_person.stalking_next_eligible_tick, GameTimeQueries.current().elapsed_ticks)


func test_skipped_opportunity_is_committed_once_and_expiry_does_not_start_an_episode() -> void:
	_use_stalking_tree()
	_rule.opportunity_probability = 0.0
	_actor.place_at(Vector3(0.0, 0.0, 5.0))
	for tick: int in 5:
		_step()
	assert_eq(_person.stalking_sequence, 1)
	assert_eq(_state.episode_sequence, 0)
	assert_null(NpcStalkingQueries.binding(_actor))
	_sample(_rule.retry_seconds)
	assert_eq(_person.stalking_sequence, 1)
	assert_true(NpcStalkingRules.opportunity_due(_person, GameTimeQueries.current().elapsed_ticks))
	_step()
	assert_eq(_person.stalking_sequence, 1)
	_camera.rotation.y = PI
	_sample(0.0)
	_camera.rotation.y = 0.0
	_sample(0.0)
	_step()
	assert_eq(_person.stalking_sequence, 2)
	assert_eq(_state.episode_sequence, 0)


func test_selected_delay_uses_active_clock_without_restarting_between_native_ticks() -> void:
	await _flat_map()
	_use_stalking_tree()
	_rule.delay_seconds = 2.0
	_actor.place_at(Vector3(0.0, 0.0, 5.0))
	_step()
	var ready: int = _state.ready_tick
	assert_gt(ready, GameTimeQueries.current().elapsed_ticks)
	assert_false(_intent().movement_active)
	for tick: int in 5:
		_step()
	assert_eq(_state.ready_tick, ready)
	assert_eq(_person.stalking_sequence, 1)
	GameTimeQueries.current().elapsed_ticks = ready - 1
	_step()
	assert_false(_intent().movement_active)
	GameTimeQueries.current().elapsed_ticks = ready
	_step()
	assert_true(_intent().movement_active)
	var generation: int = _intent().movement_generation
	_step()
	assert_eq(_intent().movement_generation, generation)


func test_interruption_during_selected_delay_releases_only_its_episode() -> void:
	_use_stalking_tree()
	_rule.delay_seconds = 2.0
	_actor.place_at(Vector3(0.0, 0.0, 5.0))
	_step()
	assert_gt(_state.ready_tick, GameTimeQueries.current().elapsed_ticks)
	var deadline: int = _person.stalking_next_eligible_tick
	_person.phase_complete = false
	_step()
	assert_eq(_state.episode_sequence, 0)
	assert_null(NpcStalkingQueries.binding(_actor))
	assert_eq(_person.stalking_next_eligible_tick, deadline)


func test_player_displacement_has_a_finite_replan_budget_and_absolute_episode_end() -> void:
	await _flat_map()
	_use_stalking_tree()
	_rule.max_replans = 1
	_actor.place_at(Vector3(0.0, 0.0, 5.0))
	_step()
	(_player as Node as Node3D).global_position.x = 1.0
	_sample(_rule.replan_seconds)
	_step()
	assert_eq(_state.replans_left, 0)
	var destination: Vector3 = _state.destination
	(_player as Node as Node3D).global_position.x = 2.0
	_sample(_rule.replan_seconds)
	_step()
	assert_eq(_state.destination, destination)
	GameTimeQueries.current().elapsed_ticks = _state.deadline_tick
	_sample(0.0)
	assert_eq(_state.episode_sequence, 0)
	assert_false(_intent().movement_active)
	assert_null(NpcStalkingQueries.binding(_actor))
	assert_true(_person.memories.is_empty())


func test_stalking_speed_is_transient_under_the_existing_movement_owner() -> void:
	await _flat_map()
	_use_stalking_tree()
	_actor.place_at(Vector3(0.0, 0.0, 5.0))
	_step()
	var motion: C_Motion = _actor.get_component(C_Motion) as C_Motion
	var speed: float = motion.max_speed
	var execution: S_NpcIntent = S_NpcIntent.new()
	execution.group = "StalkingMovement"
	_world.add_system(execution)
	_world.process(0.001, "StalkingMovement")
	assert_eq(motion.control_speed_multiplier, _rule.approach_speed_multiplier)
	assert_eq(motion.max_speed, speed)
	NpcStalkingService.cancel(_actor)
	_world.process(0.001, "StalkingMovement")
	assert_eq(motion.control_speed_multiplier, 1.0)
	assert_eq(motion.max_speed, speed)
#endregion


#region Priority, clock and participation boundaries
func test_perception_conversation_and_schedule_keep_their_native_authority() -> void:
	await _flat_map()
	_actor.place_at(Vector3(0.0, 0.0, 5.0))
	_step()
	assert_true(_intent().movement_active)
	var previous_task: int = _state.approach_task_id
	_awareness.player_visible = false
	_step()
	assert_ne(_decision.active_task_id, previous_task)
	assert_eq(_state.episode_sequence, 0)
	assert_null(NpcStalkingQueries.binding(_actor))
	_awareness.player_visible = true
	assert_true(NpcDialogueService.begin(_player, _actor, true))
	_step()
	assert_false(_intent().movement_active)
	assert_eq(_decision.intent_owner, C_NpcDecision.Owner.SERVICE)
	NpcDialogueService.end(_actor)
	_person.phase_complete = false
	assert_false(NpcStalkingQueries.eligible(_actor, _person, _player))
	_awareness.fleeing = true
	_person.phase_complete = true
	assert_false(NpcStalkingQueries.participants_available(_actor, _person, _player))


func test_brain_reset_and_participation_release_target_but_keep_committed_deadline() -> void:
	_begin_hidden()
	var deadline: int = _person.stalking_next_eligible_tick
	DistrictPopulationService.reset_brain(_actor)
	assert_false(_state.observed)
	assert_eq(_state.episode_sequence, 0)
	assert_eq(_state.approach_task_id, 0)
	assert_null(NpcStalkingQueries.binding(_actor))
	assert_eq(_person.stalking_sequence, 1)
	assert_eq(_person.stalking_next_eligible_tick, deadline)
	assert_false(NpcStalkingRules.opportunity_due(_person, GameTimeQueries.current().elapsed_ticks))
	assert_true(DistrictPopulationService.set_placement(_person, _actor, NpcRecord.Placement.HOME))
	assert_true(
		DistrictPopulationService.set_placement(_person, _actor, NpcRecord.Placement.STREET)
	)
	assert_eq(_person.stalking_next_eligible_tick, deadline)
	assert_null(NpcStalkingQueries.binding(_actor))


func test_pause_cancels_attempt_without_consuming_or_resetting_its_saved_interval() -> void:
	_begin_hidden()
	var deadline: int = _person.stalking_next_eligible_tick
	GameTimeQueries.current().paused = true
	_camera.rotation.y = PI
	_sample(10.0)
	assert_eq(GameTimeQueries.current().elapsed_ticks, 0)
	assert_eq(_state.episode_sequence, 0)
	assert_eq(_person.stalking_next_eligible_tick, deadline)
	assert_true(_person.memories.is_empty())
	GameTimeQueries.current().paused = false
	_sample(0.001)
	assert_true(_person.memories.is_empty())
	assert_eq(_person.stalking_sequence, 1)


func test_actual_terminal_reader_extends_only_that_players_approach_range() -> void:
	_player.add_component(C_GrabControl.new())
	_actor.place_at(Vector3(0.0, 0.0, _rule.approach_range + 1.0))
	assert_false(NpcStalkingQueries.eligible(_actor, _person, _player))
	var terminal: E_Terminal = (
		load("res://content/domains/packages/entities/terminal.tscn") as PackedScene
	).instantiate() as E_Terminal
	_world.add_entity(terminal)
	terminal.open_for(_player)
	assert_true(terminal.is_open_for(_player))
	_sample(0.0)
	assert_true(NpcStalkingQueries.eligible(_actor, _person, _player))
	terminal.close_panel()
	assert_false(NpcStalkingQueries.eligible(_actor, _person, _player))


func test_real_service_role_preempts_free_stalking_without_cancelling_the_visit() -> void:
	_begin_hidden()
	NpcCustomerComposition.install(_world)
	var flow: C_CustomerFlow = C_CustomerFlow.new()
	_world.query.with_all([C_District]).execute_one().add_component(flow)
	var visit: CustomerVisit = CustomerVisit.new()
	visit.visit_id = &"stalking/service"
	visit.customer_id = _person.npc_id
	visit.package_id = "stalking/package"
	visit.definition = load(
		"res://content/domains/customers/definitions/def_customer_schedule_default.tres"
	) \
			.events[0] \
			.customer
	visit.requires_registered_package = false
	flow.visits.append(visit)
	NpcServiceRole.begin(_actor, _person, visit, 1)
	_sample(0.001)
	assert_true(_actor.has_active_role())
	assert_eq(_state.episode_sequence, 0)
	assert_null(NpcStalkingQueries.binding(_actor))
	assert_false(visit.finished)


func test_replaced_player_with_same_id_cannot_inherit_an_active_target() -> void:
	_begin_hidden()
	var stable_id: String = _player.id
	var old_player: Entity = _player
	_world.remove_entity(old_player)
	old_player.free()
	var replacement: CharacterBody3D = CharacterBody3D.new()
	replacement.set_script(ENTITY_SCRIPT)
	_player = replacement as Node as Entity
	_player.id = stable_id
	_player.component_resources = [C_PlayerInputController.new(), C_Health.new()]
	_camera = Camera3D.new()
	_camera.position = Vector3.UP * NpcPerceptionService.EYE_HEIGHT
	replacement.add_child(_camera)
	_world.add_entity(_player)
	_camera.make_current()
	await _sync_physics()
	_sample(0.001)
	assert_eq(_player.id, stable_id)
	assert_eq(_state.episode_sequence, 0)
	assert_null(NpcStalkingQueries.binding(_actor))
	assert_false(NpcStalkingQueries.eligible(_actor, _person, _player))
	assert_true(_person.memories.is_empty())


func test_cooldown_expiry_requires_a_new_opportunity_before_another_decision() -> void:
	_use_stalking_tree()
	_begin_hidden()
	_camera.rotation.y = PI
	_sample(0.001)
	_camera.rotation.y = 0.0
	_sample(0.0)
	GameTimeQueries.current().elapsed_ticks = _person.stalking_next_eligible_tick
	_step()
	assert_eq(_person.stalking_sequence, 1, "Expiry alone must not create another social desire")
	_camera.rotation.y = PI
	_sample(0.0)
	_camera.rotation.y = 0.0
	_sample(0.0)
	_step()
	assert_eq(_person.stalking_sequence, 2, "A new unseen opportunity permits one decision")
	assert_eq(_person.memories.size(), 1)


func test_unconsumed_social_opportunity_expires_without_a_new_decision() -> void:
	_use_stalking_tree()
	_actor.place_at(Vector3(0.0, 0.0, 5.0))
	_sample(0.0)
	assert_true(_state.opportunity_available)
	GameTimeQueries.current().elapsed_ticks = _state.opportunity_expires_tick
	_step()
	assert_false(_state.opportunity_available)
	assert_eq(_person.stalking_sequence, 0)
	_step()
	assert_eq(_person.stalking_sequence, 0)


func test_reset_after_cooldown_cannot_manufacture_a_new_sensed_opportunity() -> void:
	_begin_hidden()
	DistrictPopulationService.reset_brain(_actor)
	GameTimeQueries.current().elapsed_ticks = _person.stalking_next_eligible_tick
	_awareness.player_visible = true
	NpcBrainService.bind_engine(_actor)
	_use_stalking_tree()
	_step()
	assert_eq(_person.stalking_sequence, 1)
	assert_false(_state.opportunity_available)
	_camera.rotation.y = PI
	_sample(0.0)
	_camera.rotation.y = 0.0
	_sample(0.0)
	_step()
	assert_eq(_person.stalking_sequence, 2)


func test_target_publication_replacing_component_releases_only_the_abandoned_binding() -> void:
	_actor.place_at(Vector3(0.0, 0.0, 1.8))
	_sample(0.0)
	var observer: DuringTargetChange = DuringTargetChange.new()
	observer.on_change = func() -> void:
		_actor.remove_component(C_NpcStalking)
		var replacement: C_NpcStalking = C_NpcStalking.new()
		replacement.rule = _rule
		_actor.add_component(replacement)
	_world.add_observer(observer)
	assert_false(NpcStalkingService.begin(_actor, _player))
	assert_null(NpcStalkingQueries.binding(_actor))
	assert_eq(_person.stalking_sequence, 1)
	assert_gt(_person.stalking_next_eligible_tick, GameTimeQueries.current().elapsed_ticks)
	assert_true(_person.memories.is_empty())
	_world.remove_observer(observer)


func test_target_release_preserves_a_callback_replacement_movement_owner() -> void:
	await _flat_map()
	_use_stalking_tree()
	_actor.place_at(Vector3(0.0, 0.0, 5.0))
	_step()
	var observer: DuringTargetChange = DuringTargetChange.new()
	observer.added = false
	observer.on_change = func() -> void:
		NpcIntentService.move_to(_actor, Vector3(6.0, 0.0, 0.0), 0.3)
		_decision.intent_owner = C_NpcDecision.Owner.SERVICE
		_decision.active_task_id = 12345
	_world.add_observer(observer)
	NpcStalkingService.cancel(_actor)
	assert_true(_intent().movement_active)
	assert_eq(_intent().move_position, Vector3(6.0, 0.0, 0.0))
	assert_eq(_decision.intent_owner, C_NpcDecision.Owner.SERVICE)
	assert_eq(_decision.active_task_id, 12345)
	assert_eq(_state.episode_sequence, 0)
	assert_null(NpcStalkingQueries.binding(_actor))
	_world.remove_observer(observer)


func test_native_roots_preserve_priority_and_visible_episode_flow() -> void:
	assert_true(NpcVariationRules.valid_archetype(CREEPY))
	assert_true(_rule.valid_configuration())
	assert_same(_state.rule, _rule)
	var npc: BehaviorTree = load(NpcBrainService.TREE_PATH) as BehaviorTree
	assert_eq(npc.get_root_task().get_child(10).get_custom_name(), "Задача расписания")
	assert_same((npc.get_root_task().get_child(11) as BTSubtree).subtree, STALKING_TREE)
	var customer: BehaviorTree = load(
		"res://content/domains/customers/ai/trees/bt_district_npc.tres"
	) as BehaviorTree
	assert_eq(customer.get_root_task().get_child(8).get_custom_name(), "Обслуживание / разговор")
	assert_eq(customer.get_root_task().get_child(9).get_custom_name(), "Задача расписания")
	assert_same((customer.get_root_task().get_child(10) as BTSubtree).subtree, STALKING_TREE)
	var sequence: BTTask = STALKING_TREE.get_root_task().get_child(1)
	assert_true(sequence is BTSequence)
	assert_eq(sequence.get_child_count(), 3)
	assert_true(sequence.get_child(0).get_script().resource_path.ends_with("stalking_begin.gd"))
	assert_true(sequence.get_child(1).get_script().resource_path.ends_with("stalking_wait.gd"))
	assert_true(sequence.get_child(2).get_script().resource_path.ends_with("stalking_approach.gd"))
#endregion
