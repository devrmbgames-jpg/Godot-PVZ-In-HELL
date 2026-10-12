extends GutTest
## Native authored lighting, real cadence and reversible hunt/calm integration.

const PROFILE: DEF_NpcArchetype = preload(
	"res://content/domains/npc/definitions/def_npc_archetype_night_hunter.tres"
)
const BODY: PackedScene = preload("res://content/domains/npc/entities/district_npc.tscn")
const DISTRICT: DEF_District = preload(
	"res://content/domains/npc/definitions/def_district_default.tres"
)
const LIGHT: PackedScene = preload("res://content/scenes/npc_light_zone.tscn")
const HUNT: BehaviorTree = preload("res://content/domains/npc/ai/trees/bt_npc_dark_predator.tres")
const CUSTOMER_TREE_PATH: String = "res://content/domains/customers/ai/trees/bt_district_npc.tres"

var _root: Node3D
var _world: World
var _district: C_District
var _actor: E_DistrictNpc
var _person: NpcRecord
var _player: Entity
var _awareness: C_NpcAwareness
var _decision: C_NpcDecision


class HuntReceiverMutator extends Observer:
	## Removes the receiver synchronously at the social fact boundary.
	var retire: bool = false
	## Retains the body but disables participation during the native update.
	var suspend: bool = false
	## Number of committed hunt facts received by this fixture.
	var calls: int = 0


	func query() -> QueryBuilder:
		return q.with_all([C_NpcIdentity]).on_event(NpcSocialReactionCommitted.EVENT)


	func each(_event: Variant, entity: Entity, _payload: Variant = null) -> void:
		calls += 1
		if retire:
			_world.remove_entity(entity)
			entity.free()
		elif suspend:
			var identity: C_NpcIdentity = entity.get_component(C_NpcIdentity) as C_NpcIdentity
			DistrictPopulationService.set_placement(
				NpcPopulationQueries.person_for(identity.npc_id),
				entity as E_DistrictNpc,
				NpcRecord.Placement.OUTSIDE,
			)
		else:
			DistrictPopulationService.reset_brain(entity as E_DistrictNpc)
			var awareness: C_NpcAwareness = entity.get_component(C_NpcAwareness) as C_NpcAwareness
			awareness.heard_remaining = 9.0
			awareness.player_visible = true


#region Real native fixture
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
	_district = C_District.new()
	_district.definition = DISTRICT
	session.component_resources = [_district, C_DayCycle.new()]
	_world.add_entity(session)
	_person = NpcRecord.new()
	_person.npc_id = &"darkness/observer"
	_person.profile = PROFILE
	_person.variation = NpcVariationRules.create(
		PROFILE,
		GameTimeQueries.current().world_seed,
		_person.npc_id,
		1,
	)
	_person.placement = NpcRecord.Placement.STREET
	_person.phase_complete = true
	_district.people.append(_person)
	_actor = BODY.instantiate() as E_DistrictNpc
	var context: EntitySpawnContext = EntityCompositionService.context_for(
		_actor,
		_world,
		String(_person.npc_id),
	)
	NpcConstructionService.configure_context(context, _person, DISTRICT)
	assert_true(EntityCompositionService.try_register(context))
	_actor.place_at(Vector3(0, 0, -3))
	_actor.freeze = true
	_actor.rotation.y = PI
	_awareness = _actor.get_component(C_NpcAwareness) as C_NpcAwareness
	_awareness.player_visible = true
	_decision = _actor.get_component(C_NpcDecision) as C_NpcDecision
	NpcBrainService.bind_engine(_actor)
	var player_body: CharacterBody3D = CharacterBody3D.new()
	player_body.set_script(load("res://addons/gecs/ecs/entity.gd"))
	_player = player_body as Node as Entity
	_player.component_resources = [C_PlayerInputController.new(), C_Health.new()]
	_world.add_entity(_player)
	await _sync_physics()


func after_each() -> void:
	for entity: Entity in _world.entities.duplicate():
		_world.remove_entity(entity)
	_world.purge(false)
	ECS.world = null
	_root.free()


func _sync_physics() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame


func _step() -> void:
	NpcAiFixture.traits(_actor, _person, _player, 0.2)
	_decision.intent_owner = C_NpcDecision.Owner.NONE
	NpcBrainService.update_tree(_actor, 0.2)


func _zone(position: Vector3, exposure: float = 1.0) -> NpcLightZone:
	var zone: NpcLightZone = LIGHT.instantiate() as NpcLightZone
	zone.moving_source = true
	zone.exposure = exposure
	_root.add_child(zone)
	zone.position = position
	return zone


