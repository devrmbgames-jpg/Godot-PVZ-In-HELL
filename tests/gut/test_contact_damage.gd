extends GutTest
## Contact damage through native inboxes, episode boundaries and committed health facts.

var _world: World = null
var _source: Entity = null
var _victim: Entity = null
var _actor: E_RigidBodyCharacter = null
var _recorder: DamageRecorder = null


## Collects committed receipts without controlling health.
class DamageRecorder extends Observer:
	## Terminal facts retained only by this fixture.
	var results: Array[DamageResult] = []


	#region Committed fact fixture
	## Subscribes to authoritative health results.
	func query() -> QueryBuilder:
		return q.with_all([C_Health]).on_event(DamageResult.EVENT)


	## Records the published receipt for source/type/actor checks.
	func each(_event: Variant, _entity: Entity, payload: Variant = null) -> void:
		results.append(payload as DamageResult)
	#endregion


#region Native source and receiver fixture
## Composes an authored chain and two physical health owners, then registers the real impact owner.
func before_each() -> void:
	_world = World.new()
	add_child(_world)
	ECS.world = _world
	_world.add_observer(O_Damage.new())
	_world.add_observer(O_GrabLifecycle.new())
	_recorder = DamageRecorder.new()
	_world.add_observer(_recorder)
	_actor = _character(Vector3(-5.0, 0.0, 0.0))
	_actor.add_component(C_GrabControl.new())
	_actor.add_component(C_CarryLoad.new())
	_actor.add_component(C_Interactor.new())
	_actor.add_component(C_Controller.new())
	var anchor: Marker3D = Marker3D.new()
	anchor.position = Vector3(0.5, 1.0, -1.0)
	_actor.add_child(anchor)
	_actor.right_hand_slot = anchor
	var ray: RayCast3D = RayCast3D.new()
	_actor.add_child(ray)
	_actor.interaction_ray_cast = ray
	_victim = _character(Vector3(10.0, 0.0, 0.0))
	var scene: PackedScene = load("res://content/domains/combat/entities/spiked_chains.tscn")
	_source = scene.instantiate() as Entity
	EntityCompositionFixture.register(_world, _source)
	var body: RigidBody3D = _source as Node as RigidBody3D
	body.gravity_scale = 0.0
	body.global_position = Vector3(0.0, 4.0, 0.0)
	_world.add_system(S_Impact.new())


## Purges native entities and the isolated World.
func after_each() -> void:
	_world.purge(false)
	_world.free()
	ECS.world = null
	_world = null
	_source = null
	_victim = null
	_actor = null
	_recorder = null


func _character(position: Vector3) -> E_RigidBodyCharacter:
	var body: RigidBody3D = RigidBody3D.new()
	body.set_script(E_RigidBodyCharacter)
	body.freeze = true
	var entity: E_RigidBodyCharacter = body as Node as E_RigidBodyCharacter
	entity.component_resources = [C_Health.new(), C_ImpactInbox.new()]
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


func _contact(target: Entity, speed: float = 2.0, impulse: float = 1.0) -> PhysicsContact:
	var contact: PhysicsContact = PhysicsContact.new()
	contact.body_a = _source as Node as PhysicsBody3D
	contact.body_b = target as Node as PhysicsBody3D
	contact.tick = Engine.get_physics_frames()
	contact.normal_speed = speed
	contact.normal_impulse = impulse
	return contact


func _deliver(contact: PhysicsContact) -> void:
	(_source.get_component(C_ImpactInbox) as C_ImpactInbox).contacts.append(contact)
	_world.process(1.0 / 60.0)


func _separate(contact: PhysicsContact) -> void:
	(_source.get_component(C_ImpactInbox) as C_ImpactInbox).separations.append(contact)
	_world.process(1.0 / 60.0)
	await get_tree().physics_frame
#endregion


#region Cutting capability and episode boundaries
## Native chain composition keeps physical storage and separates cutting from impact protection.
func test_spikes_damage_once_without_impact_receiver_and_rearm_only_after_separation() -> void:
	var item: C_InventoryItem = _source.get_component(C_InventoryItem) as C_InventoryItem
	assert_eq(item.definition.categories, DEF_InventoryItem.Category.VALUABLE)
	assert_true(item.definition.requires_world_body())
	assert_false((_source as Node as RigidBody3D).freeze)
	assert_null(_victim.get_component(C_ImpactReceiver))
	var protection: C_ImpactProtection = C_ImpactProtection.new()
	protection.tier = ImpactResult.Severity.STRONG
	_victim.add_component(protection)
	var contact: PhysicsContact = _contact(_victim)
	_deliver(contact)
	assert_eq((_victim.get_component(C_Health) as C_Health).current, 88.0)
	assert_eq(_recorder.results.size(), 1)
	assert_eq(_recorder.results[0].request.damage_type, DamageRequest.Type.MELEE)
	assert_eq(_recorder.results[0].request.source, _source)
	_deliver(_contact(_victim, 0.0, 1.0))
	_deliver(_contact(_victim, 20.0, 20.0))
	assert_eq((_victim.get_component(C_Health) as C_Health).current, 88.0)
	assert_eq(_recorder.results.size(), 1)
	await _separate(contact)
	_deliver(_contact(_victim))
	assert_eq((_victim.get_component(C_Health) as C_Health).current, 76.0)
	assert_eq(_recorder.results.size(), 2)


