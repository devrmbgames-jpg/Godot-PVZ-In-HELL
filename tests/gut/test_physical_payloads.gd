extends GutTest
## Catalog composition, committed break facts, throw snapshots and shared hazard execution.

var _world: World = null
var _actor: E_RigidBodyCharacter = null

const CATALOG_SCENES: Array[String] = [
	"res://content/domains/inventory/entities/bones_pickup.tscn",
	"res://content/domains/combat/entities/axe.tscn",
	"res://content/domains/combat/entities/scythe.tscn",
	"res://content/domains/combat/entities/throwing_knife.tscn",
	"res://content/domains/hazards/entities/fire_flask.tscn",
	"res://content/domains/hazards/entities/toxin_flask.tscn",
	"res://content/domains/hazards/entities/reagent_flask.tscn",
	"res://content/domains/combat/entities/holy_artifact.tscn",
	"res://content/domains/combat/entities/unholy_artifact.tscn",
	"res://content/domains/hazards/entities/acid_barrel.tscn",
	"res://content/domains/hazards/entities/fire_barrel.tscn",
	"res://content/domains/combat/entities/spiked_chains.tscn",
	"res://content/domains/inventory/entities/slave_collar.tscn",
	"res://content/domains/hazards/entities/blood_flask.tscn",
	"res://content/domains/hazards/entities/blood_barrel.tscn",
]


## Observes committed damage without mutating health.
class DamageRecorder extends Observer:
	## Published authoritative results retained for assertions only.
	var results: Array[DamageResult] = []


	#region Committed fact fixture
	## Watches terminal results only.
	func query() -> QueryBuilder:
		return q.with_all([C_Health]).on_event(DamageResult.EVENT)


	## Retains source/type/actor evidence after resolution.
	func each(_event: Variant, _entity: Entity, payload: Variant = null) -> void:
		results.append(payload as DamageResult)
	#endregion


## Retires the thrower synchronously between the two captured contact directions.
class ThrowerRetirer extends Observer:
	var _actor_reference: WeakRef = null
	var _victim_reference: WeakRef = null
	var _retired: bool = false


	#region Synchronous retirement fixture
	## Captures fixture endpoints before event registration.
	func configure(actor: Entity, victim: Entity) -> void:
		_actor_reference = weakref(actor)
		_victim_reference = weakref(victim)


	## Watches committed health facts.
	func query() -> QueryBuilder:
		return q.with_all([C_Health]).on_event(DamageResult.EVENT)


	## Removes only the actor of the first matching committed hit.
	func each(_event: Variant, _entity: Entity, payload: Variant = null) -> void:
		var result: DamageResult = payload as DamageResult
		if _retired or result.request.target != _victim_reference.get_ref():
			return
		_retired = true
		var actor: Entity = _actor_reference.get_ref() as Entity
		_world.remove_entity(actor)
		actor.free()
	#endregion


#region Native world fixture
## Matches runtime observer order: factory/emitter precede explicit source retirement.
func before_each() -> void:
	_world = World.new()
	add_child(_world)
	ECS.world = _world
	_world.add_observer(O_Damage.new())
	_world.add_observer(O_HazardSpawn.new())
	_world.add_observer(O_ToxicAreaSetup.new())
	_world.add_observer(O_BloodAreaSetup.new())
	_world.add_observer(O_ExplosionSetup.new())
	_world.add_observer(O_HazardEmitter.new())
	_world.add_observer(O_RemoveOnHealthDepleted.new())
	_world.add_observer(O_GrabLifecycle.new())
	_actor = _character(Vector3(-6.0, 0.0, 0.0))
	_actor.add_component(C_GrabControl.new())
	_actor.add_component(C_Interactor.new())
	_actor.add_component(C_Controller.new())
	_actor.add_component(C_CarryLoad.new())
	var anchor: Marker3D = Marker3D.new()
	anchor.position = Vector3(0.5, 1.0, 0.0)
	_actor.add_child(anchor)
	_actor.right_hand_slot = anchor
	var ray: RayCast3D = RayCast3D.new()
	_actor.add_child(ray)
	_actor.interaction_ray_cast = ray


