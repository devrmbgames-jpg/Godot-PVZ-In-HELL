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
	_rule = NpcStalkingRules.selected_rule(_person.rules_for())
	_state = _actor.get_component(C_NpcStalking) as C_NpcStalking
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
	_decision.intent_owner = C_NpcDecision.Owner.NONE
	NpcBrainService.update_tree(_actor, 0.1)


func _use_stalking_tree() -> void:
	var runner: BTPlayer = _actor.get_node("Brain") as BTPlayer
	runner.behavior_tree = STALKING_TREE


func _intent() -> C_NpcIntent:
	return _actor.get_component(C_NpcIntent) as C_NpcIntent
#endregion


#region Actual visibility and durable recognition
func test_visibility_stops_then_notice_commits_once_without_cancelling_combat() -> void:
	_use_stalking_tree()
	_step()
	assert_false(_intent().movement_active)
	_sample(_rule.notice_seconds * 0.5)
	assert_true(_state.observed)
	assert_eq(_person.memories.size(), 0)
	assert_true(CombatService.bind_target(_actor, _player))
	_sample(_rule.notice_seconds * 0.5)
	assert_true(NpcStalkingRules.noticed(_person, &"player"))
	assert_eq(_person.memories.size(), 1)
	assert_same(CombatQueries.target_for(_actor), _player)
	assert_eq(_person.memories[0].reaction, NpcMemory.Reaction.TALK)
	_sample(10.0)
	NpcStalkingService.notice(_actor, _player)
	assert_eq(_person.memories.size(), 1)
	var restored: NpcRecord = SaveDataCodec.decode(SaveDataCodec.encode(_person)) as NpcRecord
	assert_true(NpcStalkingRules.noticed(restored, &"player"))
	assert_false(NpcStalkingRules.noticed(restored, &"other"))
	assert_true(SaveDataCodec.component_data(_state).is_empty())


func test_occlusion_and_camera_loss_reset_continuous_exposure() -> void:
	_sample(_rule.notice_seconds * 0.75)
	var wall: StaticBody3D = StaticBody3D.new()
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(4.0, 4.0, 0.3)
	collision.shape = shape
	wall.add_child(collision)
	_root.add_child(wall)
	wall.position = Vector3(0.0, 1.0, -1.5)
	await _sync_physics()
	_sample(2.0)
	assert_false(_state.observed)
	assert_eq(_state.exposure_seconds, 0.0)
	assert_true(_person.memories.is_empty())
	wall.free()
	await _sync_physics()
	_sample(_rule.notice_seconds * 0.75)
	assert_true(_state.observed)
	assert_true(_person.memories.is_empty())
	var foreign_camera: Camera3D = Camera3D.new()
	_root.add_child(foreign_camera)
	foreign_camera.make_current()
	_sample(2.0)
	assert_false(_state.observed)
	assert_eq(_state.exposure_seconds, 0.0)
	assert_true(_person.memories.is_empty())
	foreign_camera.free()
	_camera.make_current()


func test_queued_notice_rejects_brain_reset_and_component_replacement() -> void:
	_state.observed = true
	_state.exposure_seconds = _rule.notice_seconds
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
	replacement.exposure_seconds = _rule.notice_seconds
	_actor.add_component(replacement)
	_world.emit_event(NpcStalkingNoticeRequest.EVENT, _actor, request)
	_world.flush_command_buffers()
	assert_true(_person.memories.is_empty())


func test_dead_and_retired_player_never_commit_notice() -> void:
	_state.observed = true
	_state.exposure_seconds = _rule.notice_seconds
	var request: NpcStalkingNoticeRequest = NpcStalkingNoticeRequest.new(_actor, _player, _state)
	_player.add_component(C_Death.new())
	_world.emit_event(NpcStalkingNoticeRequest.EVENT, _actor, request)
	_world.flush_command_buffers()
	assert_true(_person.memories.is_empty())
	_player.remove_component(C_Death)
	_world.remove_entity(_player)
	_world.emit_event(NpcStalkingNoticeRequest.EVENT, _actor, request)
	_world.flush_command_buffers()
	assert_true(_person.memories.is_empty())
	_player.free()
