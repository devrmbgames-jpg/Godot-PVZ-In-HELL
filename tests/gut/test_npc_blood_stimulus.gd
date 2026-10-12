extends GutTest
## Real composed district bodies, native LOS/Area overlaps and authored LimboAI execution.

var _root: Node3D
var _world: World
var _district: C_District
var _vampire: E_DistrictNpc
var _instigator: E_DistrictNpc
var _person: NpcRecord
var _sequence: int


class BloodRetirer extends Observer:
	func query() -> QueryBuilder:
		return q.with_all([C_NpcIdentity]).on_event(NpcSocialReactionCommitted.EVENT)


	func each(_event: Variant, _entity: Entity, _payload: Variant = null) -> void:
		var zone: Entity = _world.query.with_all([C_BloodArea]).execute_one()
		if zone != null:
			_world.remove_entity(zone)
			zone.free()


class ReceiverMutator extends Observer:
	var retire: bool = false
	var calls: int = 0


	func query() -> QueryBuilder:
		return q.with_all([C_NpcIdentity]).on_event(NpcSocialReactionCommitted.EVENT)


	func each(_event: Variant, entity: Entity, _payload: Variant = null) -> void:
		calls += 1
		if retire:
			_world.remove_entity(entity)
			entity.free()
		else:
			DistrictPopulationService.reset_brain(entity as E_DistrictNpc)
			var awareness: C_NpcAwareness = entity.get_component(C_NpcAwareness) as C_NpcAwareness
			awareness.heard_remaining = 9.0
			awareness.player_visible = true


func before_each() -> void:
	_root = Node3D.new()
	add_child(_root)
	var marker: Node3D = Node3D.new()
	marker.name = "District"
	_root.add_child(marker)
	_world = World.new()
	_root.add_child(_world)
	ECS.world = _world
	_world.add_observer(O_HazardSpawn.new())
	_world.add_observer(O_BloodAreaSetup.new())
	_world.add_observer(O_NpcBloodStimulus.new())
	var session_node: Node = Node.new()
	session_node.set_script(load("res://addons/gecs/ecs/entity.gd"))
	var session: Entity = session_node as Entity
	var district: C_District = C_District.new()
	district.definition = (
		load("res://content/domains/npc/definitions/def_district_default.tres") as DEF_District
	)
	session.component_resources = [district, C_DayCycle.new()]
	_world.add_entity(session)
	_district = session.get_component(C_District) as C_District
	_vampire = _actor(
		&"blood/vampire",
		Vector3.ZERO,
		C_ReceiverTraits.Trait.VAMPIRE | C_ReceiverTraits.Trait.UNCLEAN,
	)
	_instigator = _actor(&"blood/instigator", Vector3(2.0, 0.0, -4.0), 0)
	_person = NpcPopulationQueries.person_for(&"blood/vampire")
	NpcBrainService.bind_engine(_vampire)
	_sequence = 0


func after_each() -> void:
	for entity: Entity in _world.entities.duplicate():
		_world.remove_entity(entity)
	_world.purge(false)
	ECS.world = null
	_root.free()


func _actor(key: StringName, position: Vector3, receiver_traits: int) -> E_DistrictNpc:
	var profile: DEF_NpcArchetype = DEF_NpcArchetype.new()
	profile.key = &"fixture/blood_receiver"
	profile.dark_vision_fraction = 1.0
	profile.schedule = DEF_NpcSchedule.new()
	profile.vision_angle = 150.0
	var person: NpcRecord = NpcRecord.new()
	person.npc_id = key
	person.profile = profile
	person.variation = NpcVariationRules.create(
		profile,
		GameTimeQueries.current().world_seed,
		key,
		1,
	)
	person.placement = NpcRecord.Placement.STREET
	_district.people.append(person)
	var scene: PackedScene = load(profile.npc_scene_path) as PackedScene
	var actor: E_DistrictNpc = scene.instantiate() as E_DistrictNpc
	var context: EntitySpawnContext = EntityCompositionService.context_for(
		actor,
		_world,
		String(key),
	)
	NpcConstructionService.configure_context(context, person, _district.definition)
	var registered: bool = EntityCompositionService.try_register(context)
	assert_true(registered)
	if not registered:
		actor.free()
		return null
	actor.freeze = true
	actor.place_at(position)
	var traits: C_ReceiverTraits = C_ReceiverTraits.new()
	traits.traits = receiver_traits
	actor.add_component(traits)
	return actor


