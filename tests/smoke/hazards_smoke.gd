extends Node3D
## User-run deterministic hazard contract fixture; no main level, delivery or package dependency.

const FIXTURE_LAYER: int = 4
const SHAPE_RADIUS: float = 0.2
const GROUP: String = "HazardSmoke"

var _world: World = null
var _spawned: Array[Entity] = []
var _last_damage: DamageResult = null


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_setup_world()
	await _toxic_contract()
	await _follow_and_reset_contract()
	await _package_adapter_contract()
	await _explosion_contract()
	await _blocked_explosion_contract()
	await _short_chain_contract()
	_reset(true)
	assert(_effects().is_empty(), "All hazard registrations must be removed")
	_world.queue_free()
	ECS.world = null
	await get_tree().process_frame
	print("R09 independent hazards smoke PASS")
	get_tree().quit()


func _setup_world() -> void:
	_world = World.new()
	add_child(_world)
	ECS.world = _world
	var processors: Array[System] = [
		S_HazardFollow.new(),
		S_ToxicArea.new(),
		S_Explosion.new(),
		S_HazardLifetime.new(),
	]
	for processor: System in processors:
		processor.group = GROUP
	_world.add_systems(processors, true)
	var observers: Array[Observer] = [
		O_Damage.new(),
		O_HazardSpawn.new(),
		O_HazardEmitter.new(),
		O_ToxicAreaSetup.new(),
		O_ExplosionSetup.new(),
		O_HazardReset.new(),
		O_PackageHazardSetup.new(),
		O_PackageHazard.new(),
	]
	_world.add_observers(observers)

	var spawn_probe: SpawnProbe = SpawnProbe.new()
	spawn_probe.received = _on_spawned
	_world.add_observer(spawn_probe)
	var damage_probe: DamageProbe = DamageProbe.new()
	damage_probe.received = _on_damage
	_world.add_observer(damage_probe)


func _toxic_contract() -> void:
	var profile: DEF_ToxicArea = _toxic(0.75)
	var origin: Entity = _body(Vector3.ZERO, false)
	var victim: Entity = _body(Vector3(0.5, 0, 0))
	var prop: Entity = _body(Vector3(-0.5, 0, 0), true, false)
	var outside: Entity = _body(Vector3(8, 0, 0))
	var request: HazardSpawnRequest = _request(profile, Vector3.ZERO, "toxic-a", origin)
	request.instigator = origin
	assert(HazardSpawnService.submit(request))
	assert(HazardSpawnService.submit(request))
	assert(_effects().size() == 1, "Factory deduplicates request ID")
	assert(HazardSpawnService.submit(_request(profile, Vector3.ZERO, "toxic-b")))
	assert(_effects().size() == 2, "Independent volumes have no global cooldown")
	var actor_id: String = origin.id
	_world.remove_entity(origin)
	await _settle()

	await _tick(0.125)
	assert(_hp(victim) == 100.0, "No damage before a complete interval")
	await _tick(0.125)
	assert(_hp(victim) == 90.0, "Each zone contributes one tick")
	assert(_hp(prop) == 100.0 and _hp(outside) == 100.0, "Eligibility and radius apply")
	var first_hazard: C_Hazard = _spawned[0].get_component(C_Hazard) as C_Hazard
	assert(first_hazard.instigator_id == actor_id, "Deleted initiator retains stable attribution")
	assert(_last_damage.request.source.has_component(C_Hazard))
	assert(_last_damage.request.damage_type == DamageRequest.Type.TOXIC)
	await _tick(0.25)
	assert(_hp(victim) == 80.0)
	_world.disable_entity(_spawned[0])
	await _tick(0.25)
	assert(_hp(victim) == 75.0, "Disabled effect cannot tick")
	assert(_effects().is_empty(), "Lifetime and disable both clean up")

	var blocked_origin: Entity = _body(Vector3.ZERO, false, false, false, [C_NoDamage.new()])
	var blocked: HazardSpawnRequest = _request(
		_toxic(1.0),
		Vector3.ZERO,
		"toxic-blocked",
		blocked_origin,
	)
	assert(HazardSpawnService.submit(blocked))
	_world.remove_entity(blocked_origin)
	await _settle()
	await _tick(0.25)
	assert(_hp(victim) == 75.0, "Origin C_NoDamage survives origin removal")
	assert(_last_damage.outcome == DamageResult.Outcome.BLOCKED)
	_reset(true)