## Purges registered hazards and pending native body retirement without a rendered session.
func after_each() -> void:
	_world.purge(false)
	_world.free()
	ECS.world = null
	_world = null
	_actor = null


func _character(position: Vector3, frozen: bool = true) -> E_RigidBodyCharacter:
	var body: RigidBody3D = RigidBody3D.new()
	body.set_script(E_RigidBodyCharacter)
	body.freeze = frozen
	body.gravity_scale = 0.0
	var entity: E_RigidBodyCharacter = body as Node as E_RigidBodyCharacter
	entity.component_resources = [C_Health.new(), C_ImpactInbox.new()]
	var head: Marker3D = Marker3D.new()
	head.position.y = 1.5
	body.add_child(head)
	entity.head_axis_x = head
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: CapsuleShape3D = CapsuleShape3D.new()
	shape.radius = 0.3
	shape.height = 1.7
	collision.shape = shape
	collision.position.y = 0.85
	body.add_child(collision)
	_world.add_entity(entity)
	body.global_position = position
	return entity


func _item(key: String, position: Vector3 = Vector3.ZERO) -> Entity:
	var scene: PackedScene = load("res://content/domains/hazards/entities/%s.tscn" % key)
	var item: Entity = scene.instantiate() as Entity
	EntityCompositionFixture.register(_world, item)
	var body: RigidBody3D = item as Node as RigidBody3D
	body.gravity_scale = 0.0
	body.global_position = position
	return item


func _break(item: Entity) -> void:
	var request: DamageRequest = DamageRequest.new()
	request.source = _actor
	request.instigator = _actor
	request.target = item
	request.amount = 1000.0
	request.damage_type = DamageRequest.Type.MELEE
	assert_true(DamageRequestService.submit(request))


func _throw_flask(item: Entity) -> void:
	_actor.interaction_ray_cast.global_position = (
		(item as Node as Node3D).global_position + Vector3.BACK
	)
	await get_tree().physics_frame
	assert_true(GrabService.try_pickup(_actor, item, C_Grabbable.HoldSlot.RIGHT_HAND))
	(_actor.get_component(C_Controller) as C_Controller).direction_look = Vector3.FORWARD
	GrabService.throw(_actor, item)
	assert_eq(ThrowContext.relationship(item).target, _actor)
	await get_tree().physics_frame
#endregion


#region Bounded full-catalog physical smoke
func _catalog_body(path: String, position: Vector3) -> Entity:
	var scene: PackedScene = load(path) as PackedScene
	var entity: Entity = scene.instantiate() as Entity
	EntityCompositionFixture.register(_world, entity)
	(entity as Node as Node3D).global_position = position
	return entity


## Every authored body falls and actually contacts native collision geometry in a bounded run.
func test_full_catalog_native_gravity_and_floor_contact_smoke() -> void:
	var floor: StaticBody3D = StaticBody3D.new()
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(58.0, 0.5, 12.0)
	collision.shape = shape
	floor.add_child(collision)
	_world.add_child(floor)
	floor.position = Vector3(0.0, -0.25, -12.0)
	var references: Array[WeakRef] = []
	var catalog_ids: Array[String] = []
	var contacted: Dictionary[String, bool] = { }
	for index: int in CATALOG_SCENES.size():
		var entity: Entity = _catalog_body(
			CATALOG_SCENES[index],
			Vector3(-24.5 + index * 3.5, 4.0, -12.0),
		)
		var body: RigidBody3D = entity as Node as RigidBody3D
		assert_not_null(body, CATALOG_SCENES[index])
		assert_false(body.freeze)
		assert_gt(body.mass, 0.0)
		assert_eq(body.gravity_scale, 1.0, "Smoke uses authored gravity")
		assert_not_null(entity.get_component(C_ImpactInbox))
		references.append(weakref(entity))
		catalog_ids.append(entity.id)
	for frame: int in 4:
		await get_tree().physics_frame
	for reference: WeakRef in references:
		var body: RigidBody3D = reference.get_ref() as RigidBody3D
		assert_lt(body.global_position.y, 4.0)
		assert_lt(body.linear_velocity.y, 0.0)
	_world.add_system(S_Impact.new())
	_world.add_system(S_Explosion.new())
	for frame: int in 120:
		await get_tree().physics_frame
		for reference: WeakRef in references:
			var entity: Entity = reference.get_ref() as Entity
			if not EntityAvailability.contains(entity, _world):
				continue
			var inbox: C_ImpactInbox = entity.get_component(C_ImpactInbox) as C_ImpactInbox
			for contact: PhysicsContact in inbox.contacts:
				if contact.body_a == floor or contact.body_b == floor:
					contacted[entity.id] = true
		_world.process(1.0 / 60.0)
	assert_eq(
		contacted.size(),
		CATALOG_SCENES.size(),
		"Every catalog body produced native floor contacts",
	)
	for index: int in catalog_ids.size():
		assert_true(
			contacted.has(catalog_ids[index]),
			"Native floor contact: %s" % CATALOG_SCENES[index],
		)
	var survivors: int = 0
	for reference: WeakRef in references:
		var entity: Entity = reference.get_ref() as Entity
		if EntityAvailability.contains(entity, _world):
			var body: RigidBody3D = entity as Node as RigidBody3D
			assert_true(body.global_position.is_finite())
			assert_true(body.linear_velocity.is_finite())
			assert_gt(body.global_position.y, -0.25, "Body must remain above the solid floor")
			survivors += 1
	assert_gt(survivors, 0, "Inert items survive while destructible payloads may break")


