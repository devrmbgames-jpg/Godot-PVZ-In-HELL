extends GutTest
## Real brute, native camera/Jolt, inspection opening, damage observers and durable respect.

const BRUTE: DEF_NpcArchetype = preload(
	"res://content/domains/npc/definitions/def_npc_archetype_brute.tres"
)
const BODY: PackedScene = preload("res://content/domains/npc/entities/district_npc.tscn")
const DISTRICT: DEF_District = preload(
	"res://content/domains/npc/definitions/def_district_default.tres"
)
const TOY: DEF_InventoryItem = preload(
	"res://content/domains/inventory/definitions/def_item_toy_block.tres"
)
const TOY_TREE: BehaviorTree = preload("res://content/domains/npc/ai/trees/bt_npc_toy_pride.tres")
const SUPPLY: DEF_Delivery = preload(
	"res://content/domains/packages/definitions/def_delivery_morning_supply.tres"
)

var _root: Node3D
var _world: World
var _actor: E_DistrictNpc
var _person: NpcRecord
var _player: Entity
var _camera: Camera3D
var _pride: C_NpcPride
var _decision: C_NpcDecision
var _visit: CustomerVisit
var _parcel: E_Package


class ToyReceiverMutator extends Observer:
	## Test boundary operation: retire, suspend or reset the actual receiver synchronously.
	var mode: int = 0
	## Number of committed toy reactions, before any new frame or cadence update.
	var calls: int = 0


	func query() -> QueryBuilder:
		return q.with_all([C_NpcIdentity]).on_event(NpcSocialReactionCommitted.EVENT)


	func each(_event: Variant, entity: Entity, _payload: Variant = null) -> void:
		calls += 1
		if mode == 0:
			_world.remove_entity(entity)
			entity.free()
		elif mode == 1:
			var identity: C_NpcIdentity = entity.get_component(C_NpcIdentity) as C_NpcIdentity
			DistrictPopulationService.set_placement(
				NpcPopulationQueries.person_for(identity.npc_id),
				entity as E_DistrictNpc,
				NpcRecord.Placement.OUTSIDE,
			)
		else:
			DistrictPopulationService.reset_brain(entity as E_DistrictNpc)


#region Native fixture and actual event boundaries
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
	session.component_resources = [
		district,
		C_DayCycle.new(),
		C_CustomerFlow.new(),
		C_PackageLedger.new(),
		C_LootDrops.new(),
	]
	_world.add_entity(session)
	_person = NpcRecord.new()
	_person.npc_id = &"pride/brute"
	_person.profile = BRUTE
	_person.variation = NpcVariationRules.create(BRUTE, 1234, _person.npc_id, 1)
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
	_actor.place_at(Vector3(0, 0, -2))
	_actor.set_physics_process(false)
	_actor.rotation.y = PI
	_pride = _actor.get_component(C_NpcPride) as C_NpcPride
	_decision = _actor.get_component(C_NpcDecision) as C_NpcDecision
	NpcBrainService.bind_engine(_actor)
	var player_body: CharacterBody3D = CharacterBody3D.new()
	player_body.set_script(load("res://addons/gecs/ecs/entity.gd"))
	_player = player_body as Node as Entity
	_player.component_resources = [C_PlayerInputController.new(), C_Health.new()]
	_camera = Camera3D.new()
	_camera.position.y = NpcPerceptionService.EYE_HEIGHT
	player_body.add_child(_camera)
	_world.add_entity(_player)
	_camera.make_current()
	var witness: S_CustomerToyWitness = S_CustomerToyWitness.new()
	witness.group = "PrideFixture"
	_world.add_system(witness)
	_world.add_observer(O_Damage.new())
	_world.add_observer(O_NpcIncident.new())
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


func _toy() -> Entity:
	var item: Entity = (load(TOY.world_pickup_scene) as PackedScene).instantiate() as Entity
	EntityCompositionFixture.register(_world, item)
	var body: RigidBody3D = item as Node as RigidBody3D
	body.freeze = true
	body.global_position = Vector3(0.7, 1.2, -2.5)
	return item


func _exposure() -> String:
	return CustomerToyExposureQueries.exposed_toy_id(_actor, _player, _person, _pride.rule)


