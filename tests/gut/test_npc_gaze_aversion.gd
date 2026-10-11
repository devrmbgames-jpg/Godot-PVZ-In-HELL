extends GutTest
## Real camera/Jolt/navmesh, scheduled exposure and manual native BT interruption regression.

const SHY: DEF_NpcArchetype = preload(
	"res://content/domains/npc/definitions/def_npc_archetype_shy.tres"
)
const BODY: PackedScene = preload("res://content/domains/npc/entities/district_npc.tscn")
const DISTRICT: DEF_District = preload(
	"res://content/domains/npc/definitions/def_district_default.tres"
)
const GAZE_TREE: BehaviorTree = preload(
	"res://content/domains/npc/ai/trees/bt_npc_gaze_aversion.tres"
)

var _root: Node3D
var _world: World
var _actor: E_DistrictNpc
var _person: NpcRecord
var _player: Entity
var _camera: Camera3D
var _awareness: C_NpcAwareness
var _decision: C_NpcDecision
var _rule: DEF_NpcGazeAversion
var _map: RID = RID()
var _region: RID = RID()


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
	_person.npc_id = &"gaze/shy"
	_person.profile = SHY
	_person.variation = NpcVariationRules.create(
		SHY,
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
	_rule = _person.rule_for(DEF_NpcTrait.Kind.GAZE_AVERSION) as DEF_NpcGazeAversion
	NpcBrainService.bind_engine(_actor)
	var player_body: CharacterBody3D = CharacterBody3D.new()
	player_body.set_script(load("res://addons/gecs/ecs/entity.gd"))
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


func _step() -> void:
	_decision.intent_owner = C_NpcDecision.Owner.NONE
	NpcBrainService.update_tree(_actor, 0.1)


func _use_gaze_tree() -> void:
	var runner: BTPlayer = _actor.get_node("Brain") as BTPlayer
	runner.behavior_tree = GAZE_TREE


func _intent() -> C_NpcIntent:
	return _actor.get_component(C_NpcIntent) as C_NpcIntent
#endregion


#region Authored tree and scheduled gaze response
func test_native_tree_exposes_guard_reposition_observe_and_keeps_schedule_priority() -> void:
	assert_true(NpcVariationRules.valid_archetype(SHY))
	assert_true(_rule.valid_configuration())
	var root_task: BTTask = GAZE_TREE.get_root_task()
	assert_is(root_task, BTDynamicSequence)
	assert_eq(root_task.get_child_count(), 2)
	assert_is(root_task.get_child(0), BTCondition)
	var selection: BTTask = root_task.get_child(1)
	assert_is(selection, BTDynamicSelector)
	assert_is(selection.get_child(0), BTDynamicSequence)
	assert_is(selection.get_child(0).get_child(0), BTCondition)
	assert_is(selection.get_child(0).get_child(1), BTAction)
	assert_is(selection.get_child(1), BTAction)
	var tree: BehaviorTree = load(NpcBrainService.TREE_PATH) as BehaviorTree
	assert_eq(tree.get_root_task().get_child(6).get_custom_name(), "Разговор")
	assert_eq(tree.get_root_task().get_child(7).get_custom_name(), "Задача расписания")
	assert_eq(tree.get_root_task().get_child(8).get_custom_name(), "Свободное занятие")
	var idle: BehaviorTree = (
		load("res://content/domains/npc/ai/trees/bt_npc_idle.tres") as BehaviorTree
	)
	assert_same((idle.get_root_task().get_child(5) as BTSubtree).subtree, GAZE_TREE)


func test_prolonged_gaze_warns_then_commits_attack_once_despite_timid_personality() -> void:
	assert_eq(SHY.personality, DEF_NpcProfile.Personality.TIMID)
	_awareness.fleeing = true
	NpcAiFixture.traits(_actor, _person, _player, _rule.warning_seconds)
	assert_has(_awareness.warned_rules, DEF_NpcTrait.Kind.GAZE_AVERSION)
	assert_null(CombatQueries.target_for(_actor))
	assert_eq(_person.memories.size(), 0)
	NpcAiFixture.traits(_actor, _person, _player, _rule.reaction_seconds)
	assert_same(CombatQueries.target_for(_actor), _player)
	assert_false(_awareness.fleeing, "Gaze escalation supersedes an earlier timid retreat")
	assert_eq(_person.memories.size(), 1)
	assert_eq(_person.memories[0].reaction, NpcMemory.Reaction.ATTACK)
	assert_true(_decision.wake_requested)
	assert_true(_decision.wake_urgent)
	NpcAiFixture.traits(_actor, _person, _player, 2.0)
	assert_eq(_person.memories.size(), 1)
	var saved: NpcRecord = SaveDataCodec.decode(SaveDataCodec.encode(_person)) as NpcRecord
	assert_eq(saved.memories[0].incident_id, _person.memories[0].incident_id)
	assert_eq(saved.memories[0].reaction, NpcMemory.Reaction.ATTACK)
	_camera.rotation.y = PI
	NpcAiFixture.traits(_actor, _person, _player, 0.1)
	assert_eq(_awareness.rule_exposure[DEF_NpcTrait.Kind.GAZE_AVERSION], 0.0)
	DistrictPopulationService.reset_brain(_actor)
	_awareness.player_visible = true
	_camera.rotation.y = 0.0
	NpcAiFixture.traits(_actor, _person, _player, 10.0)
	assert_eq(_person.memories.size(), 1, "A committed incident cannot reroll or recommit")
	assert_null(CombatQueries.target_for(_actor))


func test_solid_occlusion_and_foreign_camera_do_not_accumulate_direct_gaze() -> void:
	assert_true(NpcGazeAversionSolver.gazing(_actor, _player, _rule))
	var wall: StaticBody3D = StaticBody3D.new()
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(4.0, 4.0, 0.3)
	shape.shape = box
	wall.add_child(shape)
	_root.add_child(wall)
	wall.position = Vector3(0, 1, -1.5)
	await _sync_physics()
	assert_false(NpcGazeAversionSolver.gazing(_actor, _player, _rule))
	NpcAiFixture.traits(_actor, _person, _player, 10.0)
	assert_eq(_awareness.rule_exposure[DEF_NpcTrait.Kind.GAZE_AVERSION], 0.0)
	assert_null(CombatQueries.target_for(_actor))
	wall.free()
	var foreign_camera: Camera3D = Camera3D.new()
	_root.add_child(foreign_camera)
	foreign_camera.make_current()
	assert_null(NpcGazeAversionSolver.camera_for(_player))
	assert_false(NpcGazeAversionSolver.gazing(_actor, _player, _rule))
	foreign_camera.free()
	_camera.make_current()
#endregion


#region Native movement, perception loss and higher priority work
func test_actual_cadence_sensing_and_bt_reposition_within_one_authored_interval() -> void:
	await _flat_map()
	_actor.place_at(Vector3(0.0, 0.0, -1.3))
	_actor.rotation.y = PI
	_awareness.player_visible = false
	var district: C_District = NpcPopulationQueries.current()
	NpcAiFixture.advance(district, DISTRICT.decision_interval)
	assert_true(_awareness.player_visible, "Production perception must establish the visible fact")
	assert_true(_intent().movement_active)
	assert_eq(_decision.intent_owner, C_NpcDecision.Owner.IDLE)
	assert_true(
		NpcGazeAversionSolver.safe_position(_intent().move_position, _player, _camera, _rule)
	)
	var exposure: float = _awareness.rule_exposure[DEF_NpcTrait.Kind.GAZE_AVERSION]
	assert_gt(exposure, 0.0)
	NpcAiFixture.advance(district, 0.0)
	assert_eq(_awareness.rule_exposure[DEF_NpcTrait.Kind.GAZE_AVERSION], exposure)
	assert_eq(_decision.scheduled_delta, 0.0, "Only the production cadence advances trait clocks")


func test_same_native_subtree_uses_selected_trait_independently_of_archetype_identity() -> void:
	await _flat_map()
	_use_gaze_tree()
	var other_profile: DEF_NpcArchetype = SHY.duplicate() as DEF_NpcArchetype
	other_profile.key = &"test/other_archetype"
	other_profile.display_name = "Another personality"
	_person.profile = other_profile
	_step()
	assert_true(
		_intent().movement_active,
		"The capability, not the archetype key, enables movement",
	)
	other_profile.rules = []
	_step()
	assert_false(_intent().movement_active)
	assert_eq(_actor.get_relationships(Relationship.new(R_NpcLookTarget.new())).size(), 0)
#endregion


#region Native observation movement and interruption
func test_reposition_requests_safe_navmesh_goal_and_revalidates_rotated_camera() -> void:
	await _flat_map()
	_use_gaze_tree()
	var position_before: Vector3 = _actor.global_position
	_step()
	assert_true(_intent().movement_active)
	assert_eq(_decision.intent_owner, C_NpcDecision.Owner.IDLE)
	var destination: Vector3 = _intent().move_position
	assert_true(destination.is_finite())
	assert_true(NpcGazeAversionSolver.safe_position(destination, _player, _camera, _rule))
	assert_eq(_actor.global_position, position_before, "A leaf never moves the physical transform")
	assert_same(
		_actor.get_relationships(Relationship.new(R_NpcLookTarget.new()))[0].target,
		_player,
	)
	var generation: int = _intent().movement_generation
	_step()
	assert_eq(_intent().movement_generation, generation, "Unchanged view retains the native route")
	_camera.look_at(destination + Vector3.UP * NpcPerceptionService.EYE_HEIGHT)
	_step()
	assert_ne(_intent().move_position, destination)
	assert_true(
		NpcGazeAversionSolver.safe_position(_intent().move_position, _player, _camera, _rule)
	)
	_awareness.player_visible = false
	_step()
	assert_false(_intent().movement_active)
	assert_eq(_actor.get_relationships(Relationship.new(R_NpcLookTarget.new())).size(), 0)
	assert_eq(_decision.active_task_id, 0)
	assert_eq(_actor.global_position, position_before)


func test_safe_observation_is_interrupted_by_actual_direct_camera_gaze() -> void:
	await _flat_map()
	_use_gaze_tree()
	var destination: Vector3 = NpcGazeAversionSolver.destination(_actor, _person, _player, _rule)
	assert_true(destination.is_finite())
	if not destination.is_finite():
		return
	_actor.place_at(destination)
	_step()
	assert_false(_intent().movement_active)
	assert_same(
		_actor.get_relationships(Relationship.new(R_NpcLookTarget.new()))[0].target,
		_player,
	)
	_camera.look_at(_actor.global_position + Vector3.UP * NpcPerceptionService.EYE_HEIGHT)
	_step()
	assert_true(_intent().movement_active, "Direct gaze preempts observation in the same BT step")
	NpcBrainService.set_participating(_actor, false)
	assert_false(_intent().movement_active)
	assert_eq(_actor.get_relationships(Relationship.new(R_NpcLookTarget.new())).size(), 0)
	assert_eq(_decision.active_task_id, 0)


func test_unreachable_positions_fall_back_without_invalid_movement_or_teleport() -> void:
	_use_gaze_tree()
	_actor.navigation_agent.set_navigation_map(RID())
	var original: Vector3 = _actor.global_position
	_step()
	assert_false(_intent().movement_active)
	assert_eq(_actor.global_position, original)
	assert_true(_intent().move_position.is_finite())
	_awareness.player_visible = false
	_step()
	assert_eq(_actor.get_relationships(Relationship.new(R_NpcLookTarget.new())).size(), 0)


func test_native_conversation_and_schedule_preempt_gaze_without_stale_move_cleanup() -> void:
	await _flat_map()
	_step()
	assert_true(_intent().movement_active)
	assert_true(NpcDialogueService.begin(_player, _actor, true))
	_step()
	assert_false(_intent().movement_active)
	assert_same(NpcDialogueService.participant(_actor), _player)
	assert_lt(_decision.intent_owner, C_NpcDecision.Owner.IDLE)
	NpcDialogueService.end(_actor)
	for place: DEF_DistrictPlace in DISTRICT.places:
		if place.kind == DEF_DistrictPlace.Kind.ACTIVITY:
			_person.goal_id = place.key
			break
	_person.phase_complete = false
	_person.planned_day = DayPhaseQueries.current().day_index
	_person.planned_phase = int(DayPhaseQueries.current().phase)
	_step()
	assert_eq(_decision.intent_owner, C_NpcDecision.Owner.SCHEDULE)
	assert_true(_intent().movement_active)
	assert_eq(_intent().move_position, NpcPopulationQueries.position_for(_person.goal_id))
	assert_ne(
		_decision.active_task_id,
		0,
		"Interrupted gaze leaf cannot stop the new schedule leaf",
	)


func test_invisible_and_dead_player_have_no_position_or_escalation_effect() -> void:
	_use_gaze_tree()
	_awareness.player_visible = false
	assert_null(NpcGazeAversionSolver.visible_player(_actor))
	_step()
	assert_false(_intent().movement_active)
	assert_eq(_actor.get_relationships(Relationship.new(R_NpcLookTarget.new())).size(), 0)
	_awareness.player_visible = true
	_player.add_component(C_Death.new())
	assert_null(NpcGazeAversionSolver.visible_player(_actor))
	NpcAiFixture.traits(_actor, _person, _player, 10.0)
	assert_eq(_awareness.rule_exposure[DEF_NpcTrait.Kind.GAZE_AVERSION], 0.0)
	assert_eq(_person.memories.size(), 0)
	assert_null(CombatQueries.target_for(_actor))
#endregion


#region Invalid authored configuration
func test_gaze_configuration_rejects_nonfinite_and_inconsistent_tuning() -> void:
	var invalid: DEF_NpcGazeAversion = _rule.duplicate() as DEF_NpcGazeAversion
	invalid.watch_distance = NAN
	assert_false(invalid.valid_configuration())
	invalid.watch_distance = 6.0
	invalid.distance_tolerance = 6.0
	assert_false(invalid.valid_configuration())
	invalid.distance_tolerance = 1.0
	invalid.watch_angle_degrees = INF
	assert_false(invalid.valid_configuration())
	invalid.watch_angle_degrees = 60.0
	invalid.visibility_mask = 0
	assert_false(invalid.valid_configuration())
	invalid.visibility_mask = 31
	invalid.warning_seconds = NAN
	assert_false(invalid.valid_configuration())
#endregion
