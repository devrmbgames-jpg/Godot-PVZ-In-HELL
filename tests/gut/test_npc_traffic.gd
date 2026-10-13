extends "res://tests/gut/test_npc_avoidance.gd"
## Native district capsules, unchanged trip tokens, pair memory and observed-angel passage.

const DISTRICT_BODY: PackedScene = preload("res://content/domains/npc/entities/district_npc.tscn")
const DISTRICT_DEFINITION: DEF_District = preload(
	"res://content/domains/npc/definitions/def_district_default.tres"
)
const FRIENDLY: DEF_NpcArchetype = preload(
	"res://content/domains/npc/definitions/def_npc_archetype_creepy.tres"
)
const AGGRESSIVE: DEF_NpcArchetype = preload(
	"res://content/domains/npc/definitions/def_npc_archetype_brute.tres"
)
const ANGEL_PROFILE: DEF_NpcArchetype = preload(
	"res://content/domains/npc/definitions/def_npc_archetype_weeping_angel.tres"
)
const POLICY: DEF_NpcTraffic = preload("res://content/domains/npc/definitions/def_npc_traffic.tres")

var _district: C_District


#region Native district participants
func before_each() -> void:
	await super.before_each()
	var marker: Node3D = Node3D.new()
	marker.name = "District"
	_world.add_child(marker)
	var session: Entity = Entity.new()
	var district: C_District = C_District.new()
	district.definition = DISTRICT_DEFINITION
	session.component_resources = [district, C_DayCycle.new()]
	_world.add_entity(session)
	_district = session.get_component(C_District) as C_District


func _resident(id: StringName, profile: DEF_NpcArchetype, at: Vector3) -> E_DistrictNpc:
	var person: NpcRecord = NpcRecord.new()
	person.npc_id = id
	person.profile = profile
	person.variation = NpcVariationRules.create(
		profile,
		GameTimeQueries.current().world_seed,
		id,
		1,
	)
	person.placement = NpcRecord.Placement.STREET
	_district.people.append(person)
	var body: E_DistrictNpc = DISTRICT_BODY.instantiate() as E_DistrictNpc
	body.position = at
	var context: EntitySpawnContext = EntityCompositionService.context_for(body, _world, String(id))
	NpcConstructionService.configure_context(context, person, DISTRICT_DEFINITION)
	assert_true(EntityCompositionService.try_register(context))
	return body


func _separation(left: E_NpcCharacter, right: E_NpcCharacter) -> float:
	var offset: Vector3 = left.global_position - right.global_position
	offset.y = 0.0
	return offset.length()


func _wait_frames(count: int) -> void:
	for frame: int in count:
		await get_tree().physics_frame
#endregion


#region Personal spacing and unchanged trip ownership
func test_idle_friendly_steps_back_from_aggressive_without_changing_trip_generation() -> void:
	var friendly: E_DistrictNpc = _resident(&"friendly", FRIENDLY, Vector3(0.9, 0.02, 0.0))
	var aggressive: E_DistrictNpc = _resident(&"aggressive", AGGRESSIVE, Vector3(0.0, 0.02, 0.0))
	var intent: C_NpcIntent = friendly.get_component(C_NpcIntent) as C_NpcIntent
	var generation: int = intent.movement_generation
	await _wait_frames(120)
	assert_gt(intent.avoidance_frame, -1, "Native avoidance callback initialized")
	assert_gte(_separation(friendly, aggressive), POLICY.personal_space)
	assert_eq(intent.movement_generation, generation)
	assert_false(intent.movement_active)
	assert_eq(NpcPopulationQueries.person_for(&"friendly").memories.size(), 0)
	assert_eq(NpcPopulationQueries.person_for(&"aggressive").memories.size(), 0)


func test_friendly_passes_aggressive_and_finishes_original_goal() -> void:
	var friendly: E_DistrictNpc = _resident(&"friendly", FRIENDLY, Vector3(-4.0, 0.02, 0.0))
	var aggressive: E_DistrictNpc = _resident(&"aggressive", AGGRESSIVE, Vector3.ZERO)
	NpcIntentService.move_to(friendly, Vector3(4.0, 0.0, 0.0), 0.25)
	var intent: C_NpcIntent = friendly.get_component(C_NpcIntent) as C_NpcIntent
	var generation: int = intent.movement_generation
	var nearest: float = INF
	for frame: int in ROUTE_FRAMES:
		await get_tree().physics_frame
		nearest = minf(nearest, _separation(friendly, aggressive))
		if intent.arrived:
			break
	assert_gte(nearest, POLICY.personal_space, "Retain the full authored personal space")
	assert_lt(friendly.global_position.distance_to(Vector3(4.0, 0.0, 0.0)), 0.4)
	assert_eq(intent.movement_generation, generation)
#endregion


