extends GutTest
## Real authored hag, Jolt/navmesh and native combat-distance interruption regression.

const HAG: DEF_NpcArchetype = preload(
	"res://content/domains/npc/definitions/def_npc_archetype_hag.tres"
)
const BODY: PackedScene = preload("res://content/domains/npc/entities/district_npc.tscn")
const DISTRICT: DEF_District = preload(
	"res://content/domains/npc/definitions/def_district_default.tres"
)
const CUSTOMER_TREE_PATH: String = "res://content/domains/customers/ai/trees/bt_district_npc.tres"
const RANGED_TREE: BehaviorTree = preload(
	"res://content/domains/npc/ai/trees/bt_npc_ranged_combat.tres"
)

var _root: Node3D
var _world: World
var _actor: E_DistrictNpc
var _person: NpcRecord
var _player: Entity
var _camera: Camera3D
var _awareness: C_NpcAwareness
var _decision: C_NpcDecision
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
	_person.npc_id = &"ranged/hag"
	_person.profile = HAG
	_person.variation = NpcVariationRules.create(
		HAG,
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


func _use_ranged_tree() -> void:
	var runner: BTPlayer = _actor.get_node("Brain") as BTPlayer
	runner.behavior_tree = RANGED_TREE


func _intent() -> C_NpcIntent:
	return _actor.get_component(C_NpcIntent) as C_NpcIntent
#endregion


#region Actual ranged decisions
func test_ranged_geometry_skips_invalid_definitions_and_respects_executor_bound() -> void:
	var invalid: DEF_NpcAttack = HAG.ranged_attacks[0].duplicate(true) as DEF_NpcAttack
	invalid.damage = NAN
	var preferred: DEF_NpcAttack = HAG.ranged_attacks[0].duplicate(true) as DEF_NpcAttack
	preferred.selection_priority = 10.0
	var excluded: DEF_NpcAttack = preferred.duplicate(true) as DEF_NpcAttack
	excluded.selection_priority = 100.0
	_combat().ranged_attacks = [invalid, HAG.ranged_attacks[0], preferred, excluded]
	assert_eq(NpcRangedPositionSolver.variant(_combat()), 2)
	_combat().ranged_attacks = [invalid]
	assert_eq(NpcRangedPositionSolver.variant(_combat()), -1)
	_observe_target(1.0)
	_actor.rotation.y = PI
	_step()
	assert_eq(_combat().kind, C_NpcCombat.Kind.MELEE)
	assert_eq(_combat().phase, C_NpcCombat.Phase.WINDUP)


func test_ranged_preview_rejects_lethal_hazard_route_without_changing_intent() -> void:
	await _flat_map()
	_observe_target(1.0)
	var fire: Entity = (
		load("res://content/domains/hazards/entities/npc_fire_aura.tscn") as PackedScene
	).instantiate() as Entity
	var config: DEF_ToxicArea = (
		load("res://content/domains/hazards/definitions/def_npc_fire_aura.tres") as DEF_ToxicArea
	).duplicate(true) as DEF_ToxicArea
	config.radius = 20.0
	config.damage_per_tick = 1000.0
	var hazard: C_Hazard = C_Hazard.new()
	hazard.definition = config
	_world.add_entity(fire, [hazard])
	(fire as Node as Node3D).global_position = Vector3(0.0, 1.0, -3.0)
	var generation: int = _intent().movement_generation
	assert_eq(
		NpcRangedPositionSolver.destination(
			_actor,
			_person,
			Vector3.ZERO,
			_combat().ranged_attacks[0],
		),
		Vector3.INF,
	)
	assert_eq(_intent().movement_generation, generation)
	assert_false(_intent().movement_active)
	assert_eq(_actor.global_position, Vector3(0.0, 0.0, -1.0))


func _observe_target(distance: float) -> void:
	_actor.place_at(Vector3(0.0, 0.0, -distance))
	assert_true(CombatService.bind_target(_actor, _player))
	_awareness.target_visible = true
	_awareness.last_seen_position = (_player as Node as Node3D).global_position
	_awareness.has_last_seen = true


func _combat() -> C_NpcCombat:
	return _actor.get_component(C_NpcCombat) as C_NpcCombat


func test_actual_hag_stops_residual_chase_and_starts_authored_ranged_attack() -> void:
	_observe_target(4.75)
	NpcIntentService.move_to(_actor, Vector3.ZERO, 0.1)
	_step()
	assert_eq(_combat().phase, C_NpcCombat.Phase.WINDUP)
	assert_eq(_combat().kind, C_NpcCombat.Kind.RANGED)
	assert_same(_combat().attack, HAG.ranged_attacks[0])
	assert_false(_intent().movement_active)
	assert_eq(_intent().speed_fraction, 0.0)
	assert_same(CombatQueries.target_for(_actor), _player)
	assert_eq(_person.memories.size(), 0)
	assert_eq(_decision.intent_owner, C_NpcDecision.Owner.COMBAT)


func test_close_and_far_targets_use_safe_navmesh_distance_without_moving_body() -> void:
	await _flat_map()
	for distance: float in [1.0, 10.0]:
		_observe_target(distance)
		var original: Vector3 = _actor.global_position
		_step()
		assert_true(_intent().movement_active)
		assert_true(_intent().move_position.is_finite())
		assert_almost_eq(_intent().move_position.distance_to(Vector3.ZERO), 4.75, 0.05)
		assert_eq(_actor.global_position, original, "The physics body owns its actual transform")
		assert_eq(_combat().phase, C_NpcCombat.Phase.READY)
		assert_eq(_decision.intent_owner, C_NpcDecision.Owner.COMBAT)
		DistrictPopulationService.reset_brain(_actor)
		NpcBrainService.bind_engine(_actor)


func test_cooldown_holds_firing_distance_and_then_uses_existing_executor() -> void:
	_observe_target(4.75)
	_combat().cooldown_remaining = 2.0
	_step()
	_step()
	assert_eq(_combat().phase, C_NpcCombat.Phase.READY)
	assert_eq(_combat().cooldown_remaining, 2.0, "Combat cadence owns the cooldown")
	assert_false(_intent().movement_active)
	_combat().cooldown_remaining = 0.0
	_step()
	assert_eq(_combat().phase, C_NpcCombat.Phase.WINDUP)
	assert_true(NpcAttackService.commit_effect(_actor))
	assert_false(NpcAttackService.commit_effect(_actor))
	assert_eq(_world.query.with_all([C_CombatProjectile]).execute().size(), 1)
	_step()
	assert_eq(_combat().phase, C_NpcCombat.Phase.ACTIVE)
	assert_eq(_decision.intent_owner, C_NpcDecision.Owner.COMBAT)


func test_unreachable_retreat_falls_back_to_actual_close_range_defense() -> void:
	_actor.navigation_agent.set_navigation_map(RID())
	_observe_target(1.0)
	_actor.rotation.y = PI
	_step()
	assert_eq(_combat().phase, C_NpcCombat.Phase.WINDUP)
	assert_eq(_combat().kind, C_NpcCombat.Kind.MELEE)
	assert_false(_intent().move_position == Vector3.INF)


func test_lost_target_uses_search_and_releases_old_ranged_intent() -> void:
	await _flat_map()
	_observe_target(1.0)
	_step()
	assert_true(_intent().movement_active)
	_awareness.target_visible = false
	_awareness.search_elapsed = _person.profile.search_seconds
	_step()
	assert_null(CombatQueries.target_for(_actor))
	assert_false(_intent().movement_active)
	assert_eq(_decision.active_task_id, 0)
	assert_false(_actor.has_relationship(Relationship.new(R_NpcLookTarget.new(), _player)))


func test_participation_abort_releases_native_ranged_movement_and_look() -> void:
	await _flat_map()
	_observe_target(1.0)
	_step()
	assert_true(_intent().movement_active)
	NpcBrainService.set_participating(_actor, false)
	assert_false(_intent().movement_active)
	assert_eq(_decision.active_task_id, 0)
	assert_eq(_intent().look_mode, C_NpcIntent.LookMode.MOVEMENT)
	assert_false((_actor.get_node("Brain") as BTPlayer).active)


func test_customer_and_street_roots_share_ranged_priority_below_safety() -> void:
	for tree_path: String in [
		NpcBrainService.TREE_PATH,
		"res://content/domains/customers/ai/trees/bt_district_npc.tres",
	]:
		var root_task: BTTask = (load(tree_path) as BehaviorTree).get_root_task()
		var branch_index: int = 6 if tree_path == NpcBrainService.TREE_PATH else 5
		assert_eq(root_task.get_child(branch_index - 2).get_custom_name(), "Воспринятая кровь")
		assert_same((root_task.get_child(branch_index) as BTSubtree).subtree, RANGED_TREE)
		assert_eq(root_task.get_child(branch_index + 1).get_custom_name(), "Бой / поиск")
	var runner: BTPlayer = _actor.get_node("Brain") as BTPlayer
	runner.behavior_tree = load(CUSTOMER_TREE_PATH) as BehaviorTree
	_observe_target(4.75)
	_step()
	assert_eq(_combat().kind, C_NpcCombat.Kind.RANGED)
	assert_eq(_combat().phase, C_NpcCombat.Phase.WINDUP)
#endregion