func _sync_physics() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame


func _spawn(position: Vector3, provoke: bool = true) -> E_BloodArea:
	_sequence += 1
	var request: HazardSpawnRequest = HazardSpawnRequest.new()
	request.request_id = "blood/test/%d" % _sequence
	request.origin_id = "blood/test/origin"
	request.instigator = _instigator
	request.scene = load("res://content/domains/hazards/entities/blood_spill.tscn") as PackedScene
	var profile: DEF_BloodArea = DEF_BloodArea.new()
	profile.provokes_unclean = provoke
	request.definition = profile
	request.world_pose.origin = position
	assert_true(HazardSpawnService.submit(request))
	_world.flush_command_buffers()
	for entity: Entity in _world.query.with_all([C_BloodArea, C_Hazard]).execute():
		if (entity.get_component(C_Hazard) as C_Hazard).request_id == request.request_id:
			return entity as E_BloodArea
	assert_true(false, "Committed factory must publish the requested native blood zone")
	return null


func _tick_tree() -> void:
	(_vampire.get_component(C_NpcDecision) as C_NpcDecision).intent_owner = C_NpcDecision.Owner.NONE
	assert_true(NpcBrainService.update_tree(_vampire, 0.1))


func _sample_navigation() -> void:
	var owner: S_NpcIntent = S_NpcIntent.new()
	owner.group = "blood_navigation_fixture"
	_world.add_system(owner)
	_world.process(0.0, owner.group)
	_world.remove_system(owner)


func test_visible_spawn_cancels_attack_then_native_tree_approaches_and_retains() -> void:
	await _sync_physics()
	assert_true(CombatService.bind_target(_vampire, _instigator))
	var combat: C_NpcCombat = _vampire.get_component(C_NpcCombat) as C_NpcCombat
	# Seed an in-flight execution to falsify cancellation without depending on attack range.
	combat.phase = C_NpcCombat.Phase.WINDUP
	combat.attack = combat.melee_attacks[0]
	var generation: int = combat.execution_generation
	var health: C_Health = _vampire.get_component(C_Health) as C_Health
	var before: float = health.current
	var zone: E_BloodArea = _spawn(Vector3(0.0, 0.0, -4.0))
	assert_same(NpcBloodQueries.zone_for(_vampire), zone)
	assert_null(
		CombatQueries.target_for(_vampire),
		"No sensing interval is required after a perceived spawn",
	)
	assert_eq(combat.phase, C_NpcCombat.Phase.READY)
	assert_gt(combat.execution_generation, generation)
	assert_true((_vampire.get_component(C_NpcDecision) as C_NpcDecision).wake_urgent)
	_tick_tree()
	var intent: C_NpcIntent = _vampire.get_component(C_NpcIntent) as C_NpcIntent
	assert_true(intent.movement_active)
	assert_eq(intent.move_position, zone.global_position)
	assert_eq(
		(_vampire.get_component(C_NpcDecision) as C_NpcDecision).active_behavior,
		"Подойти к крови",
	)
	_vampire.place_at(zone.global_position)
	await _sync_physics()
	assert_true(NpcBloodQueries.inside(_vampire, zone))
	NpcAiFixture.sense(_vampire, _person, null, 0.1)
	_tick_tree()
	assert_false(intent.movement_active)
	assert_eq(
		(_vampire.get_component(C_NpcDecision) as C_NpcDecision).active_behavior,
		"Оставаться у крови",
	)
	NpcSocialService.apply_reaction(_vampire, _instigator, NpcMemory.Reaction.ATTACK)
	assert_null(
		CombatQueries.target_for(_vampire),
		"A later social reaction cannot restart an attack while calmed",
	)
	NpcSocialService.apply_reaction(_vampire, _instigator, NpcMemory.Reaction.FLEE)
	assert_false((_vampire.get_component(C_NpcAwareness) as C_NpcAwareness).fleeing)
	var further: E_BloodArea = _spawn(Vector3(0.0, 0.0, -8.0))
	assert_ne(further, zone)
	assert_same(
		NpcBloodQueries.zone_for(_vampire),
		zone,
		"A new visible zone cannot lure away a retained vampire",
	)
	assert_eq(health.current, before, "Blood never heals or damages directly")