## All authored grip capabilities acquire/release through R_HeldBy and preserve real throw impulse.
func test_full_catalog_native_pickup_release_and_throw_smoke() -> void:
	_actor.hold_anchor = _actor.head_axis_x
	_actor.add_component(C_Strength.new())
	var hand_count: int = 0
	var carry_count: int = 0
	for path: String in CATALOG_SCENES:
		var entity: Entity = _catalog_body(path, _actor.right_hand_slot.global_position)
		var body: RigidBody3D = entity as Node as RigidBody3D
		body.gravity_scale = 0.0
		var grip: C_Grabbable = entity.get_component(C_Grabbable) as C_Grabbable
		if grip == null:
			assert_true(entity.has_component(C_InventoryItem), "Stack pickup has no hand grip")
			_world.remove_entity(entity)
			entity.free()
			continue
		var slot: C_Grabbable.HoldSlot = C_Grabbable.HoldSlot.RIGHT_HAND
		if grip.allowed_hand_slots == 0:
			slot = C_Grabbable.HoldSlot.CARRY
			carry_count += 1
		else:
			hand_count += 1
		_actor.interaction_ray_cast.global_position = body.global_position + Vector3.BACK
		await get_tree().physics_frame
		assert_true(GrabService.try_pickup(_actor, entity, slot), path)
		assert_same(GrabQueries.held_relationship(entity).target, _actor)
		body.linear_velocity = Vector3(0.0, 0.0, -2.0)
		GrabReleaseService.release(_actor, entity)
		assert_null(GrabQueries.held_relationship(entity))
		assert_eq(body.linear_velocity, Vector3(0.0, 0.0, -2.0), "Release preserves inertia")
		_actor.interaction_ray_cast.global_position = body.global_position + Vector3.BACK
		await get_tree().physics_frame
		assert_true(GrabService.try_pickup(_actor, entity, slot), path)
		(_actor.get_component(C_Controller) as C_Controller).direction_look = Vector3.FORWARD
		GrabService.throw(_actor, entity)
		assert_null(GrabQueries.held_relationship(entity))
		if entity.has_component(C_ThrowDamage):
			assert_not_null(ThrowContext.relationship(entity), path)
			assert_same(ThrowContext.relationship(entity).target, _actor)
		else:
			assert_null(ThrowContext.relationship(entity), "Inert throw has no damage attribution")
		await get_tree().physics_frame
		assert_lt(body.linear_velocity.z, -2.0, "Native impulse must propel the released body")
		assert_false(body.freeze)
		_world.remove_entity(entity)
		entity.free()
	assert_eq(hand_count, 11)
	assert_eq(carry_count, 3)
#endregion