## An initially resting contact cannot start periodic damage when reports continue.
func test_resting_contact_requires_a_new_physical_episode_before_cutting() -> void:
	var contact: PhysicsContact = _contact(_victim, 0.0, 1.0)
	_deliver(contact)
	_deliver(_contact(_victim))
	assert_eq((_victim.get_component(C_Health) as C_Health).current, 100.0)
	assert_eq(_recorder.results.size(), 0)
	await _separate(contact)
	_deliver(_contact(_victim))
	assert_eq((_victim.get_component(C_Health) as C_Health).current, 88.0)


## An intentional throw uses live attribution once; source veto remains on the damage authority.
func test_throw_attribution_source_veto_and_repeated_contacts_share_the_same_boundary() -> void:
	_source.add_component(C_NoDamage.new())
	ThrowContext.arm(_source, _actor)
	await get_tree().physics_frame
	_deliver(_contact(_victim))
	assert_eq(_recorder.results.size(), 1)
	var result: DamageResult = _recorder.results[0]
	assert_eq(result.request.instigator, _actor)
	assert_eq(result.request.instigator_id, _actor.id)
	assert_eq(result.outcome, DamageResult.Outcome.BLOCKED)
	assert_eq(result.applied_amount, 0.0)
	assert_null(ThrowContext.relationship(_source))
	_deliver(_contact(_victim, 20.0, 20.0))
	assert_eq(_recorder.results.size(), 1)
	assert_eq((_victim.get_component(C_Health) as C_Health).current, 100.0)


## A real grip excludes its holder while attributing contact with another receiver to that holder.
func test_held_spikes_never_cut_holder_and_attribute_another_contact() -> void:
	var body: RigidBody3D = _source as Node as RigidBody3D
	body.global_position = _actor.right_hand_slot.global_position
	_actor.interaction_ray_cast.global_position = body.global_position + Vector3.BACK
	await get_tree().physics_frame
	assert_true(GrabService.try_pickup(_actor, _source, C_Grabbable.HoldSlot.RIGHT_HAND))
	_deliver(_contact(_actor, 20.0, 20.0))
	assert_eq((_actor.get_component(C_Health) as C_Health).current, 100.0)
	assert_eq(_recorder.results.size(), 0)
	_deliver(_contact(_victim))
	assert_eq((_victim.get_component(C_Health) as C_Health).current, 88.0)
	assert_eq(_recorder.results[0].request.instigator, _actor)
	GrabReleaseService.release(_actor, _source)
	assert_false(body.freeze)


## Invalid tuning and non-finite or stationary contacts never produce authored health damage.
func test_contact_qualification_rejects_nonfinite_stationary_and_invalid_tuning() -> void:
	var config: C_ContactDamage = C_ContactDamage.new()
	assert_true(ContactDamageRules.qualifies(config, _contact(_victim)))
	assert_false(ContactDamageRules.qualifies(config, _contact(_victim, 0.0, 1.0)))
	assert_false(ContactDamageRules.qualifies(config, _contact(_victim, 2.0, 0.0)))
	assert_false(ContactDamageRules.qualifies(config, _contact(_victim, INF, 1.0)))
	assert_false(ContactDamageRules.qualifies(config, _contact(_victim, 2.0, NAN)))
	config.damage = -1.0
	assert_false(ContactDamageRules.qualifies(config, _contact(_victim)))
	config.damage = 12.0
	config.minimum_speed = NAN
	assert_false(ContactDamageRules.qualifies(config, _contact(_victim)))
#endregion


#region Bounded native contact smoke
## Real Jolt capture applies one cutting receipt and remains harmless once resting.
func test_native_chain_collision_cuts_once_and_does_not_replay_while_resting() -> void:
	(_victim as Node as Node3D).global_position = Vector3.ZERO
	var body: RigidBody3D = _source as Node as RigidBody3D
	body.global_position = Vector3(0.0, 3.0, 0.0)
	body.linear_velocity = Vector3.DOWN * 8.0
	for frame: int in 90:
		await get_tree().physics_frame
		await get_tree().process_frame
		_world.process(1.0 / 60.0)
		if not _recorder.results.is_empty():
			break
	assert_eq(_recorder.results.size(), 1, "Native collision must reach the contact damage owner")
	assert_eq((_victim.get_component(C_Health) as C_Health).current, 88.0)
	for frame: int in 12:
		await get_tree().physics_frame
		_world.process(1.0 / 60.0)
	assert_eq(_recorder.results.size(), 1)
	assert_eq((_victim.get_component(C_Health) as C_Health).current, 88.0)
#endregion