func _combat() -> C_NpcCombat:
	return _actor.get_component(C_NpcCombat) as C_NpcCombat
#endregion


#region Reversible native behavior
func test_native_hunt_completes_deferred_abort_when_receiver_becomes_dormant() -> void:
	var observer: HuntReceiverMutator = HuntReceiverMutator.new()
	observer.suspend = true
	_world.add_observer(observer)
	NpcAiFixture.advance(_district, 0.2)
	assert_eq(observer.calls, 1)
	assert_false(_actor.enabled)
	assert_false(_decision.tree_updating)
	assert_eq(_decision.intent_owner, C_NpcDecision.Owner.NONE)
	var runner: BTPlayer = _actor.get_node("Brain") as BTPlayer
	assert_false(runner.active)
	assert_eq(runner.get_bt_instance().get_root_task().get_status(), BTTask.FRESH)
	assert_null(CombatQueries.target_for(_actor))


func test_native_hunt_stops_after_synchronous_receiver_retirement() -> void:
	var observer: HuntReceiverMutator = HuntReceiverMutator.new()
	observer.retire = true
	_world.add_observer(observer)
	var reference: WeakRef = weakref(_actor)
	NpcAiFixture.advance(_district, 0.2)
	assert_eq(observer.calls, 1)
	assert_null(reference.get_ref())
	assert_eq(_person.memories.size(), 0)


func test_native_hunt_preserves_reset_state_after_synchronous_brain_reset() -> void:
	var observer: HuntReceiverMutator = HuntReceiverMutator.new()
	_world.add_observer(observer)
	var generation: int = _decision.lifecycle_generation
	NpcAiFixture.advance(_district, 0.2)
	assert_eq(observer.calls, 1)
	assert_gt(_decision.lifecycle_generation, generation)
	assert_false(_decision.tree_updating)
	assert_eq(_decision.intent_owner, C_NpcDecision.Owner.NONE)
	assert_eq(_awareness.heard_remaining, 9.0)
	assert_false(_awareness.target_visible)
	assert_null(_actor.get_node_or_null("Brain"))
	assert_null(CombatQueries.target_for(_actor))
	assert_eq(_person.memories.size(), 0)
	_world.remove_observer(observer)
	NpcBrainService.bind_engine(_actor)
	NpcAiFixture.advance(_district, 0.2)
	assert_same(CombatQueries.target_for(_actor), _player)
	assert_eq(_decision.intent_owner, C_NpcDecision.Owner.COMBAT)


func test_visible_dark_player_starts_hunt_without_durable_offense_or_restart() -> void:
	_step()
	assert_same(CombatQueries.target_for(_actor), _player)
	assert_true(_awareness.target_visible)
	assert_false(_decision.tree_updating, "An urgent hunt wake keeps the same native runtime")
	assert_eq(_person.memories.size(), 0)
	assert_false(_awareness.reacted_rules.has(DEF_NpcTrait.Kind.DARK_PREDATOR))
	var generation: int = _combat().execution_generation
	_step()
	assert_same(CombatQueries.target_for(_actor), _player)
	assert_eq(_combat().execution_generation, generation)
	assert_eq(_person.memories.size(), 0)
	assert_eq(_decision.intent_owner, C_NpcDecision.Owner.COMBAT)


func test_light_on_actor_cancels_inflight_attack_then_requests_authored_refuge() -> void:
	_step()
	_actor.place_at(Vector3(0, 0, -1))
	await _sync_physics()
	assert_true(NpcAttackService.start(_actor, C_NpcCombat.Kind.MELEE, 0))
	assert_eq(_combat().phase, C_NpcCombat.Phase.WINDUP)
	var zone: NpcLightZone = _zone(_actor.global_position + Vector3.UP)
	_step()
	assert_null(CombatQueries.target_for(_actor))
	assert_eq(_combat().phase, C_NpcCombat.Phase.READY)
	assert_false(_awareness.has_last_seen)
	assert_eq(_person.memories.size(), 0)
	_step()
	var intent: C_NpcIntent = _actor.get_component(C_NpcIntent) as C_NpcIntent
	assert_true(intent.movement_active)
	assert_eq(intent.move_position, NpcTraitService.dark_refuge(_actor, _person))
	assert_eq(_decision.intent_owner, C_NpcDecision.Owner.EMERGENCY)
	zone.enabled = false
	_step()
	assert_same(CombatQueries.target_for(_actor), _player, "Darkness can start another hunt")