#region Authored catalog and break boundary
## Five payloads share explicit break policy and retain physical-only storage semantics.
func test_payload_catalog_is_physical_destructible_and_uses_shared_capabilities() -> void:
	for key: String in [
		"fire_flask",
		"toxin_flask",
		"reagent_flask",
		"acid_barrel",
		"fire_barrel",
		"blood_flask",
		"blood_barrel",
	]:
		var item: Entity = _item(key)
		var body: RigidBody3D = item as Node as RigidBody3D
		var large: bool = key.ends_with("barrel")
		var grip: C_Grabbable = item.get_component(C_Grabbable) as C_Grabbable
		var catalog: C_InventoryItem = item.get_component(C_InventoryItem) as C_InventoryItem
		assert_false(body.freeze)
		assert_not_null(item.get_component(C_ImpactInbox))
		assert_not_null(item.get_component(C_ImpactReceiver))
		assert_not_null(item.get_component(C_RemoveOnHealthDepleted))
		assert_not_null((item.get_component(C_HazardEmitter) as C_HazardEmitter).hazard_scene)
		assert_eq((item.get_component(C_Health) as C_Health).current, 60.0 if large else 5.0)
		assert_eq(grip.allowed_hand_slots, 0 if large else 6)
		assert_eq(catalog.definition.categories, DEF_InventoryItem.Category.REAGENT)
		assert_true(catalog.definition.requires_world_body())
		assert_false(InventoryService.can_transfer(item, _actor))
		_world.remove_entity(item)


## A terminal health fact emits one native hazard with stable origin before source retirement.
func test_each_payload_breaks_once_and_preserves_actor_origin_and_effect_type() -> void:
	var keys: Array[String] = [
		"fire_flask",
		"toxin_flask",
		"reagent_flask",
		"acid_barrel",
		"fire_barrel",
	]
	var expected_types: Array[int] = [
		DamageRequest.Type.FIRE,
		DamageRequest.Type.TOXIC,
		DamageRequest.Type.IMPACT,
		DamageRequest.Type.ACID,
		DamageRequest.Type.FIRE,
	]
	for index: int in keys.size():
		var item: Entity = _item(keys[index])
		var origin_id: String = item.id
		var emitter: C_HazardEmitter = item.get_component(C_HazardEmitter) as C_HazardEmitter
		_break(item)
		var effects: Array[Entity] = _world.query.with_all([C_Hazard]).execute()
		assert_eq(effects.size(), index + 1)
		var effect: Entity = null
		for candidate: Entity in effects:
			if (candidate.get_component(C_Hazard) as C_Hazard).origin_id == origin_id:
				effect = candidate
				break
		assert_not_null(effect, "Native query ordering does not imply creation order")
		if effect == null:
			continue
		var hazard: C_Hazard = effect.get_component(C_Hazard) as C_Hazard
		assert_eq(hazard.origin_id, origin_id)
		assert_eq(hazard.instigator_id, _actor.id)
		assert_eq(hazard.instigator, _actor)
		assert_true(emitter.fired)
		assert_eq(emitter.sequence, 1)
		assert_false(EntityAvailability.contains(item, _world))
		assert_false(HazardEmitter.activate(item, _actor))
		var toxin: DEF_ToxicArea = hazard.definition as DEF_ToxicArea
		if toxin != null:
			assert_eq(toxin.damage_type, expected_types[index])
			assert_not_null(effect.get_component(C_ToxicArea))
		else:
			assert_eq((hazard.definition as DEF_Explosion).damage_type, expected_types[index])
			assert_not_null(effect.get_component(C_Explosion))
			assert_null(effect.get_component(C_ToxicArea))
		assert_eq(_world.query.with_all([C_Hazard]).execute().size(), index + 1)