func _follow_and_reset_contract() -> void:
	var definition: DEF_ToxicArea = _toxic(10.0)
	definition.ownership = DEF_Hazard.Ownership.FollowOrigin
	var emitter: C_HazardEmitter = C_HazardEmitter.new()
	emitter.definition = definition
	var customer: Entity = _body(Vector3(20, 0, 0), false, false, false, [emitter])
	assert(not customer.has_component(C_Package))
	assert(HazardEmitter.activate(customer))
	assert(not HazardEmitter.activate(customer), "Producer one-shot guard")
	var effect: Entity = _spawned.back()
	var customer_node: Node3D = customer as Node as Node3D
	customer_node.position.x += 2.0
	await _tick(0.01)
	var effect_node: Node3D = effect as Node as Node3D
	assert(effect_node.global_position.is_equal_approx(customer_node.global_position))
	_world.remove_entity(customer)
	await _tick(0.01)
	assert(EntityAvailability.contains(effect, _world) and not effect.has_component(C_HazardFollow))

	definition = _toxic(10.0)
	definition.ownership = DEF_Hazard.Ownership.FollowOrigin
	definition.owner_loss = DEF_Hazard.OwnerLoss.Despawn
	var owner: Entity = _body(Vector3(24, 0, 0), false)
	assert(
		HazardSpawnService.submit(_request(definition, Vector3(24, 0, 0), "follow-despawn", owner))
	)
	var attached: Entity = _spawned.back()
	_world.remove_entity(owner)
	await _tick(0.01)
	assert(not EntityAvailability.contains(attached, _world))

	definition = _toxic(10.0)
	definition.persistent = true
	assert(HazardSpawnService.submit(_request(definition, Vector3(26, 0, 0), "persistent")))
	_reset(false)
	assert(_effects().size() == 1, "Night reset retains only persistent hazards")
	_reset(true)
	assert(_effects().is_empty())


func _package_adapter_contract() -> void:
	var identity: C_Package = C_Package.new()
	identity.package_id = "hazard-fixture-package"
	identity.definition = DEF_Package.new()
	identity.definition.hazard = DEF_Package.Hazard.TOXIC
	identity.definition.hazard_effect = _toxic(10.0)
	var package_state: C_PackageState = C_PackageState.new()
	var package: Entity = _body(Vector3(30, 0, 0), false, false, false, [identity, package_state])
	var condition: C_PackageState = package.get_component(C_PackageState) as C_PackageState
	condition.leaking = true
	PackageLifecycle.publish(package, PackageLifecycleEvent.Kind.Leaking)
	condition.damage = C_PackageState.Damage.DESTROYED
	PackageLifecycle.publish(package, PackageLifecycleEvent.Kind.Destroyed)
	assert(_effects().size() == 1, "Leaking then destroyed emits one zone")
	_world.remove_entity(package)
	await _tick(0.01)
	assert(_effects().size() == 1, "Package removal cannot retire its independent pool")
	_reset(true)


func _explosion_contract() -> void:
	var profile: DEF_Explosion = _blast()
	var emitter_a: C_HazardEmitter = C_HazardEmitter.new()
	emitter_a.definition = profile
	var emitter_b: C_HazardEmitter = C_HazardEmitter.new()
	emitter_b.definition = profile
	var barrel_a: Entity = _body(Vector3(40, 0, 0), true, false, false, [emitter_a])
	var barrel_b: Entity = _body(Vector3(41, 0, 0), true, false, false, [emitter_b])
	var receiver: Entity = _body(Vector3(40, 0, 2))
	var blocked: Entity = _body(Vector3(40, 0, -2))
	var outside: Entity = _body(Vector3(46, 0, 0))
	var loose: Entity = _body(Vector3(42, 0, 1), false, false, true)
	# Low-HP barrel fixture uses the same health and emitter composition as any destructible.
	(barrel_b.get_component(C_Health) as C_Health).current = 10.0
	_wall(Vector3(40, 0, -1))
	await _settle()
	assert(not barrel_a.has_component(C_Package) and not barrel_b.has_component(C_Package))
	var trigger: DamageRequest = DamageRequest.new()
	trigger.target = barrel_a
	trigger.instigator = receiver
	trigger.amount = 1000.0
	assert(DamageRequestService.submit(trigger))
	assert(_effects().size() == 1, "Non-Package depletion uses the same factory")
	_world.remove_entity(barrel_a)
	await _tick(0.01)
	assert(_effects().size() == 2, "Damage can activate another guarded emitter")
	assert(is_equal_approx(_hp(receiver), 50.0), "Center-distance linear falloff")
	await _tick(0.01)
	var after_blasts: float = _hp(receiver)
	assert(after_blasts < 50.0 and after_blasts > 0.0)
	assert(_hp(blocked) == 100.0 and _hp(outside) == 100.0, "Wall LOS and radius")
	await _tick(0.01)
	assert(_hp(receiver) == after_blasts, "Explosion never resolves twice")
	var rigid: RigidBody3D = loose as Node as RigidBody3D
	assert(not rigid.linear_velocity.is_zero_approx(), "Impulse applies to bodies without Health")
	assert((_spawned.back().get_component(C_Hazard) as C_Hazard).instigator_id == receiver.id)
	_reset(true)


func _blocked_explosion_contract() -> void:
	var origin: Entity = _body(Vector3(80, 0, 0), false, false, false, [C_NoDamage.new()])
	var receiver: Entity = _body(Vector3(81, 0, 0))
	await _settle()
	assert(
		HazardSpawnService.submit(_request(_blast(), Vector3(80, 0, 0), "blast-blocked", origin))
	)
	_world.remove_entity(origin)
	await _tick(0.01)
	assert(_hp(receiver) == 100.0 and _last_damage.outcome == DamageResult.Outcome.BLOCKED)