#endregion


#region Native hidden approach and interruptions
func test_hidden_native_route_approaches_behind_without_moving_transform() -> void:
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
	assert_eq(_actor.global_position, original)
	var generation: int = _intent().movement_generation
	_step()
	assert_eq(_intent().movement_generation, generation)
	_camera.rotation.y = PI
	_sample(0.1)
	assert_true(NpcStalkingQueries.holds_approach(_actor))
	var execution: S_NpcIntent = S_NpcIntent.new()
	execution.group = "StalkingMovement"
	_world.add_system(execution)
	_world.process(0.1, "StalkingMovement")
	var controller: C_Controller = _actor.get_component(C_Controller) as C_Controller
	assert_eq(controller.direction_motion, Vector3.ZERO)
	_step()
	assert_false(_intent().movement_active)
	assert_eq(_actor.global_position, original)


func test_segment_interiors_and_unreachable_routes_are_rejected() -> void:
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
	var original: Vector3 = _actor.global_position
	_step()
	assert_false(_intent().movement_active)
	assert_true(_intent().move_position.is_finite())
	assert_eq(_actor.global_position, original)


func test_perception_loss_conversation_and_schedule_interrupt_hidden_approach() -> void:
	await _flat_map()
	_actor.place_at(Vector3(0.0, 0.0, 5.0))
	_step()
	assert_true(_intent().movement_active)
	var previous_task: int = _state.approach_task_id
	_awareness.player_visible = false
	assert_false(NpcStalkingQueries.eligible(_actor, _person, null))
	_step()
	assert_ne(_decision.active_task_id, previous_task)
	assert_eq(_state.approach_task_id, 0)
	_awareness.player_visible = true
	assert_true(NpcDialogueService.begin(_player, _actor, true))
	_step()
	assert_false(_intent().movement_active)
	assert_eq(_decision.intent_owner, C_NpcDecision.Owner.SERVICE)
	assert_eq(_state.approach_task_id, 0)
	NpcDialogueService.end(_actor)
	_person.phase_complete = false
	assert_false(NpcStalkingQueries.eligible(_actor, _person, _player))
	_awareness.fleeing = true
	_person.phase_complete = true
	assert_false(NpcStalkingQueries.eligible(_actor, _person, _player))
	_awareness.fleeing = false
	assert_true(CombatService.bind_target(_actor, _player))
	assert_false(NpcStalkingQueries.eligible(_actor, _person, _player))


func test_detection_falls_back_to_normal_behavior_and_survives_brain_reset() -> void:
	_actor.place_at(Vector3(0.0, 0.0, 5.0))
	_state.observed = true
	_state.exposure_seconds = _rule.notice_seconds
	NpcStalkingService.notice(_actor, _player)
	assert_true(_person.memories.is_empty(), "Stale sampled exposure cannot fabricate recognition")
	_camera.rotation.y = PI
	NpcStalkingService.notice(_actor, _player)
	assert_false(NpcStalkingQueries.eligible(_actor, _person, _player))
	_state.observed = true
	_state.exposure_seconds = 0.3
	DistrictPopulationService.reset_brain(_actor)
	assert_false(_state.observed)
	assert_eq(_state.exposure_seconds, 0.0)
	assert_eq(_state.approach_task_id, 0)
	assert_true(NpcStalkingRules.noticed(_person, &"player"))
	_person.profile = CREEPY.duplicate() as DEF_NpcArchetype
	_person.profile.key = &"test/another"
	assert_true(NpcStalkingRules.noticed(_person, &"player"))


func test_authored_native_roots_preserve_higher_priority_branches() -> void:
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
#endregion


#region Clock and terminal distractions
func test_pause_and_zero_elapsed_time_do_not_accumulate_recognition() -> void:
	_sample(0.0)
	assert_eq(_state.exposure_seconds, 0.0)
	GameTimeQueries.current().paused = true
	_sample(10.0)
	assert_eq(_state.exposure_seconds, 0.0)
	assert_true(_person.memories.is_empty())
	GameTimeQueries.current().paused = false
	_sample(_rule.notice_seconds)
	assert_true(NpcStalkingRules.noticed(_person, &"player"))