## Both blood payloads spawn one attributed native stimulus with no direct health behavior.
func test_blood_payloads_spawn_non_damaging_zones_with_larger_barrel_tuning() -> void:
	_world.add_system(S_ToxicArea.new())
	_world.add_system(S_HazardLifetime.new())
	var recorder: DamageRecorder = DamageRecorder.new()
	_world.add_observer(recorder)
	var flask_profile: DEF_BloodArea = load(
		"res://content/domains/hazards/definitions/def_blood_spill.tres"
	) as DEF_BloodArea
	var barrel_profile: DEF_BloodArea = load(
		"res://content/domains/hazards/definitions/def_blood_pool.tres"
	) as DEF_BloodArea
	assert_gt(barrel_profile.radius, flask_profile.radius)
	assert_gt(barrel_profile.lifetime_seconds, flask_profile.lifetime_seconds)
	for key: String in ["blood_flask", "blood_barrel"]:
		var item: Entity = _item(key)
		var source_id: String = item.id
		_break(item)
		var effects: Array[Entity] = _world.query.with_all([C_Hazard, C_BloodArea]).execute()
		assert_eq(effects.size(), 1)
		var effect: E_BloodArea = effects[0] as E_BloodArea
		var hazard: C_Hazard = effect.get_component(C_Hazard) as C_Hazard
		var profile: DEF_BloodArea = hazard.definition as DEF_BloodArea
		assert_eq(hazard.origin_id, source_id)
		assert_eq(hazard.instigator_id, _actor.id)
		assert_eq(hazard.instigator, _actor)
		assert_false(EntityAvailability.contains(item, _world))
		assert_false(effect.has_component(C_ToxicArea))
		assert_false(effect.has_component(C_Explosion))
		assert_eq((effect.get_shape().shape as SphereShape3D).radius, profile.radius)
		assert_eq((effect.get_visual().mesh as CylinderMesh).top_radius, profile.radius)
		assert_eq(
			(effect.get_visual().material_override as StandardMaterial3D).albedo_color,
			Color("#791318"),
		)
		_actor.global_position = Vector3(0.5, 0.0, 0.0)
		for frame: int in 3:
			await get_tree().physics_frame
			await get_tree().process_frame
		assert_true(effect.get_area().overlaps_body(_actor as Node as PhysicsBody3D))
		recorder.results.clear()
		_world.process(1.0)
		assert_eq((_actor.get_component(C_Health) as C_Health).current, 100.0)
		assert_true(recorder.results.is_empty(), "Blood issues neither damage nor heal requests")
		var lifetime: C_HazardLifetime = effect.get_component(C_HazardLifetime) as C_HazardLifetime
		assert_eq(lifetime.remaining_seconds, profile.lifetime_seconds - 1.0)
		_world.process(lifetime.remaining_seconds)
		assert_true(_world.query.with_all([C_BloodArea]).execute().is_empty())
		assert_true(recorder.results.is_empty())


## A collar has real inert handheld value without accidental melee or break effects.
func test_slave_collar_is_a_physical_valuable_without_extra_effects() -> void:
	var scene: PackedScene = load("res://content/domains/inventory/entities/slave_collar.tscn")
	var item: Entity = scene.instantiate() as Entity
	EntityCompositionFixture.register(_world, item)
	assert_true((item as Node) is RigidBody3D)
	assert_false((item as Node as RigidBody3D).freeze)
	assert_not_null(item.get_component(C_Grabbable))
	assert_not_null(item.get_component(C_ImpactInbox))
	assert_null(item.get_component(C_MeleeWeapon))
	assert_null(item.get_component(C_HazardEmitter))
	var catalog: C_InventoryItem = item.get_component(C_InventoryItem) as C_InventoryItem
	assert_eq(catalog.definition.categories, DEF_InventoryItem.Category.VALUABLE)
	assert_true(catalog.definition.requires_world_body())
#endregion


#region Contact attribution and native hazard execution
## A real Jolt contact from a released throw breaks the flask and registers one attributed hazard.
func test_native_thrown_flask_floor_contact_spawns_one_attributed_fire_hazard() -> void:
	await _check_native_thrown_flask("fire_flask")


## Blood uses the identical native throw/break boundary while retaining a non-damaging profile.
func test_native_thrown_blood_flask_spawns_one_attributed_non_damaging_zone() -> void:
	await _check_native_thrown_flask("blood_flask")


