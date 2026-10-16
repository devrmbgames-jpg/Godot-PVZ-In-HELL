extends GutTest
## Real authored light, native routes and interruption of optional Vampire position adjustment.

const VAMPIRE: DEF_NpcArchetype = preload(
	"res://content/domains/npc/definitions/def_npc_archetype_vampire.tres"
)
const DISTRICT: DEF_District = preload(
	"res://content/domains/npc/definitions/def_district_default.tres"
)
const ENTITY_SCRIPT: GDScript = preload("res://addons/gecs/ecs/entity.gd")
const LIGHT: PackedScene = preload("res://content/scenes/npc_light_zone.tscn")
const COMFORT: BehaviorTree = preload(
	"res://content/domains/npc/ai/trees/bt_npc_light_comfort.tres"
)
const IDLE: BehaviorTree = preload("res://content/domains/npc/ai/trees/bt_npc_idle.tres")
const CUSTOMER_TREE: String = "res://content/domains/customers/ai/trees/bt_district_npc.tres"

var _root: Node3D
var _world: World
var _district: C_District
var _actor: E_DistrictNpc
var _person: NpcRecord
var _player: Entity
var _light: NpcLightZone
var _decision: C_NpcDecision
var _awareness: C_NpcAwareness
var _cover: DEF_DistrictPlace
var _map: RID
var _region: RID


#region Native composition, authored lighting and synchronized navigation
func before_each() -> void:
	_root = Node3D.new()
	add_child(_root)
	var marker: Node3D = Node3D.new()
	marker.name = "District"
	_root.add_child(marker)
	_world = World.new()
	_root.add_child(_world)
	ECS.world = _world
	NpcCustomerComposition.install(_world)
	var session: Entity = Entity.new()
	var district: C_District = C_District.new()
	district.definition = DISTRICT.duplicate() as DEF_District
	district.definition.ambient_light = 0.05
	_cover = DEF_DistrictPlace.new()
	_cover.key = &"comfort/local_cover"
	_cover.kind = DEF_DistrictPlace.Kind.COVER
	_cover.position = Vector3(4, 0, 0)
	var portal: DEF_DistrictPlace = DEF_DistrictPlace.new()
	portal.key = &"comfort/near_exit"
	portal.kind = DEF_DistrictPlace.Kind.PORTAL
	portal.position = Vector3(3, 0, 0)
	district.definition.places = [_cover, portal]
	session.component_resources = [district, C_DayCycle.new(), C_CustomerFlow.new()]
	_world.add_entity(session)
	_district = session.get_component(C_District) as C_District
	_person = NpcRecord.new()
	_person.npc_id = &"comfort/vampire"
	_person.profile = VAMPIRE
	_person.variation = NpcVariationRules.create(VAMPIRE, 1234, _person.npc_id, 1)
	_person.placement = NpcRecord.Placement.STREET
	_person.phase_complete = true
	_district.people.append(_person)
	_actor = (load(VAMPIRE.npc_scene_path) as PackedScene).instantiate() as E_DistrictNpc
	var context: EntitySpawnContext = EntityCompositionService.context_for(
		_actor,
		_world,
		String(_person.npc_id),
	)
	NpcConstructionService.configure_context(context, _person, _district.definition)
	assert_true(EntityCompositionService.try_register(context))
	_actor.set_physics_process(false)
	_actor.place_at(Vector3.ZERO)
	_decision = _actor.get_component(C_NpcDecision) as C_NpcDecision
	_awareness = _actor.get_component(C_NpcAwareness) as C_NpcAwareness
	NpcBrainService.bind_engine(_actor)
	var player_body: CharacterBody3D = CharacterBody3D.new()
	player_body.set_script(ENTITY_SCRIPT)
	_player = player_body as Node as Entity
	_player.component_resources = [C_PlayerInputController.new(), C_Health.new(), C_Living.new()]
	_world.add_entity(_player)
	player_body.global_position = Vector3.FORWARD
	_light = _zone(Vector3.ZERO)
	await _flat_map()


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