func test_actual_terminal_reader_extends_only_that_players_approach_range() -> void:
	_player.add_component(C_GrabControl.new())
	_actor.place_at(Vector3(0.0, 0.0, _rule.approach_range + 1.0))
	assert_false(NpcStalkingQueries.eligible(_actor, _person, _player))
	var terminal: E_Terminal = (
		(load("res://content/domains/packages/entities/terminal.tscn") as PackedScene).instantiate()
		as E_Terminal
	)
	_world.add_entity(terminal)
	terminal.open_for(_player)
	assert_true(terminal.is_open_for(_player))
	assert_true(NpcStalkingQueries.eligible(_actor, _person, _player))
	terminal.close_panel()
	assert_false(NpcStalkingQueries.eligible(_actor, _person, _player))


func test_real_service_role_preempts_stalking_without_cancelling_visit() -> void:
	_actor.place_at(Vector3(0.0, 0.0, 5.0))
	NpcCustomerComposition.install(_world)
	var flow: C_CustomerFlow = C_CustomerFlow.new()
	_world.query.with_all([C_District]).execute_one().add_component(flow)
	var visit: CustomerVisit = CustomerVisit.new()
	visit.visit_id = &"stalking/service"
	visit.customer_id = _person.npc_id
	visit.package_id = "stalking/package"
	visit.definition = (
		(
			load("res://content/domains/customers/definitions/def_customer_schedule_default.tres")
			as DEF_CustomerSchedule
		)
		.events[0]
		.customer
	)
	visit.requires_registered_package = false
	flow.visits.append(visit)
	NpcServiceRole.begin(_actor, _person, visit, 1)
	assert_true(_actor.has_active_role())
	assert_false(NpcStalkingQueries.eligible(_actor, _person, _player))
	assert_false(visit.finished)
#endregion


#region Participation boundary
func test_suspension_restarts_exposure_and_preserves_durable_recognition() -> void:
	_sample(_rule.notice_seconds * 0.8)
	assert_true(_state.observed)
	assert_true(DistrictPopulationService.set_placement(_person, _actor, NpcRecord.Placement.HOME))
	_sample(2.0)
	assert_true(
		DistrictPopulationService.set_placement(_person, _actor, NpcRecord.Placement.STREET),
	)
	await _sync_physics()
	_sample(_rule.notice_seconds * 0.2)
	assert_almost_eq(_state.exposure_seconds, _rule.notice_seconds * 0.2, 0.00001)
	assert_true(_person.memories.is_empty(), "Interrupted exposure must not commit recognition")
	_sample(_rule.notice_seconds * 0.8)
	assert_true(NpcStalkingRules.noticed(_person, &"player"))
	assert_eq(_person.memories.size(), 1)
	assert_true(DistrictPopulationService.set_placement(_person, _actor, NpcRecord.Placement.HOME))
	assert_true(
		DistrictPopulationService.set_placement(_person, _actor, NpcRecord.Placement.STREET),
	)
	assert_true(NpcStalkingRules.noticed(_person, &"player"))
	assert_eq(_person.memories.size(), 1)
#endregion


#region Player incarnation boundary
## Recreating the same authored player ID cannot transfer continuous exposure to a new body.
func test_replaced_player_with_same_stable_id_starts_fresh_exposure() -> void:
	_sample(_rule.notice_seconds * 0.8)
	var stable_id: String = _player.id
	_world.remove_entity(_player)
	await get_tree().process_frame
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
	_sample(_rule.notice_seconds * 0.2)
	assert_eq(_player.id, stable_id)
	assert_almost_eq(_state.exposure_seconds, _rule.notice_seconds * 0.2, 0.00001)
	assert_true(_person.memories.is_empty())
	_sample(_rule.notice_seconds * 0.8)
	assert_true(NpcStalkingRules.noticed(_person, &"player"))
#endregion