func _check_native_thrown_flask(key: String) -> void:
	_world.add_system(S_Impact.new())
	var floor: StaticBody3D = StaticBody3D.new()
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(6.0, 0.5, 6.0)
	collision.shape = shape
	floor.add_child(collision)
	_world.add_child(floor)
	floor.global_position = Vector3(-5.5, -0.25, 0.0)
	var item: Entity = _item(key, _actor.right_hand_slot.global_position)
	_actor.interaction_ray_cast.global_position = (
		(item as Node as Node3D).global_position + Vector3.BACK
	)
	await get_tree().physics_frame
	assert_true(GrabService.try_pickup(_actor, item, C_Grabbable.HoldSlot.RIGHT_HAND))
	(_actor.get_component(C_Controller) as C_Controller).direction_look = Vector3.DOWN
	GrabService.throw(_actor, item)
	var origin_id: String = item.id
	assert_eq(ThrowContext.relationship(item).target, _actor)
	var effects: Array[Entity] = []
	for frame: int in 90:
		await get_tree().physics_frame
		await get_tree().process_frame
		_world.process(1.0 / 60.0)
		effects = _world.query.with_all([C_Hazard]).execute()
		if not effects.is_empty():
			break
	assert_eq(effects.size(), 1, "Bounded native Jolt throw must actually break against the floor")
	if effects.is_empty():
		return
	var hazard: C_Hazard = effects[0].get_component(C_Hazard) as C_Hazard
	assert_eq(hazard.origin_id, origin_id)
	assert_eq(hazard.instigator_id, _actor.id)
	if key == "blood_flask":
		assert_true(hazard.definition is DEF_BloodArea)
		assert_true(effects[0].has_component(C_BloodArea))
		assert_false(effects[0].has_component(C_ToxicArea))
	else:
		assert_eq((hazard.definition as DEF_ToxicArea).damage_type, DamageRequest.Type.FIRE)
	for frame: int in 6:
		await get_tree().physics_frame
		_world.process(1.0 / 60.0)
	assert_eq(_world.query.with_all([C_Hazard]).execute().size(), 1)
	assert_eq((_actor.get_component(C_Health) as C_Health).current, 100.0)


## Both contact directions preserve the thrower even when the outgoing hit consumes R_ThrownBy.
func test_thrown_flask_break_keeps_attribution_in_both_contact_orders() -> void:
	_world.add_system(S_Impact.new())
	var victim: Entity = _character(Vector3(10.0, 0.0, -10.0))
	var receiver: C_ImpactReceiver = C_ImpactReceiver.new()
	receiver.profile = DEF_ImpactProfile.new()
	receiver.profile.damage_per_joule = 0.1
	receiver.profile.absorption_joules = 0.0
	victim.add_component(receiver)
	for reverse: bool in [false, true]:
		var item: Entity = _item("fire_flask", _actor.right_hand_slot.global_position)
		await _throw_flask(item)
		var contact: PhysicsContact = PhysicsContact.new()
		contact.body_a = (victim if reverse else item) as Node as PhysicsBody3D
		contact.body_b = (item if reverse else victim) as Node as PhysicsBody3D
		contact.tick = Engine.get_physics_frames()
		contact.normal_speed = 20.0
		contact.normal_impulse = 20.0
		var origin_id: String = item.id
		(item.get_component(C_ImpactInbox) as C_ImpactInbox).contacts.append(contact)
		_world.process(1.0 / 60.0)
		assert_false(EntityAvailability.contains(item, _world))
		var matched: int = 0
		for effect: Entity in _world.query.with_all([C_Hazard]).execute():
			var hazard: C_Hazard = effect.get_component(C_Hazard) as C_Hazard
			if hazard.origin_id == origin_id:
				matched += 1
				assert_eq(hazard.instigator_id, _actor.id)
				assert_eq(hazard.instigator, _actor)
		assert_eq(matched, 1)