func _sample() -> void:
	_world.process(1.0 / 60.0, "PrideFixture")


func _step() -> void:
	_decision.intent_owner = C_NpcDecision.Owner.NONE
	assert_true(NpcBrainService.update_tree(_actor, 0.1))


func _wall(size: Vector3, position: Vector3) -> StaticBody3D:
	var wall: StaticBody3D = StaticBody3D.new()
	wall.collision_layer = 1
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.shape = shape
	wall.add_child(collision)
	_root.add_child(wall)
	wall.position = position
	return wall


func _damage(victim: Entity, amount: float, incident: StringName) -> void:
	var request: DamageRequest = DamageRequest.new()
	request.target = victim
	request.source = _player
	request.instigator = _player
	request.amount = amount
	request.damage_type = DamageRequest.Type.MELEE
	request.incident_id = incident
	request.combat_context = CombatContext.new()
	request.combat_context.actor_is_player = true
	assert_true(DamageRequestService.submit(request))


func _inspection() -> void:
	_world.add_observer(O_PhysicalSlotLifecycle.new())
	_world.add_observer(O_PackageOpening.new())
	_world.add_observer(O_PackageContents.new())
	_world.add_observer(O_CustomerInspectionCargo.new())
	var counter: Entity = (
		load("res://content/domains/customers/entities/delivery_counter.tscn") as PackedScene
	).instantiate() as Entity
	_world.add_entity(counter)
	var booth: Entity = (
		load("res://content/domains/customers/entities/inspection_booth.tscn") as PackedScene
	).instantiate() as Entity
	(booth as Node as Node3D).position = Vector3(4, 0, 0)
	_world.add_entity(booth)
	_visit = CustomerVisit.new()
	_visit.visit_id = &"pride/inspection"
	_visit.package_id = "pride/parcel"
	_visit.definition = DEF_Customer.new()
	_visit.definition.private_inspection = false
	_visit.definition.inspection_unpack_probability = 0.0
	_visit.started = true
	_visit.visit_count = 1
	CustomerFlowQueries.current().visits.append(_visit)
	var agent: C_CustomerAgent = C_CustomerAgent.new()
	agent.visit_id = _visit.visit_id
	agent.phase = C_CustomerAgent.Phase.WAITING_FOR_PACKAGE
	_actor.add_component(agent)
	_parcel = (
		load("res://content/domains/packages/entities/test_bread.tscn") as PackedScene
	).instantiate() as E_Package
	_parcel.package_definition = _parcel.package_definition.duplicate(true) as DEF_Package
	_parcel.package_definition.content_quantity = 1
	_parcel.gravity_scale = 0.0
	EntityCompositionFixture.register(_world, _parcel)
	var package: C_Package = _parcel.get_component(C_Package) as C_Package
	package.package_id = _visit.package_id
	var state: C_PackageState = _parcel.get_component(C_PackageState) as C_PackageState
	state.registration = C_PackageState.Registration.REGISTERED
	(_parcel.get_component(C_PackageContents) as C_PackageContents).selected_item = TOY
	CustomerParcelAssignment.bind_parcel(_actor, _visit)
#endregion


#region Physical exposure and visible native priority
func test_selected_pride_is_constructed_and_catalog_toy_has_native_physical_contract() -> void:
	assert_not_null(_pride.rule)
	assert_true(_pride.rule.valid_configuration())
	assert_true(BRUTE.valid_rules())
	assert_eq(_pride.rule.kind, DEF_NpcTrait.Kind.CAPABILITY)
	var item: Entity = _toy()
	assert_true(item.has_component(C_Grabbable))
	assert_true(item.has_component(C_InventoryItem))
	assert_false(item.has_component(C_MeleeWeapon))
	assert_true(TOY.requires_world_body())
	assert_eq(TOY.categories, DEF_InventoryItem.Category.TOY)
	assert_true(TOY in SUPPLY.order_catalog)
	assert_gt(
		BRUTE.item_category_weights[DEF_InventoryItem.Category.WEAPON],
		BRUTE.item_category_weights[DEF_InventoryItem.Category.TOY],
	)


