extends Observer
## Replaces a destroyed Package with its scene-variant debris and removes the Package node.
class_name O_PackageDestruction

func query() -> QueryBuilder:
	return q.with_all([C_Package, C_PackageDestruction]).on_event(PackageLifecycleEvent.EVENT)

func each(_event: Variant, package: Entity, payload: Variant = null) -> void:
	var event: PackageLifecycleEvent = payload as PackageLifecycleEvent
	if event == null or event.kind != PackageLifecycleEvent.Kind.Destroyed:
		return
	if not EntityAvailability.contains(package, _world):
		return

	var identity: C_Package = package.get_component(C_Package) as C_Package
	var destruction: C_PackageDestruction = package.get_component(C_PackageDestruction) as C_PackageDestruction
	if identity == null or identity.definition == null or destruction == null:
		return
	if destruction.debris_scene == null:
		push_error("Destroyed Package has no C_PackageDestruction.debris_scene")
		return

	var body: RigidBody3D = package as Node as RigidBody3D
	var linear_velocity: Vector3 = body.linear_velocity if body != null else Vector3.ZERO
	var angular_velocity: Vector3 = body.angular_velocity if body != null else Vector3.ZERO
	var spatial: Node3D = package as Node as Node3D
	if spatial == null:
		return
	var world_pose: Transform3D = (
		event.cause.world_pose
		if event.cause != null and event.cause.world_pose.is_finite()
		else spatial.global_transform
	)
	cmd.add_custom(
		_replace_with_debris.bind(
			package,
			identity.package_id,
			identity.definition,
			destruction.debris_scene,
			world_pose,
			linear_velocity,
			angular_velocity,
			event.cause,
		)
	)

func _replace_with_debris(
	package: Entity,
	package_id: String,
	definition: DEF_Package,
	debris_scene: PackedScene,
	world_pose: Transform3D,
	linear_velocity: Vector3,
	angular_velocity: Vector3,
	cause: DamageResult,
) -> void:
	if not is_instance_valid(_world) or not EntityAvailability.contains(package, _world):
		return

	var node: Node = debris_scene.instantiate()
	var debris: E_PackageDebris = node as E_PackageDebris
	var spatial: Node3D = node as Node3D
	if debris == null or spatial == null:
		node.free()
		push_error("Package debris scene must use E_PackageDebris on a Node3D root")
		return

	debris.source_package_id = package_id
	debris.source_definition = definition
	debris.name = "Debris_%s" % package_id if not package_id.is_empty() else "PackageDebris"
	_world.add_child(debris)
	spatial.global_transform = world_pose

	var rigid: RigidBody3D = debris as Node as RigidBody3D
	if rigid != null:
		rigid.linear_velocity = linear_velocity
		rigid.angular_velocity = angular_velocity

	_world.add_entity(debris, null, false)

	var spawned: PackageDebrisSpawnedEvent = PackageDebrisSpawnedEvent.new()
	spawned.debris = debris
	spawned.package_id = package_id
	spawned.definition = definition
	spawned.cause = cause
	spawned.world_pose = world_pose
	_world.emit_event(PackageDebrisSpawnedEvent.EVENT, debris, spawned)

	_world.remove_entity(package)
	package.queue_free()