func test_hidden_blood_does_not_calm_until_native_cadenced_sight_is_clear() -> void:
	var wall: StaticBody3D = StaticBody3D.new()
	var collider: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(5.0, 3.0, 0.5)
	collider.shape = shape
	wall.add_child(collider)
	_root.add_child(wall)
	wall.position = Vector3(0.0, 1.5, -2.0)
	await _sync_physics()
	assert_true(CombatService.bind_target(_vampire, _instigator))
	var zone: E_BloodArea = _spawn(Vector3(0.0, 0.0, -4.0))
	assert_null(NpcBloodQueries.zone_for(_vampire))
	assert_same(CombatQueries.target_for(_vampire), _instigator)
	NpcAiFixture.sense(_vampire, _person, null, 0.1)
	assert_null(NpcBloodQueries.zone_for(_vampire))
	wall.position.x = 20.0
	await _sync_physics()
	NpcAiFixture.sense(_vampire, _person, null, 0.1)
	assert_same(NpcBloodQueries.zone_for(_vampire), zone)
	assert_null(CombatQueries.target_for(_vampire))


func test_invalid_or_unreachable_bindings_release_and_reconstruction_clears_them() -> void:
	await _sync_physics()
	var zone: E_BloodArea = _spawn(Vector3(0.0, 0.0, -4.0))
	_tick_tree()
	var intent: C_NpcIntent = _vampire.get_component(C_NpcIntent) as C_NpcIntent
	var route: C_NpcRoute = _vampire.get_component(C_NpcRoute) as C_NpcRoute
	route.goal = intent.move_position
	route.reachable = false
	route.pending = false
	_sample_navigation()
	assert_true(intent.navigation_blocked)
	NpcAiFixture.sense(_vampire, _person, null, 0.1)
	assert_null(NpcBloodQueries.zone_for(_vampire))
	assert_true(
		(_vampire.get_component(C_NpcAwareness) as C_NpcAwareness).rejected_blood_ids.has(zone.id)
	)
	intent.navigation_blocked = false
	NpcAiFixture.sense(_vampire, _person, null, 0.1)
	assert_null(
		NpcBloodQueries.zone_for(_vampire),
		"A failed native route is not retried every interval",
	)
	(zone.get_component(C_HazardLifetime) as C_HazardLifetime).remaining_seconds = 0.0
	NpcAiFixture.sense(_vampire, _person, null, 0.1)
	assert_true(
		(_vampire.get_component(C_NpcAwareness) as C_NpcAwareness).rejected_blood_ids.is_empty()
	)
	_world.remove_entity(zone)
	zone.free()
	var next_zone: E_BloodArea = _spawn(Vector3(0.0, 0.0, -4.0))
	assert_same(NpcBloodQueries.zone_for(_vampire), next_zone)
	DistrictPopulationService.reset_brain(_vampire)
	assert_null(NpcBloodQueries.zone_for(_vampire))
	assert_true(
		(_vampire.get_component(C_NpcAwareness) as C_NpcAwareness).rejected_blood_ids.is_empty()
	)


func test_unrelated_stale_and_pending_navigation_cannot_reject_blood() -> void:
	await _sync_physics()
	var intent: C_NpcIntent = _vampire.get_component(C_NpcIntent) as C_NpcIntent
	var route: C_NpcRoute = _vampire.get_component(C_NpcRoute) as C_NpcRoute
	var decision: C_NpcDecision = _vampire.get_component(C_NpcDecision) as C_NpcDecision
	decision.active_task_id = 123
	NpcIntentService.move_to(_vampire, Vector3(4.0, 0.0, -4.0), 0.3)
	route.goal = intent.move_position
	route.reachable = false
	_sample_navigation()
	assert_true(intent.navigation_blocked)
	var zone: E_BloodArea = _spawn(Vector3(0.0, 0.0, -4.0))
	NpcAiFixture.sense(_vampire, _person, null, 0.1)
	assert_same(NpcBloodQueries.zone_for(_vampire), zone, "Old combat route is unrelated")
	_tick_tree()
	NpcAiFixture.sense(_vampire, _person, null, 0.1)
	assert_same(NpcBloodQueries.zone_for(_vampire), zone, "New request invalidates old flags")
	route.goal = intent.move_position
	route.pending = true
	_sample_navigation()
	NpcAiFixture.sense(_vampire, _person, null, 0.1)
	assert_same(NpcBloodQueries.zone_for(_vampire), zone, "Queued planning is not failure")
	route.pending = false
	decision.active_task_id = 123
	NpcIntentService.move_to(_vampire, zone.global_position, 0.3)
	_sample_navigation()
	NpcAiFixture.sense(_vampire, _person, null, 0.1)
	assert_same(NpcBloodQueries.zone_for(_vampire), zone, "Emergency may share a destination")
	_tick_tree()
	NpcAiFixture.sense(_vampire, _person, null, 0.1)
	assert_same(NpcBloodQueries.zone_for(_vampire), zone, "Earlier action result is still stale")
	_sample_navigation()
	NpcAiFixture.sense(_vampire, _person, null, 0.1)
	assert_null(NpcBloodQueries.zone_for(_vampire), "Completed blood approach failure is rejected")