func test_unrelated_visible_toy_and_closed_parcel_never_reveal_contents() -> void:
	var item: Entity = _toy()
	await _sync_physics()
	assert_true(NpcCameraVisibility.item_observed(item, _player, _pride.rule.toy_visibility_mask))
	assert_eq(_exposure(), "")
	_inspection()
	assert_true(CustomerInspectionService.begin(_actor, _visit, _parcel))
	await _sync_physics()
	assert_eq(_exposure(), "")
	_sample()
	assert_eq(_pride.exposed_toy_id, "")
	assert_null(CombatQueries.target_for(_actor))


func test_actual_held_and_reserved_toys_require_player_camera_and_npc_recognition() -> void:
	var item: Entity = _toy()
	var hand: Node3D = Node3D.new()
	_actor.add_child(hand)
	hand.global_position = (item as Node as Node3D).global_position
	_actor.right_hand_slot = hand
	_actor.add_component(C_GrabControl.new())
	_actor.add_component(C_CarryLoad.new())
	_actor.add_component(C_Interactor.new())
	var ray: RayCast3D = RayCast3D.new()
	_actor.add_child(ray)
	ray.global_position = hand.global_position + Vector3.BACK
	ray.look_at(hand.global_position)
	ray.target_position = Vector3.FORWARD * 2.0
	ray.collision_mask = 31
	ray.add_exception(_actor as Node as CollisionObject3D)
	_actor.interaction_ray_cast = ray
	_world.add_observer(O_GrabLifecycle.new())
	(item as Node as RigidBody3D).freeze = false
	(item as Node as RigidBody3D).gravity_scale = 0.0
	await _sync_physics()
	assert_true(GrabService.try_pickup(_actor, item, C_Grabbable.HoldSlot.RIGHT_HAND))
	assert_eq(GrabQueries.held_object(_actor), item)
	await _sync_physics()
	assert_true(NpcPerceptionService.can_see(_actor, _player, _person))
	assert_eq(_exposure(), item.id)
	_camera.rotation.y = PI
	assert_eq(_exposure(), "")
	_camera.rotation.y = 0.0
	_camera.far = 1.0
	assert_eq(_exposure(), "")
	_camera.far = 100.0
	(_player as Node as Node3D).position = Vector3(0, 0, -50)
	await _sync_physics()
	assert_false(NpcPerceptionService.can_see(_actor, _player, _person))
	assert_eq(_exposure(), "")


func test_camera_owned_by_other_actor_cannot_witness_and_solid_wall_hides_toy() -> void:
	var item: Entity = _toy()
	item.add_relationship(Relationship.new(R_InspectionCargo.new(), _actor))
	await _sync_physics()
	assert_eq(_exposure(), item.id)
	var spectator: Camera3D = Camera3D.new()
	_root.add_child(spectator)
	spectator.global_transform = _camera.global_transform
	spectator.make_current()
	assert_eq(_exposure(), "")
	_camera.make_current()
	_wall(Vector3(0.5, 0.8, 0.2), Vector3(0.45, 1.25, -1.5))
	await _sync_physics()
	assert_true(NpcPerceptionService.can_see(_actor, _player, _person))
	assert_eq(_exposure(), "")


func test_frame_sample_wakes_native_attack_once_and_remembered_toy_does_not_restart() -> void:
	var item: Entity = _toy()
	item.add_relationship(Relationship.new(R_InspectionCargo.new(), _actor))
	await _sync_physics()
	_decision.wake_urgent = false
	_sample()
	assert_eq(_pride.exposed_toy_id, item.id)
	assert_true(_decision.wake_urgent)
	assert_null(CombatQueries.target_for(_actor), "Only the native tree commits aggression")
	_step()
	assert_eq(CombatQueries.target_for(_actor), _player)
	assert_eq(_person.memories.size(), 1)
	assert_eq(_person.memories[0].kind, NpcMemory.Kind.OFFENSE)
	CombatService.end_combat(_actor)
	_sample()
	_step()
	assert_null(CombatQueries.target_for(_actor))
	assert_eq(_person.memories.size(), 1)