#region Pair conflict memory and lifetime
func test_aggressive_pair_waits_threatens_and_accumulates_only_pair_aggression() -> void:
	var left: E_DistrictNpc = _resident(&"a", AGGRESSIVE, Vector3(-0.7, 0.02, 0.0))
	var right: E_DistrictNpc = _resident(&"b", AGGRESSIVE, Vector3(0.7, 0.02, 0.0))
	NpcIntentService.move_to(left, Vector3(4.0, 0.0, 0.0), 0.25)
	NpcIntentService.move_to(right, Vector3(-4.0, 0.0, 0.0), 0.25)
	var intent: C_NpcIntent = left.get_component(C_NpcIntent) as C_NpcIntent
	var generation: int = intent.movement_generation
	await _wait_frames(270)
	var a: NpcRecord = NpcPopulationQueries.person_for(&"a")
	var b: NpcRecord = NpcPopulationQueries.person_for(&"b")
	assert_eq(a.memories.size(), 2, "One mutual incident per interval, no double clock")
	assert_eq(b.memories.size(), a.memories.size())
	assert_gt(NpcTrafficRules.attack_bonus(a, &"b", POLICY), 0.0)
	assert_eq(NpcTrafficRules.attack_bonus(a, &"someone_else", POLICY), 0.0)
	assert_true((left.get_node("Message") as Label3D).text in NpcSocialService.TRAFFIC_BARKS)
	assert_true((right.get_node("Message") as Label3D).text in NpcSocialService.TRAFFIC_BARKS)
	assert_gt(_separation(left, right), CONTACT_DISTANCE)
	assert_eq(intent.movement_generation, generation)
	assert_null(CombatQueries.target_for(left))
	assert_null(CombatQueries.target_for(right))


func test_participation_reset_releases_live_encounter_and_threat_clock() -> void:
	var left: E_DistrictNpc = _resident(&"a", AGGRESSIVE, Vector3(-0.7, 0.02, 0.0))
	var right: E_DistrictNpc = _resident(&"b", AGGRESSIVE, Vector3(0.7, 0.02, 0.0))
	NpcIntentService.move_to(left, Vector3(4.0, 0.0, 0.0), 0.25)
	await _wait_frames(30)
	var state: C_NpcTraffic = left.get_component(C_NpcTraffic) as C_NpcTraffic
	assert_gt(state.threat_elapsed, 0.0)
	NpcBrainService.set_participating(left, false)
	assert_eq(state.threat_elapsed, 0.0)
	for relation: Relationship in left.relationships:
		assert_false(relation.relation is R_NpcBlocking)
	_world.remove_entity(right)
	await get_tree().process_frame
	await _wait_frames(150)
	assert_eq(NpcPopulationQueries.person_for(&"a").memories.size(), 0)
#endregion


#region Angel is always a solid, silent passage exception
func test_observed_angel_is_bypassed_silently_by_aggressive_capsule() -> void:
	var walker: E_DistrictNpc = _resident(&"walker", AGGRESSIVE, Vector3(-4.0, 0.02, 0.0))
	var angel: E_DistrictNpc = _resident(&"angel", ANGEL_PROFILE, Vector3.ZERO)
	var gaze: C_NpcGazeFreeze = angel.get_component(C_NpcGazeFreeze) as C_NpcGazeFreeze
	gaze.observed = true
	angel.sync_gaze_constraint()
	NpcIntentService.move_to(walker, Vector3(4.0, 0.0, 0.0), 0.25)
	var initial: Vector3 = angel.global_position
	var nearest: float = INF
	for frame: int in ROUTE_FRAMES:
		await get_tree().physics_frame
		nearest = minf(nearest, _separation(walker, angel))
		if (walker.get_component(C_NpcIntent) as C_NpcIntent).arrived:
			break
	assert_gt(nearest, CONTACT_DISTANCE)
	assert_lt(walker.global_position.distance_to(Vector3(4.0, 0.0, 0.0)), 0.4)
	assert_lt(angel.global_position.distance_to(initial), WAITING_POSITION_TOLERANCE)
	assert_eq(NpcPopulationQueries.person_for(&"walker").memories.size(), 0)
	assert_eq(NpcPopulationQueries.person_for(&"angel").memories.size(), 0)


func test_moving_angel_takes_detour_around_ordinary_waiting_actor() -> void:
	var angel: E_DistrictNpc = _resident(&"angel", ANGEL_PROFILE, Vector3(-4.0, 0.02, 0.0))
	var waiting: E_DistrictNpc = _resident(&"waiting", AGGRESSIVE, Vector3.ZERO)
	NpcIntentService.move_to(angel, Vector3(4.0, 0.0, 0.0), 0.25)
	var nearest: float = INF
	for frame: int in ROUTE_FRAMES:
		await get_tree().physics_frame
		nearest = minf(nearest, _separation(angel, waiting))
		if (angel.get_component(C_NpcIntent) as C_NpcIntent).arrived:
			break
	assert_gt(nearest, CONTACT_DISTANCE)
	assert_lt(angel.global_position.distance_to(Vector3(4.0, 0.0, 0.0)), 0.4)
	assert_eq(NpcPopulationQueries.person_for(&"waiting").memories.size(), 0)
	assert_eq(NpcPopulationQueries.person_for(&"angel").memories.size(), 0)