func _prepare_cadenced_provocation() -> void:
	var receiver: C_ReceiverTraits = _vampire.get_component(C_ReceiverTraits) as C_ReceiverTraits
	receiver.traits = 0
	_spawn(Vector3(0.0, 0.0, -4.0))
	receiver.traits = C_ReceiverTraits.Trait.UNCLEAN
	assert_null(NpcBloodQueries.zone_for(_vampire))


func test_cadenced_provocation_stops_after_receiver_retirement() -> void:
	await _sync_physics()
	_prepare_cadenced_provocation()
	var observer: ReceiverMutator = ReceiverMutator.new()
	observer.retire = true
	_world.add_observer(observer)
	var receiver_reference: WeakRef = weakref(_vampire)
	NpcAiFixture.sense(_vampire, _person, null, 0.1)
	assert_eq(observer.calls, 1)
	assert_null(receiver_reference.get_ref())
	assert_eq(_person.memories.size(), 1, "Committed memory survives physical retirement")


func test_cadenced_provocation_stops_after_receiver_brain_reset() -> void:
	await _sync_physics()
	_prepare_cadenced_provocation()
	var observer: ReceiverMutator = ReceiverMutator.new()
	_world.add_observer(observer)
	var decision: C_NpcDecision = _vampire.get_component(C_NpcDecision) as C_NpcDecision
	var generation: int = decision.lifecycle_generation
	NpcAiFixture.sense(_vampire, _person, null, 0.1)
	assert_eq(observer.calls, 1)
	assert_gt(decision.lifecycle_generation, generation)
	var awareness: C_NpcAwareness = _vampire.get_component(C_NpcAwareness) as C_NpcAwareness
	assert_eq(awareness.heard_remaining, 9.0, "Old step cannot advance the new brain's clocks")
	assert_true(awareness.player_visible, "Old step cannot overwrite the new perception state")
	assert_null(NpcBloodQueries.zone_for(_vampire))


func test_other_unclean_provocation_is_authored_visible_and_committed_once() -> void:
	var receiver: C_ReceiverTraits = _vampire.get_component(C_ReceiverTraits) as C_ReceiverTraits
	receiver.traits = C_ReceiverTraits.Trait.UNCLEAN
	await _sync_physics()
	_spawn(Vector3(0.0, 0.0, -4.0), false)
	assert_null(CombatQueries.target_for(_vampire))
	var zone: E_BloodArea = _spawn(Vector3(0.0, 0.0, -3.0), true)
	assert_same(CombatQueries.target_for(_vampire), _instigator)
	assert_eq(_person.memories.size(), 1)
	assert_eq(_person.memories[0].reaction, NpcMemory.Reaction.ATTACK)
	NpcBloodService.observe(_vampire, _person, zone)
	assert_eq(_person.memories.size(), 1)
	assert_false(NpcBloodQueries.calmed(_vampire))
	CombatService.end_combat(_vampire)
	_instigator.place_at(Vector3(0.0, 0.0, 20.0))
	await _sync_physics()
	_spawn(Vector3(0.0, 0.0, -2.0), true)
	assert_null(CombatQueries.target_for(_vampire), "No aggression toward an unseen initiator")
	assert_eq(_person.memories.size(), 1)