func test_light_on_perceived_player_calms_without_sampling_a_hidden_position() -> void:
	_step()
	var zone: NpcLightZone = _zone(Vector3.UP)
	_awareness.player_visible = false
	_step()
	assert_same(CombatQueries.target_for(_actor), _player)
	assert_eq(_awareness.player_light_exposure, 1.0)
	assert_false(_awareness.light_distress)
	_awareness.player_visible = true
	_step()
	assert_null(CombatQueries.target_for(_actor))
	zone.enabled = false
	_step()
	assert_same(CombatQueries.target_for(_actor), _player)


func test_combat_owner_cancels_light_constrained_attack_preserving_emergency_movement() -> void:
	_step()
	_actor.place_at(Vector3(0, 0, -1))
	await _sync_physics()
	assert_true(NpcAttackService.start(_actor, C_NpcCombat.Kind.MELEE, 0))
	_zone(Vector3.UP)
	NpcAiFixture.traits(_actor, _person, _player, 0.2)
	assert_true(NpcDarknessQueries.combat_suppressed(_actor))
	var emergency_goal: Vector3 = Vector3(8, 0, 4)
	_decision.intent_owner = C_NpcDecision.Owner.EMERGENCY
	NpcIntentArbiter.move_to(_actor, emergency_goal, 0.3, C_NpcDecision.Owner.EMERGENCY)
	var owner: S_NpcCombat = S_NpcCombat.new()
	owner.group = "DarknessCombatFixture"
	_world.add_system(owner)
	_world.process(1.0, "DarknessCombatFixture")
	_world.remove_system(owner)
	assert_eq(_combat().phase, C_NpcCombat.Phase.READY)
	assert_same(CombatQueries.target_for(_actor), _player, "The BT owns target cleanup")
	var intent: C_NpcIntent = _actor.get_component(C_NpcIntent) as C_NpcIntent
	assert_true(intent.movement_active)
	assert_eq(intent.move_position, emergency_goal)
	assert_eq(intent.speed_fraction, 1.0)
	assert_eq((_player.get_component(C_Health) as C_Health).current, 100.0)


func test_late_effect_and_start_use_the_sampled_light_constraint_before_bt_calm() -> void:
	_step()
	_actor.place_at(Vector3(0, 0, -1))
	await _sync_physics()
	assert_true(NpcAttackService.start(_actor, C_NpcCombat.Kind.MELEE, 0))
	_zone(Vector3.UP)
	NpcAiFixture.traits(_actor, _person, _player, 0.2)
	assert_false(NpcAttackService.commit_effect(_actor))
	assert_eq(_combat().phase, C_NpcCombat.Phase.READY)
	assert_eq((_player.get_component(C_Health) as C_Health).current, 100.0)
	var generation: int = _combat().execution_generation
	assert_false(NpcAttackService.start(_actor, C_NpcCombat.Kind.MELEE, 0))
	assert_eq(_combat().execution_generation, generation)


func test_separate_thresholds_preserve_hunt_in_middle_exposure_without_restarting() -> void:
	_step()
	var zone: NpcLightZone = _zone(Vector3.UP, 0.3)
	_step()
	assert_same(CombatQueries.target_for(_actor), _player)
	CombatService.end_combat(_actor)
	_step()
	assert_null(CombatQueries.target_for(_actor), "Middle exposure does not start a fresh hunt")
	zone.exposure = 0.2
	_step()
	assert_same(CombatQueries.target_for(_actor), _player)
	zone.exposure = 0.5
	_step()
	assert_null(CombatQueries.target_for(_actor))


func test_switch_state_changes_hunt_and_calm_without_renderer_sampling() -> void:
	var circuit: Entity = Entity.new()
	var state: C_LightCircuit = C_LightCircuit.new()
	state.circuit_id = &"dark_predator_test"
	circuit.component_resources = [state]
	_world.add_entity(circuit)
	var zone: NpcLightZone = _zone(Vector3.UP)
	zone.circuit_id = state.circuit_id
	_step()
	assert_null(CombatQueries.target_for(_actor))
	assert_true(LightCircuitService.set_enabled(circuit, false))
	_step()
	assert_same(CombatQueries.target_for(_actor), _player)
	assert_true(LightCircuitService.set_enabled(circuit, true))
	_step()
	assert_null(CombatQueries.target_for(_actor))