func test_both_native_roots_place_toy_after_safety_and_before_ordinary_combat() -> void:
	for path: String in [
		NpcBrainService.TREE_PATH,
		"res://content/domains/customers/ai/trees/bt_district_npc.tres",
	]:
		var tree: BehaviorTree = load(path) as BehaviorTree
		var root_task: BTTask = tree.get_root_task()
		var branch_indices: Dictionary[String, int] = { }
		var toy_index: int = -1
		for child_index: int in root_task.get_child_count():
			var child: BTTask = root_task.get_child(child_index)
			branch_indices[child.get_custom_name()] = child_index
			if child is BTSubtree:
				var subtree: BehaviorTree = (child as BTSubtree).subtree
				if subtree.resource_path == TOY_TREE.resource_path:
					toy_index = child_index
		assert_gte(toy_index, 0, "Both native roots retain the authored typed toy subtree")
		if toy_index < 0:
			continue
		assert_lt(branch_indices["Опасность"], toy_index)
		assert_lt(branch_indices["Воспринятая кровь"], toy_index)
		assert_lt(branch_indices["Питание / предел обычного урона"], toy_index)
		assert_lt(toy_index, branch_indices["Дистанционный бой"])
		assert_lt(toy_index, branch_indices["Бой / поиск"])
		var item: Entity = _toy()
		item.add_relationship(Relationship.new(R_InspectionCargo.new(), _actor))
		await _sync_physics()
		_sample()
		(_actor.get_node("Brain") as BTPlayer).behavior_tree = tree
		_step()
		assert_eq(CombatQueries.target_for(_actor), _player)
		CombatService.end_combat(_actor)
		_person.memories.clear()
		_world.remove_entity(item)


func test_queued_sample_refuses_dormant_actor_and_replaced_component() -> void:
	var sampler: S_CustomerToyWitness = _world.systems[0] as S_CustomerToyWitness
	var item: Entity = _toy()
	item.add_relationship(Relationship.new(R_InspectionCargo.new(), _actor))
	await _sync_physics()
	var reference: WeakRef = weakref(_actor)
	_world.disable_entity(_actor)
	sampler.call("_sample", reference, _pride)
	assert_eq(_pride.exposed_toy_id, "")
	_world.enable_entity(_actor)
	var replacement: C_NpcPride = C_NpcPride.new()
	replacement.rule = _pride.rule
	_actor.remove_component(C_NpcPride)
	_actor.add_component(replacement)
	sampler.call("_sample", reference, _pride)
	assert_eq(replacement.exposed_toy_id, "")
#endregion


#region Actual strength, durable respect and inspection priority
func test_visible_toy_in_second_hand_is_not_hidden_by_first_held_item() -> void:
	_actor.add_component(C_GrabControl.new())
	_actor.add_component(C_CarryLoad.new())
	_world.add_observer(O_GrabLifecycle.new())
	var first: Entity = _toy()
	var second: Entity = _toy()
	(first as Node as RigidBody3D).freeze = false
	(second as Node as RigidBody3D).freeze = false
	(first as Node as RigidBody3D).gravity_scale = 0.0
	(second as Node as RigidBody3D).gravity_scale = 0.0
	(first as Node as Node3D).visible = false
	(second as Node as Node3D).global_position.x = -0.7
	for slot: int in [C_Grabbable.HoldSlot.RIGHT_HAND, C_Grabbable.HoldSlot.LEFT_HAND]:
		var hand: Node3D = Node3D.new()
		_actor.add_child(hand)
		var item: Entity = first if slot == C_Grabbable.HoldSlot.RIGHT_HAND else second
		hand.global_position = (item as Node as Node3D).global_position
		if slot == C_Grabbable.HoldSlot.RIGHT_HAND:
			_actor.right_hand_slot = hand
		else:
			_actor.left_hand_slot = hand
		var grip: R_HeldBy = R_HeldBy.new()
		grip.slot = slot as C_Grabbable.HoldSlot
		item.add_relationship(Relationship.new(grip, _actor))
		assert_true(grip.lifecycle_applied)
	await _sync_physics()
	assert_eq(_exposure(), second.id)