## With both paths active, the angel supplies the lateral detour while the ordinary actor advances.
func test_moving_angel_yields_in_head_on_encounter() -> void:
	var angel: E_DistrictNpc = _resident(&"angel", ANGEL_PROFILE, Vector3(-4.0, 0.02, 0.0))
	var walker: E_DistrictNpc = _resident(&"walker", AGGRESSIVE, Vector3(4.0, 0.02, 0.0))
	NpcIntentService.move_to(angel, Vector3(4.0, 0.0, 0.0), 0.25)
	NpcIntentService.move_to(walker, Vector3(-4.0, 0.0, 0.0), 0.25)
	var nearest: float = INF
	var angel_detour: float = 0.0
	for frame: int in ROUTE_FRAMES:
		await get_tree().physics_frame
		nearest = minf(nearest, _separation(angel, walker))
		angel_detour = maxf(angel_detour, absf(angel.global_position.z))
		if (
			(angel.get_component(C_NpcIntent) as C_NpcIntent).arrived
			and (walker.get_component(C_NpcIntent) as C_NpcIntent).arrived
		):
			break
	assert_gt(nearest, CONTACT_DISTANCE)
	assert_gt(angel_detour, 0.3)
	assert_lt(angel.global_position.distance_to(Vector3(4.0, 0.0, 0.0)), 0.4)
	assert_lt(walker.global_position.distance_to(Vector3(-4.0, 0.0, 0.0)), 0.4)
	assert_eq(NpcPopulationQueries.person_for(&"walker").memories.size(), 0)
	assert_eq(NpcPopulationQueries.person_for(&"angel").memories.size(), 0)

#endregion


#region Emergency branch takes precedence over mutual threats
func test_native_hazard_escape_passes_aggressive_opponent_without_traffic_threats() -> void:
	var left: E_DistrictNpc = _resident(&"a", AGGRESSIVE, Vector3(-0.7, 0.02, 0.0))
	var right: E_DistrictNpc = _resident(&"b", AGGRESSIVE, Vector3(0.7, 0.02, 0.0))
	var packed: PackedScene = load("res://content/domains/hazards/entities/npc_fire_aura.tscn")
	var hazard: Entity = packed.instantiate() as Entity
	var definition: DEF_ToxicArea = DEF_ToxicArea.new()
	definition.radius = 4.0
	definition.floor_height = 0.2
	definition.damage_per_tick = 1.0
	definition.damage_type = DamageRequest.Type.FIRE
	var state: C_Hazard = C_Hazard.new()
	state.definition = definition
	_world.add_entity(hazard, [state])
	(hazard as Node as Node3D).global_position = Vector3(-4.0, 0.1, 0.0)
	await _wait_frames(SETTLE_FRAMES)
	var awareness: C_NpcAwareness = left.get_component(C_NpcAwareness) as C_NpcAwareness
	awareness.hazard_distress = NpcRouteSolver.danger_here(left)
	assert_true(awareness.hazard_distress)
	assert_false(awareness.fleeing)
	assert_null(CombatQueries.target_for(left))
	NpcBrainService.bind_engine(left)
	var runner: BTPlayer = left.get_node("Brain") as BTPlayer
	runner.behavior_tree = load("res://content/domains/npc/ai/trees/bt_npc_emergency.tres")
	assert_true(NpcBrainService.update_tree(left, 1.0 / 60.0))
	var decision: C_NpcDecision = left.get_component(C_NpcDecision) as C_NpcDecision
	assert_eq(decision.intent_owner, C_NpcDecision.Owner.EMERGENCY)
	var intent: C_NpcIntent = left.get_component(C_NpcIntent) as C_NpcIntent
	var escape_goal: Vector3 = intent.move_position
	var escape_generation: int = intent.movement_generation
	assert_gt(escape_goal.x, left.global_position.x, "Actual native escape meets the other capsule")
	NpcIntentService.move_to(right, Vector3(-4.0, 0.0, 0.0), 0.25)
	var nearest: float = INF
	for frame: int in ROUTE_FRAMES:
		await get_tree().physics_frame
		nearest = minf(nearest, _separation(left, right))
		if intent.arrived and (right.get_component(C_NpcIntent) as C_NpcIntent).arrived:
			break
	assert_gt(nearest, CONTACT_DISTANCE)
	assert_lt(left.global_position.distance_to(escape_goal), 0.6)
	assert_lt(right.global_position.distance_to(Vector3(-4.0, 0.0, 0.0)), 0.4)
	assert_eq(intent.movement_generation, escape_generation)
	assert_eq(NpcPopulationQueries.person_for(&"a").memories.size(), 0)
	assert_eq(NpcPopulationQueries.person_for(&"b").memories.size(), 0)
#endregion