func test_native_and_customer_roots_preserve_other_branches_and_share_blood_priority() -> void:
	for tree_path: String in [
		NpcBrainService.TREE_PATH,
		"res://content/domains/customers/ai/trees/bt_district_npc.tres",
	]:
		var tree: BehaviorTree = load(tree_path) as BehaviorTree
		var root_task: BTTask = tree.get_root_task()
		var hunt_index: int = 3 if tree_path == NpcBrainService.TREE_PATH else 2
		assert_eq(root_task.get_child_count(), 11 if hunt_index == 3 else 10)
		assert_eq(root_task.get_child(hunt_index - 1).get_custom_name(), "Опасность")
		assert_eq(root_task.get_child(hunt_index + 1).get_custom_name(), "Воспринятая кровь")
		assert_eq(root_task.get_child(hunt_index + 3).get_custom_name(), "Дистанционный бой")
		assert_eq(root_task.get_child(hunt_index + 4).get_custom_name(), "Бой / поиск")
		assert_same(
			(root_task.get_child(hunt_index + 1) as BTSubtree).subtree,
			load("res://content/domains/npc/ai/trees/bt_npc_blood.tres"),
		)


func test_observer_survives_queued_and_synchronous_source_retirement() -> void:
	await _sync_physics()
	var zone: E_BloodArea = _spawn(Vector3(0.0, 0.0, -4.0), false)
	NpcBloodService.release(_vampire)
	var observer: O_NpcBloodStimulus = O_NpcBloodStimulus.new()
	observer.command_buffer_flush_mode = Observer.FlushMode.MANUAL
	_world.add_observer(observer)
	var result: HazardSpawnResult = HazardSpawnResult.new()
	result.hazard = zone
	observer.each(HazardSpawnResult.EVENT, zone, result)
	assert_eq(observer.cmd.size(), 1)
	_world.remove_entity(zone)
	zone.free()
	_world.flush_command_buffers()
	assert_null(NpcBloodQueries.zone_for(_vampire))
	assert_false(observer.has_pending_commands())
	_world.remove_observer(observer)
	observer.free()
	var receiver: C_ReceiverTraits = _vampire.get_component(C_ReceiverTraits) as C_ReceiverTraits
	receiver.traits = C_ReceiverTraits.Trait.UNCLEAN
	zone = _spawn(Vector3(0.0, 0.0, -4.0), false)
	NpcBloodService.release(_vampire)
	((zone.get_component(C_Hazard) as C_Hazard).definition as DEF_BloodArea).provokes_unclean = true
	_world.add_observer(BloodRetirer.new())
	result.hazard = zone
	_world.emit_event(HazardSpawnResult.EVENT, zone, result)
	_world.flush_command_buffers()
	assert_eq(_world.query.with_all([C_BloodArea]).execute().size(), 0)
	assert_null(NpcBloodQueries.zone_for(_vampire))
	assert_eq(_person.memories.size(), 1)


func test_sight_range_sector_receiver_tags_death_and_customer_tree_execution() -> void:
	await _sync_physics()
	var behind: E_BloodArea = _spawn(Vector3(0.0, 0.0, 4.0))
	assert_null(NpcBloodQueries.zone_for(_vampire))
	_person.profile.dark_vision_fraction = 0.05
	var far: E_BloodArea = _spawn(Vector3(0.0, 0.0, -10.0))
	assert_null(NpcBloodQueries.zone_for(_vampire))
	_person.profile.dark_vision_fraction = 1.0
	NpcAiFixture.sense(_vampire, _person, null, 0.1)
	assert_same(NpcBloodQueries.zone_for(_vampire), far)
	assert_null(NpcBloodQueries.zone_for(_instigator), "Ordinary untagged NPCs are unaffected")
	var runner: BTPlayer = _vampire.get_node("Brain") as BTPlayer
	runner.behavior_tree = (
		load("res://content/domains/customers/ai/trees/bt_district_npc.tres") as BehaviorTree
	)
	_tick_tree()
	assert_eq(
		(_vampire.get_component(C_NpcDecision) as C_NpcDecision).active_behavior,
		"Подойти к крови",
	)
	_vampire.add_component(C_Death.new())
	assert_null(NpcBloodQueries.zone_for(_vampire))
	assert_true(NpcBloodQueries.valid_zone(behind))