func test_native_offense_survives_synchronous_retirement_without_stale_access() -> void:
	var reference: WeakRef = weakref(_actor)
	var observer: ToyReceiverMutator = ToyReceiverMutator.new()
	_world.add_observer(observer)
	var item: Entity = _toy()
	item.add_relationship(Relationship.new(R_InspectionCargo.new(), _actor))
	await _sync_physics()
	_sample()
	NpcBrainService.update_tree(_actor, 0.1)
	assert_eq(observer.calls, 1)
	assert_null(reference.get_ref())
	assert_eq(_person.memories.size(), 1)


func test_native_offense_aborts_when_receiver_becomes_dormant() -> void:
	var observer: ToyReceiverMutator = ToyReceiverMutator.new()
	observer.mode = 1
	_world.add_observer(observer)
	var item: Entity = _toy()
	item.add_relationship(Relationship.new(R_InspectionCargo.new(), _actor))
	await _sync_physics()
	_sample()
	NpcBrainService.update_tree(_actor, 0.1)
	assert_eq(observer.calls, 1)
	assert_false(_actor.enabled)
	assert_false(_decision.tree_updating)
	assert_null(CombatQueries.target_for(_actor))
	assert_false((_actor.get_node("Brain") as BTPlayer).active)


func test_native_offense_preserves_synchronous_reset_state() -> void:
	var observer: ToyReceiverMutator = ToyReceiverMutator.new()
	observer.mode = 2
	_world.add_observer(observer)
	var item: Entity = _toy()
	item.add_relationship(Relationship.new(R_InspectionCargo.new(), _actor))
	await _sync_physics()
	_sample()
	NpcBrainService.update_tree(_actor, 0.1)
	assert_eq(observer.calls, 1)
	assert_eq(_pride.exposed_toy_id, "")
	assert_null(CombatQueries.target_for(_actor))
	assert_null(_actor.get_node_or_null("Brain"))


func test_strength_replaces_unrecognized_panic_and_restores_normal_priority() -> void:
	var wall: StaticBody3D = _wall(Vector3(4, 4, 0.3), Vector3(0, 1.3, -1.5))
	await _sync_physics()
	_damage(_actor, 1.0, &"pride/unseen_hit")
	var awareness: C_NpcAwareness = _actor.get_component(C_NpcAwareness) as C_NpcAwareness
	assert_true(awareness.fleeing)
	wall.free()
	await _sync_physics()
	_damage(_actor, _pride.rule.respected_damage, &"pride/recognized_strength")
	assert_true(NpcPrideRules.respects(_person, &"player"))
	assert_false(awareness.fleeing)
	_step()
	assert_ne(_decision.intent_owner, C_NpcDecision.Owner.COMBAT)


func test_brute_category_selection_includes_rare_real_toys_and_prefers_weapons() -> void:
	var toys: int = 0
	var weapons: int = 0
	for index: int in 128:
		var selected: DEF_InventoryItem = PackageOrderRules.choose(
			SUPPLY.order_catalog,
			BRUTE.item_category_weights,
			1234,
			String(_person.npc_id),
			1,
			"pride/order/%d" % index,
		)
		assert_not_null(selected)
		if selected.categories & DEF_InventoryItem.Category.TOY:
			toys += 1
		elif selected.categories & DEF_InventoryItem.Category.WEAPON:
			weapons += 1
	assert_gt(toys, 0)
	assert_gt(weapons, toys)
	assert_eq(toys + weapons, 128)


func test_recognized_applied_strength_ends_matching_combat_and_suppresses_toy_attack() -> void:
	assert_true(CombatService.bind_target(_actor, _player))
	var health: C_Health = _actor.get_component(C_Health) as C_Health
	var before: float = health.current
	_damage(_actor, _pride.rule.respected_damage, &"pride/strength")
	assert_almost_eq(health.current, before - _pride.rule.respected_damage, 0.001)
	assert_true(NpcPrideRules.respects(_person, &"player"))
	assert_null(CombatQueries.target_for(_actor))
	assert_eq(_person.memories[0].reaction, NpcMemory.Reaction.RESPECT)
	var item: Entity = _toy()
	item.add_relationship(Relationship.new(R_InspectionCargo.new(), _actor))
	await _sync_physics()
	_sample()
	assert_eq(_pride.exposed_toy_id, item.id)
	assert_eq(NpcPrideQueries.pending_toy_incident(_actor, _person), &"")
	_step()
	assert_null(CombatQueries.target_for(_actor))