func test_real_cadence_senses_player_and_starts_hunt_in_one_authored_interval() -> void:
	_awareness.player_visible = false
	NpcAiFixture.advance(_district, 0.2)
	assert_true(_awareness.player_visible)
	assert_same(CombatQueries.target_for(_actor), _player)
	assert_eq(_awareness.self_light_exposure, DISTRICT.ambient_light)
	assert_eq(_person.memories.size(), 0)
	var zone: NpcLightZone = _zone(Vector3.UP)
	NpcAiFixture.advance(_district, 0.2)
	assert_null(CombatQueries.target_for(_actor))
	zone.enabled = false
	_player.add_component(C_Death.new())
	NpcAiFixture.advance(_district, 0.2)
	assert_null(CombatQueries.target_for(_actor))


func test_native_and_customer_roots_share_guarded_hunt_below_immediate_safety() -> void:
	for path: String in [
		NpcBrainService.TREE_PATH,
		"res://content/domains/customers/ai/trees/bt_district_npc.tres",
	]:
		var root_task: BTTask = (load(path) as BehaviorTree).get_root_task()
		var branch_index: int = 3 if path == NpcBrainService.TREE_PATH else 2
		assert_same((root_task.get_child(branch_index) as BTSubtree).subtree, HUNT)
		assert_eq(root_task.get_child(branch_index - 1).get_custom_name(), "Опасность")
		assert_eq(root_task.get_child(branch_index + 1).get_custom_name(), "Воспринятая кровь")
		assert_is(HUNT.get_root_task(), BTDynamicSelector)
		for index: int in HUNT.get_root_task().get_child_count():
			var branch: BTTask = HUNT.get_root_task().get_child(index)
			assert_is(branch, BTDynamicSequence)
			assert_is(branch.get_child(0), BTCondition)
			assert_is(branch.get_child(1), BTAction)
	var runner: BTPlayer = _actor.get_node("Brain") as BTPlayer
	runner.behavior_tree = load(CUSTOMER_TREE_PATH) as BehaviorTree
	_step()
	assert_same(CombatQueries.target_for(_actor), _player)
	_zone(Vector3.UP)
	_step()
	assert_null(CombatQueries.target_for(_actor))


func test_solid_occlusion_prevents_hunt_until_real_perception_recovers() -> void:
	var wall: StaticBody3D = StaticBody3D.new()
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(4, 4, 0.3)
	shape.shape = box
	wall.add_child(shape)
	_root.add_child(wall)
	wall.position = Vector3(0, 1, -1.5)
	await _sync_physics()
	NpcAiFixture.advance(_district, 0.2)
	assert_false(_awareness.player_visible)
	assert_eq(_awareness.player_light_exposure, 1.0)
	assert_null(CombatQueries.target_for(_actor))
	assert_eq(_person.memories.size(), 0)
	wall.free()
	await _sync_physics()
	NpcAiFixture.advance(_district, 0.2)
	assert_true(_awareness.player_visible)
	assert_same(CombatQueries.target_for(_actor), _player)


func test_capability_is_reusable_and_sampled_state_resets_without_mutating_definition() -> void:
	var copy: DEF_NpcArchetype = PROFILE.duplicate(true) as DEF_NpcArchetype
	copy.key = &"archetype/another_dark_hunter"
	_person.profile = copy
	_person.variation = NpcVariationRules.create(
		copy,
		GameTimeQueries.current().world_seed,
		_person.npc_id,
		1,
	)
	_step()
	assert_same(CombatQueries.target_for(_actor), _player)
	DistrictPopulationService.reset_brain(_actor)
	assert_eq(_awareness.self_light_exposure, 1.0)
	assert_eq(_awareness.player_light_exposure, 1.0)
	# Persistence accepts authored references; the temporary capability-reuse profile is unsaved.
	_person.profile = PROFILE
	_person.variation = NpcVariationRules.create(
		PROFILE,
		GameTimeQueries.current().world_seed,
		_person.npc_id,
		1,
	)
	var restored: NpcRecord = SaveDataCodec.decode(SaveDataCodec.encode(_person)) as NpcRecord
	assert_eq(restored.variation.seed, _person.variation.seed)
	assert_eq(restored.variation.optional_trait_keys, _person.variation.optional_trait_keys)
	assert_true(NpcVariationRules.valid_archetype(PROFILE))
	var rule: DEF_NpcDarkPredator = DEF_NpcDarkPredator.new()
	assert_true(rule.valid_configuration())
	rule.peaceful_light_threshold = rule.light_threshold
	assert_false(rule.valid_configuration())
	rule.peaceful_light_threshold = NAN
	assert_false(rule.valid_configuration())
#endregion