## A thrower's free during the outgoing hit cannot invalidate the incoming break attribution.
func test_contact_snapshot_keeps_stable_thrower_id_after_synchronous_actor_free() -> void:
	_world.add_system(S_Impact.new())
	var victim: Entity = _character(Vector3(10.0, 0.0, -10.0))
	var receiver: C_ImpactReceiver = C_ImpactReceiver.new()
	receiver.profile = DEF_ImpactProfile.new()
	receiver.profile.damage_per_joule = 0.1
	receiver.profile.absorption_joules = 0.0
	victim.add_component(receiver)
	var retire: ThrowerRetirer = ThrowerRetirer.new()
	retire.configure(_actor, victim)
	_world.add_observer(retire)
	var item: Entity = _item("fire_flask", _actor.right_hand_slot.global_position)
	await _throw_flask(item)
	var actor_id: String = _actor.id
	var origin_id: String = item.id
	var contact: PhysicsContact = PhysicsContact.new()
	contact.body_a = item as Node as PhysicsBody3D
	contact.body_b = victim as Node as PhysicsBody3D
	contact.tick = Engine.get_physics_frames()
	contact.normal_speed = 20.0
	contact.normal_impulse = 20.0
	(item.get_component(C_ImpactInbox) as C_ImpactInbox).contacts.append(contact)
	_world.process(1.0 / 60.0)
	assert_false(is_instance_valid(_actor))
	var effect: Entity = _world.query.with_all([C_Hazard]).execute_one()
	assert_not_null(effect)
	var hazard: C_Hazard = effect.get_component(C_Hazard) as C_Hazard
	assert_eq(hazard.origin_id, origin_id)
	assert_eq(hazard.instigator_id, actor_id)
	assert_null(hazard.instigator)
	var recorder: DamageRecorder = DamageRecorder.new()
	_world.add_observer(recorder)
	HazardDamage.submit(effect, hazard, victim, 8.0, DamageRequest.Type.FIRE)
	assert_eq(recorder.results.size(), 1)
	assert_eq(recorder.results[0].request.instigator_id, actor_id)
	assert_null(recorder.results[0].request.instigator)
	assert_eq(recorder.results[0].applied_amount, 8.0)


## Native area overlap carries FIRE damage and copies source veto through producer retirement.
func test_fire_spill_ticks_through_damage_authority_and_preserves_source_veto() -> void:
	_world.add_system(S_ToxicArea.new())
	var victim: Entity = _character(Vector3(0.7, 0.0, 0.0))
	victim.add_component(C_Living.new())
	var item: Entity = _item("fire_flask")
	_break(item)
	for frame: int in 3:
		await get_tree().physics_frame
	_world.process(1.0)
	assert_eq((victim.get_component(C_Health) as C_Health).current, 92.0)
	_world.process(1.0)
	assert_eq((victim.get_component(C_Health) as C_Health).current, 84.0)
	var old_effect: Entity = _world.query.with_all([C_Hazard]).execute_one()
	_world.remove_entity(old_effect)
	var guarded: Entity = _item("fire_flask")
	guarded.add_component(C_NoDamage.new())
	_break(guarded)
	var effect: Entity = _world.query.with_all([C_Hazard]).execute_one()
	assert_true(effect.has_component(C_NoDamage))
	for frame: int in 3:
		await get_tree().physics_frame
	_world.process(1.0)
	assert_eq((victim.get_component(C_Health) as C_Health).current, 84.0)


## Explosion presentation/impulse are native; health uses authored IMPACT and resolves once.
func test_reagent_blast_applies_native_impulse_with_impact_health_damage_once() -> void:
	_world.add_system(S_Explosion.new())
	var recorder: DamageRecorder = DamageRecorder.new()
	_world.add_observer(recorder)
	var victim: Entity = _character(Vector3(0.75, 0.0, 0.0), false)
	var body: RigidBody3D = victim as Node as RigidBody3D
	var item: Entity = _item("reagent_flask")
	await get_tree().physics_frame
	_break(item)
	_world.process(1.0 / 60.0)
	var health_after: float = (victim.get_component(C_Health) as C_Health).current
	assert_lt(health_after, 100.0)
	var blast_results: int = 0
	for result: DamageResult in recorder.results:
		if result.request.target == victim:
			blast_results += 1
			assert_eq(result.request.damage_type, DamageRequest.Type.IMPACT)
			assert_eq(result.request.instigator_id, _actor.id)
			assert_eq(result.outcome, DamageResult.Outcome.APPLIED)
	assert_eq(blast_results, 1)
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_gt(body.linear_velocity.length(), 0.0)
	_world.process(1.0 / 60.0)
	assert_eq((victim.get_component(C_Health) as C_Health).current, health_after)
#endregion