func test_weak_or_occluded_damage_cannot_fabricate_respect() -> void:
	_damage(_actor, 1.0, &"pride/weak")
	assert_false(NpcPrideRules.respects(_person, &"player"))
	_wall(Vector3(4, 4, 0.3), Vector3(0, 1.3, -1.5))
	await _sync_physics()
	assert_false(NpcPerceptionService.can_see(_actor, _player, _person))
	_damage(_actor, _pride.rule.respected_damage, &"pride/unrecognized")
	assert_false(NpcPrideRules.respects(_person, &"player"))


func test_respect_preserves_other_combat_target_and_survives_codec_and_body_reset() -> void:
	var stranger: Entity = Entity.new()
	var identity: C_NpcIdentity = C_NpcIdentity.new()
	identity.npc_id = &"pride/stranger"
	stranger.component_resources = [identity, C_Health.new()]
	_world.add_entity(stranger)
	assert_true(CombatService.bind_target(_actor, stranger))
	NpcSocialService.remember(
		_person,
		_player,
		_actor,
		NpcMemory.Kind.ATTACK,
		&"pride/respect",
		NpcMemory.Reaction.RESPECT,
	)
	NpcSocialService.apply_reaction(_actor, _player, NpcMemory.Reaction.RESPECT)
	assert_eq(CombatQueries.target_for(_actor), stranger)
	var restored: NpcRecord = SaveDataCodec.decode(SaveDataCodec.encode(_person)) as NpcRecord
	assert_true(NpcPrideRules.respects(restored, &"player"))
	assert_false(NpcPrideRules.respects(restored, &"pride/stranger"))
	_pride.exposed_toy_id = "transient/toy"
	DistrictPopulationService.restore_participation()
	assert_eq(_pride.exposed_toy_id, "")
	assert_not_null(_pride.rule)
	assert_true(NpcPrideRules.respects(_person, &"player"))
	NpcSocialService.remember(
		_person,
		_player,
		_actor,
		NpcMemory.Kind.SUBMISSION,
		&"pride/submission",
	)
	assert_false(NpcPrideRules.respects(_person, &"player"))


func test_brute_prefers_booth_and_opens_actual_toy_once_without_mutating_visit_policy() -> void:
	_inspection()
	assert_eq(
		(CustomerFlowService as Script).call("_resolve_delivery", _actor, _visit, _parcel, null),
		PackageDeliveryCheck.Result.READY,
	)
	var agent: C_CustomerAgent = _actor.get_component(C_CustomerAgent) as C_CustomerAgent
	assert_eq(agent.phase, C_CustomerAgent.Phase.GOING_TO_BOOTH)
	assert_eq(CustomerInspectionQueries.owner_for(_parcel), _actor)
	assert_false(_visit.definition.private_inspection)
	CustomerInspectionService.arrive(_actor)
	CustomerInspectionService.inspect_contents(_actor, _visit)
	var state: C_PackageState = _parcel.get_component(C_PackageState) as C_PackageState
	assert_eq(state.opening, C_PackageState.Opening.OPENED)
	var cargo: Array[Entity] = CustomerInspectionQueries.cargo(_actor)
	assert_eq(cargo.size(), 2)
	var item: Entity = cargo[0] if cargo[0] != _parcel else cargo[1]
	assert_eq((item.get_component(C_InventoryItem) as C_InventoryItem).definition, TOY)
	CustomerInspectionService.inspect_contents(_actor, _visit)
	assert_eq(CustomerInspectionQueries.cargo(_actor).size(), 2)
	assert_eq(_visit.definition.inspection_unpack_probability, 0.0)
	(item as Node as RigidBody3D).freeze = true
	(item as Node as Node3D).global_position = Vector3(0.7, 1.2, -2.5)
	await _sync_physics()
	assert_eq(_exposure(), item.id)
	_sample()
	_step()
	assert_eq(CombatQueries.target_for(_actor), _player)
	assert_eq(agent.phase, C_CustomerAgent.Phase.INSPECTING)
#endregion