func _flat_map() -> void:
	var mesh: NavigationMesh = NavigationMesh.new()
	mesh.vertices = PackedVector3Array(
		[Vector3(-8, 0, -8), Vector3(-8, 0, 8), Vector3(8, 0, 8), Vector3(8, 0, -8)]
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
		if (
			NavigationServer3D.map_get_iteration_id(_map) > 0
			and NavigationServer3D.map_get_closest_point_owner(_map, Vector3.ZERO) == _region
		):
			break
	assert_gt(NavigationServer3D.map_get_iteration_id(_map), 0)


func _zone(position: Vector3) -> NpcLightZone:
	var zone: NpcLightZone = LIGHT.instantiate() as NpcLightZone
	zone.moving_source = true
	zone.exposure = 1.0
	_root.add_child(zone)
	zone.position = position
	return zone


func _step() -> void:
	NpcAiFixture.traits(_actor, _person, _player, 0.2)
	_decision.intent_owner = C_NpcDecision.Owner.NONE
	NpcBrainService.update_tree(_actor, 0.2)


func _intent() -> C_NpcIntent:
	return _actor.get_component(C_NpcIntent) as C_NpcIntent


func _use_comfort_tree() -> void:
	(_actor.get_node("Brain") as BTPlayer).behavior_tree = COMFORT
#endregion


#region Light preference, priorities and lifecycle
func test_bright_vampire_moves_locally_without_emergency_flight_or_offense() -> void:
	assert_true(NpcLightComfortSolver.available(_actor, _person))
	assert_eq(
		NpcLightComfortSolver.destination_for(
			_actor,
			_person,
			NpcLightComfortSolver.rule_for(_person),
		),
		_cover.key,
	)
	_step()
	assert_false(_awareness.light_distress)
	assert_false(_awareness.fleeing)
	assert_true(_person.memories.is_empty())
	assert_eq(_person.placement, NpcRecord.Placement.STREET)
	assert_true(_intent().movement_active)
	assert_eq(_intent().move_position, _cover.position)
	assert_eq(_decision.intent_owner, C_NpcDecision.Owner.IDLE)
	assert_eq(_actor.global_position, Vector3.ZERO)
	var request_generation: int = _intent().movement_generation
	_step()
	assert_eq(_intent().movement_generation, request_generation)


func test_light_switch_and_arrival_clear_the_owned_native_request() -> void:
	_use_comfort_tree()
	_step()
	assert_true(_intent().movement_active)
	_light.enabled = false
	_step()
	assert_false(_intent().movement_active)
	assert_eq(_decision.active_task_id, 0)
	_light.enabled = true
	_step()
	assert_true(_intent().movement_active)
	_actor.place_at(_cover.position)
	_step()
	assert_false(_intent().movement_active)
	assert_eq(_decision.active_task_id, 0)


func test_obligation_and_actual_conversation_preempt_comfort() -> void:
	_step()
	assert_true(_intent().movement_active)
	assert_true(NpcDialogueService.begin(_player, _actor))
	assert_false(NpcLightComfortSolver.available(_actor, _person))
	_step()
	assert_eq(_decision.intent_owner, C_NpcDecision.Owner.SERVICE)
	assert_same(NpcDialogueService.participant(_actor), _player)
	assert_false(_intent().movement_active)
	NpcDialogueService.end(_actor)
	_person.phase_complete = false
	_person.goal_id = _cover.key
	_step()
	assert_eq(_decision.intent_owner, C_NpcDecision.Owner.SCHEDULE)
	assert_false(NpcLightComfortSolver.available(_actor, _person))
	assert_false(_awareness.fleeing)


func test_active_native_service_role_keeps_its_binding() -> void:
	var visit: CustomerVisit = CustomerVisit.new()
	visit.visit_id = &"comfort/service"
	visit.customer_id = _person.npc_id
	visit.definition = DEF_Customer.new()
	(CustomerFlowQueries.current() as C_CustomerFlow).visits.append(visit)
	assert_true(NpcServiceRole.begin(_actor, _person, visit, 1))
	assert_false(NpcLightComfortSolver.available(_actor, _person))
	assert_true(_actor.has_active_role())
	assert_false(visit.finished)
	NpcServiceRole.release(_actor, visit.visit_id)


func test_lit_unreachable_and_distant_places_do_not_force_an_exit() -> void:
	_use_comfort_tree()
	var destination_light: NpcLightZone = _zone(_cover.position)
	_step()
	assert_false(_intent().movement_active)
	destination_light.enabled = false
	_cover.position = Vector3(10, 0, 0)
	_step()
	assert_false(_intent().movement_active)
	_cover.position = Vector3(15, 0, 0)
	_step()
	assert_false(_intent().movement_active)
	assert_eq(_person.placement, NpcRecord.Placement.STREET)
	assert_false(_awareness.fleeing)


func test_destination_light_change_aborts_existing_adjustment() -> void:
	_use_comfort_tree()
	_step()
	assert_true(_intent().movement_active)
	_zone(_cover.position)
	_step()
	assert_false(_intent().movement_active)
	assert_eq(_decision.active_task_id, 0)


func test_combat_and_participation_abort_preserve_their_owners() -> void:
	_use_comfort_tree()
	_step()
	assert_true(_intent().movement_active)
	assert_true(CombatService.bind_target(_actor, _player))
	_step()
	assert_false(_intent().movement_active)
	assert_same(CombatQueries.target_for(_actor), _player)
	CombatService.end_combat(_actor)
	_step()
	assert_true(_intent().movement_active)
	NpcBrainService.set_participating(_actor, false)
	assert_false(_intent().movement_active)
	assert_eq(_decision.active_task_id, 0)


func test_typed_trait_reuse_and_variation_exclude_legacy_emergency_light() -> void:
	assert_true(NpcVariationRules.valid_archetype(VAMPIRE))
	assert_not_null(NpcLightComfortSolver.rule_for(_person))
	for seed: int in range(32):
		var variation: NpcVariation = NpcVariationRules.create(VAMPIRE, seed, &"comfort/person", 1)
		assert_true(NpcVariationRules.valid_variation(VAMPIRE, variation, seed, &"comfort/person"))
		assert_false(variation.optional_trait_keys.has(&"trait_1"))
	var profile: DEF_NpcArchetype = DEF_NpcArchetype.new()
	profile.rules = [NpcLightComfortSolver.rule_for(_person)]
	_person.profile = profile
	_person.variation = NpcVariation.new()
	assert_true(NpcLightComfortSolver.available(_actor, _person))
	_step()
	assert_true(_intent().movement_active)


func test_harmful_destination_is_rejected_by_the_actual_route_risk_owner() -> void:
	var spatial: Node3D = Node3D.new()
	spatial.set_script(ENTITY_SCRIPT)
	var hazard: Entity = spatial as Node as Entity
	var definition: DEF_ToxicArea = DEF_ToxicArea.new()
	definition.radius = 1.0
	definition.damage_per_tick = 20.0
	definition.damage_type = DamageRequest.Type.GENERIC
	var state: C_Hazard = C_Hazard.new()
	state.definition = definition
	hazard.component_resources = [state, C_ToxicArea.new()]
	_world.add_entity(hazard)
	spatial.global_position = _cover.position + Vector3.UP * NpcPerceptionService.TORSO_HEIGHT
	_use_comfort_tree()
	assert_eq(
		NpcLightComfortSolver.destination_for(
			_actor,
			_person,
			NpcLightComfortSolver.rule_for(_person),
		),
		&"",
	)
	_step()
	assert_false(_intent().movement_active)
	assert_false(_awareness.fleeing)


func test_failed_destination_waits_for_native_cooldown_before_retrying() -> void:
	_use_comfort_tree()
	var destination_light: NpcLightZone = _zone(_cover.position)
	_step()
	assert_false(_intent().movement_active)
	destination_light.enabled = false
	_step()
	assert_false(_intent().movement_active)
	await get_tree().create_timer(3.1).timeout
	_step()
	assert_true(_intent().movement_active)


func test_route_owner_stopping_a_running_request_returns_failure_without_restarting() -> void:
	_use_comfort_tree()
	_step()
	assert_true(_intent().movement_active)
	NpcIntentService.stop(_actor)
	var generation: int = _intent().movement_generation
	_step()
	assert_false(_intent().movement_active)
	assert_eq(_decision.active_task_id, 0)
	assert_gt(_intent().movement_generation, generation)
	_step()
	assert_false(_intent().movement_active)


func test_both_roots_share_low_priority_comfort_with_visible_native_leaves() -> void:
	var idle_root: BTTask = IDLE.get_root_task()
	var comfort: BTSubtree = idle_root.get_child(6) as BTSubtree
	assert_same(comfort.subtree, COMFORT)
	assert_is(COMFORT.get_root_task(), BTDynamicSequence)
	assert_is(COMFORT.get_root_task().get_child(0), BTCondition)
	var cooldown: BTCooldown = COMFORT.get_root_task().get_child(1) as BTCooldown
	assert_not_null(cooldown)
	assert_eq(cooldown.duration, 3.0)
	assert_true(cooldown.trigger_on_failure)
	assert_is(cooldown.get_child(0), BTAction)
	for path: String in [NpcBrainService.TREE_PATH, CUSTOMER_TREE]:
		var root_task: BTTask = (load(path) as BehaviorTree).get_root_task()
		assert_same(
			(root_task.get_child(root_task.get_child_count() - 1) as BTSubtree).subtree,
			IDLE,
		)
		var schedule_index: int = 10 if path == NpcBrainService.TREE_PATH else 9
		assert_eq(root_task.get_child(schedule_index).get_custom_name(), "Задача расписания")
#endregion