func _short_chain_contract() -> void:
	_reset(true)
	var profile: DEF_Explosion = _blast()
	profile.lifetime_seconds = 0.005
	var emitter: C_HazardEmitter = C_HazardEmitter.new()
	emitter.definition = profile
	var origin: Entity = _body(Vector3(100, 0, 0), false)
	# An ordinary layer-1 physical emitter must not block its own ray from inside the body.
	var origin_body: PhysicsBody3D = origin as Node as PhysicsBody3D
	origin_body.collision_layer = 1
	var successor: Entity = _body(Vector3(101, 0, 0), true, false, false, [emitter])
	(successor.get_component(C_Health) as C_Health).current = 10.0
	await _settle()
	assert(HazardSpawnService.submit(_request(profile, Vector3(100, 0, 0), "short-chain", origin)))
	await _tick(0.01)
	assert(_hp(successor) == 0.0, "Origin collider is excluded from LOS")
	assert(_effects().size() == 1, "New chained blast survives until its first resolution")
	var chained: C_Explosion = (_effects()[0] as Entity).get_component(C_Explosion) as C_Explosion
	assert(not chained.resolved)
	await _tick(0.01)
	assert(chained.resolved and _effects().is_empty())


func _body(
	location: Vector3,
	health: bool = true,
	living: bool = true,
	rigid: bool = false,
	extra: Array[Component] = [],
) -> Entity:
	var body: PhysicsBody3D = RigidBody3D.new() if rigid else StaticBody3D.new()
	body.set_script(Entity)
	body.position = location
	body.collision_layer = FIXTURE_LAYER
	body.collision_mask = 0
	if rigid:
		var rigid_body: RigidBody3D = body as RigidBody3D
		rigid_body.gravity_scale = 0.0

	var collider: CollisionShape3D = CollisionShape3D.new()
	var sphere: SphereShape3D = SphereShape3D.new()
	sphere.radius = SHAPE_RADIUS
	collider.shape = sphere
	body.add_child(collider)
	_world.add_child(body)
	var components: Array[Component] = extra.duplicate()
	if health:
		components.append(C_Health.new())
	if living:
		components.append(C_Living.new())
	var entity: Entity = body as Node as Entity
	_world.add_entity(entity, components, false)
	return entity


func _wall(location: Vector3) -> void:
	var wall: StaticBody3D = StaticBody3D.new()
	wall.position = location
	wall.collision_layer = 1
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(2, 2, 0.2)
	shape.shape = box
	wall.add_child(shape)
	_world.add_child(wall)


func _toxic(lifetime: float) -> DEF_ToxicArea:
	var definition: DEF_ToxicArea = DEF_ToxicArea.new()
	definition.scene = preload("res://content/entities/hazards/toxic_area.tscn")
	definition.tick_seconds = 0.25
	definition.damage_per_tick = 5.0
	definition.radius = 2.0
	definition.lifetime_seconds = lifetime
	return definition


func _blast() -> DEF_Explosion:
	var definition: DEF_Explosion = DEF_Explosion.new()
	definition.scene = preload("res://content/entities/hazards/explosion.tscn")
	definition.damage = 100.0
	definition.impulse = 4.0
	definition.lifetime_seconds = 0.35
	return definition


func _request(
	definition: DEF_Hazard,
	location: Vector3,
	key: String,
	origin: Entity = null,
) -> HazardSpawnRequest:
	var request: HazardSpawnRequest = HazardSpawnRequest.new()
	request.definition = definition
	request.request_id = key
	request.origin_id = key
	request.world_pose.origin = location
	request.origin = origin
	request.ownership = definition.ownership
	request.owner_loss = definition.owner_loss
	return request


func _reset(include_persistent: bool) -> void:
	var request: HazardResetRequest = HazardResetRequest.new()
	request.include_persistent = include_persistent
	_world.emit_event(HazardResetRequest.EVENT, null, request)


func _effects() -> Array:
	return _world.query.with_all([C_Hazard]).execute()


func _hp(entity: Entity) -> float:
	return (entity.get_component(C_Health) as C_Health).current


func _settle() -> void:
	for step: int in 3:
		await get_tree().physics_frame


func _tick(delta: float) -> void:
	await get_tree().physics_frame
	_world.process(delta, GROUP)


func _on_spawned(result: HazardSpawnResult) -> void:
	_spawned.append(result.hazard)


func _on_damage(result: DamageResult) -> void:
	_last_damage = result


class SpawnProbe extends Observer:
	var received: Callable


	func query() -> QueryBuilder:
		return q.on_event(HazardSpawnResult.EVENT)


	func each(_event: Variant, _entity: Entity, payload: Variant = null) -> void:
		received.call(payload as HazardSpawnResult)


class DamageProbe extends Observer:
	var received: Callable


	func query() -> QueryBuilder:
		return q.on_event(DamageResult.EVENT)


	func each(_event: Variant, _entity: Entity, payload: Variant = null) -> void:
		received.call(payload as DamageResult)
