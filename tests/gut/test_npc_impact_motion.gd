extends GutTest
## Native stationary NPC contact damage and measured motion before the CharacterBody migration.

const NPC_SCENE: PackedScene = preload("res://content/domains/npc/entities/npc_character.tscn")
const DELTA: float = 1.0 / 60.0
const SAMPLE_FRAMES: int = 120

var _world: World
var _npc: E_NpcCharacter
var _body: RigidBody3D
var _health: C_Health


#region Native contact fixture
func before_each() -> void:
	_world = World.new()
	add_child(_world)
	ECS.world = _world
	_world.add_observer(O_Damage.new())
	_world.add_system(S_Impact.new())
	var floor_body: StaticBody3D = StaticBody3D.new()
	var floor_shape: BoxShape3D = BoxShape3D.new()
	floor_shape.size = Vector3(30.0, 0.5, 30.0)
	floor_body.add_child(_collider(floor_shape))
	floor_body.position.y = -0.25
	_world.add_child(floor_body)
	_npc = NPC_SCENE.instantiate() as E_NpcCharacter
	EntityCompositionFixture.register(_world, _npc)
	_body = _npc as Node as RigidBody3D
	_body.global_position = Vector3(0.0, 0.02, 0.0)
	_health = _npc.get_component(C_Health) as C_Health
	_health.value = 100.0
	_health.current = 100.0
	for frame: int in 12:
		await _tick()
	_health.current = 100.0


func after_each() -> void:
	_world.purge(false)
	_world.free()
	ECS.world = null
	await get_tree().process_frame


func _collider(shape: Shape3D) -> CollisionShape3D:
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.shape = shape
	return collision


func _tick() -> Array[PhysicsContact]:
	await get_tree().physics_frame
	await get_tree().process_frame
	var inbox: C_ImpactInbox = _npc.get_component(C_ImpactInbox) as C_ImpactInbox
	var contacts: Array[PhysicsContact] = inbox.contacts.duplicate()
	_world.process(DELTA)
	return contacts


func _measure_free_impact(projectile_mass: float, projectile_speed: float) -> Dictionary:
	var projectile: RigidBody3D = RigidBody3D.new()
	projectile.mass = projectile_mass
	projectile.gravity_scale = 0.0
	projectile.linear_damp = 0.0
	projectile.angular_damp = 0.0
	projectile.continuous_cd = true
	projectile.collision_layer = 4
	projectile.collision_mask = 3
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3.ONE * 0.7
	projectile.add_child(_collider(shape))
	_world.add_child(projectile)
	projectile.global_position = Vector3(0.0, 0.85, -3.0)
	projectile.linear_velocity = Vector3(0.0, 0.0, projectile_speed)
	var origin: Vector3 = _body.global_position
	var peak_speed: float = 0.0
	var peak_upward: float = 0.0
	var maximum_height: float = origin.y
	var maximum_displacement: float = 0.0
	var contact_seen: bool = false
	for frame: int in SAMPLE_FRAMES:
		var contacts: Array[PhysicsContact] = await _tick()
		peak_speed = maxf(
			peak_speed,
			Vector2(_body.linear_velocity.x, _body.linear_velocity.z).length(),
		)
		peak_upward = maxf(peak_upward, _body.linear_velocity.y)
		maximum_height = maxf(maximum_height, _body.global_position.y)
		maximum_displacement = maxf(maximum_displacement, _body.global_position.distance_to(origin))
		for contact: PhysicsContact in contacts:
			if contact.body_b == projectile or contact.body_a == projectile:
				contact_seen = true
	var result: Dictionary = {
		"native_body": _body.get_class(),
		"npc_mass": _body.mass,
		"projectile_mass": projectile_mass,
		"projectile_speed": projectile_speed,
		"contact_seen": contact_seen,
		"health": _health.current,
		"peak_planar_speed": peak_speed,
		"peak_upward_speed": peak_upward,
		"maximum_height": maximum_height,
		"maximum_displacement": maximum_displacement,
		"frames": SAMPLE_FRAMES,
	}
	print("NATIVE_NPC_IMPACT_PROBE " + JSON.stringify(result))
	return result
#endregion


#region Free contact preserves damage
func test_light_free_box_damages_stationary_native_npc() -> void:
	var result: Dictionary = await _measure_free_impact(2.0, 30.0)
	assert_true(bool(result.contact_seen), "The native collider must actually contact this NPC")
	assert_lt(_health.current, 100.0, "Stationary NPC receives damage through S_Impact/O_Damage")


func test_heavy_free_body_damages_stationary_native_npc() -> void:
	var result: Dictionary = await _measure_free_impact(80.0, 20.0)
	assert_true(bool(result.contact_seen), "The native collider must actually contact this NPC")
	assert_lt(_health.current, 100.0, "Motion limits must not suppress actual heavy-contact damage")
#endregion
